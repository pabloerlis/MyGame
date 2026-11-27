extends RefCounted
## Adapter for Godot 4.4's existing FABRIK solver. No synthetic animation clips.
var rig: Skeleton3D
var ik: SkeletonIK3D
var tip_id := -1
var upper_id := -1
var lower_id := -1
var target_world := Vector3.ZERO
var before_cm := -1.0
var after_cm := -1.0
var state := "idle"

static func chain(skeleton: Skeleton3D, hand: int) -> PackedInt32Array:
	if not is_instance_valid(skeleton) or hand < 0 or hand >= skeleton.get_bone_count():
		return PackedInt32Array()
	var lower := -1
	var upper := -1
	var cursor := skeleton.get_bone_parent(hand)
	while cursor >= 0:
		var n := str(skeleton.get_bone_name(cursor)).to_lower().replace("_", "").replace(".", "").replace("-", "")
		if lower < 0 and ("lowerarm" in n or "forearm" in n):
			lower = cursor
		elif lower >= 0 and ("upperarm" in n or ("arm" in n and not "forearm" in n and not "lowerarm" in n)):
			upper = cursor
			break
		cursor = skeleton.get_bone_parent(cursor)
	if upper < 0 or lower < 0:
		return PackedInt32Array()
	return PackedInt32Array([upper, lower, hand])

static func reachable(a: Vector3, b: Vector3, c: Vector3, goal: Vector3) -> bool:
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var d := a.distance_to(goal)
	return l1 > 0.0001 and l2 > 0.0001 and d >= absf(l1 - l2) - 0.0001 and d <= l1 + l2 - 0.0001

func clear() -> void:
	if is_instance_valid(ik):
		ik.stop()
		ik.get_parent().remove_child(ik)
		ik.queue_free()
	ik = null
	rig = null
	tip_id = -1
	upper_id = -1
	lower_id = -1
	before_cm = -1.0
	after_cm = -1.0
	state = "idle"

func suspend(reason: String) -> void:
	if is_instance_valid(ik) and ik.is_running():
		ik.stop()
	before_cm = -1.0
	after_cm = -1.0
	state = reason

func apply(skeleton: Skeleton3D, hand: int, goal: Vector3, weight: float) -> void:
	var ids := chain(skeleton, hand)
	if ids.size() != 3 or not goal.is_finite():
		suspend("unsupported_rig")
		return
	if rig != skeleton or tip_id != hand or not is_instance_valid(ik):
		clear()
		rig = skeleton
		upper_id = ids[0]
		lower_id = ids[1]
		tip_id = ids[2]
		ik = SkeletonIK3D.new()
		ik.root_bone = rig.get_bone_name(upper_id)
		ik.tip_bone = rig.get_bone_name(tip_id)
		ik.override_tip_basis = false
		ik.max_iterations = 24
		ik.min_distance = 0.002
		rig.add_child(ik)
		ik.modification_processed.connect(_measure)
	var a := rig.to_global(rig.get_bone_global_pose(upper_id).origin)
	var b := rig.to_global(rig.get_bone_global_pose(lower_id).origin)
	var c := rig.to_global(rig.get_bone_global_pose(tip_id).origin)
	target_world = goal
	if not reachable(a, b, c, goal):
		suspend("out_of_reach")
		before_cm = c.distance_to(goal) * 100.0
		return
	before_cm = c.distance_to(goal) * 100.0
	ik.target = Transform3D(Basis.IDENTITY, goal)
	ik.influence = clampf(weight, 0.0, 1.0)
	if not ik.is_running():
		ik.start()
	state = "active"

func _measure() -> void:
	if state == "active" and is_instance_valid(rig) and tip_id >= 0:
		after_cm = rig.to_global(rig.get_bone_global_pose(tip_id).origin).distance_to(target_world) * 100.0

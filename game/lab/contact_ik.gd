extends RefCounted
## Selectable contact backends. FABRIK remains the default; RenIK is experimental.
const RenIK = preload("res://addons/renik/renik_limb.gd")
var renik: RenIK
var renik_target: Node3D
var backend := "godot_fabrik"
var samples := 0
var rig: Skeleton3D
var ik: SkeletonIK3D
var tip_id := -1
var upper_id := -1
var lower_id := -1
var target_world := Vector3.ZERO
var before_cm := -1.0
var after_cm := -1.0
var state := "idle"

static func is_contact_tip(name: String) -> bool:
	var n := name.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(":", "").replace(" ", "")
	for part in ["hand", "foot"]:
		for suffix in ["left" + part, "right" + part, part + "left", part + "right", part + "l", part + "r", "l" + part, "r" + part]:
			if n.ends_with(suffix):
				return true
	return n == "hand" or n == "foot"

static func chain(skeleton: Skeleton3D, hand: int) -> PackedInt32Array:
	if not is_instance_valid(skeleton) or hand < 0 or hand >= skeleton.get_bone_count():
		return PackedInt32Array()
	if not is_contact_tip(str(skeleton.get_bone_name(hand))):
		return PackedInt32Array()
	var lower := -1
	var upper := -1
	var tip_name := str(skeleton.get_bone_name(hand)).to_lower()
	var foot := "foot" in tip_name
	var cursor := skeleton.get_bone_parent(hand)
	while cursor >= 0:
		var n := str(skeleton.get_bone_name(cursor)).to_lower().replace("_", "").replace(".", "").replace("-", "")
		var lower_match := ("lowerleg" in n or "calf" in n or ("leg" in n and not "upperleg" in n and not "upleg" in n)) if foot else ("lowerarm" in n or "forearm" in n)
		var upper_match := ("upperleg" in n or "upleg" in n or "thigh" in n) if foot else ("upperarm" in n or ("arm" in n and not "forearm" in n and not "lowerarm" in n))
		if lower < 0 and lower_match:
			lower = cursor
		elif lower >= 0 and upper_match:
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

func select_backend(value: String) -> void:
	if value not in ["godot_fabrik", "renik"] or backend == value:
		return
	clear()
	backend = value

func clear() -> void:
	if is_instance_valid(renik):
		renik.active = false
		renik.get_parent().remove_child(renik)
		renik.queue_free()
	renik = null
	renik_target = null
	samples = 0
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
	if is_instance_valid(renik):
		renik.active = false
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
	if rig != skeleton or tip_id != hand or (not is_instance_valid(ik) and not is_instance_valid(renik)):
		clear()
		rig = skeleton
		upper_id = ids[0]
		lower_id = ids[1]
		tip_id = ids[2]
		if backend == "renik":
			renik = RenIK.new()
			renik.active = false
			renik.preset = 4
			renik.upper_bone = rig.get_bone_name(upper_id)
			renik.lower_bone = rig.get_bone_name(lower_id)
			renik.leaf_bone = rig.get_bone_name(tip_id)
			var hand_name := str(renik.leaf_bone).to_lower()
			renik.mirror = "right" in hand_name or hand_name.ends_with("_r") or hand_name.ends_with(".r")
			renik.has_shoulder = false
			renik.stretchiness = 0.0
			rig.add_child(renik)
			renik_target = Node3D.new()
			renik.add_child(renik_target)
			renik.target = renik_target
			renik.modification_processed.connect(_measure)
		else:
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
	state = "active"
	if is_instance_valid(renik):
		# Retain the incoming animation's hand orientation as the IK goal.
		# The upstream solver is designed around +Y aligned limb rests.
		if not _renik_rest_compatible():
			suspend("renik_rig_incompatible")
			return
		var basis := (rig.global_transform.basis * rig.get_bone_global_pose(tip_id).basis).orthonormalized()
		renik_target.global_transform = Transform3D(basis, goal)
		renik.influence = clampf(weight, 0.0, 1.0)
		renik.active = true
	else:
		ik.target = Transform3D(Basis.IDENTITY, goal)
		ik.influence = clampf(weight, 0.0, 1.0)
		if not ik.is_running():
			ik.start()

func _renik_rest_compatible() -> bool:
	# The upstream port constructs transforms with +Y as the limb axis.
	# Refuse unadapted rests instead of twisting a differently oriented rig.
	if rig.get_bone_parent(lower_id) != upper_id or rig.get_bone_parent(tip_id) != lower_id:
		return false
	for id in [lower_id, tip_id]:
		var rest := rig.get_bone_rest(id)
		if rest.origin.length() < 0.0001 or rest.origin.normalized().dot(Vector3.UP) < 0.99:
			return false
	return rig.get_bone_parent(upper_id) >= 0

func _measure() -> void:
	if state == "active" and is_instance_valid(rig) and tip_id >= 0:
		var error := rig.to_global(rig.get_bone_global_pose(tip_id).origin).distance_to(target_world) * 100.0
		if is_finite(error):
			after_cm = error
			samples += 1
		else:
			after_cm = -1.0
			state = "invalid_solution"

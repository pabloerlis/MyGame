extends RefCounted
# Classification from stable source names. Suggestions are not authored grip data.
static func category(name: String) -> String:
	var n := name.to_lower()
	if n.begins_with("pistol"): return "pistol"
	if n.begins_with("revolver"): return "revolver"
	if n.begins_with("shotgun"): return "shotgun"
	if n.begins_with("bow"): return "bow"
	if n.begins_with("shield"): return "shield"
	if n.begins_with("claymore") or n.begins_with("sword_big"): return "sword_two_handed"
	if n.begins_with("sword"): return "sword"
	if n.begins_with("dagger"): return "dagger"
	if n.begins_with("axe"): return "axe"
	if n.begins_with("pickaxe"): return "pickaxe"
	if n.begins_with("hammer"): return "hammer"
	if n.begins_with("spear"): return "spear"
	if n.begins_with("scythe"): return "scythe"
	if n.begins_with("fishing"): return "fishing"
	if n.begins_with("potion"): return "potion"
	if n.begins_with("torch"): return "torch"
	if n.begins_with("lantern"): return "lantern"
	return "other"

static func matches(name: String, clip: String) -> bool:
	var c := clip.to_lower()
	match category(name):
		"pistol": return c.contains("pistol")
		"revolver": return c.contains("pistol") and not c.contains("reload")
		"shotgun": return c.contains("shotgun")
		"sword": return c.contains("sword")
		"bow": return c.contains("bow_")
		"shield": return c.contains("shield")
		"axe": return c.contains("treechopping")
		"pickaxe": return c.contains("mining")
		"fishing": return c.contains("fish_")
		"potion": return c.contains("drink") or c.contains("consume")
		"torch": return c.contains("torch")
		"lantern": return c.contains("lantern")
		_: return false

static func find_grip(root: Node) -> Node3D:
	for node in root.get_children():
		if node is Node3D and not node is MeshInstance3D and str(node.name).to_lower() in ["grip", "grip_point", "grippoint", "socket_grip"]:
			return node
		var found := find_grip(node)
		if is_instance_valid(found):
			return found
	return null

static func source_label(source: String) -> String:
	match source:
		"manual": return "Ajuste individual"
		"category_unverified": return "Perfil da categoria (revisar)"
		"asset_marker_unverified": return "Marcador do asset (revisar)"
		"measured_model_unverified": return "Geometria medida (revisar)"
		"category_scale_unverified": return "Escala por categoria (revisar)"
		_: return "Pivô original (calibrar)"

# Source geometry measured from GLB position accessor bounds and node transforms.
# Fractions locate the estimated physical grip in the imported model's local AABB.
# They are not authored sockets or visually approved calibrations.
const MODEL_GRIPS := {
	"medieval_weapons_pack/Sword": Vector3(0.50, 0.150, 0.50),
	"medieval_weapons_pack/Axe": Vector3(0.185, 0.327, 0.50),
	"medieval_weapons_pack/Bow_Wooden": Vector3(0.278, 0.50, 0.50),
	"medieval_weapons_pack/Shield_Round": Vector3(0.50, 0.50, 0.15),
	"rpg_items_pack/Potion1_Filled": Vector3(0.50, 0.38, 0.50),
	"survival_pack/Pistol_1": Vector3(0.185, 0.35, 0.50)
}
# Stylized real-world reference dimensions, relative to a 1.75 m actor.
const TARGET_LENGTHS := {
	"pistol": 0.20, "revolver": 0.26, "shotgun": 0.95,
	"sword": 0.90, "sword_two_handed": 1.25, "dagger": 0.34,
	"axe": 0.72, "pickaxe": 0.80, "hammer": 0.65, "spear": 1.80,
	"scythe": 1.45, "bow": 1.15, "shield": 0.65, "potion": 0.16,
	"fishing": 1.70, "torch": 0.45, "lantern": 0.28
}

static func _local_boxes(node: Node, relative: Transform3D, boxes: Array[AABB]) -> void:
	var next := relative
	if node is Node3D:
		next = relative * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(next * node.get_aabb())
	for child in node.get_children():
		_local_boxes(child, next, boxes)

static func model_bounds(root: Node) -> AABB:
	var boxes: Array[AABB] = []
	for child in root.get_children():
		_local_boxes(child, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result := boxes[0]
	for i in range(1, boxes.size()):
		result = result.merge(boxes[i])
	return result

# Build a palm frame from the real hand's finger roots in rest pose.
# X points from wrist toward knuckles; Y points toward the index/thumb side.
# If finger metadata is absent, do not invent a rotation.
static func hand_frame(skeleton: Skeleton3D, bone: int) -> Dictionary:
	if bone < 0:
		return {}
	var index := Vector3.ZERO
	var little := Vector3.ZERO
	var center := Vector3.ZERO
	var count := 0
	for child in skeleton.get_bone_children(bone):
		var n := str(skeleton.get_bone_name(child)).to_lower()
		var point := skeleton.get_bone_rest(child).origin
		if "thumb" in n:
			continue
		if "index" in n:
			index = point
		elif "pinky" in n or "little" in n:
			little = point
		elif not ("middle" in n or "ring" in n):
			continue
		center += point
		count += 1
	if count == 0:
		return {}
	center /= float(count)
	var result := {"center": center * 0.65}
	var x := center.normalized()
	var across := index - little
	var y := (across - x * across.dot(x)).normalized()
	if index.length_squared() > 0.00000001 and little.length_squared() > 0.00000001 and x.length_squared() > 0.9 and y.length_squared() > 0.9:
		result["basis"] = Basis(x, y, x.cross(y).normalized()).orthonormalized()
	return result

static func fit(record: Dictionary, bounds: AABB, actor_height: float, parent_scale: float, hand: Dictionary) -> Dictionary:
	var kind := category(str(record.get("name", "")))
	var length := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if not TARGET_LENGTHS.has(kind) or length <= 0.000001 or parent_scale <= 0.000001 or not bounds.size.is_finite():
		return {}
	var target: float = float(TARGET_LENGTHS[kind]) * actor_height / 1.75
	var factor := clampf(target / (length * parent_scale), 0.01, 5.0)
	var key := str(record.get("pack", "")) + "/" + str(record.get("name", ""))
	var anchor := Vector3.ZERO
	var orientation := Basis.IDENTITY
	var source := "category_scale_unverified"
	if MODEL_GRIPS.has(key):
		var fractions: Vector3 = MODEL_GRIPS[key]
		anchor = bounds.position + bounds.size * fractions
		orientation = hand.get("basis", Basis.IDENTITY)
		source = "measured_model_unverified"
	var palm: Vector3 = hand.get("center", Vector3.ZERO)
	var basis := orientation * factor
	return {"transform": Transform3D(basis, palm - basis * anchor), "anchor": anchor, "target_m": target, "scale": factor, "source": source}

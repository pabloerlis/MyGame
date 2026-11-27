extends RefCounted
# Classification from stable source names. Suggestions are not authored grip data.
static func category(name: String) -> String:
	var n := name.to_lower()
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
		_: return "Pivô original (calibrar)"

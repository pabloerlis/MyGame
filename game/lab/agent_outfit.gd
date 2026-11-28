extends RefCounted
# Adapt the existing CC0 mannequin and reuse the existing black armour mesh.
# No changes to skeleton, bind weights, animation tracks, grip transforms or colliders.
const VEST_PATH := "res://assets/runtime/item-rpg_items_pack-Armor_Black.glb"
const ORIGINAL := "lab_original_mesh"
const MATERIALS := "lab_original_materials"

static func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is BoneAttachment3D:
		return
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		_meshes(child, out)

static func restore(actor: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(actor, meshes)
	for mesh in meshes:
		if mesh.has_meta(ORIGINAL):
			mesh.mesh = mesh.get_meta(ORIGINAL)
			var mats: Array = mesh.get_meta(MATERIALS)
			for i in range(mats.size()):
				mesh.set_surface_override_material(i, mats[i])
			mesh.remove_meta(ORIGINAL)
			mesh.remove_meta(MATERIALS)

static func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box := AABB()
	var first := true
	for mesh in meshes:
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _palette(height: float) -> Color:
	# Flat garment palette evaluated once in the mesh rest coordinates, not per pose.
	if height > 0.86:
		return Color("#c0a38e")
	if height > 0.54:
		return Color("#343c45")
	if height > 0.45:
		return Color("#161c22")
	if height > 0.12:
		return Color("#2b323a")
	return Color("#15191e")

static func _recolor(mesh: MeshInstance3D, box: AABB) -> void:
	var original := mesh.mesh as ArrayMesh
	if original == null or original.get_blend_shape_count() > 0:
		return
	var replacement := ArrayMesh.new()
	var previous: Array = []
	for i in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(i)
		if arrays.is_empty():
			return
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for j in range(vertices.size()):
			var world := mesh.global_transform * vertices[j]
			colors[j] = _palette(clampf((world.y - box.position.y) / box.size.y, 0.0, 1.0))
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := original.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		replacement.add_surface_from_arrays(original.surface_get_primitive_type(i), arrays, [], {}, flags)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.9
		replacement.surface_set_material(i, material)
		previous.append(mesh.get_surface_override_material(i))
	mesh.set_meta(ORIGINAL, original)
	mesh.set_meta(MATERIALS, previous)
	mesh.mesh = replacement
	for i in range(replacement.get_surface_count()):
		mesh.set_surface_override_material(i, null)

static func apply(actor: Node3D, skeleton: Skeleton3D) -> Node3D:
	var meshes: Array[MeshInstance3D] = []
	_meshes(actor, meshes)
	var box := _bounds(meshes)
	if box.size.y < 0.05:
		return null
	for mesh in meshes:
		_recolor(mesh, box)
	# Use a real existing garment asset; fit its rest bounds near the chest.
	# A rigid chest accessory is intentionally experimental until physical inspection.
	var chest := -1
	var best := 99.0
	for i in range(skeleton.get_bone_count()):
		var name := str(skeleton.get_bone_name(i)).to_lower()
		if "spine" not in name and "chest" not in name and "thorax" not in name:
			continue
		var world := skeleton.global_transform * skeleton.get_bone_global_rest(i).origin
		var height := (world.y - box.position.y) / box.size.y
		var score := absf(height - 0.71)
		if score < best:
			chest = i
			best = score
	if chest < 0 or not ResourceLoader.exists(VEST_PATH):
		return null
	var scene := load(VEST_PATH) as PackedScene
	if scene == null:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "AgentVest"
	skeleton.add_child(attachment)
	attachment.bone_idx = chest
	var wrapper := Node3D.new()
	attachment.add_child(wrapper)
	var model := scene.instantiate() as Node3D
	if model == null:
		attachment.free()
		return null
	wrapper.add_child(model)
	# Set wrapper in the skeleton rest frame so it follows subsequent bone poses.
	var rest := skeleton.global_transform * skeleton.get_bone_global_rest(chest)
	var model_meshes: Array[MeshInstance3D] = []
	_meshes(model, model_meshes)
	var garment_box := _bounds(model_meshes)
	if garment_box.size.y < 0.00001:
		attachment.free()
		return null
	var factor := box.size.y * 0.27 / garment_box.size.y
	var current_basis := wrapper.global_transform.basis
	if absf(current_basis.determinant()) < 0.000000000001:
		attachment.free()
		return null
	# Measure in world space and center in the chest region without resizing the actor.
	var desired := box.position + Vector3(box.size.x * 0.5, box.size.y * 0.72, box.size.z * 0.5)
	var initial := wrapper.global_transform
	var center := garment_box.get_center()
	var fitted := Transform3D(initial.basis.scaled(Vector3.ONE * factor), desired + (initial.origin - center) * factor)
	wrapper.transform = rest.affine_inverse() * fitted
	for m in model_meshes:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#20272e")
		material.roughness = 0.85
		m.material_override = material
	return attachment

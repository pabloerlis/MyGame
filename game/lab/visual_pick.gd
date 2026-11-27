extends RefCounted
# Mesh AABBs (including bind-pose skinned bounds) are approximate pick volumes.
static func _meshes(node: Node, skip_attached: bool, out: Array[MeshInstance3D]) -> void:
	if skip_attached and node is BoneAttachment3D:
		return
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_meshes(child, skip_attached, out)

static func hit_distance(node: Node3D, origin: Vector3, end: Vector3, skip_attached: bool = false) -> float:
	var meshes: Array[MeshInstance3D] = []
	_meshes(node, skip_attached, meshes)
	var best := INF
	for mesh in meshes:
		if absf(mesh.global_transform.basis.determinant()) < 0.000000000001:
			continue
		var inverse := mesh.global_transform.affine_inverse()
		var hit: Variant = mesh.get_aabb().intersects_segment(inverse * origin, inverse * end)
		if hit is Vector3:
			var world_hit: Vector3 = mesh.global_transform * hit
			best = minf(best, origin.distance_to(world_hit))
	return best

static func screen_bounds(node: Node3D, camera: Camera3D, skip_attached: bool = false) -> Rect2:
	var meshes: Array[MeshInstance3D] = []
	_meshes(node, skip_attached, meshes)
	var result := Rect2()
	var found := false
	for mesh in meshes:
		var bounds := mesh.get_aabb()
		for i in range(8):
			var point := mesh.global_transform * bounds.get_endpoint(i)
			if camera.is_position_behind(point):
				continue
			var p := camera.unproject_position(point)
			if not found:
				result = Rect2(p, Vector2.ZERO)
				found = true
			else:
				result = result.expand(p)
	return result

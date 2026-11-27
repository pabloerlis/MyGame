extends RefCounted
## Infer a seat surface and back direction from the original chair triangles.
## Coordinates are in the floor-centred context root, before scaling.
static func _faces(node: Node, root: Node3D, out: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var relative: Transform3D = root.global_transform.affine_inverse() * node.global_transform
		for vertex in node.mesh.get_faces():
			out.append(relative * vertex)
	for child in node.get_children():
		_faces(child, root, out)

static func geometry(root: Node3D, model: Node3D, size: Vector3) -> Dictionary:
	var faces: Array[Vector3] = []
	_faces(model, root, faces)
	var bins := {}
	var step := maxf(size.y * 0.012, 0.000001)
	for i in range(0, faces.size() - 2, 3):
		var normal := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		var area := normal.length() * 0.5
		var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if area <= 0.000000001 or absf(normal.normalized().y) < 0.96:
			continue
		if center.y < size.y * 0.30 or center.y > size.y * 0.74:
			continue
		var key := roundi(center.y / step)
		var bin: Dictionary = bins.get(key, {"area": 0.0, "sum": Vector3.ZERO})
		bin["area"] = float(bin["area"]) + area
		bin["sum"] = Vector3(bin["sum"]) + center * area
		bins[key] = bin
	var seat := Vector3(0.0, size.y * 0.50, 0.0)
	var best := 0.0
	var found := false
	for key in bins:
		var bin: Dictionary = bins[key]
		var area: float = bin["area"]
		var center: Vector3 = bin["sum"] / area
		if area > best * 1.015 or (area >= best * 0.985 and center.y > seat.y):
			best = area
			seat = center
			found = true
	# Backrest is the high geometry behind the seat. Area weight avoids mesh density bias.
	var back := Vector3.ZERO
	var weight := 0.0
	for i in range(0, faces.size() - 2, 3):
		var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if center.y < seat.y + size.y * 0.16:
			continue
		var area := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length() * 0.5
		back += center * area
		weight += area
	var forward := Vector3.FORWARD
	if weight > 0.000000001:
		var direction := seat - back / weight
		direction.y = 0.0
		if direction.length() > maxf(size.x, size.z) * 0.06:
			forward = direction.normalized()
	return {"seat": seat, "forward": forward, "measured": found}

static func pose(skeleton: Skeleton3D) -> Dictionary:
	var hips := -1
	var thighs: Array[int] = []
	var knees: Array[int] = []
	for i in range(skeleton.get_bone_count()):
		var n := str(skeleton.get_bone_name(i)).to_lower().replace("_", "").replace(".", "").replace("-", "").replace(":", "")
		if n.ends_with("hips") or n.ends_with("pelvis") or n == "hip":
			hips = i
		if "thigh" in n or "upleg" in n or "upperleg" in n or "legupper" in n:
			if not "twist" in n:
				thighs.append(i)
		elif "shin" in n or "calf" in n or "lowerleg" in n or "leglower" in n or n.ends_with("leftleg") or n.ends_with("rightleg") or n == "legl" or n == "legr":
			if not "twist" in n:
				knees.append(i)
	if knees.size() < 2:
		knees.clear()
		for thigh in thighs:
			var children := skeleton.get_bone_children(thigh)
			if not children.is_empty():
				knees.append(children[0])
	var hip := Vector3.ZERO
	if hips >= 0:
		hip = skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
	elif thighs.size() >= 2:
		for thigh in thighs:
			hip += skeleton.to_global(skeleton.get_bone_global_pose(thigh).origin)
		hip /= float(thighs.size())
	else:
		return {}
	var forward := Vector3.ZERO
	if knees.size() >= 2:
		for knee in knees:
			forward += skeleton.to_global(skeleton.get_bone_global_pose(knee).origin)
		forward = forward / float(knees.size()) - hip
		forward.y = 0.0
	return {"hip": hip, "forward": forward}

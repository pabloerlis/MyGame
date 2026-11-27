extends RefCounted
## Normalized coordinates on an approximate box. Shape scales with its real asset.
static func nearest_surface(point: Vector3, half: Vector3) -> Vector3:
	var safe := half.max(Vector3.ONE * 0.005)
	var p := point.clamp(-safe, safe)
	if p.is_equal_approx(point):
		var d := safe - p.abs()
		var axis := 0
		if d.y < d[axis]:
			axis = 1
		if d.z < d[axis]:
			axis = 2
		p[axis] = safe[axis] if p[axis] >= 0.0 else -safe[axis]
	return p / safe

static func top_surface(point: Vector3, half: Vector3) -> Vector3:
	var safe := half.max(Vector3.ONE * 0.005)
	return Vector3(clampf(point.x / safe.x, -1.0, 1.0), 1.0, clampf(point.z / safe.z, -1.0, 1.0))

static func phase_weight(phase: float, center: float, span: float) -> float:
	# No wrap: a capture near start/end is not automatically a contact at both.
	var distance := absf(phase - center)
	var radius := maxf(span * 0.5, 0.001)
	var fade := minf(radius * 0.5, 0.05)
	return 1.0 - smoothstep(radius - fade, radius, distance)

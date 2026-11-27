extends RefCounted
## Phase-driven translation of an outer actor node, independent of imported tracks.
## Context collider is an approximate box. No claim of full body collision.
static func proposed_offset(tip: Vector3, goal: Vector3, weight: float, maximum: float, axes: int) -> Vector3:
	if not tip.is_finite() or not goal.is_finite():
		return Vector3.ZERO
	var delta := goal - tip
	if axes == 1:
		delta.y = 0.0
	elif axes == 2:
		delta.x = 0.0
		delta.z = 0.0
	return delta.limit_length(maxf(maximum, 0.0)) * clampf(weight, 0.0, 1.0)

static func blocked_segment(start: Vector3, finish: Vector3, half: Vector3, radius: float) -> bool:
	var extent := half.abs() + Vector3.ONE * maxf(radius, 0.0)
	var box := AABB(-extent, extent * 2.0)
	return box.has_point(start) or box.has_point(finish) or box.intersects_segment(start, finish) != null

static func safe_fraction(points: PackedVector3Array, delta: Vector3, half: Vector3, radius: float) -> float:
	if points.is_empty():
		return 0.0
	if delta.is_zero_approx():
		return 1.0
	var lo := 0.0
	var hi := 1.0
	for i in range(9):
		var fraction := hi if i == 0 else (lo + hi) * 0.5
		var blocked := false
		for point in points:
			if blocked_segment(point, point + delta * fraction, half, radius):
				blocked = true
				break
		if blocked:
			hi = fraction
		else:
			lo = fraction
			if i == 0:
				return 1.0
	return lo

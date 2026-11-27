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

## Weighted compromise: one translation for all active constraints.
## Divide by at least one so a single fading contact remains smooth.
static func compromise(offsets: PackedVector3Array, weights: PackedFloat32Array, maximum: float) -> Vector3:
	if offsets.size() != weights.size():
		return Vector3.ZERO
	var total := Vector3.ZERO
	var weight_sum := 0.0
	for i in range(offsets.size()):
		var weight := clampf(weights[i], 0.0, 1.0)
		if offsets[i].is_finite() and is_finite(weight):
			total += offsets[i] * weight
			weight_sum += weight
	return (total / maxf(1.0, weight_sum)).limit_length(maxf(0.0, maximum))

## Weighted planar rigid alignment. Translation is removed by centering.
## At least two distinct points are required; no inferred yaw from one contact.
static func fitted_yaw(points: PackedVector3Array, goals: PackedVector3Array, weights: PackedFloat32Array, maximum: float) -> float:
	if points.size() != goals.size() or points.size() != weights.size() or points.size() < 2:
		return 0.0
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var total := 0.0
	var count := 0
	for i in range(points.size()):
		if not points[i].is_finite() or not goals[i].is_finite() or not is_finite(weights[i]):
			return 0.0
		var w := clampf(weights[i], 0.0, 1.0)
		if w <= 0.001:
			continue
		a += points[i] * w
		b += goals[i] * w
		total += w
		count += 1
	if count < 2 or total <= 0.001:
		return 0.0
	a /= total
	b /= total
	var dot := 0.0
	var cross := 0.0
	for i in range(points.size()):
		var u := points[i] - a
		var v := goals[i] - b
		var w := clampf(weights[i], 0.0, 1.0)
		dot += w * (u.x * v.x + u.z * v.z)
		cross += w * (u.z * v.x - u.x * v.z)
	if absf(dot) + absf(cross) < 0.000001:
		return 0.0
	var bound := maxf(maximum, 0.0)
	return clampf(atan2(cross, dot), -bound, bound) * minf(total / 2.0, 1.0)

## Guard a yaw sweep of torso proxies against a world-space box.
## Chords are expanded by the maximum arc sagitta, conservatively.
## A blocked sweep is rejected instead of forcing rotation through geometry.
static func yaw_is_clear(points: PackedVector3Array, pivot: Vector3, angle: float, box_world: Transform3D, half: Vector3, radius: float) -> bool:
	if points.is_empty() or not is_finite(angle):
		return false
	if is_zero_approx(angle):
		return true
	var inv := box_world.affine_inverse()
	var steps := maxi(1, ceili(absf(angle) / deg_to_rad(5.0)))
	for point in points:
		var offset := point - pivot
		var planar_radius := Vector2(offset.x, offset.z).length()
		var sagitta := planar_radius * (1.0 - cos(absf(angle) / float(steps) * 0.5))
		var last := inv * point
		for i in range(1, steps + 1):
			var next := inv * (pivot + offset.rotated(Vector3.UP, angle * float(i) / float(steps)))
			if blocked_segment(last, next, half, radius + sagitta):
				return false
			last = next
	return true

extends RefCounted
## Quasi-static geometric proxy: capsule around the line between foot anchors.
## Not a mass distribution, force, or dynamic stability solver.
static func closest_support(center: Vector3, foot_a: Vector3, foot_b: Vector3) -> Vector3:
	var p := Vector3(center.x, 0, center.z)
	var a := Vector3(foot_a.x, 0, foot_a.z)
	var b := Vector3(foot_b.x, 0, foot_b.z)
	var line := b - a
	var t := 0.0
	if line.length_squared() > 0.000001:
		t = clampf((p - a).dot(line) / line.length_squared(), 0.0, 1.0)
	return a + line * t

static func correction(center: Vector3, a: Vector3, b: Vector3, radius: float, maximum: float) -> Vector3:
	if not center.is_finite() or not a.is_finite() or not b.is_finite():
		return Vector3.ZERO
	var p := Vector3(center.x, 0, center.z)
	var delta := closest_support(center, a, b) - p
	var distance := delta.length()
	if distance <= maxf(radius, 0.0) or distance < 0.000001:
		return Vector3.ZERO
	return delta.normalized() * minf(distance - maxf(radius, 0.0), maxf(maximum, 0.0))

static func support_error(center: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var p := Vector3(center.x, 0, center.z)
	return maxf(0.0, p.distance_to(closest_support(center, a, b)) - maxf(radius, 0.0))

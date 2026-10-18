extends RefCounted

var active := false
var blend := 0.0
var turn_side := 1.0


func reset() -> void:
	active = false
	blend = 0.0
	turn_side = 1.0


func rudder(offset: Vector2, heading: float, manual: float, drift: Vector2,
		yaw_rate: float, delta: float, radius: float, soft_fraction: float,
		inward_bias: float, forward_speed: float = 6.3) -> float:
	var distance := offset.length()
	var radial := offset / maxf(distance, 0.001)
	var forward := Vector2(sin(heading), -cos(heading))
	var right := Vector2(cos(heading), sin(heading))
	var outward_speed := (forward * forward_speed + drift).dot(radial)
	var soft_radius := radius * soft_fraction
	if not active and distance >= soft_radius and outward_speed > 0.1:
		active = true
		var tangent := Vector2(-radial.y, radial.x)
		var tangent_turn := wrapf(atan2(tangent.x, -tangent.y) - heading, -PI, PI)
		turn_side = signf(manual) if absf(manual) > 0.1 else signf(tangent_turn)
		if turn_side == 0.0:
			turn_side = 1.0
	if distance < soft_radius - 12.0:
		active = false
	var weight := maxf(0.35, smoothstep(soft_radius, radius - 8.0, distance)) if active else 0.0
	blend = move_toward(blend, weight, delta * 1.8)
	if blend <= 0.0:
		return manual
	var tangent := Vector2(-radial.y, radial.x) * turn_side
	var desired := (tangent - radial * inward_bias).normalized()
	var error := wrapf(atan2(desired.x, -desired.y) - heading, -PI, PI)
	var automatic := clampf(error * 2.4 - yaw_rate * 0.6, -1.0, 1.0)
	if manual * right.dot(radial) < -0.05 and manual * automatic < 0.0:
		return manual
	return lerpf(manual, automatic, blend)


func bounded_motion(offset: Vector3, motion: Vector3, radius: float) -> Vector3:
	var next := offset + motion
	next.y = 0.0
	if next.length() <= radius:
		return motion
	# Integrate a bounded step before collision sweeping. No post-move relocation,
	# hidden wall or heading snap; tangential motion remains available at the rim.
	return next.normalized() * radius - offset

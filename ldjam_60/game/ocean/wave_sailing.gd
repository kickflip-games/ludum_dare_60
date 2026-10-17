extends RefCounted
## Arcade horizontal momentum; the visible wave supplies all external forcing.
var drift := Vector2.ZERO
var yaw_rate := 0.0
var rudder_rate := 0.0
var displacement := Vector2.ZERO
const DRAG := 0.85
const YAW_DRAG := 2.1
# The wave's centre of pressure is forward of the hull's lateral resistance.
# This bow lever converts a broadside shove into a lasting change of heading.
const WAVE_PRESSURE_LEVER := 0.55
const MAX_WAVE_YAW_RATE := 0.56

func reset() -> void:
	drift = Vector2.ZERO
	yaw_rate = 0.0
	rudder_rate = 0.0
	displacement = Vector2.ZERO

func step(field: RefCounted, center: Vector2, heading: float, steering: float, time: float, delta: float) -> float:
	# Resolve the crest crossing at up to 120 Hz, including movement within a tick.
	# Otherwise stronger turning changes time spent on the crest differently at 30/120 Hz.
	displacement = Vector2.ZERO
	var steps := maxi(1, ceili(delta * 120.0 - 0.00001))
	var dt := delta / steps
	for i in range(steps):
		var old_velocity := Vector2(sin(heading), -cos(heading)) * 6.3 + drift
		var old_turn := rudder_rate + yaw_rate
		var mid_heading := heading + old_turn * dt * 0.5
		var mid_center := center + displacement + old_velocity * dt * 0.5
		_integrate_forces(field, mid_center, mid_heading, steering, time - delta + (i + 0.5) * dt, dt)
		heading = wrapf(heading + (old_turn + rudder_rate + yaw_rate) * 0.5 * dt, -PI, PI)
		var new_velocity := Vector2(sin(heading), -cos(heading)) * 6.3 + drift
		displacement += (old_velocity + new_velocity) * 0.5 * dt
	return heading

func _integrate_forces(field: RefCounted, center: Vector2, heading: float, steering: float, time: float, delta: float) -> void:
	var forward := Vector2(sin(heading), -cos(heading))
	var right := Vector2(cos(heading), sin(heading))
	var acceleration := Vector2.ZERO
	var torque := 0.0
	for arm: Vector2 in [Vector2.ZERO, forward * 2.1, -forward * 2.1, right * 1.05, -right * 1.05]:
		var force: Vector2 = field.push_at(center + arm, heading, time)
		acceleration += force / 5.0
		torque += (arm + forward * WAVE_PRESSURE_LEVER).cross(force) / 5.0 * 0.75
	var drag_decay := exp(-DRAG * delta)
	drift = (drift * drag_decay + acceleration * (1.0 - drag_decay) / DRAG).limit_length(3.8)
	var yaw_decay := exp(-YAW_DRAG * delta)
	yaw_rate = clampf(yaw_rate * yaw_decay + torque * (1.0 - yaw_decay) / YAW_DRAG, -MAX_WAVE_YAW_RATE, MAX_WAVE_YAW_RATE)
	rudder_rate = lerpf(rudder_rate, clampf(steering, -1.0, 1.0) * 0.72, 1.0 - exp(-7.0 * delta))

func slide(normal: Vector2) -> void:
	if drift.dot(normal) < 0.0:
		drift = drift.slide(normal)

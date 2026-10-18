extends RefCounted
## Presentation only. Coordinates: +X starboard, -Z bow, positive pitch lifts bow.
const Field = preload("res://game/ocean/wave_field.gd")
const POSITION_RATE := 18.0
const ANGLE_RATE := 13.0
const IMPACT_RATE := 10.0
var initialized := false
var height := 0.0
var height_velocity := 0.0
var angles := Vector3.ZERO
var angle_velocity := Vector3.ZERO
var impact := Vector3.ZERO # local lateral, compression, unused
var impact_velocity := Vector3.ZERO
var kick := Vector3.ZERO # pitch, unused, roll
var kick_velocity := Vector3.ZERO
var contacts: Dictionary = {}
var events: Array[Dictionary] = []
var previous_position := Vector3.ZERO
var previous_time := -1.0
var impact_count := 0
var snapped := false


static func spring(value: Vector3, velocity: Vector3, target: Vector3, rate: float, dt: float) -> Array[Vector3]:
	# Exact critically damped solution for a constant target; stable at any dt.
	var offset := value - target
	var c := velocity + offset * rate
	var decay := exp(-rate * dt)
	return [target + (offset + c * dt) * decay, (velocity - c * rate * dt) * decay]


func reset() -> void:
	initialized = false
	height_velocity = 0.0
	angles = Vector3.ZERO
	angle_velocity = Vector3.ZERO
	impact = Vector3.ZERO
	impact_velocity = Vector3.ZERO
	kick = Vector3.ZERO
	kick_velocity = Vector3.ZERO
	contacts.clear()
	events.clear()
	previous_time = -1.0
	impact_count = 0


func pose(anchor: Node3D, boat: Node3D, motion: RefCounted, ocean: Node3D,
		heading: float, glance: float, dt: float, motion_scale: float, active: bool) -> Transform3D:
	events.clear()
	var at := anchor.global_position
	var time: float = ocean.wave_time
	var discontinuity := not initialized or at.distance_to(previous_position) > 12.0 or dt > 0.25 or time < previous_time
	snapped = discontinuity
	if discontinuity:
		reset()
		height = at.y
		initialized = true
	# Most heave comes directly from the authored anchor, including the pivot lever.
	var target_angles := Vector3(
		(motion.pitch - motion.sailing_pitch) * 0.78 + motion.sailing_pitch * 0.25,
		0.0, (motion.roll - motion.sailing_roll) * 0.52 + motion.sailing_roll * 0.12)
	target_angles.x = clampf(target_angles.x, -0.12, 0.12) * motion_scale
	target_angles.z = clampf(target_angles.z, -0.105, 0.105) * motion_scale
	if discontinuity:
		angles = target_angles
	var step := clampf(dt, 0.0, 0.25)
	var h := spring(Vector3(0,height,0), Vector3(0,height_velocity,0), Vector3(0,at.y,0), POSITION_RATE, step)
	height = h[0].y
	height_velocity = h[1].y
	var a := spring(angles, angle_velocity, target_angles, ANGLE_RATE, step)
	angles = a[0]
	angle_velocity = a[1]
	var i := spring(impact, impact_velocity, Vector3.ZERO, IMPACT_RATE, step)
	impact = i[0]
	impact_velocity = i[1]
	var k := spring(kick, kick_velocity, Vector3.ZERO, IMPACT_RATE, step)
	kick = k[0]
	kick_velocity = k[1]
	if active and not discontinuity and step > 0.0:
		_sample_contacts(boat, ocean, step)
	elif not active:
		contacts.clear()
		impact = Vector3.ZERO
		impact_velocity = Vector3.ZERO
		kick = Vector3.ZERO
		kick_velocity = Vector3.ZERO
	previous_position = at
	previous_time = time
	# Vertical lag never exceeds 14 cm: the deck remains a solid foreground reference.
	at.y += clampf(height - at.y, -0.14, 0.14) + clampf(impact.y, -0.13, 0.10) * motion_scale
	var orientation := Basis(Vector3.UP, -heading)
	at += orientation * Vector3(clampf(impact.x, -0.10, 0.10) * motion_scale, 0, 0)
	var view_angles := angles + Vector3(clampf(kick.x,-0.035,0.035),0,clampf(kick.z,-0.035,0.035)) * motion_scale
	view_angles.x -= deg_to_rad(7.0)
	# Glance turns the head on the same deck anchor, without moving the hull or gun.
	var basis := orientation * Basis.from_euler(view_angles) * Basis(Vector3.UP, -deg_to_rad(75.0) * glance)
	if not at.is_finite() or not basis.is_finite():
		reset()
		return Transform3D(orientation, anchor.global_position)
	return Transform3D(basis, at)


func _sample_contacts(boat: Node3D, ocean: Node3D, dt: float) -> void:
	var center: Vector3 = boat.to_global(Vector3(0,0,-2.1))
	var p := Vector2(center.x,center.z)
	var live: Dictionary = {}
	for w: Dictionary in ocean.wave_field.waves:
		live[w.id] = true
		var sample_value := Field.sample_one(w,p,ocean.wave_time)
		var h: float = sample_value.x
		var contact: Dictionary = contacts.get(w.id, {"height":h,"peak":0.0,"speed":0.0,"fired":false})
		# The difference is bounded, filtered and reset across clock gaps/teleports.
		var velocity := clampf((h - float(contact.height)) / dt, -6.0, 6.0)
		contact.speed = lerpf(contact.speed, velocity, 1.0-exp(-12.0*dt))
		contact.height = h
		contact.peak = maxf(contact.peak,h)
		# One compression per event on its descending face, with peak hysteresis.
		if not contact.fired and contact.peak > 0.28 and h > 0.12 and contact.speed < -0.32:
			contact.fired = true
			var strength := clampf(contact.peak / 1.85 * absf(contact.speed) / 1.8, 0.12, 1.0)
			var d: Vector2 = w.direction
			var local := boat.global_basis.inverse() * Vector3(d.x,0,d.y)
			impact_velocity = (impact_velocity + Vector3(local.x*0.85,-1.8,0)*strength).limit_length(2.8)
			kick_velocity = (kick_velocity + Vector3(-local.z*0.7,0,-local.x*0.7)*strength).limit_length(1.2)
			events.append({"id":w.id,"strength":strength,"direction":local,"time":ocean.wave_time})
			impact_count += 1
		contacts[w.id] = contact
	for id in contacts.keys():
		if not live.has(id):
			contacts.erase(id)

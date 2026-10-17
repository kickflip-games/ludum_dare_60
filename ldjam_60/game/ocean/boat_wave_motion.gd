extends RefCounted
## Applies only to the dedicated model pivot; the movement/collision root stays planar.

var heave: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var initialized: bool = false
const HULL_CENTER := Vector3(0.0, 0.0, -2.1)
const HALF_LENGTH: float = 2.1
const HALF_BEAM: float = 1.05


func update_motion(ocean: Node3D, boat: Node3D, visual: Node3D, delta: float, snap: bool = false) -> void:
	var settings = ocean.settings
	var center: Vector3 = boat.to_global(HULL_CENTER)
	var forward: Vector3 = -boat.global_basis.z
	var right: Vector3 = boat.global_basis.x
	var bow: Vector3 = center + forward * HALF_LENGTH
	var stern: Vector3 = center - forward * HALF_LENGTH
	var port: Vector3 = center - right * HALF_BEAM
	var starboard: Vector3 = center + right * HALF_BEAM
	var h_bow: float = ocean.height_at(Vector2(bow.x, bow.z))
	var h_stern: float = ocean.height_at(Vector2(stern.x, stern.z))
	var h_port: float = ocean.height_at(Vector2(port.x, port.z))
	var h_starboard: float = ocean.height_at(Vector2(starboard.x, starboard.z))
	var h_center: float = ocean.height_at(Vector2(center.x, center.z))
	var average_height: float = h_center * 0.5 + (h_bow + h_stern + h_port + h_starboard) * 0.125
	var target_heave: float = settings.sea_level + (average_height - settings.sea_level) * settings.bob_strength
	var target_pitch: float = clampf(atan2(h_bow - h_stern, HALF_LENGTH * 2.0) * settings.pitch_strength,
		-deg_to_rad(settings.pitch_limit_degrees), deg_to_rad(settings.pitch_limit_degrees))
	var target_roll: float = clampf(atan2(h_starboard - h_port, HALF_BEAM * 2.0) * settings.roll_strength,
		-deg_to_rad(settings.roll_limit_degrees), deg_to_rad(settings.roll_limit_degrees))
	var amount: float = 1.0 if snap or not initialized else 1.0 - exp(-settings.motion_damping * delta)
	heave = lerpf(heave, target_heave, amount)
	pitch = lerp_angle(pitch, target_pitch, amount)
	roll = lerp_angle(roll, target_roll, amount)
	initialized = true
	var rotation_basis := Basis.from_euler(Vector3(pitch, 0.0, roll))
	visual.basis = rotation_basis
	# Rotate around hull center, not the helm at the stern.
	visual.position = HULL_CENTER - rotation_basis * HULL_CENTER + Vector3(0.0, heave + settings.hull_draft_offset, 0.0)


func reset() -> void:
	initialized = false

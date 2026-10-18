extends RefCounted
## Applies only to the dedicated model pivot; the movement/collision root stays planar.

var heave: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var sailing_pitch: float = 0.0
var sailing_roll: float = 0.0
var initialized: bool = false
const HULL_CENTER := Vector3(0.0, 0.0, -2.1)
const HALF_LENGTH: float = 2.1
const HALF_BEAM: float = 1.05


func update_motion(ocean: Node3D, boat: Node3D, visual: Node3D, delta: float, snap: bool = false,
		speed_ratio: float = 0.0, turn_rate: float = 0.0) -> void:
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
	# The deck eye exposes the old centre-weighted hull lag at a broadside crest:
	# the high-side gunwale vanished under water while the centre was still low.
	# Keep the same five samples and damping, with at most 50 cm of extra support
	# as an edge rises. This only lifts the visual pivot, never the collision root.
	var edge_height := maxf(maxf(h_bow,h_stern),maxf(h_port,h_starboard))
	target_heave = maxf(target_heave,minf(target_heave+0.50,edge_height-0.50))
	var target_pitch: float = clampf(atan2(h_bow - h_stern, HALF_LENGTH * 2.0) * settings.pitch_strength,
		-deg_to_rad(settings.pitch_limit_degrees), deg_to_rad(settings.pitch_limit_degrees))
	var target_roll: float = clampf(atan2(h_starboard - h_port, HALF_BEAM * 2.0) * settings.roll_strength,
		-deg_to_rad(settings.roll_limit_degrees), deg_to_rad(settings.roll_limit_degrees))
	# A little sail-driven heel underway; bank into the actual turn, including wave yaw.
	# Actual displacement gates this response, so a blocked hull settles naturally.
	var speed_weight := clampf(speed_ratio, 0.0, 1.0)
	var sailing_amount := 1.0 if snap or not initialized else 1.0 - exp(-3.5 * delta)
	sailing_pitch = lerpf(sailing_pitch, deg_to_rad(1.3) * speed_weight, sailing_amount)
	sailing_roll = lerpf(sailing_roll,
		deg_to_rad(-1.8 - 10.0 * clampf(turn_rate / 0.72, -1.0, 1.0)) * speed_weight, sailing_amount)
	target_pitch = clampf(target_pitch + sailing_pitch,
		-deg_to_rad(settings.pitch_limit_degrees), deg_to_rad(settings.pitch_limit_degrees))
	target_roll = clampf(target_roll + sailing_roll,
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
	sailing_pitch = 0.0
	sailing_roll = 0.0

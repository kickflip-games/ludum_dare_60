extends Node3D
## A hand-placed, short crossing. All gameplay distances are in metres.

const HUD_SCRIPT = preload("res://game/navigation_hud.gd")
const OceanController = preload("res://game/ocean/ocean_controller.gd")
const WaveSettings = preload("res://game/ocean/wave_settings.gd")
const BoatWaveMotion = preload("res://game/ocean/boat_wave_motion.gd")
const SKY_SHADER = preload("res://game/night_sky.gdshader")
const CANNON_SCRIPT = preload("res://game/broadside_cannon.gd")
const PIRATE_SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const PIRATE_ROCK = preload("res://assets/pirate_kit/rock.glb")
const CREATURE_SCRIPT = preload("res://game/sea_creatures.gd")
const SPEED: float = 6.3
const TURN_SPEED: float = 0.48
const TARGET_HEADING: float = PI / 6.0
const CROSSING_LENGTH: float = 530.0
const ARRIVAL_RADIUS: float = 58.0
const BEACON_REVEAL_DISTANCE: float = 150.0
const START_HEADING: float = PI * 0.28
const CAST_OFF_SECONDS: float = 1.25

@export_group("Ocean")
@export var ocean_settings: WaveSettings = preload("res://game/ocean/presets/choppy.tres"):
	set(value):
		ocean_settings = value
		if is_instance_valid(ocean):
			ocean.configure(value)
@export_enum("Low", "Standard", "High") var ocean_quality: int = 1:
	set(value):
		ocean_quality = value
		if is_instance_valid(ocean):
			ocean.set_quality(value)

enum State { READY, SAILING, LOST, ARRIVED, CASTING_OFF }
var state: State = State.READY
var heading: float = START_HEADING
var elapsed: float = 0.0
var sea_time: float = 0.0
var reading: bool = false
var read_blend: float = 0.0
var turn_input: float = 0.0
var last_reading: float = START_HEADING
var has_reading: bool = false
var beacon_seen: bool = false
var failure_reason: String = ""
var transition_elapsed: float = 0.0
var end_view_blend: float = 0.0
var _transition_from: Transform3D
var boat: CharacterBody3D
var boat_visual: Node3D
var camera: Camera3D
var sky_root: Node3D
var beacon: Node3D
var beacon_lamp: MeshInstance3D
var hud: Control
var cannon: Node3D
var sea_creatures: Node3D
var ocean: Node3D
var boat_motion := BoatWaveMotion.new()
var water_material: ShaderMaterial
var sky_material: ShaderMaterial
var obstacles: Array[Dictionary] = []
var target: Vector3 = Vector3.ZERO
var _sound: AudioStreamPlayer
var _audio_playback: AudioStreamGeneratorPlayback
var _audio_phase: float = 0.0
var _audio_noise: float = 0.0
var _audio_rng := RandomNumberGenerator.new()
var _sound_enabled: bool = true


func course_forward() -> Vector3:
	return Vector3(sin(TARGET_HEADING), 0.0, -cos(TARGET_HEADING))


func course_right() -> Vector3:
	return Vector3(cos(TARGET_HEADING), 0.0, sin(TARGET_HEADING))


func _ready() -> void:
	target = course_forward() * CROSSING_LENGTH
	_configure_inputs()
	_build_world()
	_build_boat()
	cannon = Node3D.new()
	cannon.set_script(CANNON_SCRIPT)
	cannon.set("game", self)
	boat_visual.add_child(cannon)
	_build_hazards()
	sea_creatures = Node3D.new()
	sea_creatures.set_script(CREATURE_SCRIPT)
	sea_creatures.set("game", self)
	add_child(sea_creatures)
	_build_destination()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(HUD_SCRIPT)
	hud.set("game", self)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	_build_audio()
	_update_view(1.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("The Last Bearing | Ludum Dare 60")


func _configure_inputs() -> void:
	var bindings := {
		"steer_port": [KEY_A, KEY_LEFT], "steer_starboard": [KEY_D, KEY_RIGHT],
		"astrolabe": [KEY_SPACE], "restart_crossing": [KEY_R],
		"begin_crossing": [KEY_ENTER], "mute_sea": [KEY_M],
		"fire_starboard": [KEY_F],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_crossing") and state in [State.SAILING, State.LOST, State.ARRIVED]:
		restart()
	elif event.is_action_pressed("begin_crossing") and state == State.READY:
		start_crossing()
	elif event.is_action_pressed("fire_starboard"):
		cannon.fire()
	elif event.is_action_pressed("mute_sea"):
		_sound_enabled = not _sound_enabled
		if is_instance_valid(_sound):
			_sound.volume_db = -26.0 if _sound_enabled else -80.0
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func start_crossing() -> void:
	if state != State.READY:
		return
	transition_elapsed = 0.0
	_transition_from = camera.transform
	state = State.CASTING_OFF


func journey_distance() -> float:
	if state == State.ARRIVED:
		return CROSSING_LENGTH
	return clampf(boat.position.dot(course_forward()), 0.0, CROSSING_LENGTH * 0.99)


func journey_progress() -> float:
	return journey_distance() / CROSSING_LENGTH


func restart() -> void:
	cannon.reset()
	for obstacle: Dictionary in obstacles:
		obstacle.body.visible = true
		obstacle.body.collision_layer = 1
		obstacle.body.set_meta("destroyed", false)
	boat.position = Vector3.ZERO
	boat.velocity = Vector3.ZERO
	heading = START_HEADING
	boat_motion.reset()
	ocean.reset_wake(heading)
	elapsed = 0.0
	sea_creatures.reset()
	reading = false
	read_blend = 0.0
	turn_input = 0.0
	last_reading = START_HEADING
	has_reading = false
	beacon_seen = false
	beacon.visible = false
	failure_reason = ""
	transition_elapsed = 0.0
	end_view_blend = 0.0
	state = State.READY
	_update_view(1.0)
	start_crossing()


func _physics_process(delta: float) -> void:
	sea_time += delta
	if state == State.SAILING:
		reading = Input.is_action_pressed("astrolabe")
		turn_input = Input.get_axis("steer_port", "steer_starboard")
		advance_sailing(delta, turn_input)
	elif state == State.CASTING_OFF:
		reading = false
		turn_input = 0.0
		transition_elapsed = minf(CAST_OFF_SECONDS, transition_elapsed + delta)
		if transition_elapsed >= CAST_OFF_SECONDS:
			state = State.SAILING
	else:
		reading = false
		turn_input = 0.0
	_update_view(delta)
	hud.queue_redraw()


func advance_sailing(delta: float, steering: float) -> void:
	# Also used by the deterministic smoke test, with real physics collisions.
	if state != State.SAILING:
		return
	elapsed += delta
	sea_creatures.update_creatures()
	heading = wrapf(heading + steering * TURN_SPEED * delta, -PI, PI)
	boat.rotation.y = -heading
	boat.velocity = Vector3(sin(heading), 0.0, -cos(heading)) * SPEED
	var hit := boat.move_and_collide(boat.velocity * delta)
	if hit:
		failure_reason = "The hull struck %s." % hit.get_collider().get_meta("hazard_name", "wreckage")
		state = State.LOST
	if reading:
		last_reading = heading
		has_reading = true
	var distance := boat.position.distance_to(target)
	if distance < BEACON_REVEAL_DISTANCE and not beacon_seen:
		beacon_seen = true
		beacon.visible = true
	if distance < ARRIVAL_RADIUS and state == State.SAILING:
		state = State.ARRIVED
	# A broad safety boundary catches sailing away without punishing detours.
	if boat.position.length() > 1150.0 or elapsed > 240.0:
		failure_reason = "The current carried you beyond the crossing."
		state = State.LOST
	if state == State.LOST or state == State.ARRIVED:
		reading = false
		turn_input = 0.0
		cannon.reset()


func _update_view(delta: float) -> void:
	read_blend = move_toward(read_blend, 1.0 if reading else 0.0, delta * 4.5)
	boat.rotation.y = -heading
	var speed_factor := boat.velocity.length() / SPEED if state == State.SAILING else 0.0
	ocean.update_surface(boat.global_position, sea_time, delta, speed_factor, heading)
	boat_motion.update_motion(ocean, boat, boat_visual, delta)
	sea_creatures.update_ocean_visuals()
	var helm_pose := Transform3D(Basis.from_euler(Vector3(
		lerpf(deg_to_rad(-6.0), deg_to_rad(56.0), read_blend), -heading,
		0.0)),
		boat.position + Vector3(0.0, 2.55 + clampf((boat_motion.heave - ocean_settings.sea_level) * ocean_settings.camera_bob_strength, -0.18, 0.18), 0.0))
	camera.h_offset = 0.0
	camera.fov = 74.0
	if state == State.READY:
		camera.transform = _title_camera_pose()
		camera.h_offset = -4.2
		camera.fov = 64.0
	elif state == State.CASTING_OFF:
		var amount := smoothstep(0.0, 1.0, transition_elapsed / CAST_OFF_SECONDS)
		camera.transform = _transition_from.interpolate_with(helm_pose, amount)
		camera.h_offset = lerpf(-4.2, 0.0, amount)
		camera.fov = lerpf(64.0, 74.0, amount)
	elif state == State.ARRIVED or state == State.LOST:
		end_view_blend = minf(1.0, end_view_blend + delta * 1.3)
		var orientation := Basis(Vector3.UP, -heading)
		var at := boat.position + orientation * Vector3(8.0, 5.0, 10.0)
		var look_at_point := boat.position + course_forward() * 5.0 + Vector3.UP * 3.0
		var end_pose := Transform3D(Basis.looking_at(look_at_point - at), at)
		camera.transform = helm_pose.interpolate_with(end_pose, smoothstep(0.0, 1.0, end_view_blend))
		camera.h_offset = lerpf(0.0, -3.6, end_view_blend)
	else:
		camera.transform = helm_pose
	sky_root.position = camera.position
	sky_material.set_shader_parameter("visual_time", sea_time)
	if is_instance_valid(beacon_lamp):
		beacon_lamp.scale = Vector3.ONE * (1.0 + sin(sea_time * 1.7) * 0.12)


func _title_camera_pose() -> Transform3D:
	var orientation := Basis(Vector3.UP, -heading)
	var at := boat.position + orientation * Vector3(7.0, 4.5, -7.0)
	var look_at_point := boat.position + orientation * Vector3(0.0, 0.8, -1.6)
	return Transform3D(Basis.looking_at(look_at_point - at), at)


func _process(_delta: float) -> void:
	_fill_audio()


func _exit_tree() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
	_audio_playback = null


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if emission > 0.0:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


func _mesh(parent: Node3D, shape: Mesh, position_value: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = position_value
	instance.material_override = mat
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, size_value: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size_value
	return _mesh(parent, shape, at, mat)


func _cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 10
	return _mesh(parent, shape, at, mat)


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var night_sky := Sky.new()
	night_sky.sky_material = sky_material
	night_sky.radiance_size = Sky.RADIANCE_SIZE_32
	night_sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = night_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("60838e")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("243c46")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.007
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
	moon.light_color = Color("a4c6d4")
	moon.light_energy = 0.85
	add_child(moon)
	ocean = OceanController.new()
	ocean.name = "Ocean"
	add_child(ocean)
	ocean.initialize(ocean_settings, ocean_quality)
	water_material = ocean.material
	sky_root = Node3D.new()
	sky_root.name = "FixedCelestialSky"
	add_child(sky_root)
	var star_mat := _material(Color("91aab3"), 1.0)
	star_mat.no_depth_test = true
	star_mat.disable_fog = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	for i in range(110):
		var azimuth := rng.randf_range(-PI, PI)
		var altitude := rng.randf_range(0.24, 1.5)
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.25, 0.6)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 4
		sphere.rings = 2
		var direction := Vector3(sin(azimuth) * cos(altitude), sin(altitude), -cos(azimuth) * cos(altitude))
		_mesh(sky_root, sphere, direction * 700.0, star_mat)
	# The navigation star stays at world north, 56 degrees above the horizon.
	var north_material := _material(Color("fff0be"), 2.0)
	north_material.no_depth_test = true
	north_material.disable_fog = true
	var north_direction := Vector3(0.0, sin(deg_to_rad(56.0)), -cos(deg_to_rad(56.0)))
	var north_star := SphereMesh.new()
	north_star.radius = 2.0
	north_star.height = 4.0
	_mesh(sky_root, north_star, north_direction * 700.0, north_material)
	# A cross silhouette makes the reference star distinct from background stars.
	var cross := _box(sky_root, Vector3(7.0, 0.6, 0.6), north_direction * 699.0, north_material)
	cross.look_at(Vector3.ZERO)
	var vertical := _box(sky_root, Vector3(0.6, 7.0, 0.6), north_direction * 699.0, north_material)
	vertical.look_at(Vector3.ZERO)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 74.0
	camera.far = 1800.0
	camera.near = 0.08
	add_child(camera)


func _build_boat() -> void:
	boat = CharacterBody3D.new()
	boat.name = "Boat"
	boat.collision_layer = 2
	boat.collision_mask = 1
	add_child(boat)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.25
	collision.shape = sphere
	collision.position = Vector3(0.0, 0.4, -0.5)
	boat.add_child(collision)
	boat_visual = Node3D.new()
	boat_visual.name = "BoatVisualPivot"
	boat.add_child(boat_visual)
	var ship: Node3D = PIRATE_SHIP.instantiate()
	ship.name = "PirateKitPlayerShip"
	ship.rotation.y = -PI / 2.0
	ship.scale = Vector3(1.15, 0.8, 0.8)
	ship.position = Vector3(0.0, -0.10, -1.8)
	boat_visual.add_child(ship)
	var dark := _material(Color("211e1d"))
	_box(boat_visual, Vector3(0.07, 0.48, 0.07), Vector3(-1.05, 0.96, -2.9), dark)
	var brass := _material(Color("e4b96f"), 1.0)
	_box(boat_visual, Vector3(0.22, 0.32, 0.22), Vector3(-1.05, 1.3, -2.9), brass)
	_box(boat_visual, Vector3(0.34, 0.08, 0.34), Vector3(-1.05, 1.51, -2.9), dark)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.0, 1.6, -2.8)
	lamp.light_color = Color("ffc178")
	lamp.light_energy = 2.0
	lamp.omni_range = 7.0
	boat_visual.add_child(lamp)


func _build_hazards() -> void:
	# [distance along course, lateral offset, radius, type]. Early clear water is deliberate.
	var layout := [
		[80.0, 0.0, 5.5, "rock"], [125.0, -17.0, 5.0, "rock"],
		[170.0, 9.0, 6.0, "wreck"], [215.0, -7.0, 4.2, "debris"],
		[260.0, 18.0, 6.0, "rock"], [300.0, -6.0, 6.0, "wreck"],
		[348.0, -21.0, 5.0, "rock"], [390.0, 10.0, 6.0, "wreck"],
		[435.0, -6.0, 4.0, "debris"], [470.0, 23.0, 6.0, "rock"],
		[145.0, 65.0, 12.0, "rock"], [290.0, -75.0, 16.0, "rock"],
		[410.0, 80.0, 14.0, "rock"],
		[105.0, 28.0, 4.5, "debris"], [155.0, -38.0, 5.0, "rock"],
		[235.0, 38.0, 4.8, "debris"], [325.0, 30.0, 5.0, "debris"],
		[365.0, -45.0, 5.5, "rock"], [450.0, -40.0, 4.5, "debris"],
	]
	for entry: Array in layout:
		_add_hazard(course_forward() * entry[0] + course_right() * entry[1], entry[2], entry[3])


func _add_hazard(at: Vector3, radius: float, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("hazard_name", "a rock" if kind == "rock" else "a wreck" if kind == "wreck" else "floating timber")
	body.set_meta("destructible", kind == "debris")
	body.set_meta("destroyed", false)
	if kind == "debris":
		body.set_meta("target_kind", "timber")
		body.set_meta("target_radius", radius)
		body.add_to_group("cannon_targets")
	add_child(body)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	body.add_child(collision)
	obstacles.append({"position": at, "radius": radius, "kind": kind, "body": body})
	var visual := Node3D.new()
	visual.name = "HazardVisual"
	body.add_child(visual)
	var timber := _material(Color("564c3c"))
	var edge := _material(Color("798a83"))
	if kind == "rock":
		var rock: Node3D = PIRATE_ROCK.instantiate()
		rock.name = "PirateKitRock"
		rock.scale = Vector3.ONE * radius * 2.65
		rock.rotation.y = at.x
		visual.add_child(rock)
	elif kind == "wreck":
		body.rotation.y = -0.7 + at.x * 0.03
		var hull: Node3D = PIRATE_SHIP.instantiate()
		hull.name = "PirateKitWreckHull"
		hull.scale = Vector3(radius * 0.25, radius * 0.10, radius * 0.26)
		hull.position.y = -0.2
		hull.rotation.z = 0.23
		visual.add_child(hull)
		_box(visual, Vector3(0.35, 8.5, 0.35), Vector3(0.7, 3.2, 0.0), timber).rotation.z = -0.34
		_box(visual, Vector3(5.0, 0.2, 0.2), Vector3(1.5, 5.1, 0.0), edge).rotation.z = -0.34
		for i in range(4):
			_box(visual, Vector3(0.35, 2.7, 0.28), Vector3(-radius * 0.6, 1.4, -2.0 + i * 1.4), edge).rotation.z = 0.3
	else:
		timber = _material(Color("8f7350"))
		for i in range(5):
			var plank := _box(visual, Vector3(0.7, 0.9, radius * 1.6), Vector3(-radius * 0.65 + i * radius * 0.32, 0.5, sin(i * 2.0)), timber)
			plank.rotation.y = sin(i * 3.0) * 0.3
		# A pale crossbeam distinguishes shootable timber from permanent rocks/wrecks.
		_box(visual, Vector3(radius * 1.4, 0.22, 0.4), Vector3(0.0, 1.05, 0.0), _material(Color("bda778")))
	if kind != "rock":
		ocean.register_float_visual(visual)


func _build_destination() -> void:
	beacon = Node3D.new()
	beacon.name = "LateVisibleLighthouse"
	beacon.position = target
	beacon.visible = false
	add_child(beacon)
	var stone := _material(Color("566369"))
	var pale := _material(Color("b2b5a5"))
	var red := _material(Color("593c38"))
	_cylinder(beacon, 25.0, 16.0, 5.0, Vector3(0.0, -0.8, 0.0), stone)
	_cylinder(beacon, 4.8, 3.2, 22.0, Vector3(0.0, 11.0, 0.0), pale)
	_cylinder(beacon, 4.2, 3.9, 3.0, Vector3(0.0, 15.0, 0.0), red)
	_cylinder(beacon, 5.0, 5.0, 0.8, Vector3(0.0, 22.0, 0.0), stone)
	beacon_lamp = _cylinder(beacon, 2.8, 2.8, 3.0, Vector3(0.0, 24.0, 0.0), _material(Color("ffdb8a"), 2.0))
	_cylinder(beacon, 4.2, 0.0, 3.5, Vector3(0.0, 27.0, 0.0), red)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0.0, 24.0, 0.0)
	glow.light_color = Color("ffcc83")
	glow.light_energy = 5.0
	glow.omni_range = 40.0
	beacon.add_child(glow)


func _build_audio() -> void:
	# Quiet synthesized surf: no asset downloads or audio dependencies.
	if DisplayServer.get_name() == "headless":
		return
	_sound = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.15
	_sound.stream = stream
	_sound.volume_db = -26.0
	add_child(_sound)
	_sound.play()
	_audio_playback = _sound.get_stream_playback()
	_audio_rng.seed = 60


func _fill_audio() -> void:
	if not is_instance_valid(_audio_playback):
		return
	var frames := _audio_playback.get_frames_available()
	for i in range(frames):
		_audio_phase += 1.0 / 22050.0
		_audio_noise = lerpf(_audio_noise, _audio_rng.randf_range(-1.0, 1.0), 0.07)
		var swell := 0.45 + 0.2 * sin(_audio_phase * 0.75)
		var sample := _audio_noise * swell + sin(_audio_phase * TAU * 57.0) * 0.015
		_audio_playback.push_frame(Vector2(sample, sample))

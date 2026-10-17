extends Node3D
## A compact, authored three-star archipelago. Distances are in metres.

const VoyageDirector = preload("res://game/voyage_director.gd")
const NavigationBearings = preload("res://game/navigation_bearings.gd")
const HUD_SCRIPT = preload("res://game/navigation_hud.gd")
const OceanController = preload("res://game/ocean/ocean_controller.gd")
const WaveSettings = preload("res://game/ocean/wave_settings.gd")
const BoatWaveMotion = preload("res://game/ocean/boat_wave_motion.gd")
const WaveSailing = preload("res://game/ocean/wave_sailing.gd")
const WaveEncounters = preload("res://game/ocean/wave_encounters.gd")
var wave_sailing := WaveSailing.new()
var wave_encounters := WaveEncounters.new()
var actual_speed := 0.0
const NightClouds = preload("res://game/night_clouds.gd")
const SKY_SHADER = preload("res://game/night_sky.gdshader")
const CANNON_SCENE = preload("res://game/broadside_cannon.tscn")
const PIRATE_SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const PIRATE_ROCK = preload("res://assets/pirate_kit/rock.glb")
const ENCOUNTER_SCRIPT = preload("res://game/enemy_encounters.gd")
const ARCHIPELAGO = preload("res://game/world/archipelago.tscn")
const SPEED: float = 6.3
const TURN_SPEED: float = 0.64
const TARGET_HEADING: float = PI / 6.0
const START_HEADING: float = -PI * 0.28
const CAST_OFF_SECONDS: float = 1.25
# Leave room for the hull and camera inside the terrain's 512 m edges.
const SAILING_LIMIT: float = 480.0
const NORTH_STAR_DIRECTION := Vector3(0.0, 0.8290376, -0.5591929)

@export_group("Sailing difficulty")
@export var encounter_seed: int = 60
# Legacy fixture properties; no invisible current or gust forces in gameplay.
var current_strength := 0.0
var gust_strength := 0.0

@export_group("Hull")
@export_range(1, 6, 1) var hull_capacity: int = 3
@export_range(1, 3, 1) var contact_damage: int = 1
@export_range(0.5, 4.0, 0.1) var hit_immunity_seconds: float = 2.2
## Restore one hull point per uninterrupted interval clear of cutters and incoming fire.
@export_range(2.0, 20.0, 0.5) var hull_repair_seconds: float = 8.0

@export_group("Voyage presentation")
@export var weather_enabled: bool = true

@export_group("Stargazing sky")
@export_range(0.0, 1.0, 0.05) var star_density: float = 0.72
@export_range(0.0, 0.5, 0.01) var twinkle_strength: float = 0.16
@export_subgroup("Cloud formations")
@export_range(0.0, 1.0, 0.05) var cloud_density: float = 0.62
@export_range(0.4, 2.0, 0.05) var cloud_scale: float = 1.0
@export var cloud_wind := Vector2(1.0, 0.28)
@export_range(0.0, 3.0, 0.05) var cloud_speed: float = 0.7
@export_range(0.3, 1.5, 0.05) var cloud_brightness: float = 0.85
@export_range(0.0, 1.0, 0.05) var cloud_highlights: float = 0.55
@export_range(0.0, 1.0, 0.05) var cloud_softness: float = 0.60
## Billowing banks at zero; more stretched upper wisps at one.
@export_range(0.0, 1.0, 0.05) var cloud_variation: float = 0.35
@export var cloud_seed: int = 60
@export_subgroup("Cloud fallback")
## Disable only to compare or revert to the previous painted sky.
@export var procedural_clouds: bool = true
@export var cloud_size_range := Vector2(0.9, 1.2)
@export_subgroup("")
@export_range(80.0, 100.0, 1.0) var stargazing_fov: float = 94.0

@export_group("Sextant assistance")
@export_range(0.2, 2.5, 0.05) var focus_delay: float = 0.95
@export_range(0.2, 1.2, 0.05) var focus_duration: float = 0.65
@export_range(0.0, 1.0, 0.05) var target_highlight_strength: float = 0.65
@export_range(1.8, 5.0, 0.1) var extended_focus_delay: float = 2.6
@export_enum("None", "Hold to focus") var search_text: int = 1
@export_enum("None", "Star name", "Name and bearing") var focused_text: int = 2
@export_enum("Keep focus text", "Course hint") var extended_text: int = 0

@export_group("Sailing camera")
## Distance behind the hull centre, before a gentle speed extension.
@export_range(8.0, 24.0, 0.5) var sailing_follow_distance: float = 11.0
@export_range(3.0, 12.0, 0.25) var sailing_camera_height: float = 5.5
## Exponential response rates, in inverse seconds. Larger values follow faster.
@export_range(2.0, 14.0, 0.5) var sailing_follow_smoothing: float = 7.0
@export_range(2.0, 14.0, 0.5) var sailing_rotation_smoothing: float = 5.5
@export_range(0.0, 10.0, 0.5) var sailing_look_ahead: float = 5.0
@export_range(0.0, 6.0, 0.25) var sailing_speed_fov: float = 3.0

@export_group("Cannon camera")
@export_range(0.1, 0.8, 0.05) var aim_camera_seconds: float = 0.4
@export_range(0.2, 1.0, 0.05) var camera_return_seconds: float = 0.4
## Offset from the existing cannon mount, in hull coordinates (X is starboard).
@export var aim_camera_offset := Vector3(-2.8, 1.9, 0.0)
@export var combat_camera_offset := Vector3(2.8, 6.0, 10.5)
@export_range(0.0, 0.25, 0.01) var camera_target_bias: float = 0.1
@export_range(60.0, 90.0, 1.0) var aim_camera_fov: float = 76.0
@export_range(0.0, 0.2, 0.01) var cannon_camera_tracking: float = 0.15

@export_group("Ocean")
@export var ocean_settings: WaveSettings = preload("res://game/ocean/presets/calm.tres"):
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
var phase: int = 0
var phase_banner_left: float = 4.0
var storm_blend: float = 0.0
var last_sighting_time: float = 0.0
var _last_thunder: int = -1
var world_environment: WorldEnvironment
var moon: DirectionalLight3D
var _victory_audio: AudioStreamPlayer
var _danger_audio: AudioStreamPlayer
var hull: int = 3
var damage_immunity: float = 0.0
var hit_flash: float = 0.0
var shake_strength: float = 0.0
var hit_message: String = ""
var hit_message_left: float = 0.0
var hits_taken: int = 0
var hull_repair_elapsed: float = 0.0
var hull_repair_notice_left: float = 0.0
var _last_hull_damage_time: float = 0.0
var voyage := VoyageDirector.new()
var archipelago: Node3D
var discovery_text: String = ""
var discovery_left: float = 0.0
var _at_sailing_boundary: bool = false
@export_group("Development")
@export var development_tools: bool = false
var _warning_audio: AudioStreamPlayer
var heading: float = START_HEADING
var elapsed: float = 0.0
var sea_time: float = 0.0
var reading: bool = false
var read_blend: float = 0.0
var focus_elapsed: float = 0.0
var focus_strength: float = 0.0
var look_blend: float = 0.0
var starboard_look: bool = false
enum CameraMode { SAILING, COMBAT, CANNON, STARGAZING }
var camera_mode: CameraMode = CameraMode.SAILING
var aim_camera_blend: float = 0.0
var combat_camera_blend: float = 0.0
var _camera_aim_degrees: float = 0.0
var _camera_target_offset := Vector3.ZERO
var _sailing_anchor := Vector3.ZERO
var _sailing_heading: float = START_HEADING
var _sailing_speed: float = 0.0
var _sailing_camera_initialized := false
var _camera_clear_fraction: float = 1.0
var _camera_probe := SphereShape3D.new()
var _cannon_impulse: float = 0.0
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
var enemy_encounters: Node3D
var ocean: Node3D
var boat_motion := BoatWaveMotion.new()
var water_material: ShaderMaterial
var _cloud_layout := NightClouds.new()
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
	var bearing := destination_bearing()
	return Vector3(sin(bearing), 0.0, -cos(bearing))


func course_right() -> Vector3:
	var bearing := destination_bearing()
	return Vector3(cos(bearing), 0.0, sin(bearing))


func _ready() -> void:
	ocean_settings = ocean_settings.duplicate(true)
	hull = hull_capacity
	target = Vector3(-230, 0, -155)
	_configure_inputs()
	_build_world()
	_build_boat()
	archipelago = ARCHIPELAGO.instantiate()
	add_child(archipelago)
	archipelago.configure(self)
	var star_directions := PackedVector3Array()
	for region: Marker3D in archipelago.get_node("NavigationRegions").get_children():
		star_directions.append(region.star_direction.normalized())
	sky_material.set_shader_parameter("guiding_stars", star_directions)
	boat.position = archipelago.get_node("SpawnPoints/Departure").position
	cannon = CANNON_SCENE.instantiate()
	cannon.set("game", self)
	boat_visual.add_child(cannon)
	cannon.fired.connect(_on_cannon_fired)
	voyage.reset(encounter_seed)
	voyage.set_target(self)
	wave_encounters.reset(encounter_seed)
	_build_hazards()
	enemy_encounters = Node3D.new()
	enemy_encounters.set_script(ENCOUNTER_SCRIPT)
	enemy_encounters.set("game", self)
	add_child(enemy_encounters)
	_build_destination()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(HUD_SCRIPT)
	hud.set("game", self)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	_build_audio()
	if DisplayServer.get_name() != "headless":
		_warning_audio = cannon._audio(220.0, 0.5, -18.0)
		_victory_audio = cannon._audio(440.0, 0.03, -16.0)
		_danger_audio = cannon._audio(66.0, 0.8, -16.0)
	_update_view(1.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Latitude Lines")
	for arg in OS.get_cmdline_user_args():
		if arg == "--layout-debug":
			development_tools = true
			archipelago.toggle_debug()


func _configure_inputs() -> void:
	var bindings := {
		"steer_port": [KEY_A, KEY_LEFT], "steer_starboard": [KEY_D, KEY_RIGHT],
		"astrolabe": [KEY_SPACE], "restart_crossing": [KEY_R],
		"begin_crossing": [KEY_ENTER], "mute_sea": [KEY_M],
		"fire_starboard": [KEY_F], "watch_starboard": [KEY_E],
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
	if development_tools and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F2:
			archipelago.toggle_debug()
		elif event.keycode in [KEY_F3, KEY_F4, KEY_F5]:
			archipelago.debug_spawn(event.keycode - KEY_F3)
		elif event.keycode == KEY_F6:
			archipelago.debug_wave_zone()
	if event.is_action_pressed("restart_crossing") and state in [State.SAILING, State.LOST, State.ARRIVED]:
		restart()
	elif event.is_action_pressed("begin_crossing") and state == State.READY:
		start_crossing()
	elif event.is_action("fire_starboard") and not event.is_echo():
		cannon.set_fire_held(event.is_pressed())
	elif (event.is_action("steer_port") or event.is_action("steer_starboard")) and not event.is_echo():
		cannon.note_steering_event(maxf(event.get_action_strength("steer_port"), event.get_action_strength("steer_starboard")))
	elif event.is_action_pressed("astrolabe"):
		cannon.cancel_aim()
	elif event.is_action_pressed("mute_sea"):
		_sound_enabled = not _sound_enabled
		if is_instance_valid(_sound):
			_sound.volume_db = -26.0 if _sound_enabled else -80.0
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(cannon):
		cannon.cancel_aim()


func _on_cannon_fired(_direction: Vector3) -> void:
	_cannon_impulse = 1.0


func start_crossing() -> void:
	if state != State.READY:
		return
	transition_elapsed = 0.0
	_transition_from = camera.transform
	state = State.CASTING_OFF


func destination_bearing() -> float:
	# Internal radians may be signed; presentation converts absolute bearings to 000–359°.
	return NavigationBearings.bearing_to(boat.global_position if is_instance_valid(boat) else Vector3.ZERO, target, heading)


func destination_turn() -> float:
	return NavigationBearings.signed_turn(heading, destination_bearing())


func guiding_star_direction() -> Vector3:
	return voyage.region(self).star_direction.normalized()


func guiding_star_name() -> String:
	return voyage.region(self).star_name


func show_discovery(value: String, seconds: float = 4.0) -> void:
	discovery_text = value
	discovery_left = seconds


func journey_progress() -> float:
	if voyage.stage == voyage.Stage.COMPLETE:
		return 1.0
	var lengths := [350.0, 470.0, 410.0]
	var local_progress := clampf(1.0 - boat.position.distance_to(target) / lengths[voyage.stage], 0.0, 0.99)
	return (voyage.stage + local_progress) / 3.0


func restart() -> void:
	cannon.reset()
	wave_sailing.reset()
	wave_encounters.reset(encounter_seed)
	ocean.wave_field.clear()
	sea_time = 0.0
	actual_speed = 0.0
	hull = hull_capacity
	damage_immunity = 0.0
	hit_flash = 0.0
	shake_strength = 0.0
	hits_taken = 0
	hull_repair_elapsed = 0.0
	hull_repair_notice_left = 0.0
	_last_hull_damage_time = 0.0
	hit_message_left = 0.0
	phase = 0
	phase_banner_left = 4.0
	storm_blend = 0.0
	last_sighting_time = 0.0
	_last_thunder = -1
	for obstacle: Dictionary in obstacles:
		if obstacle.body.get_meta("landmark", false):
			continue
		obstacle.body.collision_layer = 0
		obstacle.body.set_meta("destroyed", true)
		obstacle.body.queue_free()
	obstacles = obstacles.filter(func(o: Dictionary) -> bool: return o.body.get_meta("landmark", false))
	ocean.floating_visuals = ocean.floating_visuals.filter(func(o: Dictionary) -> bool: return is_instance_valid(o.visual) and o.visual.get_parent().get_meta("landmark", false))
	voyage.reset(encounter_seed)
	voyage.set_target(self)
	archipelago.reset()
	discovery_left = 0.0
	_at_sailing_boundary = false
	boat.position = archipelago.get_node("SpawnPoints/Departure").position
	boat.velocity = Vector3.ZERO
	heading = START_HEADING
	boat_motion.reset()
	ocean.reset_wake(heading)
	elapsed = 0.0
	enemy_encounters.reset()
	reading = false
	read_blend = 0.0
	focus_elapsed = 0.0
	focus_strength = 0.0
	look_blend = 0.0
	starboard_look = false
	aim_camera_blend = 0.0
	combat_camera_blend = 0.0
	_camera_aim_degrees = 0.0
	_camera_target_offset = Vector3.ZERO
	_sailing_camera_initialized = false
	_camera_clear_fraction = 1.0
	_cannon_impulse = 0.0
	camera_mode = CameraMode.SAILING
	turn_input = 0.0
	last_reading = START_HEADING
	has_reading = false
	beacon_seen = false
	beacon.visible = false
	failure_reason = ""
	transition_elapsed = 0.0
	end_view_blend = 0.0
	state = State.READY
	_build_hazards()
	_update_view(1.0)
	start_crossing()


func _physics_process(delta: float) -> void:
	if state != State.SAILING:
		sea_time += delta
	reading = state == State.SAILING and Input.is_action_pressed("astrolabe")
	if reading or state != State.SAILING:
		cannon.cancel_aim()
	cannon.set_fire_held(Input.is_action_pressed("fire_starboard"))
	cannon.update_aim(delta)
	if state == State.SAILING:
		starboard_look = Input.is_action_pressed("watch_starboard") and not reading
		turn_input = 0.0 if cannon.aiming else Input.get_axis("steer_port", "steer_starboard")
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
	sea_time += delta
	damage_immunity = maxf(0.0, damage_immunity - delta)
	wave_encounters.update(self, delta)
	ocean.wave_time = sea_time
	enemy_encounters.update_encounters(delta)
	# A fresh steering press exits cannon view; waves continue throughout aiming.
	if cannon.aiming:
		steering = 0.0
	var center: Vector3 = boat.to_global(BoatWaveMotion.HULL_CENTER)
	heading = wave_sailing.step(ocean.wave_field, Vector2(center.x, center.z), heading, steering, sea_time, delta)
	boat.rotation.y = -heading
	boat.velocity = Vector3(wave_sailing.displacement.x, 0, wave_sailing.displacement.y) / maxf(delta, 0.0001)
	var previous_position := boat.position
	var hit := boat.move_and_collide(boat.velocity * delta)
	if hit:
		take_damage(contact_damage, "Hull struck %s" % hit.get_collider().get_meta("hazard_name", "wreckage"))
		# Keep responsive steering and let glancing hits slide; never teleport through a reef.
		var shore_normal := Vector3(hit.get_normal().x, 0, hit.get_normal().z).normalized()
		wave_sailing.slide(Vector2(shore_normal.x, shore_normal.z))
		boat.move_and_collide(hit.get_remainder().slide(shore_normal))
	boat.position.y = 0.0
	_constrain_sailing_area()
	boat.velocity = (boat.position - previous_position) / maxf(delta, 0.0001)
	actual_speed = boat.velocity.length()
	if reading and focus_strength >= 1.0:
		# This snapshot is a focused landmark reading, not the bow's heading.
		# It never supplies a sailing arrow or persistent HUD label.
		last_reading = destination_bearing()
		has_reading = true
		last_sighting_time = elapsed
	voyage.update_progress(self)
	archipelago.update_discoveries()
	var distance := boat.position.distance_to(archipelago.get_node("Landmarks/Lighthouse").position)
	if voyage.stage >= voyage.Stage.LIGHTHOUSE and distance < 230.0 and not beacon_seen:
		beacon_seen = true
		beacon.visible = true
	if state == State.LOST or state == State.ARRIVED:
		reading = false
		turn_input = 0.0
		cannon.reset()
		enemy_encounters.stop()
		wave_encounters.stop(ocean.wave_field)
		wave_sailing.reset()
	_update_hull_recovery(delta)


func is_repairing_hull() -> bool:
	return state == State.SAILING and hull > 0 and hull < hull_capacity and not enemy_encounters.battle_active()


func restore_hull(amount: int) -> bool:
	if state != State.SAILING or hull <= 0 or hull >= hull_capacity or amount <= 0:
		return false
	hull = mini(hull_capacity, hull + amount)
	hull_repair_notice_left = 3.0
	if hull == hull_capacity:
		hull_repair_elapsed = 0.0
	return true


func _update_hull_recovery(delta: float) -> void:
	hull_repair_notice_left = maxf(0.0, hull_repair_notice_left - delta)
	if not is_repairing_hull():
		hull_repair_elapsed = 0.0
		return
	# Hits resolved during this sailing step cannot count as time spent safe.
	hull_repair_elapsed += minf(delta, maxf(0.0, elapsed - _last_hull_damage_time))
	while hull_repair_elapsed + 0.00001 >= hull_repair_seconds and hull < hull_capacity:
		hull_repair_elapsed = maxf(0.0, hull_repair_elapsed - hull_repair_seconds)
		restore_hull(1)
		cue_sound("victory")


func _constrain_sailing_area() -> void:
	var at_boundary := false
	for axis: int in [Vector3.AXIS_X, Vector3.AXIS_Z]:
		var coordinate: float = boat.position[axis]
		if absf(coordinate) < SAILING_LIMIT:
			continue
		at_boundary = true
		boat.position[axis] = clampf(coordinate, -SAILING_LIMIT, SAILING_LIMIT)
		var inward := Vector2.ZERO
		inward[0 if axis == Vector3.AXIS_X else 1] = -signf(coordinate)
		# Stop outward wave momentum; preserve motion along the edge and the rudder.
		wave_sailing.slide(inward)
	if at_boundary and not _at_sailing_boundary:
		show_discovery("Open sea · turn back toward the islands")
	_at_sailing_boundary = at_boundary


func take_damage(amount: int, reason: String) -> bool:
	if state != State.SAILING or damage_immunity > 0.0:
		return false
	hull = maxi(0, hull - amount)
	hits_taken += 1
	hull_repair_elapsed = 0.0
	hull_repair_notice_left = 0.0
	_last_hull_damage_time = elapsed
	damage_immunity = hit_immunity_seconds
	hit_flash = 0.8
	hit_message = reason.to_upper()
	hit_message_left = 2.0
	shake(0.16)
	cue_sound("damage")
	if hull == 0:
		wave_encounters.stop(ocean.wave_field)
		wave_sailing.reset()
		failure_reason = "The hull gave way. The sea came in."
		state = State.LOST
		reading = false
		cannon.reset()
	return true


func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func _update_view(delta: float) -> void:
	discovery_left = maxf(0.0, discovery_left - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	hit_message_left = maxf(0.0, hit_message_left - delta)
	shake_strength = maxf(0.0, shake_strength - delta * 0.9)
	_update_weather(delta)
	look_blend = move_toward(look_blend, 1.0 if starboard_look and not reading and state == State.SAILING else 0.0, delta * 5.0)
	read_blend = move_toward(read_blend, 1.0 if reading else 0.0, delta * 4.5)
	# A fresh, uninterrupted hold is required every time; lowering erases assistance.
	if reading and state == State.SAILING:
		focus_elapsed += delta
		focus_strength = smoothstep(focus_delay, focus_delay + focus_duration, focus_elapsed)
	else:
		focus_elapsed = 0.0
		focus_strength = 0.0
	boat.rotation.y = -heading
	var speed_factor := actual_speed / SPEED if state == State.SAILING else 0.0
	ocean.update_surface(boat.global_position, sea_time, delta, speed_factor, heading)
	boat_motion.update_motion(ocean, boat, boat_visual, delta)
	enemy_encounters.update_visuals(delta)
	if state == State.LOST:
		boat_visual.position.y -= minf(2.6, end_view_blend * 2.6)
		boat_visual.rotation.z += end_view_blend * 0.32
	var sky_blend := smoothstep(0.0, 1.0, read_blend)
	var helm_pose := _normal_sailing_pose(delta)
	helm_pose = _sailing_camera_pose(helm_pose, delta)
	# Sky has final priority, including while the aim camera is blending out.
	var sky_pose := Transform3D(Basis.from_euler(Vector3(deg_to_rad(78.0), -heading, 0.0)),
		boat.position + Vector3(0, 2.55, 0))
	helm_pose = helm_pose.interpolate_with(sky_pose, sky_blend)
	camera.h_offset = 0.0
	var sailing_fov := lerpf(62.0 + sailing_speed_fov * _sailing_speed, 74.0, smoothstep(0.0, 1.0, combat_camera_blend))
	camera.fov = lerpf(lerpf(sailing_fov, aim_camera_fov, aim_camera_blend), stargazing_fov, sky_blend)
	if state == State.READY:
		camera.transform = _title_camera_pose()
		camera.h_offset = -4.2
		camera.fov = 64.0
	elif state == State.CASTING_OFF:
		var amount := smoothstep(0.0, 1.0, transition_elapsed / CAST_OFF_SECONDS)
		camera.transform = _transition_from.interpolate_with(helm_pose, amount)
		camera.h_offset = lerpf(-4.2, 0.0, amount)
		camera.fov = lerpf(64.0, sailing_fov, amount)
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
	if state == State.SAILING:
		# Keep the chase view quiet during impacts; retain dedicated gun feedback.
		var sailing_shake := lerpf(0.22, 1.0, maxf(aim_camera_blend, combat_camera_blend))
		var sight_shake := shake_strength * lerpf(sailing_shake, 0.15, sky_blend)
		camera.position += camera.basis.x * sin(sea_time * 73.0) * sight_shake
		camera.position.y += cos(sea_time * 91.0) * sight_shake * 0.5
		camera.position -= cannon.aimed_direction() * _cannon_impulse * 0.18 * (1.0 - sky_blend)
		camera.position.y = maxf(camera.position.y, ocean.height_at(Vector2(camera.position.x, camera.position.z)) + 1.2)
		# Final safety includes the sky transition and the small recoil displacement.
		camera.position = _camera_obstruction_limit(camera.position)
	_cannon_impulse *= exp(-16.0 * delta)
	sky_root.position = camera.position
	sky_material.set_shader_parameter("visual_time", sea_time)
	sky_material.set_shader_parameter("star_density", star_density)
	sky_material.set_shader_parameter("twinkle_strength", twinkle_strength)
	sky_material.set_shader_parameter("cloud_density", cloud_density)
	sky_material.set_shader_parameter("cloud_speed", cloud_speed)
	sky_material.set_shader_parameter("cloud_scale", cloud_scale)
	sky_material.set_shader_parameter("cloud_wind", cloud_wind)
	sky_material.set_shader_parameter("procedural_clouds", procedural_clouds)
	_cloud_layout.configure_procedural(sky_material, cloud_seed)
	_cloud_layout.configure(sky_material, cloud_seed, cloud_size_range)
	sky_material.set_shader_parameter("cloud_brightness", cloud_brightness)
	sky_material.set_shader_parameter("cloud_highlights", cloud_highlights)
	sky_material.set_shader_parameter("cloud_softness", cloud_softness)
	sky_material.set_shader_parameter("cloud_variation", cloud_variation)
	sky_material.set_shader_parameter("active_star", mini(voyage.stage, 2))
	sky_material.set_shader_parameter("target_focus", focus_strength * target_highlight_strength)
	if is_instance_valid(beacon_lamp):
		beacon_lamp.scale = Vector3.ONE * (1.0 + sin(sea_time * 1.7) * 0.12)


func _normal_sailing_pose(delta: float) -> Transform3D:
	# The planar collision root supplies position and heading; only a little
	# filtered heave follows the visual hull. Pitch and roll never enter the rig.
	var stable_orientation := Basis(Vector3.UP, -heading)
	var center := boat.position + stable_orientation * BoatWaveMotion.HULL_CENTER
	center.y += clampf((boat_motion.heave - ocean_settings.sea_level) * ocean_settings.camera_bob_strength, -0.18, 0.18)
	var speed := clampf(actual_speed / SPEED, 0.0, 1.15) if state == State.SAILING else 0.0
	if not _sailing_camera_initialized or _sailing_anchor.distance_to(center) > 60.0:
		_sailing_anchor = center
		_sailing_heading = heading
		_sailing_speed = speed
		_sailing_camera_initialized = true
		_camera_clear_fraction = 1.0
	else:
		_sailing_anchor = _sailing_anchor.lerp(center, 1.0 - exp(-sailing_follow_smoothing * delta))
		_sailing_heading = lerp_angle(_sailing_heading, heading, 1.0 - exp(-sailing_rotation_smoothing * delta))
		_sailing_speed = lerpf(_sailing_speed, speed, 1.0 - exp(-3.0 * delta))
	var orientation := Basis(Vector3.UP, -_sailing_heading - deg_to_rad(75.0) * look_blend)
	var distance := sailing_follow_distance * (1.0 + _sailing_speed * 0.07)
	var at := _sailing_anchor + orientation * Vector3(0, sailing_camera_height, distance)
	var focus := _sailing_anchor + orientation * Vector3(0, 0.85, -sailing_look_ahead)
	return Transform3D(Basis.looking_at(focus - at, Vector3.UP), at)


func _camera_obstruction_limit(at: Vector3) -> Vector3:
	# Extend the existing terrain-only feeler to every sailing pose. A small swept
	# sphere protects the near plane and the screen edges rather than one thin ray.
	var anchor := _camera_shore_anchor()
	var motion := at - anchor
	if motion.length_squared() < 0.01:
		return at
	_camera_probe.radius = 0.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_probe
	query.transform = Transform3D(Basis.IDENTITY, anchor)
	query.motion = motion
	query.collision_mask = 1
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	var result := anchor + motion * maxf(0.0, fractions[0] - (0.15 / motion.length() if fractions[0] < 1.0 else 0.0))
	var floor_height: float = ocean.height_at(Vector2(result.x, result.z)) + 1.2
	if result.y < floor_height:
		# A shortened arm may end over a different part of a crest. Lift there,
		# then recheck terrain rather than pushing the camera below that water.
		result.y = floor_height
		query.motion = result - anchor
		fractions = get_world_3d().direct_space_state.cast_motion(query)
		result = anchor.lerp(result, fractions[0])
	return result


func _camera_shore_anchor() -> Vector3:
	# Keep the feeler above passing crests as well as above the planar hull root.
	var water: float = ocean.height_at(Vector2(boat.position.x, boat.position.z))
	return boat.position + Vector3.UP * maxf(2.8, water + 1.6)


func _sailing_camera_pose(helm_pose: Transform3D, delta: float) -> Transform3D:
	# Compose poses for the single transform writer in _update_view; never change gun yaw.
	var ship = enemy_encounters.ship
	var combat: bool = is_zero_approx(turn_input) and enemy_encounters.enabled and ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED, ship.Mode.SINKING] and ship.position.distance_to(boat.position) < 80.0
	camera_mode = CameraMode.STARGAZING if reading else CameraMode.CANNON if cannon.aiming else CameraMode.COMBAT if combat else CameraMode.SAILING
	var aiming: bool = camera_mode == CameraMode.CANNON
	var seconds: float = aim_camera_seconds if aiming else camera_return_seconds
	aim_camera_blend = move_toward(aim_camera_blend, 1.0 if aiming else 0.0, delta / seconds)
	combat_camera_blend = lerpf(combat_camera_blend, 1.0 if combat and not cannon.aiming and not reading else 0.0, 1.0 - exp(-5.0 * delta))
	_camera_aim_degrees = lerpf(_camera_aim_degrees, cannon.aim_degrees, 1.0 - exp(-12.0 * delta))
	var orientation := Basis(Vector3.UP, -heading)
	var enemy_offset: Vector3 = orientation.inverse() * (ship.position - boat.position)
	var target_offset := Vector3.ZERO
	if combat and enemy_offset.x > 5.0 and absf(enemy_offset.z) < enemy_offset.x:
		target_offset = Vector3(0, clampf(enemy_offset.y, -1, 2), clampf(enemy_offset.z, -10, 10)) * camera_target_bias
	_camera_target_offset = _camera_target_offset.lerp(target_offset, 1.0 - exp(-5.0 * delta))
	var combat_at := boat.position + orientation * combat_camera_offset
	var combat_focus := boat.position + orientation * (Vector3(12, 1.4, -4) + _camera_target_offset)
	var combat_pose := Transform3D(Basis.looking_at(combat_focus - combat_at), combat_at)
	var sailing_pose := helm_pose.interpolate_with(combat_pose, smoothstep(0, 1, combat_camera_blend))
	# Close elevated gunner view anchored to the real mount. Keep a level horizon
	# and only 15% yaw tracking: the barrel sweeps visibly across a stable sea.
	# Enemy bias is intentionally confined to the automatic combat pose above.
	var mount: Vector3 = cannon.global_position
	var aim_at := mount + orientation * aim_camera_offset
	var aim_direction := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(_camera_aim_degrees * cannon_camera_tracking))
	var aim_focus := mount + orientation * (aim_direction * 22.0 + Vector3.UP * 0.5)
	var aim_pose := Transform3D(Basis.looking_at(aim_focus - aim_at), aim_at)
	var result := sailing_pose.interpolate_with(aim_pose, smoothstep(0, 1, aim_camera_blend))
	if state == State.SAILING:
		# Pull inward immediately at a shore; ease back to full distance once clear.
		var anchor := _camera_shore_anchor()
		var full_distance := anchor.distance_to(result.origin)
		var safe_distance := anchor.distance_to(_camera_obstruction_limit(result.origin))
		var fraction := clampf(safe_distance / maxf(full_distance, 0.01), 0.0, 1.0)
		if aiming or reading:
			_camera_clear_fraction = fraction
		else:
			_camera_clear_fraction = minf(fraction, lerpf(_camera_clear_fraction, 1.0, 1.0 - exp(-5.0 * delta)))
		result.origin = anchor.lerp(result.origin, _camera_clear_fraction)
	return result


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
	world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	moon = DirectionalLight3D.new()
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
	# Stars and clouds share the world-direction sky shader, including partial
	# cloud occlusion. The HUD projects the same fixed north / 56 degree direction.
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
	boat.collision_mask = 5
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
	archipelago.rebuild_hazards()


func phase_name() -> String:
	return ["THE WRECK", "TWIN PEAKS", "LIGHTHOUSE HARBOUR", "SAFE HARBOUR"][mini(voyage.stage, 3)]


func _update_weather(delta: float) -> void:
	var progress: float = journey_progress()
	var new_phase: int = 0 if progress < 0.2 else 1 if progress < 0.5 else 2 if progress < 0.85 else 3
	if new_phase != phase and state == State.SAILING:
		phase = new_phase
		phase_banner_left = 3.0
	phase_banner_left = maxf(0, phase_banner_left - delta)
	if not weather_enabled:
		return
	var strength: float = [0.0, 0.25, 0.45, 0.15][phase]
	storm_blend = lerpf(storm_blend, strength, 1.0 - exp(-0.6 * delta))
	# Lighting follows voyage progress; wave difficulty belongs to the encounter director.
	world_environment.environment.ambient_light_energy = lerpf(0.78, 0.56, storm_blend)
	world_environment.environment.fog_density = lerpf(0.0035, 0.0048, storm_blend)
	moon.light_energy = lerpf(0.88, 0.68, storm_blend)
	sky_material.set_shader_parameter("storm", storm_blend)
	var flash: float = maxf(0.0, 1.0 - fmod(elapsed, 9.0) / 0.16) if phase == 2 else 0.0
	sky_material.set_shader_parameter("lightning", flash * 0.3)
	var thunder: int = int(elapsed / 9.0)
	if flash > 0.0 and thunder != _last_thunder:
		_last_thunder = thunder
		cue_sound("thunder")


func cue_sound(kind: String) -> void:
	if not _sound_enabled:
		return
	if kind == "victory" and is_instance_valid(_victory_audio):
		_victory_audio.play()
	elif kind in ["enemy_shot", "damage", "thunder"] and is_instance_valid(_danger_audio):
		_danger_audio.pitch_scale = 0.7 if kind == "thunder" else 1.0
		_danger_audio.play()
	elif is_instance_valid(_warning_audio):
		_warning_audio.pitch_scale = 0.6 if kind == "gust" else 1.0
		_warning_audio.play()


func _add_hazard(at: Vector3, radius: float, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("hazard_name", "a rock" if kind == "rock" else "a wreck" if kind == "wreck" else "floating barrels" if kind == "barrels" else "floating timber")
	body.set_meta("destructible", kind in ["debris", "barrels"])
	body.set_meta("destroyed", false)
	if kind in ["debris", "barrels"]:
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
	elif kind == "barrels":
		var staves := _material(Color("a28a61"))
		var hoops := _material(Color("435b60"))
		for i in range(3):
			var barrel := Node3D.new()
			barrel.position = Vector3((i - 1) * radius * 0.62, 0.1, sin(i * 2.0) * radius * 0.4)
			barrel.rotation = Vector3(0.12 * i, i * 1.7, 0.2 - i * 0.2)
			visual.add_child(barrel)
			_cylinder(barrel, 0.65, 0.65, 1.7, Vector3.ZERO, staves)
			for y: float in [-0.55, 0.55]:
				_cylinder(barrel, 0.69, 0.69, 0.12, Vector3(0, y, 0), hoops)
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
	beacon.position = archipelago.get_node("Landmarks/Lighthouse").position
	beacon.visible = false
	add_child(beacon)
	beacon_lamp = archipelago.story_landmarks.build_lighthouse_effects(beacon)


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
		var swell := (0.45 + 0.2 * sin(_audio_phase * 0.75)) * (1.0 + storm_blend * 0.75)
		var sample := _audio_noise * swell + sin(_audio_phase * TAU * 57.0) * 0.015
		_audio_playback.push_frame(Vector2(sample, sample))

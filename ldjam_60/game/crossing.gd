extends Node3D
const ActiveMetrics = preload("res://game/active_frame_metrics.gd")
## Lighthouse arena with retained voyage fixtures. Distances are in metres.

const VoyageDirector = preload("res://game/voyage_director.gd")
const NavigationBearings = preload("res://game/navigation_bearings.gd")
const HUD_SCRIPT = preload("res://game/navigation_hud.gd")
const LiveDiagnostics = preload("res://game/live_diagnostics.gd")
const ActiveFPS = preload("res://game/active_fps_investigation.gd")
var active_fps: Node
const AudioShutdown = preload("res://game/audio_shutdown.gd")
const MobileControls = preload("res://game/mobile_controls.gd")
var mobile_controls: CanvasLayer
var diagnostics: CanvasLayer
var _owns_quit_request := false
var _previous_auto_accept_quit := true
var _closing := false
const OceanController = preload("res://game/ocean/ocean_controller.gd")
const WaveSettings = preload("res://game/ocean/wave_settings.gd")
const BoatWaveMotion = preload("res://game/ocean/boat_wave_motion.gd")
const DeckCameraResponse = preload("res://game/ocean/deck_camera_response.gd")
const TurbulenceEffects = preload("res://game/ocean/turbulence_effects.gd")
const CombatParticles = preload("res://game/combat_particles.gd")
const BoatDamage = preload("res://game/boat_damage.gd")
const BoostWind = preload("res://game/boost_wind.gd")
const WaveSailing = preload("res://game/ocean/wave_sailing.gd")
const WaveEncounters = preload("res://game/ocean/wave_encounters.gd")
## Retained for enemy navigation bounds; never applied to the player.
const ArenaReturn = preload("res://game/arena_return.gd")
const FlowZones = preload("res://game/flow_zones.gd")
const Walkthrough = preload("res://game/walkthrough.gd")
var walkthrough := Walkthrough.new()
var flow_zones := FlowZones.new()
var arena_return := ArenaReturn.new()
var wave_sailing := WaveSailing.new()
var wave_encounters := WaveEncounters.new()
var actual_speed := 0.0
var boosting := false
const NightClouds = preload("res://game/night_clouds.gd")
const SKY_SHADER = preload("res://game/night_sky.gdshader")
const StormAtmosphere = preload("res://game/storm_atmosphere.gd")
var storm_atmosphere: CanvasLayer
const StormLightning = preload("res://game/storm_lightning.gd")
var storm_lightning := StormLightning.new()
const CANNON_SCENE = preload("res://game/broadside_cannon.tscn")
const ShipPennant = preload("res://game/ship_pennant.gd")
const ClothMotion = preload("res://game/ship_cloth_motion.gd")
var player_pennant: MeshInstance3D

const PLAYER_SAIL_BOAT = preload("res://assets/sail_boat/sail_boat.glb")
const PIRATE_SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const PIRATE_ROCK = preload("res://assets/pirate_kit/rock.glb")
const ENCOUNTER_SCRIPT = preload("res://game/enemy_encounters.gd")
const ARCHIPELAGO = preload("res://game/world/archipelago.tscn")
# Retain the speed accessor used by cutters and existing gameplay fixtures.
var SPEED: float:
	get:
		return sailing_speed
const TURN_SPEED: float = 0.64
const TARGET_HEADING: float = PI / 6.0
const START_HEADING: float = -PI * 0.28
const CAST_OFF_SECONDS: float = 1.25
const RESTART_HOLD_SECONDS: float = 0.6
const VICTORY_HOLD_SECONDS := 4.2
const LOSS_HOLD_SECONDS := 2.8
var result_active := false
var result_elapsed := 0.0
var result_salutes := 0
var _result_camera_from := Transform3D.IDENTITY
var _result_camera_to := Transform3D.IDENTITY
var _result_camera_offset := 0.0
const DAMAGE_SHAKE_SECONDS: float = 0.32
const DAMAGE_SHAKE_DISTANCE: float = 0.28
# Leave room for the hull and camera inside the terrain's 512 m edges.
const SAILING_LIMIT: float = 480.0
const GUIDING_STAR_ELEVATION: float = PI / 3.0
const GUIDING_STAR_COLORS := [Color("ffe8b8"), Color("b8ddff"), Color("ffd0be")]

@export_group("Sailing difficulty")
@export_range(3.0, 14.0, 0.1) var sailing_speed: float = 7.5
@export var encounter_seed: int = 60
@export_group("Lighthouse arena")
@export var arena_mode: bool = false
## Warning line for the player; retained as the enemy navigation radius.
@export_range(140.0, 200.0, 1.0) var arena_radius: float = 170.0
@export_range(20.0, 70.0, 1.0) var storm_warning_margin: float = 38.0
@export_range(7.0, 12.0, 0.5) var arena_rudder_response: float = 9.0
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
@export_subgroup("Arena storm")
@export_range(0.0, 1.0, 0.05) var arena_storm_strength: float = 0.65
@export var storm_post_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var storm_rain_amount: float = 0.65
@export var storm_lightning_enabled: bool = true
## Random seconds between single distant flashes; thunder follows 0.9–2.4 s later.
@export var storm_lightning_interval := Vector2(14.0, 28.0)

@export_group("Night illumination")
@export var night_ambient_color := Color("71879e")
@export var moonlight_color := Color("bacfe8")
@export var night_fog_color := Color("263b53")
@export_range(0.0, 2.0, 0.05) var calm_ambient_energy: float = 0.73
@export_range(0.0, 2.0, 0.05) var storm_ambient_energy: float = 0.57
@export_range(0.0, 2.0, 0.05) var calm_moon_energy: float = 0.78
@export_range(0.0, 2.0, 0.05) var storm_moon_energy: float = 0.53
@export var lantern_color := Color("ffc878")
@export_range(0.0, 3.0, 0.05) var lantern_energy: float = 1.15

@export_group("Stargazing sky")
@export_range(0.0, 1.0, 0.05) var star_density: float = 0.72
@export_range(0.0, 0.5, 0.01) var twinkle_strength: float = 0.16
@export_subgroup("Cloud formations")
@export_range(0.0, 1.0, 0.05) var cloud_density: float = 0.62
@export_range(0.4, 2.0, 0.05) var cloud_scale: float = 1.0
@export var cloud_wind := Vector2(1.0, 0.28)
@export_range(0.0, 3.0, 0.05) var cloud_speed: float = 2.1
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
## Upward sighting angle; yaw continues to follow the boat's actual heading.
@export_range(10.0, 45.0, 0.5) var stargazing_pitch_degrees: float = 25.0
@export_range(80.0, 100.0, 1.0) var stargazing_fov: float = 94.0

@export_group("Sextant assistance")
@export_range(0.2, 2.5, 0.05) var focus_delay: float = 0.4
@export_range(0.2, 1.2, 0.05) var focus_duration: float = 0.4
@export_range(0.0, 1.0, 0.05) var target_highlight_strength: float = 0.65

@export_group("Sailing camera")
enum SailingCameraRig { CHASE, DECK }
@export var sailing_camera_rig: SailingCameraRig = SailingCameraRig.CHASE
## Chase framing restored from 534b021; the deck rig remains available for fixtures.
@export_range(8.0, 24.0, 0.5) var sailing_follow_distance: float = 11.0
@export_range(3.0, 12.0, 0.25) var sailing_camera_height: float = 5.5
@export_range(2.0, 14.0, 0.5) var sailing_follow_smoothing: float = 7.0
@export_range(2.0, 14.0, 0.5) var sailing_rotation_smoothing: float = 5.5
@export_range(0.0, 10.0, 0.5) var sailing_look_ahead: float = 5.0
## Hull-local eye position, authored against the existing six-metre boat.
@export var helm_eye := Vector3(0.0, 2.05, 0.45)
## Full motion in normal play; retained internally for legacy regression fixtures.
var motion_setting: int = 0
@export_range(0.0, 6.0, 0.25) var sailing_speed_fov: float = 3.0

@export_group("Arcade chase look")
@export_range(0.0, 60.0, 1.0) var camera_yaw_limit: float = 45.0
@export_range(0.01, 0.5, 0.01) var camera_mouse_sensitivity: float = 0.12
@export_range(1.0, 20.0, 0.5) var camera_look_response: float = 12.0
@export_range(0.0, 4.0, 0.1) var camera_recenter_delay: float = 1.5
@export_range(0.2, 8.0, 0.1) var camera_recenter_speed: float = 2.2
@export var camera_port_offset: float = 8.0
@export var camera_starboard_focus: float = 8.0
# Above and outside the starboard gunwale, beyond the rocking barrel and canvas.
@export var cannon_view_offset := Vector3(3.0, 2.6, 0.4)
var look_yaw: float = 0.0
var look_target: float = 0.0
var look_idle: float = 0.0
var arena_cannon_view: bool = false
var _window_focused := true
var _fire_armed := false

@export_group("Legacy voyage camera")
@export_range(0.1, 0.8, 0.05) var aim_camera_seconds: float = 0.4
@export_range(0.2, 1.0, 0.05) var camera_return_seconds: float = 0.4
## Offset from the existing cannon mount, in hull coordinates (X is starboard).
@export var aim_camera_offset := Vector3(-0.6, 1.0, -0.6)
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
var paused := false
var phase: int = 0
var phase_banner_left: float = 4.0
var storm_blend: float = 0.0
var last_sighting_time: float = 0.0
var _last_thunder: int = -1
var world_environment: WorldEnvironment
var moon: DirectionalLight3D
var _wave_audio: AudioStreamPlayer
var _victory_audio: AudioStreamPlayer
var _danger_audio: AudioStreamPlayer
var hull: int = 3
var damage_immunity: float = 0.0
var hit_flash: float = 0.0
var shake_strength: float = 0.0
var damage_shake_left: float = 0.0
var hit_message: String = ""
var hits_taken: int = 0
var hull_repair_elapsed: float = 0.0
var _last_hull_damage_time: float = 0.0
var voyage := VoyageDirector.new()
var archipelago: Node3D
var discovery_text: String = ""
var discovery_left: float = 0.0
var _at_sailing_boundary: bool = false
@export_group("Development")
@export var development_tools: bool = false
# Fixture switches; deliberately absent from the normal gameplay controls.
var development_camera_response := true
var development_spray := true
var development_overlays := true
var development_sound := true
var turbulence_effects: Node3D
var _warning_audio: AudioStreamPlayer
var heading: float = START_HEADING
var elapsed: float = 0.0
var sea_time: float = 0.0
var reading: bool = false
var read_blend: float = 0.0
var focus_elapsed: float = 0.0
var focus_strength: float = 0.0
var restart_elapsed: float = 0.0
var _restart_consumed: bool = false
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
var helm_anchor: Marker3D
var deck_response := DeckCameraResponse.new()
var camera: Camera3D
var sky_root: Node3D
var beacon: Node3D
var beacon_lamp: MeshInstance3D
var hud: Control
var cannon: Node3D
var enemy_encounters: Node3D
var ocean: Node3D
var boat_motion := BoatWaveMotion.new()
var combat_particles: Node3D
var boat_damage := BoatDamage.new()
var boost_wind: MeshInstance3D
var water_material: ShaderMaterial
var _cloud_layout := NightClouds.new()
var sky_material: ShaderMaterial
var obstacles: Array[Dictionary] = []
var target: Vector3 = Vector3.ZERO
var _sound: AudioStreamPlayer
var _music: AudioStreamPlayer
var _audio_playback: AudioStreamGeneratorPlayback
var _audio_phase: float = 0.0
var _audio_noise: float = 0.0
var _audio_rng := RandomNumberGenerator.new()
var _whiz_players: Array[AudioStreamPlayer3D] = []
var _whiz_player_cursor: int = 0
var _sound_enabled: bool = true
var diagnostic_audio_mode := 0
var diagnostic_generator := false
var _generator_skips_total := 0
var _last_generator_skips := 0


func course_forward() -> Vector3:
	var bearing := destination_bearing()
	return Vector3(sin(bearing), 0.0, -cos(bearing))


func course_right() -> Vector3:
	var bearing := destination_bearing()
	return Vector3(cos(bearing), 0.0, sin(bearing))


func _ready() -> void:
	_owns_quit_request = not OS.has_feature("web") and get_tree().current_scene == self
	if _owns_quit_request:
		_previous_auto_accept_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
	ocean_settings = ocean_settings.duplicate(true)
	hull = hull_capacity
	target = Vector3(-230, 0, -155)
	_configure_inputs()
	_build_world()
	_build_boat()
	archipelago = ARCHIPELAGO.instantiate()
	archipelago.arena_mode = arena_mode
	add_child(archipelago)
	archipelago.configure(self)
	if arena_mode:
		flow_zones.configure(archipelago.arena_layout.get_node("FlowZones"))
	_place_player()
	combat_particles = CombatParticles.new()
	combat_particles.name = "CombatParticles"
	add_child(combat_particles)
	cannon = CANNON_SCENE.instantiate()
	cannon.set("game", self)
	boat_visual.add_child(cannon)
	cannon.fired.connect(_on_cannon_fired)
	voyage.reset(encounter_seed)
	voyage.set_target(self)
	if arena_mode:
		target = arena_center()
	wave_encounters.reset(encounter_seed)
	_build_hazards()
	enemy_encounters = Node3D.new()
	enemy_encounters.set_script(ENCOUNTER_SCRIPT)
	enemy_encounters.set("game", self)
	add_child(enemy_encounters)
	_build_destination()
	if arena_mode:
		beacon_seen = true
		beacon.visible = true
		water_material.set_shader_parameter("coastal_foam_mask", ImageTexture.create_from_image(load("res://game/ocean/arena_coastal_foam_mask.res")))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(HUD_SCRIPT)
	hud.set("game", self)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	storm_atmosphere = StormAtmosphere.new()
	add_child(storm_atmosphere)
	add_child(storm_lightning)
	storm_lightning.reset(encounter_seed, storm_lightning_interval)
	turbulence_effects = TurbulenceEffects.new()
	turbulence_effects.name = "TurbulenceEffects"
	add_child(turbulence_effects)
	turbulence_effects.setup(self,layer)
	_build_audio()
	diagnostics = LiveDiagnostics.new()
	diagnostics.game = self
	add_child(diagnostics)
	active_fps = ActiveFPS.new()
	active_fps.game = self
	add_child(active_fps)
	mobile_controls = MobileControls.new()
	mobile_controls.game = self
	add_child(mobile_controls)
	if DisplayServer.get_name() != "headless":
		_warning_audio = cannon._audio(220.0, 0.5, -18.0)
		_wave_audio = cannon._audio(110.0, 0.55, -22.0)
		_victory_audio = cannon._audio(440.0, 0.03, -16.0)
		_danger_audio = cannon._audio(66.0, 0.8, -16.0)
	_update_view(1.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(ProjectSettings.get_setting("application/config/name"))
	for arg in OS.get_cmdline_user_args():
		if arg == "--debug-tools":
			development_tools = true
		if arg == "--layout-debug":
			development_tools = true
			archipelago.toggle_debug()


func _configure_inputs() -> void:
	var bindings := {
		"steer_port": [KEY_A, KEY_LEFT], "steer_starboard": [KEY_D, KEY_RIGHT],
		"astrolabe": [] if arena_mode else [KEY_SPACE], "restart_crossing": [KEY_R],
		"begin_crossing": [KEY_ENTER], "mute_sea": [KEY_M],
		"fire_starboard": [KEY_SPACE] if arena_mode else [KEY_F], "watch_starboard": [KEY_E], "fire_mouse": [],
		"boost_sailing": [KEY_SHIFT, KEY_W],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

	if arena_mode:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire_mouse", click)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device in [InputEvent.DEVICE_ID_EMULATION, MobileControls.MENU_DEVICE]: return
	if paused or (is_instance_valid(diagnostics) and diagnostics.panel.visible):
		return
	# A fresh canvas click can restore capture if a browser denied an Esc resume.
	if OS.has_feature("web") and arena_mode and state == State.SAILING and _window_focused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_request_mouse_capture()
	if arena_mode and event is InputEventMouseMotion:
		if state == State.SAILING and _window_focused:
			var motion: Vector2 = event.relative
			# Relative input follows Godot's viewport stretch. Retain the authored
			# 1280-pixel look sensitivity when Web switches between 540p and 720p.
			if OS.has_feature("web") and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
				motion *= 1280.0 / get_window().content_scale_size.x
			apply_camera_look(motion)
		return
	if walkthrough.active and (walkthrough.step != Walkthrough.Step.FIRE or walkthrough.practiced) and (event.is_action("fire_starboard") or event.is_action("fire_mouse")):
		return
	if development_tools and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F2:
			archipelago.toggle_debug()
		elif event.keycode in [KEY_F3, KEY_F4, KEY_F5]:
			archipelago.debug_spawn(event.keycode - KEY_F3)
		elif event.keycode == KEY_F6:
			archipelago.debug_wave_zone()
		elif event.keycode == KEY_F7 and arena_mode and state == State.SAILING:
			enemy_encounters.debug_cutter()
	# Hidden wave-arrival shortcut is available in normal and exported play.
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD] or event.unicode == KEY_PLUS:
			if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
				enemy_encounters.debug_skip_wave()
				get_viewport().set_input_as_handled()
				return
	if event.is_action("restart_crossing") and not event.is_echo():
		if not event.is_pressed():
			restart_elapsed = 0.0
			_restart_consumed = false
		elif not _restart_consumed and state in [State.LOST, State.ARRIVED] and result_ready() and not hud.settings_open and not hud.credits_open:
			restart()
	elif event.is_action_pressed("begin_crossing") and state == State.READY and not hud.settings_open and not hud.credits_open:
		# Preserve the focused launch action when Enter reaches the global shortcut.
		start_crossing(hud.walkthrough_button.has_focus() and hud.walkthrough_button.is_visible_in_tree())
	elif (event.is_action("fire_starboard") or (arena_mode and event.is_action("fire_mouse"))) and not event.is_echo():
		if not arena_mode:
			cannon.set_fire_held(event.is_pressed())
		elif state == State.SAILING and _window_focused:
			_set_arena_fire(event.is_pressed())
	elif event.is_action("watch_starboard") and not event.is_echo():
		if arena_mode:
			if event.is_pressed() and state == State.SAILING and _window_focused:
				arena_cannon_view = not arena_cannon_view
		else:
			cannon.set_aim_held(event.is_pressed())
	elif event.is_action("astrolabe") and not event.is_echo() and not arena_mode:
		# Even a release/repress between physics ticks starts a new sighting.
		focus_elapsed = 0.0
		focus_strength = 0.0
		if event.is_pressed():
			cannon.cancel_aim()
		else:
			reading = false
		update_guiding_star()
	elif event.is_action_pressed("mute_sea"):
		_sound_enabled = not _sound_enabled
		_sync_audio_volumes(1.0)
		note_event("mute", {"muted": not _sound_enabled})


func apply_camera_look(motion: Vector2) -> void:
	walkthrough.note_mouse(motion)
	look_target = clampf(look_target - motion.x * camera_mouse_sensitivity, -camera_yaw_limit, camera_yaw_limit)
	if not motion.is_zero_approx(): look_idle = 0.0


func _set_arena_fire(pressed: bool) -> void:
	if walkthrough.active and (walkthrough.step != Walkthrough.Step.FIRE or walkthrough.practiced): return
	if paused or state != State.SAILING or not _window_focused: return
	if pressed: _fire_armed = true
	cannon.set_fire_held(_fire_armed and (Input.is_action_pressed("fire_starboard") or Input.is_action_pressed("fire_mouse")))


func set_touch_fire(pressed: bool) -> void:
	if pressed: Input.action_press("fire_starboard")
	else: Input.action_release("fire_starboard")
	_set_arena_fire(pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _owns_quit_request:
		if not _closing:
			_closing = true
			AudioShutdown.close_scene(self)
		return
	if what not in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: return
	if not is_instance_valid(cannon): return
	var focused := what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]
	# Browser document/canvas state is authoritative; pointer capture isn't focus.
	if OS.has_feature("web") and is_instance_valid(diagnostics) and diagnostics._has_browser:
		focused = diagnostics.browser_focused()
	application_focus_changed(focused, "godot_notification")


func application_focus_changed(focused: bool, source: String) -> void:
	_window_focused = focused
	note_event("focus", {"focused": focused, "source": source})
	if not focused:
		_clear_player_controls()
		Input.action_release("restart_crossing")
		_restart_consumed = false
		set_paused(true)
		if is_instance_valid(diagnostics): diagnostics.pause_audio(true)
	# Restoring focus never resumes gameplay or captures the pointer.
	elif not paused and is_instance_valid(diagnostics):
		diagnostics.pause_audio(false)


func _request_mouse_capture() -> void:
	if is_instance_valid(mobile_controls) and mobile_controls.enabled: return
	if not arena_mode or not _window_focused: return
	if OS.has_feature("web") and (not is_instance_valid(diagnostics) or not diagnostics.can_capture()):
		note_event("pointer_capture_deferred", {"reason": "no_browser_user_gesture"})
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_paused(value: bool, restore_capture: bool = true) -> void:
	if value == paused or (value and state not in [State.SAILING, State.CASTING_OFF]): return
	if not value and restore_capture and is_instance_valid(diagnostics):
		diagnostics.focus_canvas()
		if OS.has_feature("web") and not _window_focused: return
	# Set paused before releasing pointer lock, which may notify synchronously.
	paused = value
	_clear_player_controls(false)
	Input.action_release("restart_crossing")
	_restart_consumed = false
	get_tree().paused = value
	if is_instance_valid(diagnostics):
		diagnostics.steering(0.0)
		diagnostics.pause_audio(value)
	note_event("pause", {"paused": value})
	if not value and restore_capture and state == State.SAILING and not walkthrough.active:
		_request_mouse_capture()
	hud._sync_button()
	hud.queue_redraw()


func _clear_player_controls(reset_view: bool = true, release_mouse: bool = true) -> void:
	if is_instance_valid(mobile_controls): mobile_controls.reset_touches()
	_fire_armed = false
	if reset_view:
		look_yaw = 0.0
		look_target = 0.0
		look_idle = 0.0
	if arena_mode:
		if reset_view:
			arena_cannon_view = false
			aim_camera_blend = 0.0
			camera_mode = CameraMode.SAILING
		if release_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action: String in ["watch_starboard", "fire_starboard", "fire_mouse", "astrolabe", "steer_port", "steer_starboard", "boost_sailing"]:
		Input.action_release(action)
	cannon.set_aim_held(false)
	cannon.set_fire_held(false)
	reading = false
	boosting = false
	if is_instance_valid(boost_wind): boost_wind.reset()
	turn_input = 0.0
	focus_elapsed = 0.0
	focus_strength = 0.0
	restart_elapsed = 0.0
	_restart_consumed = Input.is_action_pressed("restart_crossing")
	update_guiding_star()


func _update_restart_hold(delta: float) -> void:
	if not Input.is_action_pressed("restart_crossing"):
		restart_elapsed = 0.0
		_restart_consumed = false
	elif state == State.SAILING and not _restart_consumed:
		restart_elapsed += delta
		if restart_elapsed + 0.000001 >= RESTART_HOLD_SECONDS:
			restart()
	else:
		restart_elapsed = 0.0


func _on_cannon_fired(_direction: Vector3) -> void:
	_cannon_impulse = 1.0
	note_event("cannon_volley", {"side": "player", "shots": cannon.shots_fired})


func start_crossing(with_walkthrough: bool = false) -> void:
	if state != State.READY:
		return
	walkthrough.pending = arena_mode and with_walkthrough
	restart_elapsed = 0.0
	_restart_consumed = Input.is_action_pressed("restart_crossing")
	transition_elapsed = 0.0
	_transition_from = camera.transform
	state = State.CASTING_OFF
	if is_instance_valid(diagnostics):
		diagnostics.focus_canvas()
		diagnostics.pause_audio(false)
	if not with_walkthrough: _request_mouse_capture()


func arena_center() -> Vector3:
	var landmark: Vector3 = archipelago.get_node("Landmarks/Lighthouse").global_position
	return Vector3(landmark.x, 0.0, landmark.z)


func _place_player() -> void:
	var spawn: Marker3D = archipelago.get_node("SpawnPoints/ArenaSpawn" if arena_mode else "SpawnPoints/Departure")
	var forward := -spawn.global_basis.z
	heading = atan2(forward.x, -forward.z) if arena_mode else START_HEADING
	boat.global_transform = Transform3D(Basis(Vector3.UP, -heading), spawn.global_position)


func destination_bearing() -> float:
	# Internal radians may be signed; presentation converts absolute bearings to 000–359°.
	return NavigationBearings.bearing_to(boat.global_position if is_instance_valid(boat) else Vector3.ZERO, target, heading)


func destination_turn() -> float:
	return NavigationBearings.signed_turn(heading, destination_bearing())


func guiding_star_direction() -> Vector3:
	# The same live landmark bearing drives the sky, focus and edge projection.
	# North is -Z, east is +X; neither camera shake nor hull rocking enters here.
	var bearing := destination_bearing()
	return Vector3(sin(bearing) * cos(GUIDING_STAR_ELEVATION), sin(GUIDING_STAR_ELEVATION),
		-cos(bearing) * cos(GUIDING_STAR_ELEVATION))


func guiding_star_color() -> Color:
	return GUIDING_STAR_COLORS[mini(voyage.stage, 2)]


func update_guiding_star() -> void:
	sky_material.set_shader_parameter("guiding_star", guiding_star_direction())
	sky_material.set_shader_parameter("guiding_star_color", guiding_star_color())
	sky_material.set_shader_parameter("active_star", mini(voyage.stage, 2))
	sky_material.set_shader_parameter("target_focus", focus_strength * target_highlight_strength if reading and state == State.SAILING else 0.0)


func show_discovery(value: String, seconds: float = 4.0) -> void:
	discovery_text = value
	discovery_left = seconds


func journey_progress() -> float:
	if arena_mode:
		return 0.0
	if voyage.stage == voyage.Stage.COMPLETE:
		return 1.0
	var lengths := [350.0, 470.0, 410.0]
	var local_progress := clampf(1.0 - boat.position.distance_to(target) / lengths[voyage.stage], 0.0, 0.99)
	return (voyage.stage + local_progress) / 3.0


func restart(to_menu: bool = false) -> void:
	var retry_wave: int = maxi(1, enemy_encounters.wave_number) if arena_mode and state == State.LOST and not to_menu else 0
	note_event("restart", {"to_menu": to_menu, "retry_wave": retry_wave})
	set_paused(false, false)
	walkthrough.cancel()
	hud.reset_storm_notice()
	combat_particles.reset()
	# A held-R restart keeps an existing Web capture; opening menus releases it.
	_clear_player_controls(true, to_menu or not OS.has_feature("web"))
	flow_zones.reset()
	cannon.reset()
	wave_sailing.reset()
	arena_return.reset()
	wave_encounters.reset(encounter_seed)
	ocean.wave_field.clear()
	sea_time = 0.0
	actual_speed = 0.0
	hull = hull_capacity
	damage_immunity = 0.0
	hit_flash = 0.0
	shake_strength = 0.0
	damage_shake_left = 0.0
	hits_taken = 0
	hull_repair_elapsed = 0.0
	_last_hull_damage_time = 0.0
	phase = 0
	phase_banner_left = 4.0
	storm_blend = arena_storm_strength if arena_mode and weather_enabled else 0.0
	last_sighting_time = 0.0
	_last_thunder = -1
	storm_lightning.reset(encounter_seed, storm_lightning_interval)
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
	if arena_mode:
		target = arena_center()
	archipelago.reset()
	discovery_left = 0.0
	_at_sailing_boundary = false
	_place_player()
	boat.velocity = Vector3.ZERO
	boat_motion.reset()
	ocean.reset_wake(heading)
	elapsed = 0.0
	enemy_encounters.reset()
	reading = false
	read_blend = 0.0
	focus_elapsed = 0.0
	focus_strength = 0.0
	aim_camera_blend = 0.0
	combat_camera_blend = 0.0
	_camera_aim_degrees = 0.0
	_camera_target_offset = Vector3.ZERO
	_sailing_camera_initialized = false
	deck_response.reset()
	turbulence_effects.reset()
	ocean.clear_turbulence()
	_camera_clear_fraction = 1.0
	_cannon_impulse = 0.0
	camera_mode = CameraMode.SAILING
	turn_input = 0.0
	last_reading = heading
	has_reading = false
	beacon_seen = arena_mode
	beacon.visible = arena_mode
	failure_reason = ""
	result_active = false
	result_elapsed = 0.0
	result_salutes = 0
	transition_elapsed = 0.0
	end_view_blend = 0.0
	state = State.READY
	_build_hazards()
	_update_view(1.0)
	if not to_menu:
		start_crossing()
		if retry_wave > 0:
			enemy_encounters.resume_wave(retry_wave)


func _physics_process(delta: float) -> void:
	var started := ActiveMetrics.start()
	_measured__physics_process(delta)
	ActiveMetrics.finish("physics_tick", started)


func _measured__physics_process(delta: float) -> void:
	if is_instance_valid(diagnostics): diagnostics.poll_lifecycle()
	if not _window_focused and state in [State.SAILING, State.CASTING_OFF]:
		set_paused(true)
	if paused:
		return
	if result_active:
		if result_ready(): return
		result_elapsed = minf(result_duration(), result_elapsed + delta)
		# Two blank salutes reuse muzzle/smoke/audio, never gameplay projectiles.
		if state == State.ARRIVED:
			while result_salutes < 2 and result_elapsed >= 1.1 + result_salutes * 0.85:
				cannon.salute()
				result_salutes += 1
		sea_time += delta
		_update_view(delta)
		hud.queue_redraw()
		return
	_update_restart_hold(delta)
	if walkthrough.active and state == State.SAILING:
		_physics_walkthrough(delta)
		return
	boosting = state == State.SAILING and Input.is_action_pressed("boost_sailing")
	if state != State.SAILING:
		sea_time += delta
	reading = not arena_mode and state == State.SAILING and Input.is_action_pressed("astrolabe")
	if reading or state != State.SAILING:
		cannon.cancel_aim()
	if arena_mode:
		var held := Input.is_action_pressed("fire_starboard") or Input.is_action_pressed("fire_mouse")
		if not held:
			_fire_armed = false
		cannon.set_fire_held(held and _fire_armed and _window_focused and state == State.SAILING)
		if not OS.has_feature("web") and not (is_instance_valid(mobile_controls) and mobile_controls.enabled):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == State.SAILING and _window_focused else Input.MOUSE_MODE_VISIBLE
		elif state not in [State.SAILING, State.CASTING_OFF] or not _window_focused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		cannon.set_aim_held(Input.is_action_pressed("watch_starboard"))
		cannon.set_fire_held(Input.is_action_pressed("fire_starboard"))
	cannon.update_aim(delta)
	if state == State.SAILING:
		turn_input = 0.0 if (not arena_mode and cannon.aiming) or (arena_mode and not _window_focused) else Input.get_axis("steer_port", "steer_starboard")
		advance_sailing(delta, turn_input)
	elif state == State.CASTING_OFF:
		reading = false
		turn_input = 0.0
		transition_elapsed = minf(CAST_OFF_SECONDS, transition_elapsed + delta)
		if transition_elapsed >= CAST_OFF_SECONDS:
			state = State.SAILING
			if walkthrough.pending:
				walkthrough.begin(self)
	else:
		reading = false
		turn_input = 0.0
	_update_view(delta)
	if arena_mode:
		cannon.update_cone_feedback()
	hud.queue_redraw()


func _physics_walkthrough(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	boosting = walkthrough.step == Walkthrough.Step.BOOST and walkthrough.moving(self)
	var fire: bool = walkthrough.step == Walkthrough.Step.FIRE and not walkthrough.practiced and _window_focused
	cannon.set_fire_held(fire and _fire_armed and (Input.is_action_pressed("fire_starboard") or Input.is_action_pressed("fire_mouse")))
	cannon.update_aim(delta)
	if walkthrough.moving(self):
		turn_input = Input.get_axis("steer_port", "steer_starboard")
		advance_sailing(minf(delta, maxf(0.0, 0.5 - walkthrough.held_seconds)), turn_input)
	else:
		turn_input = 0
		actual_speed = 0
		boat.velocity = Vector3.ZERO
		wave_sailing.reset()
	walkthrough.update(self, delta)
	_update_view(delta)
	cannon.update_cone_feedback()
	hud.queue_redraw()


func finish_walkthrough() -> void:
	if not walkthrough.active: return
	walkthrough.finish()
	# Begin a clean scored voyage: no practice time, shots, boosts or scenery damage.
	restart()


func advance_sailing(delta: float, steering: float) -> void:
	# Bound long frames so real obstacle collision sweeps remain continuous.
	if arena_mode and delta > 1.0 / 30.0 + 0.00001:
		var steps := ceili(delta * 60.0)
		for step in steps:
			advance_sailing(delta / steps, steering)
		return
	# Also used by the deterministic smoke test, with real physics collisions.
	if state != State.SAILING:
		return
	elapsed += delta
	sea_time += delta
	damage_immunity = maxf(0.0, damage_immunity - delta)
	if not walkthrough.active:
		wave_encounters.update(self, delta)
	ocean.wave_time = sea_time
	if not walkthrough.active:
		enemy_encounters.update_encounters(delta)
	if state != State.SAILING:
		_clear_player_controls()
		cannon.reset()
		enemy_encounters.stop()
		wave_encounters.stop(ocean.wave_field)
		wave_sailing.reset()
		flow_zones.reset()
		boat.velocity = Vector3.ZERO
		actual_speed = 0.0
		return
	if arena_mode:
		var earned := flow_zones.collect_at(Vector2(boat.global_position.x, boat.global_position.z))
		if earned > 0:
			show_discovery("SPEED +25%", 2.2)
			cue_sound("victory")
	var forward_speed := propulsion_speed()
	# Only the retained voyage fixture has a gun-view steering gate.
	if not arena_mode and cannon.aiming:
		steering = 0.0
	if is_instance_valid(diagnostics): diagnostics.steering(steering)
	var movement_started := ActiveMetrics.start()
	var center: Vector3 = boat.to_global(BoatWaveMotion.HULL_CENTER)
	wave_sailing.rudder_response = arena_rudder_response if arena_mode else 7.0
	heading = wave_sailing.step(ocean.wave_field, Vector2(center.x, center.z), heading, steering, sea_time, delta, forward_speed)
	boat.rotation.y = -heading
	boat.velocity = Vector3(wave_sailing.displacement.x, 0, wave_sailing.displacement.y) / maxf(delta, 0.0001)
	var previous_position := boat.position
	var travel := boat.velocity * delta
	var hit := boat.move_and_collide(travel, false, 0.001, arena_mode)
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
	ActiveMetrics.finish("player_movement", movement_started)
	if reading and focus_strength >= 1.0:
		# This snapshot is a focused landmark reading, not the bow's heading.
		# It never supplies a sailing arrow or persistent HUD label.
		last_reading = destination_bearing()
		has_reading = true
		last_sighting_time = elapsed
	if not arena_mode:
		voyage.update_progress(self)
		archipelago.update_discoveries()
	var distance := boat.position.distance_to(archipelago.get_node("Landmarks/Lighthouse").position)
	if voyage.stage >= voyage.Stage.LIGHTHOUSE and distance < 230.0 and not beacon_seen:
		beacon_seen = true
		beacon.visible = true
	if state == State.LOST or state == State.ARRIVED:
		_clear_player_controls()
		cannon.reset()
		enemy_encounters.stop()
		wave_encounters.stop(ocean.wave_field)
		wave_sailing.reset()
		flow_zones.reset()
	_update_hull_recovery(delta)


func storm_distance() -> float:
	var offset := boat.global_position - arena_center()
	return Vector2(offset.x, offset.z).length()


func storm_warning_strength() -> float:
	if not arena_mode or state != State.SAILING:
		return 0.0
	return smoothstep(arena_radius - storm_warning_margin, arena_radius, storm_distance())


func outside_storm_line() -> bool:
	return arena_mode and state == State.SAILING and storm_distance() >= arena_radius


func propulsion_speed() -> float:
	var rewarded_speed := sailing_speed * flow_zones.multiplier() if arena_mode else sailing_speed
	return rewarded_speed * (1.5 if boosting and state == State.SAILING else 1.0)


func is_repairing_hull() -> bool:
	return state == State.SAILING and hull > 0 and hull < hull_capacity and not enemy_encounters.battle_active()


func restore_hull(amount: int) -> bool:
	if state != State.SAILING or hull <= 0 or hull >= hull_capacity or amount <= 0:
		return false
	hull = mini(hull_capacity, hull + amount)
	if hull == hull_capacity:
		hull_repair_elapsed = 0.0
	boat_damage.update(hull, hull_capacity, hit_flash)
	return true


func _update_hull_recovery(delta: float) -> void:
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
	if arena_mode:
		return
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
		show_discovery("Return to the islands")
	_at_sailing_boundary = at_boundary


func take_damage(amount: int, reason: String) -> bool:
	if walkthrough.active: return false
	if state != State.SAILING or damage_immunity > 0.0 or amount <= 0:
		return false
	hull = maxi(0, hull - amount)
	hits_taken += 1
	note_event("hull_damage", {"hull": hull, "reason": reason, "amount": amount})
	hull_repair_elapsed = 0.0
	_last_hull_damage_time = elapsed
	damage_immunity = hit_immunity_seconds
	hit_flash = 0.8
	boat_damage.update(hull, hull_capacity, hit_flash)
	hit_message = reason.to_upper()
	damage_shake_left = DAMAGE_SHAKE_SECONDS
	cue_sound("damage")
	if hull == 0:
		flow_zones.reset()
		boat.velocity = Vector3.ZERO
		actual_speed = 0.0
		wave_encounters.stop(ocean.wave_field)
		wave_sailing.reset()
		failure_reason = "The hull gave way. The sea came in."
		begin_result(false)
		note_event("death", {"wave": enemy_encounters.wave_number})
		_clear_player_controls()
		cannon.reset()
	combat_particles.damage(boat_visual.to_global(Vector3(0, 1.0, -1.8)), hull == 0)
	return true


func result_duration() -> float:
	return VICTORY_HOLD_SECONDS if state == State.ARRIVED else LOSS_HOLD_SECONDS


func result_ready() -> bool:
	return not result_active or result_elapsed >= result_duration()


func begin_result(won: bool) -> void:
	if result_active: return
	state = State.ARRIVED if won else State.LOST
	if not arena_mode: return
	result_active = true
	result_elapsed = 0.0
	result_salutes = 0
	_result_camera_from = camera.transform
	_result_camera_offset = camera.h_offset
	var at := boat.position + Basis(Vector3.UP, -heading) * Vector3(9, 6, 12)
	var focus := boat.position + Vector3.UP * 1.5
	if won:
		at = camera.position + Vector3.UP * 3.0
		focus = enemy_encounters.boss.position + Vector3.UP * 3.0
	at = _camera_obstruction_limit(at)
	_result_camera_to = Transform3D(Basis.looking_at(focus - at), at)
	_clear_player_controls(false)
	cannon.reset()
	enemy_encounters.stop()
	wave_encounters.stop(ocean.wave_field)
	wave_sailing.reset()
	flow_zones.reset()
	boat.velocity = Vector3.ZERO
	actual_speed = 0.0
	if won: cue_sound("victory")


func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func _update_view(delta: float) -> void:
	var started := ActiveMetrics.start()
	_measured__update_view(delta)
	ActiveMetrics.finish("view", started)


func _measured__update_view(delta: float) -> void:
	flow_zones.present(water_material, arena_mode and state == State.SAILING)
	var light := arena_center()
	water_material.set_shader_parameter("storm_boundary", Vector4(light.x, light.z, arena_radius, storm_warning_strength()))
	discovery_left = maxf(0.0, discovery_left - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	boat_damage.update(hull, hull_capacity, hit_flash, delta, state == State.SAILING)
	shake_strength = maxf(0.0, shake_strength - delta * 0.9)
	damage_shake_left = maxf(0.0, damage_shake_left - delta)
	_update_weather(delta)
	_apply_night_illumination()
	storm_atmosphere.present(self)
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
	ocean.update_turbulence(wave_encounters,delta)
	var sailing_turn := wave_sailing.rudder_rate + wave_sailing.yaw_rate if state == State.SAILING else 0.0
	# Legacy gun view settles sail heel; the arena always keeps sailing trim.
	var trim_speed := 0.0 if not arena_mode and cannon.aiming else speed_factor
	boat_motion.update_motion(ocean, boat, boat_visual, delta, false, trim_speed, sailing_turn)
	player_pennant.flutter(sea_time)
	boost_wind.update_wind(boosting and state==State.SAILING,sea_time,delta,camera,motion_setting==1,cannon.aiming)
	enemy_encounters.update_visuals(delta)
	if state == State.LOST:
		var sink := smoothstep(0.15, LOSS_HOLD_SECONDS, result_elapsed) if result_active else end_view_blend
		boat_visual.position.y -= sink * 3.8
		boat_visual.rotation.z += sink * 0.42
	var sky_blend := smoothstep(0.0, 1.0, read_blend)
	var helm_pose := _normal_sailing_pose(delta)
	helm_pose = _sailing_camera_pose(helm_pose, delta)
	# Sky has final priority, including while the aim camera is blending out.
	var sky_pose := Transform3D(Basis.from_euler(Vector3(deg_to_rad(stargazing_pitch_degrees), -heading, 0.0)),
		boat.position + Basis(Vector3.UP, -heading) * Vector3(0, 2.55, -4.5))
	helm_pose = helm_pose.interpolate_with(sky_pose, sky_blend)
	camera.h_offset = 0.0
	var base_fov := 62.0 if sailing_camera_rig == SailingCameraRig.CHASE else 74.0
	var sailing_fov := lerpf(base_fov + sailing_speed_fov * _sailing_speed * motion_amount(), 74.0, smoothstep(0.0, 1.0, combat_camera_blend))
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
	elif result_active:
		# Preserve the killing frame, then ease to the wreck without a menu cut.
		end_view_blend = smoothstep(0.15, 1.25, result_elapsed)
		camera.transform = _result_camera_from.interpolate_with(_result_camera_to, end_view_blend)
		camera.h_offset = lerpf(_result_camera_offset, 0.0, end_view_blend)
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
		# Keep generic firing/impact shake restrained; retain dedicated gun recoil.
		var sailing_shake := lerpf(0.22, 1.0, maxf(aim_camera_blend, combat_camera_blend))
		var sight_shake := shake_strength * lerpf(sailing_shake, 0.15, sky_blend) * motion_amount()
		camera.position += camera.basis.x * sin(sea_time * 73.0) * sight_shake
		camera.position.y += cos(sea_time * 91.0) * sight_shake * 0.5
		camera.position -= cannon.aimed_direction() * _cannon_impulse * 0.18 * (1.0 - sky_blend) * motion_amount()
	if state == State.SAILING or state == State.LOST:
		# A separate hit envelope makes hull damage readable in the chase view,
		# including the killing blow, without amplifying cannon recoil or rolling the horizon.
		var hit_envelope := pow(damage_shake_left / DAMAGE_SHAKE_SECONDS, 2.0)
		var hit_time := DAMAGE_SHAKE_SECONDS - damage_shake_left
		var rig_scale := 1.0 if sailing_camera_rig == SailingCameraRig.CHASE else 0.22
		var hit_amount := DAMAGE_SHAKE_DISTANCE * hit_envelope * lerpf(rig_scale, 0.15, sky_blend) * motion_amount()
		camera.position += (camera.basis.x * cos(hit_time * 67.0) + camera.basis.y * sin(hit_time * 89.0) * 0.5) * hit_amount
		camera.position.y = maxf(camera.position.y, ocean.height_at(Vector2(camera.position.x, camera.position.z)) + 1.2)
		# Final safety includes sky transitions, recoil and damage displacement.
		camera.position = _camera_obstruction_limit(camera.position)
	_cannon_impulse *= exp(-16.0 * delta)
	turbulence_effects.update_effects(self,delta)
	if state != State.SAILING:
		turbulence_effects.reset()
	sky_root.position = camera.position
	sky_material.set_shader_parameter("visual_time", sea_time)
	sky_material.set_shader_parameter("star_density", star_density)
	sky_material.set_shader_parameter("twinkle_strength", twinkle_strength)
	var storm_cover := storm_blend * 0.42 if arena_mode and weather_enabled else 0.0
	sky_material.set_shader_parameter("cloud_density", lerpf(cloud_density, 1.0, storm_cover))
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
	if is_instance_valid(active_fps): active_fps.after_view()
	update_guiding_star()
	if is_instance_valid(beacon_lamp):
		beacon_lamp.scale = Vector3.ONE * (1.0 + sin(sea_time * 1.7) * 0.12)


func _normal_sailing_pose(delta: float) -> Transform3D:
	helm_anchor.position = helm_eye
	var center := boat.to_global(BoatWaveMotion.HULL_CENTER)
	# The chase view follows the planar hull, with only a little filtered heave.
	# Wave pitch/roll remain visible on the boat without tilting the horizon.
	center.y += clampf((boat_motion.heave - ocean_settings.sea_level) * ocean_settings.camera_bob_strength, -0.18, 0.18) * motion_amount()
	var speed := clampf(actual_speed / SPEED, 0.0, 1.15) if state == State.SAILING else 0.0
	if not _sailing_camera_initialized or _sailing_anchor.distance_to(center) > 60.0 or delta > 0.25:
		deck_response.reset()
		_sailing_anchor = center
		_sailing_heading = heading
		_sailing_speed = speed
		_sailing_camera_initialized = true
		_camera_clear_fraction = 1.0
	else:
		_sailing_anchor = _sailing_anchor.lerp(center, 1.0 - exp(-sailing_follow_smoothing * delta))
		_sailing_heading = lerp_angle(_sailing_heading, heading, 1.0 - exp(-sailing_rotation_smoothing * delta))
		_sailing_speed = lerpf(_sailing_speed, speed, 1.0 - exp(-3.0 * delta))
	# Continue detecting real crest contacts for spray/audio in either view.
	var result := deck_response.pose(helm_anchor, boat, boat_motion, ocean, heading, 0.0,
		delta, motion_amount(), state == State.SAILING)
	if sailing_camera_rig == SailingCameraRig.DECK:
		if development_tools and not development_camera_response:
			return Transform3D(Basis.from_euler(Vector3(-deg_to_rad(7),-heading,0)),boat.to_global(helm_eye))
		return result
	if arena_mode:
		look_idle += delta
		if look_idle > camera_recenter_delay:
			look_target *= exp(-camera_recenter_speed * delta)
		look_yaw = lerpf(look_yaw, look_target, 1.0 - exp(-camera_look_response * delta))
	var orientation := Basis(Vector3.UP, -_sailing_heading + deg_to_rad(look_yaw if arena_mode else 0.0))
	var distance := sailing_follow_distance * (1.0 + _sailing_speed * 0.07)
	var at := _sailing_anchor + orientation * Vector3(-camera_port_offset if arena_mode else 0.0, sailing_camera_height, distance)
	var focus := _sailing_anchor + orientation * Vector3(camera_starboard_focus if arena_mode else 0.0, 0.85, -sailing_look_ahead)
	return Transform3D(Basis.looking_at(focus - at, Vector3.UP), at)


func motion_amount() -> float:
	return 0.28 if motion_setting == 1 else 1.0


func _camera_obstruction_limit(at: Vector3) -> Vector3:
	var started := ActiveMetrics.start()
	var result := _measured__camera_obstruction_limit(at)
	ActiveMetrics.finish("camera_collision", started)
	return result


func _measured__camera_obstruction_limit(at: Vector3) -> Vector3:
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
	if arena_mode:
		# E changes only the view. The cannon and steering have no aiming mode.
		var close_view: bool = arena_cannon_view and state == State.SAILING
		camera_mode = CameraMode.CANNON if close_view else CameraMode.SAILING
		var seconds: float = aim_camera_seconds if close_view else camera_return_seconds
		aim_camera_blend = move_toward(aim_camera_blend, 1.0 if close_view else 0.0, delta / seconds)
		combat_camera_blend = 0.0
		var orientation := Basis(Vector3.UP, -_sailing_heading)
		var mount := _sailing_anchor + orientation * (cannon.position - BoatWaveMotion.HULL_CENTER)
		# The mount already has smoothed wave heave; follow it vertically so the
		# barrel cannot rise through the close camera on the larger rolling sea.
		mount.y = cannon.global_position.y
		# The outboard eye looks across open sea at either mouse limit.
		# Keep the same bounded yaw and filtered tracking, independent of aim.
		var at := mount + orientation * cannon_view_offset
		var focus := mount + orientation * (Vector3.RIGHT * 22.0 + Vector3.UP * 0.5)
		focus = at + (focus - at).rotated(Vector3.UP, deg_to_rad(look_yaw))
		var close_pose := Transform3D(Basis.looking_at(focus - at, Vector3.UP), at)
		var pose := helm_pose.interpolate_with(close_pose, smoothstep(0, 1, aim_camera_blend))
		return _safe_chase_pose(pose, delta)
	# Compose poses for the single transform writer in _update_view; never change gun yaw.
	var ship = enemy_encounters.focus_ship()
	var combat: bool = ocean.wave_field.waves.is_empty() and not wave_encounters.busy() and is_zero_approx(turn_input) and enemy_encounters.enabled and ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED, ship.Mode.SINKING] and ship.position.distance_to(boat.position) < 80.0
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


func _safe_chase_pose(pose: Transform3D, delta: float) -> Transform3D:
	var anchor := _camera_shore_anchor()
	var distance := anchor.distance_to(pose.origin)
	var safe := anchor.distance_to(_camera_obstruction_limit(pose.origin))
	var fraction := clampf(safe / maxf(distance, 0.01), 0.0, 1.0)
	_camera_clear_fraction = minf(fraction, lerpf(_camera_clear_fraction, 1.0, 1.0 - exp(-5.0 * delta)))
	pose.origin = anchor.lerp(pose.origin, _camera_clear_fraction)
	return pose


func _title_camera_pose() -> Transform3D:
	if arena_mode:
		var at := arena_center() + Vector3(95, 42, -145)
		# Menu composition: leave sky for the centred title and light below it.
		var focus := arena_center() + Vector3(0, 42, -12)
		return Transform3D(Basis.looking_at(focus - at), at)
	var orientation := Basis(Vector3.UP, -heading)
	var at := boat.position + orientation * Vector3(7.0, 4.5, -7.0)
	var look_at_point := boat.position + orientation * Vector3(0.0, 0.8, -1.6)
	return Transform3D(Basis.looking_at(look_at_point - at), at)


func _process(delta: float) -> void:
	_fill_audio()
	_sync_audio_volumes(delta)


func _exit_tree() -> void:
	if _owns_quit_request and not _closing:
		get_tree().auto_accept_quit = _previous_auto_accept_quit
	if paused:
		get_tree().paused = false
		paused = false
	if is_instance_valid(_sound):
		_sound.stop()
	if is_instance_valid(_music):
		_music.stop()
	for player in _whiz_players:
		player.stop()
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
	environment.ambient_light_color = night_ambient_color
	environment.ambient_light_energy = calm_ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = night_fog_color
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.0035
	environment.fog_sky_affect = 0.0
	world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
	moon.light_color = moonlight_color
	moon.light_energy = calm_moon_energy
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
	boost_wind = BoostWind.new()
	boost_wind.name = "BoostTailwind"
	boat_visual.add_child(boost_wind)
	helm_anchor = Marker3D.new()
	helm_anchor.name = "HelmEye"
	helm_anchor.position = helm_eye
	boat_visual.add_child(helm_anchor)
	var ship: Node3D = PLAYER_SAIL_BOAT.instantiate()
	ship.name = "SailBoatPlayer"
	# The source bow faces +Z; seat the 6 m hull around the existing flotation centre.
	ship.rotation.y = PI
	ship.scale = Vector3.ONE * 7.0
	ship.position = Vector3(-0.072, 0.0, -2.065)
	boat_visual.add_child(ship)
	var sail := ship.get_node("RootNode/Sail") as Node3D
	# Restore the visible canvas and boom angle from 534b021 for the chase view.
	sail.basis = Basis(Vector3.UP, deg_to_rad(35.0)) * sail.basis
	sail.visible = sailing_camera_rig == SailingCameraRig.CHASE
	# Surface 1 is canvas; surface 0 includes the mast and boom. Never edit imports.
	var canvas := (sail as MeshInstance3D).get_active_material(1).duplicate() as StandardMaterial3D
	canvas.albedo_color = Color("d7bd8b") # Warm ivory under the nearby amber lantern.
	canvas.metallic = 0.0
	canvas.roughness = 0.95
	canvas.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	(sail as MeshInstance3D).set_surface_override_material(1, canvas)
	var sail_motion := ClothMotion.new()
	sail_motion.configure_canvas(sail, 1)
	sail.add_child(sail_motion)
	player_pennant = ShipPennant.new()
	boat_visual.add_child(player_pennant)
	# Seat the flag at the actual imported mast tip, then retain boat-local scale.
	var tip := Vector3.ZERO
	for vertex: Vector3 in (sail as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var local_tip := boat_visual.to_local(sail.to_global(vertex))
		if local_tip.y > tip.y:
			tip = local_tip
	player_pennant.position = tip + Vector3.UP * 0.1
	player_pennant.configure(Color("d9ac58"), Vector2(1.05, 0.48))
	player_pennant.visible = sail.visible
	if sailing_camera_rig == SailingCameraRig.DECK:
		_build_deck_floor()
	boat_damage.configure(boat_visual, ship)
	for wood: StandardMaterial3D in boat_damage.wood:
		wood.metallic = 0.0
		wood.roughness = 0.9
	var dark := _material(Color("211e1d"))
	_box(boat_visual, Vector3(0.07, 0.48, 0.07), Vector3(-1.05, 0.96, -2.9), dark)
	var brass := _material(Color("d9ac58"), 1.0)
	_box(boat_visual, Vector3(0.22, 0.32, 0.22), Vector3(-1.05, 1.3, -2.9), brass)
	_box(boat_visual, Vector3(0.34, 0.08, 0.34), Vector3(-1.05, 1.51, -2.9), dark)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.0, 1.6, -2.8)
	lamp.light_color = lantern_color
	lamp.light_energy = lantern_energy
	lamp.light_specular = 0.15
	lamp.omni_range = 7.0
	boat_visual.add_child(lamp)
	for x in [-0.095,0.095]:
		for z in [-0.095,0.095]:
			_box(boat_visual,Vector3(0.025,0.34,0.025),Vector3(-1.05+x,1.3,-2.9+z),dark)


func _build_deck_floor() -> void:
	var outline := PackedVector2Array([Vector2(-0.98,0.5),Vector2(0.98,0.5),
		Vector2(1.0,-2.5),Vector2(0.72,-3.8),Vector2(0,-4.75),Vector2(-0.72,-3.8),Vector2(-1.0,-2.5)])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		var p := outline[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2((p.x+1.0)/2.0,(p.y+4.75)/5.25))
		surface.add_vertex(Vector3(p.x,0.65,p.y))
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/ocean/deck_wood.gdshader")
	var floor_mesh := _mesh(boat_visual,surface.commit(),Vector3.ZERO,material)
	floor_mesh.name = "PlankedDeck"


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
	storm_lightning.update(self, delta)
	if not weather_enabled:
		if arena_mode: sky_material.set_shader_parameter("lightning", 0.0)
		return
	var strength: float = [0.0, 0.25, 0.45, 0.15][phase]
	if arena_mode:
		var boundary := smoothstep(arena_radius - 8.0, arena_radius + 24.0, storm_distance()) if state == State.SAILING else 0.0
		strength = lerpf(arena_storm_strength, 1.0, boundary)
	storm_blend = lerpf(storm_blend, strength, 1.0 - exp(-0.6 * delta))
	# Storm presentation never changes wave forces or player controls.
	sky_material.set_shader_parameter("storm", storm_blend)
	if arena_mode:
		sky_material.set_shader_parameter("lightning", storm_lightning.strength)
		return
	var flash: float = maxf(0.0, 1.0 - fmod(elapsed, 9.0) / 0.16) if phase == 2 else 0.0
	sky_material.set_shader_parameter("lightning", flash * 0.3)
	var thunder: int = int(elapsed / 9.0)
	if flash > 0.0 and thunder != _last_thunder:
		_last_thunder = thunder
		cue_sound("thunder")


func _apply_night_illumination() -> void:
	# The same continuous weather blend serves startup, retry and every camera.
	var environment := world_environment.environment
	environment.ambient_light_color = night_ambient_color
	environment.ambient_light_energy = lerpf(calm_ambient_energy, storm_ambient_energy, storm_blend)
	environment.ambient_light_energy += storm_lightning.strength * 0.25
	environment.fog_light_color = night_fog_color
	environment.fog_density = lerpf(0.0035, 0.0048, storm_blend)
	moon.light_color = moonlight_color
	moon.light_energy = lerpf(calm_moon_energy, storm_moon_energy, storm_blend)
	moon.light_energy += storm_lightning.strength * 1.8
	water_material.set_shader_parameter("storm_shading", storm_blend)


func cue_sound(kind: String) -> void:
	if not effects_enabled():
		return
	if kind == "wave" and is_instance_valid(_wave_audio):
		_wave_audio.play()
	elif kind == "victory" and is_instance_valid(_victory_audio):
		_victory_audio.play()
	elif kind in ["enemy_shot", "damage", "thunder"] and is_instance_valid(_danger_audio):
		_danger_audio.pitch_scale = 0.7 if kind == "thunder" else 1.0
		_danger_audio.play()
	elif is_instance_valid(_warning_audio):
		_warning_audio.pitch_scale = 0.6 if kind == "gust" else 1.0
		_warning_audio.play()


func cannonball_whiz(from: Vector3, to: Vector3, shot: Dictionary) -> void:
	if shot.get("whiz_played", false) or not effects_enabled() or _whiz_players.is_empty() or not is_instance_valid(boat):
		return
	var segment := to - from
	var along := clampf((boat.global_position - from).dot(segment) / maxf(0.0001, segment.length_squared()), 0.0, 1.0)
	var closest := from + segment * along
	var offset := closest - boat.global_position
	var distance := offset.length()
	if distance > 12.0 or absf(offset.y) > 9.0:
		return
	shot["whiz_played"] = true
	var player := _whiz_players[_whiz_player_cursor]
	_whiz_player_cursor = (_whiz_player_cursor + 1) % _whiz_players.size()
	player.global_position = closest
	player.volume_db = lerpf(-7.0, -15.0, distance / 12.0)
	player.play()


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
		ocean.register_float_visual(visual, 0.35 if kind in ["debris", "barrels"] else 0.0)


func _build_destination() -> void:
	beacon = Node3D.new()
	beacon.name = "LateVisibleLighthouse"
	beacon.position = archipelago.get_node("Landmarks/Lighthouse").position
	beacon.visible = false
	add_child(beacon)
	beacon_lamp = archipelago.story_landmarks.build_lighthouse_effects(beacon)


func _build_audio() -> void:
	# One continuous loop across menus, retries and endings; tree pause suspends it.
	_music = AudioStreamPlayer.new()
	_music.name = "BackgroundMusic"
	var music_stream := preload("res://assets/music/esa.ogg").duplicate() as AudioStreamOggVorbis
	music_stream.loop = true
	_music.stream = music_stream
	_music.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	# Keep long samples attached while the browser AudioContext is suspended.
	# This backend resumes a paused sample with a seek offset that it then reuses
	# on every loop, truncating the track after an ordinary game pause.
	if OS.has_feature("web"): _music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.volume_db = -18.0
	add_child(_music)
	_music.play()
	# The continuous ocean is a seamless sample; no per-frame sample generation.
	_sound = AudioStreamPlayer.new()
	_sound.name = "OceanAmbience"
	_sound.stream = _ocean_loop()
	_sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	if OS.has_feature("web"): _sound.process_mode = Node.PROCESS_MODE_ALWAYS
	_sound.volume_db = -26.0
	add_child(_sound)
	_sound.play()
	# Positional cannon whizzes.
	if DisplayServer.get_name() == "headless":
		return
	var whistle := AudioStreamWAV.new()
	whistle.mix_rate = 22050
	whistle.format = AudioStreamWAV.FORMAT_16_BITS
	whistle.stereo = false
	var sample_count := 5292 # 0.24 seconds at 22.05 kHz.
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase := 0.0
	for i in sample_count:
		var progress := float(i) / float(sample_count - 1)
		var frequency := lerpf(1480.0, 560.0, progress)
		phase += TAU * frequency / float(whistle.mix_rate)
		var envelope := pow(maxf(0.0, sin(PI * progress)), 1.25)
		var sample := sin(phase) * envelope * 0.62
		pcm.encode_s16(i * 2, int(sample * 32767.0))
	whistle.data = pcm
	for i in 4:
		var player := AudioStreamPlayer3D.new()
		player.name = "CannonWhiz%d" % i
		player.stream = whistle
		player.volume_db = -7.0
		player.unit_size = 8.0
		player.max_distance = 30.0
		add_child(player)
		_whiz_players.append(player)


func note_event(kind: String, data: Dictionary = {}) -> void:
	if is_instance_valid(diagnostics): diagnostics.note(kind, data)


func effects_enabled() -> bool:
	return _sound_enabled and diagnostic_audio_mode in [0, 3]


func _sync_audio_volumes(delta: float) -> void:
	var music_paused := (paused and not OS.has_feature("web")) or diagnostic_audio_mode == 2
	_set_continuous_audio_paused(_music, music_paused)
	var music_db := -18.0 if _sound_enabled and diagnostic_audio_mode != 2 else -80.0
	if _music.volume_db != music_db: _music.volume_db = music_db
	var gain := 1.0 + (clampf(actual_speed / sailing_speed - 1.0, 0.0, 1.0) * 0.28 if state == State.SAILING else 0.0)
	gain *= 1.0 + storm_blend * 0.75
	var target_db := -26.0 + linear_to_db(gain) if _sound_enabled and diagnostic_audio_mode != 1 else -80.0
	if is_instance_valid(_sound):
		var ocean_paused := (paused and not OS.has_feature("web")) or diagnostic_audio_mode == 1
		_set_continuous_audio_paused(_sound, ocean_paused)
		# Generator already applies the weather/speed gain to its samples.
		if diagnostic_generator and target_db > -80.0: target_db = -26.0
		var next_db := lerpf(_sound.volume_db, target_db, 1.0 - exp(-3.0 * delta)) if target_db > -80.0 and delta < 1.0 else target_db
		if not is_equal_approx(_sound.volume_db, next_db): _sound.volume_db = next_db
	var whiz_db := -7.0 if effects_enabled() else -80.0
	for player in _whiz_players:
		if player.volume_db != whiz_db: player.volume_db = whiz_db


func _set_continuous_audio_paused(player: AudioStreamPlayer, value: bool) -> void:
	if player.stream_paused == value: return
	player.stream_paused = value
	# Leaving a solo comparison starts a full sample, never a repeating tail.
	if not value and OS.has_feature("web") and player.playback_type == AudioServer.PLAYBACK_TYPE_SAMPLE:
		player.stop()
		player.play()


func set_diagnostic_audio(mode: int) -> void:
	diagnostic_audio_mode = mode
	if not effects_enabled():
		for player in find_children("*", "AudioStreamPlayer", true, false) + find_children("*", "AudioStreamPlayer3D", true, false):
			if player != _music and player != _sound: player.stop()
	_sync_audio_volumes(1.0)
	note_event("audio_mode", {"mode": mode})


func set_music_playback(sample: bool) -> void:
	_music.stop()
	_music.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if sample and OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	# The Web sample backend reuses its initial offset on every loop. Start at zero
	# for mode comparisons so it cannot repeat only the tail of the supplied OGG.
	_music.play()
	note_event("music_mode", {"playback_type": _music.playback_type, "restarted_from_zero": true})


func set_ocean_generator(value: bool) -> void:
	if is_instance_valid(_audio_playback):
		var skips := _audio_playback.get_skips()
		_generator_skips_total += skips
		note_event("generator_stopped", {"skips": skips})
	_sound.stop()
	_audio_playback = null
	diagnostic_generator = value
	_last_generator_skips = 0
	if value:
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = 22050.0
		stream.buffer_length = 0.15
		_sound.stream = stream
		_sound.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	else:
		_sound.stream = _ocean_loop()
		_sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	_sound.play()
	if value:
		_audio_playback = _sound.get_stream_playback()
		_audio_rng.seed = 60
		_audio_phase = 0.0
		_audio_noise = 0.0
		_fill_audio()
	_sync_audio_volumes(1.0)
	note_event("ocean_mode", {"generator": value, "total_skips": _generator_skips_total})


func _ocean_loop() -> AudioStreamWAV:
	var stream := preload("res://assets/sounds/ocean_loop.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 22050 * 32
	return stream


func audio_diagnostic_state() -> Dictionary:
	var raw_position := _music.get_playback_position()
	var ocean_position := _sound.get_playback_position() if is_instance_valid(_sound) and not diagnostic_generator else -1.0
	return {"enabled": _sound_enabled, "mode": diagnostic_audio_mode, "music_playing": _music.playing,
		"music_paused": _music.stream_paused, "music_playback_type": _music.playback_type,
		"music_position_s": fposmod(raw_position, _music.stream.get_length()), "music_raw_position_s": raw_position,
		"music_volume_db": _music.volume_db,
		"ocean_generator": diagnostic_generator, "ocean_playing": is_instance_valid(_sound) and _sound.playing,
		"ocean_paused": _sound.stream_paused if is_instance_valid(_sound) else null,
		"ocean_position_s": fposmod(ocean_position, 32.0) if ocean_position >= 0.0 else null,
		"effects_enabled": effects_enabled(),
		"ocean_volume_db": _sound.volume_db if is_instance_valid(_sound) else null,
		"generator_skips": _audio_playback.get_skips() if is_instance_valid(_audio_playback) else null,
		"generator_past_skips": _generator_skips_total}


func _fill_audio() -> void:
	if not is_instance_valid(_audio_playback) or diagnostic_audio_mode == 1:
		return
	var skips := _audio_playback.get_skips()
	if skips != _last_generator_skips:
		note_event("generator_skips", {"skips": skips, "increase": skips - _last_generator_skips})
		_last_generator_skips = skips
	var frames := _audio_playback.get_frames_available()
	var speed_gain := 1.0
	if state == State.SAILING:
		speed_gain += clampf(actual_speed / sailing_speed - 1.0, 0.0, 1.0) * 0.28
	for i in range(frames):
		_audio_phase += 1.0 / 22050.0
		_audio_noise = lerpf(_audio_noise, _audio_rng.randf_range(-1.0, 1.0), 0.07)
		var swell := (0.45 + 0.2 * sin(_audio_phase * 0.75)) * (1.0 + storm_blend * 0.75)
		swell *= speed_gain
		var sample := _audio_noise * swell + sin(_audio_phase * TAU * 57.0) * 0.015
		_audio_playback.push_frame(Vector2(sample, sample))

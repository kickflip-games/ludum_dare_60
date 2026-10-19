extends Node
## Isolated real-world fixtures. No studio code is loaded by crossing.tscn.
enum Shot { COVER, HERO, COMBAT, FLAGSHIP }
const WORLD = preload("res://game/crossing.tscn")
const NAUTICAL = preload("res://game/nautical_theme.gd")
const CLOTH = preload("res://game/ship_cloth_motion.gd")
const LANDMARK = preload("res://game/world/landmark_dressing.gd")
const NAMES := ["blackwater-cover-still", "blackwater-hero", "blackwater-combat", "blackwater-flagship"]
const STEP := 1.0 / 60.0
const FIRE_TICK := 132 # 2.2 seconds, after an uninterrupted sailing opening.

@export_enum("A · Animated cover", "B · Atmospheric hero", "C · Broadside combat", "D · Flagship") var preset: int = Shot.COVER
@export_group("Presentation")
@export var autoplay := true
@export_enum("Preset default", "Visible", "Hidden") var title_visibility := 0
## Cinematic presets only: small, explicit local ambient lift. Zero uses production lighting.
@export_range(0.0, 0.2, 0.01) var cinematic_ambient_lift := 0.06
@export var camera_position_adjustment := Vector3.ZERO
@export var camera_rotation_adjustment := Vector3.ZERO
## Zero retains the preset / production FOV.
@export_range(0.0, 100.0, 0.5) var fov_override := 0.0
## Use View/Camera's saved transform as a player-relative pose; edit it with normal editor gizmos.
@export var use_editor_camera := false
@export_group("Export")
@export_dir var output_directory := "res://../build/marketing_studio"
@export_range(1, 2, 1) var cover_render_scale := 2
@export_range(1.0, 10.0, 0.5) var duration_seconds := 5.0
@export_range(15, 30, 15) var recording_fps := 30

@onready var view: SubViewport = $View
@onready var studio_camera: Camera3D = $View/Camera
var game
var subject
var title: Label
var tick := 0
var events: Array[Dictionary] = []
var busy := false
var ready_for_preview := false
var _active_preset := -1
var _editor_pose: Transform3D
var _editor_fov: float
var _cli := ""
var _previous_max_fps: int
var _cloth: Array[Node] = []
var _scenery: Array[Node] = []

func _ready() -> void:
	_previous_max_fps = Engine.max_fps
	_editor_pose = studio_camera.transform
	_editor_fov = studio_camera.fov
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_directory = arg.trim_prefix("--output=")
		if arg.begins_with("--preset="): preset = clampi(int(arg.trim_prefix("--preset=")), 0, 3)
		if arg == "--studio-stills": _cli = "stills"
		if arg == "--studio-record": _cli = "record"
	Engine.max_fps = recording_fps
	$Preview.texture = view.get_texture()
	reset_shot()
	_boot.call_deferred()

func _boot() -> void:
	# Draw real sails/water, then muzzle + splash materials before any saved frame.
	if DisplayServer.get_name() != "headless":
		game.cannon.fire()
		game.cannon.water_splash(game.boat.position + Vector3(16, 0, -5), false)
		for i in 8: await _draw_frame()
	reset_shot()
	ready_for_preview = true
	if _cli == "stills":
		get_tree().quit(0 if await capture_all() else 1)
	elif _cli == "record":
		get_tree().quit(0 if await record_cover() else 1)
	print("STUDIO: 1–4 shots · R replay · P pause · S still · V cover sequence · A all stills · T title")

func _exit_tree() -> void:
	Engine.max_fps = _previous_max_fps

func target_size() -> Vector2i:
	return Vector2i(630, 500) if preset == Shot.COVER else Vector2i(1920, 1080)

func _shown(setting: int, default_value: bool) -> bool:
	return default_value if setting == 0 else setting == 1

func reset_shot() -> void:
	# Fresh instances reset cloth phases, RNGs, mines, pooled effects and HUD together.
	if is_instance_valid(game): game.free()
	if is_instance_valid(title): title.get_parent().free()
	seed(60)
	preset = clampi(preset, 0, 3)
	_active_preset = preset
	view.size = target_size() * (cover_render_scale if preset == Shot.COVER else 1)
	game = WORLD.instantiate()
	game.encounter_seed = 60
	view.add_child(game)
	_cloth.clear()
	_scenery.clear()
	_freeze(game)
	game._sound_enabled = false
	game._music.stop()
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.storm_lightning_enabled = false
	game.weather_enabled = preset >= Shot.COMBAT
	game.storm_blend = game.arena_storm_strength if game.weather_enabled else 0.0
	game.sky_material.set_shader_parameter("storm", game.storm_blend)
	game.heading = 0.0
	var start := Vector3(285, 0, 415) if preset < Shot.COMBAT else Vector3(175, 0, 382)
	game.boat.transform = Transform3D(Basis.IDENTITY, start)
	game.boat.velocity = Vector3(0, 0, -game.SPEED)
	game.actual_speed = game.SPEED
	game.sea_time = 12.0
	game.ocean.wave_time = 12.0
	game.ocean.reset_wake(0.0)
	var fleet = game.enemy_encounters
	subject = fleet.boss if preset == Shot.FLAGSHIP else fleet.ships[0]
	if preset != Shot.HERO:
		if preset == Shot.FLAGSHIP:
			# Production final-wave roster/HUD, with just the flagship in this composition.
			fleet.wave_number = 5
			fleet.phase = fleet.Phase.ACTIVE
			fleet.spawn_queue.clear()
		else:
			subject.configure_archetype(load("res://game/enemies/heavy.tres"))
			fleet.wave_number = 2
			fleet.phase = fleet.Phase.ACTIVE
			fleet.records.append({"wave": 2, "count": 1, "defeated": 0})
		subject.begin(game.boat.position + Vector3(27 if preset == Shot.FLAGSHIP else 19, 0, -12 if preset == Shot.FLAGSHIP else -3))
		# A legal, already-joined attack-run fixture; all subsequent navigation is real AI.
		subject.heading = 0.0
		subject.rotation.y = 0.0
		subject.run_heading = 0.0
		subject.run_speed = game.SPEED * 0.96
		subject._speed = subject.run_speed
		subject._change_navigation(subject.Navigation.ATTACK_RUN)
		subject.cooldown = 6.0
		subject.sea_effects.advance_arrival(1.0)
		subject.sea_effects.apply_arrival()
		if preset == Shot.FLAGSHIP:
			subject.pattern = subject.Pattern.ROLLING
			subject.cooldown = 0.0
			subject._prepare_volley(1.6)
			subject._update_mines(0.0)
	game.enemy_encounters.announcement_left = 0.0
	game.damage_immunity = 100.0
	game._sailing_camera_initialized = false
	tick = 0
	events.clear()
	var layer := CanvasLayer.new()
	view.add_child(layer)
	title = Label.new()
	layer.add_child(title)
	title.text = "BLACKWATER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", NAUTICAL.TITLE)
	title.add_theme_color_override("font_color", NAUTICAL.IVORY)
	title.add_theme_color_override("font_shadow_color", Color(0.015, 0.035, 0.07, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 3 * cover_render_scale)
	title.add_theme_constant_override("outline_size", 1 * cover_render_scale)
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.035, 0.07, 0.6))
	# Settle flotation, wakes and sail cloth before time zero, without story events.
	for i in 60: _step(false)
	tick = 0
	events.clear()
	_present(0.0)

func _freeze(node: Node) -> void:
	# Disabling process_mode removes CollisionObject3D bodies from the physics space.
	# Disable callbacks individually, keeping all real collision/raycast behaviour.
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node.get_script() == CLOTH:
		node._phase = float(_cloth.size()) * 1.73
		_cloth.append(node)
	if node.get_script() == LANDMARK: _scenery.append(node)
	for child in node.get_children(): _freeze(child)

func _step(story: bool = true) -> void:
	if story and tick == FIRE_TICK and preset in [Shot.COVER, Shot.COMBAT]:
		if game.cannon.fire(): events.append({"event": "fire", "time": tick * STEP})
	var old_hull: int = subject.hull
	game.advance_sailing(STEP, 0.0)
	if preset != Shot.HERO: subject.update_ship(STEP)
	game.cannon.advance(STEP)
	game.combat_particles.advance(STEP)
	game.combat_particles.set_process(false)
	for cloth in _cloth: cloth._process(STEP)
	for scenery in _scenery: scenery._process(STEP)
	if story and subject.hull < old_hull:
		events.append({"event": "impact", "time": tick * STEP, "hull": subject.hull})
	if story and game.cannon.feedback.begins_with("SPLASH") and (events.is_empty() or events[-1].event != "splash"):
		events.append({"event": "splash", "time": tick * STEP})
	_present(STEP)
	if story: tick += 1

func advance_frame() -> void:
	# 60 Hz mechanics at both supported output frame rates; wall clock never drives a recording.
	for i in int(60 / recording_fps): _step()

func _present(delta: float) -> void:
	game._update_view(delta)
	game.cannon.update_cone_feedback()
	game.hud._process(delta)
	_hide_gameplay_overlays()
	title.visible = _shown(title_visibility, preset == Shot.COVER)
	title.position = Vector2(view.size.x * 0.04, view.size.y * 0.065)
	title.size = Vector2(view.size.x * 0.92, view.size.y * 0.15)
	title.add_theme_font_size_override("font_size", roundi(view.size.x * 0.09))
	if preset < Shot.COMBAT or use_editor_camera:
		var pose := _editor_pose
		var lens := _editor_fov
		if not use_editor_camera:
			var at := Vector3(-9, 9, 20) if preset == Shot.COVER else Vector3(-11, 8, 21)
			var focus := Vector3(10, 7, -18) if preset == Shot.COVER else Vector3(-7, 8, -30)
			pose = Transform3D(Basis.looking_at(focus - at), at)
			lens = 56.0
		studio_camera.transform = Transform3D(pose.basis, pose.origin + game.boat.position)
		studio_camera.position += camera_position_adjustment
		studio_camera.rotation_degrees += camera_rotation_adjustment
		studio_camera.fov = fov_override if fov_override > 0 else lens
		studio_camera.make_current()
		game.world_environment.environment.ambient_light_energy += cinematic_ambient_lift
	else:
		game.camera.position += camera_position_adjustment
		game.camera.rotation_degrees += camera_rotation_adjustment
		if fov_override > 0: game.camera.fov = fov_override
		game.camera.make_current()

func _hide_gameplay_overlays() -> void:
	# Artwork keeps physical ships/effects, with only the optional title overlay.
	game.hud.hide()
	game.cannon.cone_visual.hide()
	game.water_material.set_shader_parameter("storm_boundary", Vector4.ZERO)
	game.water_material.set_shader_parameter("flow_count", 0)
	for area in game.enemy_encounters.boss.warnings: area.hide()
	for ship in game.enemy_encounters.combat_ships():
		ship.set_aim_highlight(false)
		if ship.weapon_state == ship.Weapon.TELEGRAPH:
			for mount in ship.gun_mounts: mount.flash.hide()
		var mines: Array = ship.mine_layer.pool if ship.mine_layer != null else ship.mine_pool
		for mine in mines: mine.ring.hide()

func _process(_delta: float) -> void:
	if not ready_for_preview or busy or not _cli.is_empty(): return
	if preset != _active_preset: reset_shot()
	if autoplay:
		if tick >= roundi(duration_seconds * 60): reset_shot()
		advance_frame()
	else: _present(0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or busy: return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			preset = event.keycode - KEY_1
			reset_shot()
		KEY_R: reset_shot()
		KEY_P: autoplay = not autoplay
		KEY_T: title_visibility = 2 if title.visible else 1
		KEY_S: capture_still()
		KEY_V: record_cover()
		KEY_A: capture_all()

func _draw_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _warm_shot() -> void:
	await get_tree().physics_frame
	while not game.cannon.combat_warmup.complete: await _draw_frame()
	await _draw_frame()

func _output() -> String:
	return ProjectSettings.globalize_path(output_directory)

func _save(path: String) -> bool:
	var picture := view.get_texture().get_image()
	var size := target_size()
	if picture.get_size() != size: picture.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var result := picture.save_png(path)
	if result != OK: push_error("Studio could not save %s (error %d)" % [path, result])
	return result == OK

func capture_still() -> void:
	if busy or not ready_for_preview: return
	busy = true
	DirAccess.make_dir_recursive_absolute(_output())
	_present(0.0)
	await _draw_frame()
	var path := _output().path_join(NAMES[preset] + ".png")
	if _save(path): print("STUDIO STILL ", path)
	busy = false

func capture_all() -> bool:
	if busy: return false
	if DisplayServer.get_name() == "headless":
		push_error("Studio exports require the native renderer.")
		return false
	busy = true
	DirAccess.make_dir_recursive_absolute(_output())
	var previous := preset
	for shot in 4:
		preset = shot
		reset_shot()
		# Sync collision transforms before the first real ballistic step.
		await _warm_shot()
		var moment := 134 if shot == Shot.COMBAT else (92 if shot == Shot.FLAGSHIP else 0)
		while tick < moment:
			advance_frame()
			await get_tree().physics_frame
		await _draw_frame()
		if not _save(_output().path_join(NAMES[shot] + ".png")):
			busy = false
			return false
		print("STUDIO STILL ", NAMES[shot])
		if shot == Shot.COMBAT:
			# Optional resolved-shot frame beside the muzzle-flash selection.
			while tick < 150:
				advance_frame()
				await get_tree().physics_frame
			await _draw_frame()
			if not _save(_output().path_join("blackwater-combat-impact.png")):
				busy = false
				return false
	preset = previous
	if _cli.is_empty(): reset_shot()
	busy = false
	return true

func record_cover() -> bool:
	if busy: return false
	if DisplayServer.get_name() == "headless":
		push_error("Studio exports require the native renderer.")
		return false
	busy = true
	var previous := preset
	preset = Shot.COVER
	reset_shot()
	# Unique takes prevent stale frames after changing duration or FPS.
	var take := _output().path_join("cover-" + str(Time.get_unix_time_from_system()).replace(".", "-"))
	DirAccess.make_dir_recursive_absolute(take)
	await _warm_shot()
	var count := roundi(duration_seconds * recording_fps)
	var saved := 0
	for frame in count:
		if frame > 0: advance_frame()
		await _draw_frame()
		if not _save(take.path_join("frame-%04d.png" % frame)): break
		saved += 1
		if frame == 0: _save(_output().path_join(NAMES[Shot.COVER] + ".png"))
	var manifest := {"fps": recording_fps, "duration_seconds": duration_seconds,
		"frames": saved, "expected_frames": count, "size": [630, 500], "seed": 60,
		"first_frame_time": 0, "last_frame_time": float(saved - 1) / recording_fps,
		"events": events.duplicate(true), "renderer": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info().string, "cinematic_ambient_lift": cinematic_ambient_lift,
		"complete": saved == count}
	var file := FileAccess.open(take.path_join("capture.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(manifest, "\t"))
	if saved == count:
		var latest := FileAccess.open(_output().path_join("latest-cover.txt"), FileAccess.WRITE)
		if latest: latest.store_line(take)
	print("STUDIO SEQUENCE ", take, " ", JSON.stringify(manifest))
	preset = previous
	if _cli.is_empty(): reset_shot()
	busy = false
	return saved == count and file != null

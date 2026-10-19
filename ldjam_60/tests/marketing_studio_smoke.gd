extends SceneTree
## Same fixtures and fixed-step path as F6; native export is validated separately.
var studio
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func snapshot() -> Dictionary:
	return {"player": studio.game.boat.position, "enemy": studio.subject.position,
		"hull": studio.subject.hull, "sea": studio.game.sea_time,
		"cloth": studio._cloth[0]._time, "phase": studio._cloth[0]._phase,
		"events": studio.events.duplicate(true), "emitted": studio.game.combat_particles.emitted}

func play() -> Dictionary:
	studio.reset_shot()
	await physics_frame
	var start: Vector3 = studio.game.boat.position
	var cloth_time: float = studio._cloth[0]._time
	var subjects_framed := true
	for frame in roundi(5.0 * studio.recording_fps):
		studio.advance_frame()
		await physics_frame
		for point in [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 10, 0)]:
			var screen: Vector2 = studio.studio_camera.unproject_position(studio.subject.position + point)
			subjects_framed = subjects_framed and Rect2(Vector2.ZERO, Vector2(studio.view.size)).has_point(screen)
	check(subjects_framed, "enemy hull and sail remain inside every cover frame")
	check(studio.game.boat.position.distance_to(start) > 30.0, "real sailing advances")
	check(studio._cloth[0]._time > cloth_time + 4.9, "real cloth advances with capture clock")
	check(studio.game.cannon.shots_fired == 1, "one real player cannon shot")
	check(studio.events.any(func(e): return e.event == "fire"), "fire beat occurs")
	check(studio.events.any(func(e): return e.event in ["impact", "splash"]), "ballistic impact or splash occurs")
	check(studio.game.cannon.projectiles.is_empty(), "shot resolves before loop boundary")
	check(not studio.game.cannon.flash.visible, "no flash at loop boundary")
	check(studio.game.state == studio.game.State.SAILING, "sailing survives sequence")
	return snapshot()

func _run() -> void:
	studio = load("res://tools/marketing_studio.tscn").instantiate()
	studio.autoplay = false
	root.add_child(studio)
	while not studio.ready_for_preview: await process_frame
	check(studio.target_size() == Vector2i(630, 500), "cover aspect ratio")
	check(studio.title.visible and not studio.game.hud.visible, "cover title with no HUD")
	check(not studio.game.cannon.cone_visual.visible, "cinematic firing guide hidden")
	check(studio.game.water_material.get_shader_parameter("storm_boundary") == Vector4.ZERO, "cinematic boundary guide hidden")
	check(studio.title.position.x >= 0 and studio.title.get_rect().end.x <= studio.view.size.x, "title inside capture")
	check(studio.game.boat.is_inside_tree() and studio.game.boat.can_process(), "live physics bodies retained")
	var first: Dictionary = await play()
	var second: Dictionary = await play()
	check(first == second, "reset repeats positions, cloth, particles and story events exactly")
	studio.recording_fps = 15
	var slower: Dictionary = await play()
	check(first == slower, "15/30 FPS exports share 60 Hz mechanics and duration")
	studio.recording_fps = 30
	for shot in [3, 1, 2, 0, 3, 0]:
		studio.preset = shot
		studio.reset_shot()
		await physics_frame
		check(studio.game.cannon.shots_fired == 0 and studio.game.cannon.projectiles.is_empty(), "switch clears player shots")
		check(studio.events.is_empty() and studio.tick == 0, "switch resets story")
		check(studio.title.visible == (shot == 0), "switch applies title")
		check(not studio.game.hud.visible, "all artwork presets hide HUD")
		check(not studio.game.cannon.cone_visual.visible, "all artwork presets hide player firing guide")
		check(studio.game.water_material.get_shader_parameter("flow_count") == 0, "all artwork presets hide speed ribbons")
		check(studio.game.water_material.get_shader_parameter("storm_boundary") == Vector4.ZERO, "all artwork presets hide boundary guide")
		check(studio.game.enemy_encounters.ships.filter(func(s): return s.visible).size() == (1 if shot in [0, 2] else 0), "no stale ordinary ships")
		check(studio.game.enemy_encounters.boss.visible == (shot == 3), "no stale boss")
		if shot == 3:
			check(studio.game.enemy_encounters.boss_active(), "real final-wave state")
			check(not studio.subject.mines.is_empty() and not studio.subject.volley.is_empty(), "real mine and volley fixture")
			check(studio.subject.warnings.all(func(w): return not w.visible), "active flagship attack cones hidden")
			check(studio.subject.mines.all(func(m): return not m.ring.visible and m.visible), "mine warning rings hidden, physical mines retained")
		if shot >= 2:
			check(studio.view.get_camera_3d() == studio.game.camera, "production camera for gameplay shots")
	studio.title_visibility = 2
	studio._present(0.0)
	check(not studio.title.visible and not studio.game.hud.visible, "title override keeps artwork HUD hidden")
	studio.use_editor_camera = true
	studio.camera_position_adjustment = Vector3(1, 2, 3)
	studio.fov_override = 71
	studio._present(0.0)
	check(studio.view.get_camera_3d() == studio.studio_camera and studio.studio_camera.fov == 71, "editable camera/FOV override")
	check(studio.studio_camera.position.is_equal_approx(studio.game.boat.position + studio._editor_pose.origin + Vector3(1, 2, 3)), "editor camera pose follows player-relative origin")
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = KEY_P
	studio._unhandled_key_input(press)
	check(studio.autoplay, "preview pause shortcut")
	press.echo = true
	studio._unhandled_key_input(press)
	check(studio.autoplay, "held shortcut does not repeat")
	studio.autoplay = false
	press.echo = false
	press.keycode = KEY_R
	studio._unhandled_key_input(press)
	check(studio.tick == 0 and studio.game.cannon.projectiles.is_empty(), "replay shortcut resets event lifecycle")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/crossing.tscn", "normal main scene preserved")
	print("STUDIO REPLAY ", first)
	studio.queue_free()
	await process_frame
	print("MARKETING STUDIO: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

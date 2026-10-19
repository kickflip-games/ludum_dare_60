extends "res://tests/arcade_controls_smoke.gd"
## Persistent guide geometry, shared waves, exact cone placement and reset paths.
const Metrics = preload("res://game/active_frame_metrics.gd")

func _run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	fresh()
	var guide = game.cannon.cone_visual
	check(guide.material in game.ocean.surface_materials, "guide registers once with the authoritative surface upload")
	var geometry = guide.mesh
	var builds: int = guide.geometry_builds
	Metrics.take()
	Metrics.enabled = true
	for i in 180:
		game.heading = i * 0.02
		game.boat.rotation.y = -game.heading
		game.boat.position.x += 0.03
		guide.update_surface()
	var counts := Metrics.take()
	Metrics.enabled = false
	check(counts.calls.get("wave_queries", 0) == 0, "180 moving guide updates make zero CPU ocean queries")
	check(guide.mesh == geometry and guide.geometry_builds == builds, "moving and turning never rebuild or replace guide geometry")
	for heading in [-PI, -1.2, 0.0, 0.9, PI]:
		game.heading = heading
		game.boat.rotation.y = -heading
		guide.update_surface()
		for angle in [-10.0, 0.0, 10.0]:
			var local: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(angle)) * game.cannon.cone_range
			var actual: Vector3 = guide.to_global(local)
			var expected: Vector3 = game.cannon.cone_point(angle, game.cannon.cone_range)
			check(Vector2(actual.x, actual.z).distance_to(Vector2(expected.x, expected.z)) < 0.001, "guide XZ matches target cone at heading %.2f angle %.0f" % [heading, angle])
	game.ocean.register_surface_material(guide.material)
	check(game.ocean.surface_materials.size() == 1, "registration is idempotent")
	game.ocean.wave_field.add_wave(Vector2(game.boat.position.x, game.boat.position.z), Vector2.RIGHT, 1.2, 5.0, 30.0, 4.0, 0.0, 12.0)
	game.sea_time = 2.5
	game._update_view(1.0 / 60)
	check(guide.material.get_shader_parameter("event_count") == game.water_material.get_shader_parameter("event_count"), "guide receives the same finite wave count as water")
	check(guide.material.get_shader_parameter("event_origins") == game.water_material.get_shader_parameter("event_origins"), "guide receives the same finite wave trajectories")
	check(guide.material.get_shader_parameter("wave_time") == game.water_material.get_shader_parameter("wave_time"), "guide and sea use identical time")
	check(guide.material.get_shader_parameter("focus_xz") == game.ocean.focus_xz, "guide uses the water's ambient fade origin")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await comparison(guide, "rolling-sea")
	game.set_paused(true)
	var time: float = guide.material.get_shader_parameter("wave_time")
	for i in 4: await process_frame
	check(guide.material.get_shader_parameter("wave_time") == time, "pause freezes the shared guide clock")
	game.set_paused(false)
	game.begin_result(false)
	game.cannon.update_cone_feedback()
	check(not guide.visible, "loss hides the guide while preserving the sinking sequence")
	game.restart()
	check(game.cannon.cone_visual == guide and guide.mesh == geometry and not guide.visible, "retry retains geometry and clears visibility")
	check(game.ocean.surface_materials.size() == 1, "retry never accumulates surface registrations")
	game.state = game.State.SAILING
	game._update_view(0.0)
	game.cannon.update_cone_feedback()
	check(guide.material.get_shader_parameter("event_count") == 0 and guide.visible, "retry clears finite waves and restores the guide")
	await investigation_lifecycle()
	print("FIRING GUIDE: %d checks, %d failures" % [checks, failures])
	game.diagnostics.set_enabled(false)
	var clean := await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	quit(1 if failures or not clean else 0)

func comparison(guide, name: String) -> void:
	var old = load("res://game/diagnostic_firing_cone.gd").new()
	old.cannon = game.cannon
	game.add_child(old)
	old.update_surface()
	old.visible = true
	guide.visible = false
	await capture(name + "-before")
	old.visible = false
	guide.visible = true
	await capture(name + "-after")
	old.queue_free()

func investigation_lifecycle() -> void:
	var a = game.active_fps
	game.enemy_encounters.enabled = true
	game.wave_encounters.enabled = true
	game.application_focus_changed(true, "test")
	a.start()
	check(a.running and game.enemy_encounters.enabled and game.state == game.State.SAILING, "A/B runs real active enemies in the production scene")
	a.after_view()
	var pose: Transform3D = game.camera.transform
	var boat_at: Vector3 = game.boat.position
	var elapsed: float = game.elapsed
	a.case_name = "downward_camera"
	a.after_view()
	check(game.camera.transform != pose and game.boat.position == boat_at and game.elapsed == elapsed, "downward comparison changes only the camera pose")
	game._physics_process(1.0 / 60)
	check(game.elapsed > elapsed and game.enemy_encounters.enabled, "downward comparison keeps physics and AI running (paused %s focused %s state %s)" % [game.paused, game._window_focused, game.state])
	a.case_name = "frozen_simulation"
	a.started = Time.get_ticks_usec() - 4000000
	a.measured = 0
	a._process(0.0)
	check(game.process_mode == Node.PROCESS_MODE_DISABLED and not game.paused, "simulation freeze retains the current view without a pause overlay")
	a.cancel("test cleanup")
	check(not a.running and game.process_mode == Node.PROCESS_MODE_INHERIT and game.paused, "cancel restores processing and leaves explicit Resume required")
	check(game.cannon.cone_visual == a._guide and not is_instance_valid(a._legacy), "cancel restores the production guide")
	game.restart(true)

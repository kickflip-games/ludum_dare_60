extends "res://tests/night_cloud_previews.gd"
## Matched real-renderer poses and uncapped frame timing, without readback in timing samples.
var performance_only := false


func _run() -> void:
	performance_only = "--performance-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless":
		push_error("Cloud previews need a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if "--legacy" in OS.get_cmdline_user_args():
		game.procedural_clouds = false
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.phase_banner_left = 0.0
	game.elapsed = 10.0
	game.sea_time = 60.0
	game.heading = game.START_HEADING
	game._update_view(2.0)
	game.hud._process(0.0)
	for scenario in ["sailing", "stargazing", "storm"]:
		game.reading = scenario != "sailing"
		game._update_view(2.0)
		game.storm_blend = 1.0 if scenario == "storm" else 0.0
		game.sky_material.set_shader_parameter("storm", game.storm_blend)
		game.sky_material.set_shader_parameter("lightning", 0.0)
		game.hud._process(0.0)
		if not performance_only:
			await capture(scenario)
		await benchmark(scenario)
	if not performance_only:
		game.hud.hide()
		game.sky_material.set_shader_parameter("storm", 0.0)
		for pitch in [0, 30, 60, 90]:
			for yaw in [0, 90, 180, 270]:
				game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(-yaw), 0))
				await capture("pitch-%02d-yaw-%03d" % [pitch, yaw])
		game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(78), -game.START_HEADING, 0))
		for density in [0.0, 0.62, 1.0]:
			game.sky_material.set_shader_parameter("cloud_density", density)
			await capture("coverage-%03d" % roundi(density * 100))
		game.sky_material.set_shader_parameter("cloud_density", game.cloud_density)
		game.sky_material.set_shader_parameter("storm", 1.0)
		game.sky_material.set_shader_parameter("lightning", 0.3)
		await capture("lightning")
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["viewport"] = [root.size.x, root.size.y]
	var file := FileAccess.open(output.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CLOUD BENCHMARK ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit()


func benchmark(label: String) -> void:
	# Keep clock, viewport, ship and weather fixed for an identical scene each run.
	for frame in range(90):
		await process_frame
	var intervals: Array[float] = []
	var then := Time.get_ticks_usec()
	for frame in range(360):
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - then) / 1000.0)
		then = now
	intervals.sort()
	report[label] = {"median_ms": intervals[180], "p95_ms": intervals[342], "samples": intervals.size()}

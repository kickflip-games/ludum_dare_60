extends "res://tests/arcade_controls_smoke.gd"
## Matched gameplay frames and optional uncapped same-scene native timings.

func weather(storm: bool, post: bool) -> void:
	game.weather_enabled = true
	game.storm_post_enabled = post
	game.arena_storm_strength = 0.65 if storm else 0.0
	game.storm_blend = game.arena_storm_strength
	game._update_view(0)
	game.hud._process(0)

func benchmark(label: String) -> void:
	for i in 20: await process_frame
	var samples: Array[float] = []
	for i in 120:
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	print("STORM TIMING %s: median %.2f ms, p95 %.2f ms" % [label, samples[60], samples[114]])

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	if output.is_empty(): output = "/tmp/blackwater-storm"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart(true)
	game.storm_blend = 0.65
	game._update_view(0)
	game.hud._process(0)
	await capture("menu-storm")
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters._begin_wave()
	game.hud._process(3.2)
	game.sea_time = 28.0
	for i in 60: game._update_view(1.0 / 60)
	var ship = game.enemy_encounters.ships[0]
	ship.begin(game.boat.position + game.cannon.starboard_direction() * 34 + game.course_forward() * 18)
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	ship.sea_effects.advance_arrival(1)
	ship.sea_effects.apply_arrival()
	for view in ["chase", "cannon"]:
		game.arena_cannon_view = view == "cannon"
		for i in 60: game._update_view(1.0 / 60)
		weather(false, false)
		await capture(view + "-before")
		weather(true, false)
		await capture(view + "-weather-only")
		weather(true, true)
		await capture(view + "-storm")
	game.motion_setting = 1
	game._update_view(0)
	await capture("reduced-motion")
	game.motion_setting = 0
	game.arena_cannon_view = false
	for i in 60: game._update_view(1.0 / 60)
	root.size = Vector2i(900, 506)
	await capture("small-storm")
	root.size = Vector2i(1280, 720)
	weather(true, false)
	await benchmark("post-off")
	weather(true, true)
	await benchmark("post-on")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

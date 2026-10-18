extends SceneTree
## Bounded real-renderer sequence. Scripted input and staged weather/encounter.
var game
var output := "/tmp/stargazing-review"
var requested_size := Vector2i(1280, 720)
var frame_index := 0
var clip_index := 0
var capture_clip := true
var framing_review := false
var framing: Array[Dictionary] = []
var capture_failures := 0
var enemy_shots := 0
var cadence: Array[float] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--no-clip":
			capture_clip = false
		if arg == "--framing":
			framing_review = true
			capture_clip = false
		if arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run.call_deferred()


func capture(label: String) -> void:
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var pixels := root.get_texture().get_image()
	var result := pixels.save_png(output.path_join(label + ".png"))
	print("SIGHT CAPTURE %s: %d, hold=%.2f focus=%.2f" % [label, result, game.focus_elapsed, game.focus_strength])
	if result != OK:
		capture_failures += 1
		quit(1)
	if framing_review and pixels.get_size() != requested_size:
		push_error("Capture dimensions differ from requested size: " + label)
		capture_failures += 1


func advance(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		var before := Time.get_ticks_usec()
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		var held := Input.is_action_pressed("astrolabe")
		var focus_elapsed: float = game.focus_elapsed
		var focus_strength: float = game.focus_strength
		await process_frame
		if framing_review and held:
			# Ignore OS focus notifications in these staged comparison frames.
			# Production focus-loss behavior has its own input regression check.
			Input.action_press("astrolabe")
			game.reading = true
			game.focus_elapsed = focus_elapsed
			game.focus_strength = focus_strength
			game.update_guiding_star()
			game.hud._process(0.0)
		RenderingServer.force_draw(true, 1.0 / 60.0)
		cadence.append((Time.get_ticks_usec() - before) / 1000.0)
		if capture_clip and frame_index % 3 == 0:
			root.get_texture().get_image().save_png(output.path_join("clip/frame-%04d.png" % clip_index))
			clip_index += 1
		frame_index += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Stargazing previews require a real renderer.")
		quit(1)
		return
	if framing_review:
		await _run_framing()
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	root.size = requested_size
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	await advance(game.CAST_OFF_SECONDS)
	game.elapsed = 10
	game.phase_banner_left = 0
	await advance(0.5)
	Input.action_press("astrolabe")
	await advance(0.4)
	capture("01-initial-search")
	await advance(0.8)
	capture("02-mid-focus")
	await advance(0.6)
	capture("03-focused-star")
	await advance(1.0)
	Input.action_release("astrolabe")
	await advance(0.35)
	capture("04-return-sailing")
	for i in range(3):
		Input.action_press("astrolabe")
		await advance(0.3)
		Input.action_release("astrolabe")
		await advance(0.25)
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 40.0
	ship.heading = game.heading
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0
	ship.locked_point = game.boat.position
	Input.action_press("astrolabe")
	await advance(1.3)
	capture("05-combat-focus")
	await advance(0.7)
	Input.action_release("astrolabe")
	Input.action_press("watch_starboard")
	await advance(0.4)
	capture("06-return-combat")
	enemy_shots = ship.shots_fired
	Input.action_release("watch_starboard")
	ship.reset()
	# The supported storm palette, held at a fixed authored phase for comparison.
	game.weather_enabled = false
	game.storm_blend = 1.0
	game.sky_material.set_shader_parameter("storm", 1.0)
	game.sea_time = 72.0
	Input.action_press("astrolabe")
	await advance(2.0)
	capture("07-storm-focused")
	await advance(2.0)
	capture("08-drifting-clouds")
	Input.action_release("astrolabe")
	await advance(0.35)
	capture("09-storm-return")
	cadence.sort()
	print("SIGHT RENDER: %d frames, median=%.2fms p95=%.2fms (scripted draw/readback, not GPU-only); hull=%d enemy shots=%d" % [frame_index, cadence[cadence.size() / 2], cadence[int(cadence.size() * 0.95)], game.hull, enemy_shots])
	game.queue_free()
	await process_frame
	quit()


func record_framing(label: String) -> void:
	capture(label)
	var viewport: Vector2 = game.hud.size
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	var horizon: Vector2 = game.camera.unproject_position(game.camera.global_position + forward * 700.0)
	var star: Vector2 = game.hud._star_screen_position()
	if label in ["03-focused-star", "07-near-islands", "08-storm-focused"] and game.focus_strength != 1.0:
		push_error("Focused capture lost its scripted hold: " + label)
		capture_failures += 1
	framing.append({"image": label + ".png", "pixels": str(root.get_texture().get_image().get_size()),
		"boat": str(game.boat.position), "heading": game.heading, "sea_time": game.sea_time,
		"camera": str(game.camera.position), "pitch_degrees": rad_to_deg(game.camera.rotation.x),
		"fov": game.camera.fov, "storm": game.storm_blend, "focus": game.focus_strength,
		"star_fraction": [star.x / viewport.x, star.y / viewport.y],
		"horizon_fraction": horizon.y / viewport.y, "guidance": game.hud.star_guidance()})
	print("FRAMING %s: %s" % [label, JSON.stringify(framing.back())])


func _run_framing() -> void:
	# Identical scripted inputs, seed, clock, boat poses and weather before/after.
	# Heading changes here are comparison fixtures, never production star tracking.
	DirAccess.make_dir_recursive_absolute(output)
	root.size = requested_size
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.start_crossing()
	await advance(game.CAST_OFF_SECONDS)
	game.heading = game.destination_bearing()
	game.wave_sailing.reset()
	game.sea_time = 37.2
	game.phase_banner_left = 0.0
	await advance(0.6)
	record_framing("01-normal-sailing")
	Input.action_press("astrolabe")
	await advance(0.4)
	record_framing("02-searching")
	await advance(1.4)
	record_framing("03-focused-star")
	Input.action_release("astrolabe")
	await advance(1.0 / 60)
	record_framing("04-immediate-release")
	await advance(0.4)
	record_framing("05-return-sailing")
	game.heading = game.destination_bearing() + PI
	game.wave_sailing.reset()
	Input.action_press("astrolabe")
	await advance(1.8)
	record_framing("06-wrong-heading")
	Input.action_release("astrolabe")
	await advance(0.4)
	game.boat.position = Vector3(-175, 0, -40)
	game.heading = game.destination_bearing()
	game.wave_sailing.reset()
	Input.action_press("astrolabe")
	await advance(1.8)
	record_framing("07-near-islands")
	game.storm_blend = 1.0
	game.sky_material.set_shader_parameter("storm", 1.0)
	game.sea_time = 72.0
	await advance(0.2)
	record_framing("08-storm-focused")
	Input.action_release("astrolabe")
	await advance(0.4)
	record_framing("09-storm-return")
	var report := FileAccess.open(output.path_join("framing.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(framing, "\t"))
	report.close()
	game.queue_free()
	await process_frame
	quit(0 if capture_failures == 0 else 1)

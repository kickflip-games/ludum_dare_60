extends SceneTree
## Real-renderer review: genuine sweep phases, fire, steering and live moving duels.
const Pilot = preload("res://tests/cannon_sweep_pilot.gd")
var game
var output := "/tmp/cannon-sweep-review"
var dimensions := Vector2i(1280, 720)
var capture_clip := true
var views_only := false
var clip_index := 0
var frame_index := 0
var pilot := Pilot.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--views-only":
			views_only = true
		elif arg == "--no-clip":
			capture_clip = false
	_run.call_deferred()


func capture(label: String) -> void:
	RenderingServer.force_draw(true, 1.0 / 60)
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("SWEEP CAPTURE %s: %d cannon=%s yaw=%.1f mode=%d" % [label, result, game.cannon.aiming, game.cannon.aim_degrees, game.camera_mode])


func advance(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		game._physics_process(1.0 / 60)
		game.cannon.advance(1.0 / 60)
		game.hud._process(1.0 / 60)
		await process_frame
		if capture_clip and frame_index % 3 == 0:
			RenderingServer.force_draw(true, 1.0 / 60)
			root.get_texture().get_image().save_png(output.path_join("clip/frame-%04d.png" % clip_index))
			clip_index += 1
		frame_index += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the real renderer for gunner previews.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	if capture_clip:
		var directory := DirAccess.open(output.path_join("clip"))
		for filename in directory.get_files():
			if filename.begins_with("frame-") and filename.ends_with(".png"):
				directory.remove(filename)
	root.size = dimensions
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	await advance(1.3)
	game.boat.position = Vector3(400, 0, 360)
	game.elapsed = 10
	game.phase_banner_left = 0
	game.current_strength = 0
	game.gust_strength = 0
	game.enemy_encounters.enabled = false
	await advance(0.4)
	capture("01-sailing")
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 32
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	ship.velocity = Vector3.ZERO
	ship.mode = ship.Mode.POSITION
	pilot.tap()
	await advance(0.4)
	capture("02-elevated-gunner")
	await advance(0.35)
	capture("03-left-sweep-limit")
	await advance(1.5)
	capture("04-right-sweep-limit")
	await advance(0.75)
	pilot.tap()
	await advance(0.05)
	capture("05-firing")
	pilot.action("steer_port", true)
	await advance(0.12)
	capture("06-returning-to-steering")
	await advance(0.45)
	pilot.action("steer_port", false)
	capture("07-sailing-again")
	pilot.tap()
	await advance(0.45)
	pilot.action("astrolabe", true)
	await advance(0.4)
	capture("08-stargazing")
	pilot.action("astrolabe", false)
	await advance(0.6)
	# Three actual moving AI battles with the real renderer, waves and input path.
	for trial in range(0 if views_only else 3):
		game.cannon.reset()
		ship.reset()
		game.boat.position = Vector3(400, 0, 360)
		game.heading = game.START_HEADING
		game.boat.rotation.y = -game.heading
		game.elapsed = 0
		game.sea_time = trial * 5.0
		game.hull = game.hull_capacity
		game.damage_immunity = 0
		game.current_strength = trial * 0.35
		game.gust_strength = trial * 0.04
		game.enemy_encounters.enabled = true
		ship.begin()
		ship.position = game.boat.position + game.cannon.starboard_direction() * 34 + game.course_forward() * (trial - 1) * 8
		ship.territory = ship.position
		ship.heading = game.heading
		ship.rotation.y = -ship.heading
		pilot = Pilot.new()
		for frame in range(1500):
			if game.state != game.State.SAILING or ship.hull <= 0 or ship.mode == ship.Mode.ESCAPED:
				break
			pilot.update(game, 1.0 / 60)
			await advance(1.0 / 60)
			if frame == 90:
				capture("09-live-battle-%d" % (trial + 1))
		if ship.hull <= 0:
			await advance(0.6)
			capture("10-cutter-sinking-%d" % (trial + 1))
		print("RENDERED DUEL %d: shots=%d hits=%d hull=%d enemy_hull=%d entries=%d exits=%d" % [trial + 1, game.cannon.shots_fired, game.cannon.targets_hit, game.hull, ship.hull, pilot.entries, pilot.steering_exits])
		pilot.release()
	game.cannon.reset()
	game.enemy_encounters.stop()
	game.queue_free()
	await process_frame
	await process_frame
	quit()

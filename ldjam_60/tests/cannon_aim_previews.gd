extends SceneTree
## Scripted real-renderer review, staged broadside then a moving AI duel.
var game
var output := "/tmp/cannon-aim-review"
var dimensions := Vector2i(1280, 720)
var capture_clip := true
var clip_index := 0
var frame_index := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--no-clip":
			capture_clip = false
	_run.call_deferred()


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func capture(label: String) -> void:
	if label in ["02-aim-broadside", "03-front-limit", "04-rear-limit"] and not game.cannon.aiming:
		push_error("Aim cancelled before capture (another window may have taken focus). Retry this visual run.")
		quit(1)
		return
	RenderingServer.force_draw(true, 1.0 / 60)
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("AIM CAPTURE %s: %d aim=%s yaw=%.1f mode=%d" % [label, result, game.cannon.aiming, game.cannon.aim_degrees, game.camera_mode])


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
		push_error("Use the real renderer for aiming previews.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	if capture_clip:
		# Remove only this harness's previous sequence so a shorter rerun cannot
		# leave stale frames at the end of an encoded battle.
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
	game.boat.position = game.course_right() * -120
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
	action("fire_starboard", true)
	await advance(0.6)
	capture("02-aim-broadside")
	action("steer_port", true)
	await advance(0.45)
	action("steer_port", false)
	capture("03-front-limit")
	action("steer_starboard", true)
	await advance(0.8)
	action("steer_starboard", false)
	capture("04-rear-limit")
	action("steer_port", true)
	await advance(20.0 / 55)
	action("steer_port", false)
	action("fire_starboard", false)
	await advance(0.05)
	capture("05-firing")
	await advance(0.25)
	capture("06-returning")
	await advance(0.7)
	capture("07-return-sailing")
	action("fire_starboard", true)
	await advance(0.45)
	action("astrolabe", true)
	await advance(0.4)
	capture("08-cancel-sky")
	action("astrolabe", false)
	await advance(0.6)
	action("fire_starboard", false)
	# Allow normal enemy AI to run. The scripted player steers until the enemy
	# enters the manual arc, aims and releases; no in-game assistance is added.
	game.enemy_encounters.enabled = true
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 34 + game.course_forward() * 8
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	var fired := false
	for frame in range(900):
		if game.state != game.State.SAILING:
			break
		var offset: Vector3 = ship.to_global(Vector3(0, 1, -1.8)) - game.cannon.shot_origin()
		offset.y = 0
		var right: Vector3 = game.cannon.starboard_direction()
		var desired: float = rad_to_deg(atan2(right.cross(offset.normalized()).y, right.dot(offset.normalized())))
		if not game.cannon.aiming:
			if absf(desired) < 18 and game.cannon.cooldown == 0:
				action("steer_port", false)
				action("steer_starboard", false)
				action("fire_starboard", true)
			else:
				action("steer_port", desired > 3)
				action("steer_starboard", desired < -3)
		else:
			var error: float = desired - game.cannon.aim_degrees
			action("steer_port", error > 0.5)
			action("steer_starboard", error < -0.5)
			if absf(error) < 1.2 or absf(desired) > 24:
				action("fire_starboard", false)
				fired = true
		await advance(1.0 / 60)
		if frame == 90:
			capture("09-live-combat")
		if ship.mode == ship.Mode.SINKING:
			capture("10-cutter-sinking")
			break
	action("steer_port", false)
	action("steer_starboard", false)
	action("fire_starboard", false)
	print("AIM REVIEW: frames=%d shots=%d hits=%d hull=%d enemy_hull=%d fired=%s" % [frame_index, game.cannon.shots_fired, game.cannon.targets_hit, game.hull, ship.hull, fired])
	game.cannon.reset()
	game.enemy_encounters.stop()
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit()

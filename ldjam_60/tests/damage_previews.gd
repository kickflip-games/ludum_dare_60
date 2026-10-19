extends SceneTree
## Real gameplay camera, fixed comparison pose; damage/repair use game methods.
var game
var output := "/tmp/latitude-lines-damage"
var baseline := false
var requested_size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--baseline":
			baseline = true
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			requested_size = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func capture(label: String, storm: bool = false) -> void:
	# Match boat, camera, sea and light across health states without changing hull.
	# This manually stepped fixture must not capture an incidental focus-loss menu.
	game.set_paused(false, false)
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game.heading = 0.0
	game.sea_time = 14.0
	game.ocean.wave_time = game.sea_time
	game.ocean.reset_wake(game.heading)
	game.actual_speed = game.SPEED
	game.storm_blend = 1.0 if storm else 0.0
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	game._update_view(0.0)
	game.hud._process(0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var pixels := root.get_texture().get_image()
	assert(pixels.get_size() == requested_size)
	assert(pixels.save_png(output.path_join(label + ".png")) == OK)
	print("DAMAGE CAPTURE %s hull=%d state=%d camera=%d" % [label, game.hull, game.state, game.camera_mode])


func sail(seconds: float) -> void:
	for frame in range(roundi(seconds * 60.0)):
		# Hold the comparison pose clear of terrain while advancing real repair/view paths.
		game.elapsed += 1.0 / 60.0
		game.damage_immunity = maxf(0.0, game.damage_immunity - 1.0 / 60.0)
		game._update_hull_recovery(1.0 / 60.0)
		game._update_view(1.0 / 60.0)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Damage previews require a real renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = requested_size
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
	game._physics_process(game.CAST_OFF_SECONDS)
	await capture("01-healthy")
	if not baseline:
		game.take_damage(1, "preview impact")
		await capture("02-impact")
		sail(game.hit_immunity_seconds + 0.1)
		await capture("03-damaged")
		game.take_damage(1, "preview second impact")
		sail(1.0)
		await capture("04-heavily-damaged")
		await capture("05-heavy-storm", true)
		sail(game.hull_repair_seconds - 1.0)
		assert(game.hull == 2)
		await capture("06-partly-repaired")
		sail(game.hull_repair_seconds)
		assert(game.hull == game.hull_capacity)
		await capture("07-repaired")
		game.take_damage(1, "preview repaired hit")
		sail(1.0)
		await capture("08-hit-again")
		game.damage_immunity = 0.0
		game.take_damage(game.hull_capacity, "preview lethal impact")
		game._update_view(1.5)
		await capture("09-lost")
		game.restart()
		game._physics_process(game.CAST_OFF_SECONDS)
		await capture("10-restarted")
	print("DAMAGE PREVIEWS: complete — " + output)
	game.queue_free()
	await process_frame
	quit()

extends "res://tests/arcade_controls_smoke.gd"
## Screen-space clearance, resizing, camera independence and lifecycle integration.
func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	fresh()
	var wind = game.boost_wind
	check(wind.mouse_filter == Control.MOUSE_FILTER_IGNORE, "slipstream passes all mouse input through")
	check(wind.get_parent() is CanvasLayer and not game.boat_visual.is_ancestor_of(wind), "slipstream uses a screen layer independent of the boat")
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(900, 506)]:
		root.size = resolution
		await process_frame
		check(wind.size.is_equal_approx(root.get_visible_rect().size), "slipstream fills resized viewport %s" % resolution)
		var clear_center := true
		for frame in 120:
			wind.update_wind(true, float(frame) / 60.0, 1.0 / 60, game.camera, false, false)
			for stream in wind.active_streams:
				for point in wind.stream_points(stream):
					clear_center = clear_center and absf(point.x / wind.size.x - 0.5) > 0.38
		check(clear_center, "every stroke leaves central 76 percent clear at %s" % resolution)
	var points: PackedVector2Array = wind.stream_points(0)
	game.camera.rotation.y += 0.8
	game.boat_visual.rotation.z += 0.4
	check(points == wind.stream_points(0), "camera look and boat roll cannot drag strokes over the ship")
	key(KEY_W, true)
	step(0.3)
	check(wind.visible and wind.active_streams == 8 and game.boosting, "physical W activates screen slipstream and propulsion")
	key(KEY_W, false)
	step(0.2)
	check(not wind.visible and wind.active_streams == 0, "release fully removes the overlay")
	key(KEY_SHIFT, true)
	step(0.3)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not wind.visible and wind.strength == 0.0, "focus loss clears overlay immediately")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	key(KEY_SHIFT, false)
	key(KEY_W, true)
	step(0.3)
	game.restart()
	check(not wind.visible and wind.strength == 0.0, "restart clears screen effect without a lingering frame")
	key(KEY_W, false)
	await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	print("BOOST LINES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

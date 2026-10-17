extends "res://tests/stargazing_previews.gd"
## Real input and production cameras; staged locations make stage comparisons repeatable.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Navigation previews require a real renderer.")
		quit(1)
		return
	capture_clip = false
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
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.start_crossing()
	await advance(game.CAST_OFF_SECONDS + 0.5)
	capture("01-normal-sailing")
	Input.action_press("astrolabe")
	await advance(0.5)
	capture("02-initial-stargazing")
	await advance(1.3)
	capture("03-focused-wreck-star")
	Input.action_release("astrolabe")
	await advance(1.0 / 60.0)
	capture("04-release-clears-reading")
	await advance(0.4)
	capture("05-return-to-sailing")
	# Reach the real region with an old focused reading still open.
	Input.action_press("astrolabe")
	await advance(1.8)
	game.boat.position = game.target + Vector3(0, 0, 12)
	game.voyage.update_progress(game)
	await advance(1.0 / 60.0)
	capture("06-new-stage-clears-old-star")
	Input.action_release("astrolabe")
	await advance(0.4)
	capture("07-wreck-discovery")
	Input.action_press("astrolabe")
	await advance(1.8)
	capture("08-focused-twin-peaks-star")
	Input.action_release("astrolabe")
	await advance(0.4)
	game.boat.position = game.target + Vector3(0, 0, 12)
	game.voyage.update_progress(game)
	await advance(0.1)
	capture("09-twin-peaks-discovery")
	Input.action_press("astrolabe")
	await advance(1.8)
	capture("10-focused-lighthouse-star")
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 40
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0
	ship.locked_point = game.boat.position
	await advance(0.1)
	capture("11-reading-during-combat")
	Input.action_release("astrolabe")
	await advance(0.4)
	capture("12-return-during-combat")
	Input.action_release("watch_starboard")
	game.queue_free()
	await process_frame
	quit()

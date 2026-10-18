extends "res://tests/naval_ai_smoke.gd"

var output := "/tmp/latitude-naval/single"

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	root.size = Vector2i(1280, 720)
	var game = await make_game()
	game.set_process_unhandled_input(false)
	game.enemy_encounters.enabled = true
	game.enemy_encounters.phase = game.enemy_encounters.Phase.STOPPED
	game.boat.position = Vector3(215, 0, 325)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(game.boat.position + Vector3(16, 0, 60))
	game._update_view(1.0)
	var captures := {}
	var samples: Array[Dictionary] = []
	for frame in 22 * 60:
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		var label := ""
		if ship.navigation_state == ship.Navigation.APPROACH and ship.age > 2.0:
			label = "01-approach"
		elif ship.navigation_state == ship.Navigation.ATTACK_RUN and ship.navigation_time > 1.0:
			label = "02-parallel-run"
		elif ship.navigation_state == ship.Navigation.TURN_AWAY and ship.navigation_time > 2.0:
			label = "03-turn-away"
		if frame % 6 == 0 or (label != "" and not captures.has(label)):
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
			var rendered: Image = root.get_texture().get_image()
			if frame % 6 == 0:
				rendered.save_png(output.path_join("frames/%04d.png" % (frame / 6)))
				samples.append({"seconds": ship.age, "navigation": ship.navigation_state,
					"weapon": ship.weapon_state, "position": [ship.position.x, ship.position.z],
					"player": [game.boat.position.x, game.boat.position.z], "heading": ship.heading})
			if label != "" and not captures.has(label):
				rendered.save_png(output.path_join(label + ".png"))
				captures[label] = true
		await physics_frame
	var report := FileAccess.open(output.path_join("motion.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(samples, "\t"))
	print("SINGLE PREVIEWS: ", captures.keys(), " shots=", ship.shots_fired, " collisions=", ship.collisions)
	game.queue_free()
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	OS.delay_msec(200)
	await process_frame
	quit(0 if captures.size() == 3 else 1)

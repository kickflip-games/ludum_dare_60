extends "res://tests/ship_smoke.gd"
## Real rendered motion, with the same stable open-water fixture as the behavior suite.
var output := ProjectSettings.globalize_path("res://../build/enemy_ai_review")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var game = await make_game()
	game.hull_capacity = 20
	game.hull = 20
	var ship = game.enemy_encounters.ship
	ship.begin()
	for i in range(25):
		await process_frame
	var captures := {}
	var samples: Array[Dictionary] = []
	var index := 0
	for frame in range(64 * 60):
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		var label := ""
		if ship.age > 2 and ship.mode == ship.Mode.APPROACH and ship.passes == 0:
			label = "01-approach"
		elif ship.mode == ship.Mode.TELEGRAPH and ship.passes == 1:
			label = "02-broadside"
		elif ship.mode == ship.Mode.REPOSITION and ship.timer > 3:
			label = "03-turn"
		elif ship.mode == ship.Mode.TELEGRAPH and ship.passes == 2:
			label = "04-return"
		elif ship.mode == ship.Mode.DISENGAGING and ship.timer > 3:
			label = "05-retreat"
		if frame % 5 == 0:
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
			var image: Image = root.get_texture().get_image()
			image.save_png(output.path_join("frames/%05d.png" % index))
			index += 1
			samples.append({"time": ship.age, "ship": [ship.position.x, ship.position.z], "player": [game.boat.position.x, game.boat.position.z], "heading": ship.heading, "mode": ship.mode, "pass": ship.passes})
		if label != "" and not captures.has(label):
			RenderingServer.force_draw(true, 1.0 / 60.0)
			root.get_texture().get_image().save_png(output.path_join(label + ".png"))
			captures[label] = true
	var report := FileAccess.open(output.path_join("rendered-motion.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps": 12, "frames": index, "captures": captures.keys(), "samples": samples}, "\t"))
	print("SHIP PREVIEWS: %d frames; %s" % [index, captures.keys()])
	game.queue_free()
	await process_frame
	game = await make_game()
	ship = game.enemy_encounters.ship
	ship.begin()
	var pilot = load("res://tests/cannon_sweep_pilot.gd").new()
	var duel_captures := {}
	DirAccess.make_dir_recursive_absolute(output.path_join("duel-frames"))
	for frame in range(18 * 60):
		pilot.update(game, 1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		if frame % 5 == 0:
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
			root.get_texture().get_image().save_png(output.path_join("duel-frames/%05d.png" % (frame / 5)))
		var label := "06-hit" if ship.hull == 1 else "07-sinking" if ship.mode == ship.Mode.SINKING and ship.timer > 1.0 else ""
		if label != "" and not duel_captures.has(label):
			RenderingServer.force_draw(true, 1.0 / 60.0)
			root.get_texture().get_image().save_png(output.path_join(label + ".png"))
			duel_captures[label] = true
	pilot.release()
	print("RENDERED DUEL: shots=%d hits=%d enemy_hull=%d captures=%s" % [game.cannon.shots_fired, game.cannon.targets_hit, ship.hull, duel_captures.keys()])
	var passed: bool = captures.size() == 5 and duel_captures.size() == 2 and game.cannon.targets_hit == 2
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

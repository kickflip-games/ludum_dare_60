extends "res://tests/fleet_interactions_smoke.gd"

var output := "/tmp/latitude-naval/fleet"

func capture(game, label: String, overview: bool = false) -> void:
	if overview:
		game.camera.global_position = game.arena_center() + Vector3(180, 240, 180)
		game.camera.look_at(game.arena_center())
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(output.path_join("pair"))
	DirAccess.make_dir_recursive_absolute(output.path_join("six"))
	var game = await make_game(2)
	game.set_process_unhandled_input(false)
	var manager = game.enemy_encounters
	manager.phase = manager.Phase.STOPPED
	manager.survival_settings.attack_slots[0] = 2
	game.boat.position = Vector3(215, 0, 325)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	var first = staged_ship(game, 0, game.boat.position + Vector3(-9, 0, 28))
	var second = staged_ship(game, 1, game.boat.position + Vector3(9, 0, 44))
	first.navigation_time = 1.0
	second.navigation_time = 1.0
	manager.director.update(1.0)
	for ship in [first, second]:
		ship.receive_attack_slot()
		ship._change_navigation(ship.Navigation.ATTACK_RUN)
	for frame in 5 * 60:
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		if frame % 6 == 0:
			await capture(game, "pair/%04d" % (frame / 6))
		if frame in [30, 125]:
			await capture(game, "warning-%d" % frame)
		await physics_frame
	print("RENDER PAIR: ", manager.director.warning_history)
	game.queue_free()
	await process_frame
	game = await make_game(6)
	game.set_process_unhandled_input(false)
	game.hull_capacity = 100
	game.hull = 100
	game.boat.position = game.arena_center() + Vector3(0, 0, -138)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	var pilot := Pilot.new()
	for frame in 30 * 60:
		sail_orbit(game, pilot)
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		if frame % 6 == 0:
			await capture(game, "six/%04d" % (frame / 6), true)
		if frame == 12 * 60:
			game._update_view(1.0 / 60.0)
			await capture(game, "six-chase")
			await capture(game, "six-overview", true)
		await physics_frame
	print("RENDER SIX: alive=", game.enemy_encounters.living_ships().size(), " slots=", game.enemy_encounters.director.owners.size())
	pilot.release()
	game.queue_free()
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	OS.delay_msec(200)
	await process_frame
	quit()

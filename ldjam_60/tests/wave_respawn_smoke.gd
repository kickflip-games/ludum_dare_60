extends "res://tests/fleet_hud_smoke.gd"
## Exercise both death Retry paths and normal fresh-run boundaries.

func _run() -> void:
	create_game()
	await physics_frame
	for number in range(1, 6):
		game.restart(true)
		begin()
		for previous in range(1, number):
			enemies.debug_skip_wave()
		enemies._update_arena(3)
		if number == 5:
			enemies.boss.take_hit()
		game.damage_immunity = 0
		game.take_damage(game.hull_capacity, "respawn fixture")
		check(game.state == game.State.LOST and enemies.wave_number == number, "wave %d death retains checkpoint" % number)
		game._physics_process(game.LOSS_HOLD_SECONDS)
		hud._process(0)
		check(hud.menu_details.text == "Reached wave %d of 5" % number, "wave %d result contains no time" % number)
		if number % 2 == 0:
			hud.action_button.pressed.emit()
		else:
			var event := InputEventAction.new()
			event.action = "restart_crossing"
			event.pressed = true
			game._unhandled_input(event)
		check(game.state == game.State.CASTING_OFF and game.hull == game.hull_capacity and game.damage_immunity == 0, "wave %d Retry restores full healthy ship" % number)
		check(enemies.wave_number == number and enemies.records.size() == number and enemies.ships_sunk == 0, "wave %d restarts same wave with clean accounting" % number)
		check(not enemies.has_projectiles() and game.cannon.projectiles.is_empty() and game.ocean.wave_field.waves.is_empty(), "wave %d Retry clears hazards" % number)
		game._physics_process(game.CAST_OFF_SECONDS)
		enemies._update_arena(0)
		hud._process(0)
		check(hud.wave_announcement.text == ("FLAGSHIP" if number == 5 else "WAVE %d / 5" % number), "wave %d announces after respawn" % number)
		check(enemies.spawn_queue.all(func(id): return id == number) and enemies.living_ships().all(func(ship): return ship == enemies.boss or ship.get_meta("wave_id") == number), "wave %d respawns only current roster" % number)
		check(enemies.records.back().count == enemies.survival_settings.enemy_counts[number-1] and enemies.wave_remaining == enemies.survival_settings.deadlines[number-1], "wave %d restores full roster and deadline" % number)
		if number == 5:
			check(enemies.boss_active() and enemies.boss.hull == enemies.boss.hull_capacity and enemies.boss.mines.is_empty(), "flagship respawns at full health without old mines")
		else:
			for repeat in 2:
				game.damage_immunity = 0
				game.take_damage(game.hull_capacity, "repeated death")
				game._physics_process(game.LOSS_HOLD_SECONDS)
				hud._on_action_pressed()
				game._physics_process(game.CAST_OFF_SECONDS)
			check(enemies.wave_number == number and enemies.records.size() == number, "repeated retries preserve wave without duplicate records")
			enemies.wave_remaining = 0
			enemies._update_arena(0)
			check(enemies.wave_number == number + 1 and enemies.records.size() == number + 1, "wave %d progression continues after respawn" % number)
	game.damage_immunity = 0
	game.take_damage(game.hull_capacity, "menu boundary")
	game.restart(true)
	check(game.state == game.State.READY and enemies.wave_number == 0 and enemies.records.is_empty(), "Main Menu discards death checkpoint")
	begin()
	check(enemies.wave_number == 1, "Play from menu starts wave one")
	enemies.debug_skip_wave()
	game.restart()
	check(enemies.wave_number == 0, "held restart during live play starts a fresh run")
	game.state = game.State.ARRIVED
	enemies.wave_number = 5
	hud._on_action_pressed()
	check(enemies.wave_number == 0 and game.state == game.State.CASTING_OFF, "Play Again after victory starts a fresh run")
	game.restart(true)
	game.start_crossing()
	game.state = game.State.SAILING
	game.take_damage(game.hull_capacity, "before first arrival")
	game.restart()
	check(enemies.wave_number == 1, "death before first arrival retries wave one")
	game._physics_process(game.CAST_OFF_SECONDS)
	enemies.phase = enemies.Phase.EARLY_CLEAR
	game.damage_immunity = 0
	game.take_damage(game.hull_capacity, "intermission")
	game.restart()
	check(enemies.wave_number == 1 and enemies.phase == enemies.Phase.ACTIVE, "intermission death restarts the reached wave")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture_results()
	print("WAVE RESPAWN: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func capture_results() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "captures require native renderer")
		return
	game.set_process_unhandled_input(false)
	var output := "/tmp/blackwater-respawn-review"
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1280, 720), Vector2i(900, 506)]:
		root.size = dimensions
		await process_frame
		for number in [3, 5]:
			game.restart(true)
			begin()
			for previous in range(1, number): enemies.debug_skip_wave()
			game.damage_immunity = 0
			game.take_damage(game.hull_capacity, "capture")
			game._physics_process(game.LOSS_HOLD_SECONDS)
			hud._process(1)
			await settle()
			RenderingServer.force_draw(true, 1.0 / 60)
			root.get_texture().get_image().save_png(output.path_join("%dx%d-wave%d-sunk.png" % [dimensions.x, dimensions.y, number]))
			hud._on_action_pressed()
			game._physics_process(game.CAST_OFF_SECONDS)
			enemies._update_arena(3)
			game._update_view(1)
			hud._process(0)
			await settle()
			RenderingServer.force_draw(true, 1.0 / 60)
			root.get_texture().get_image().save_png(output.path_join("%dx%d-wave%d-respawn.png" % [dimensions.x, dimensions.y, number]))

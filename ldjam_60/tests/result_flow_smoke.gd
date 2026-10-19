extends "res://tests/fleet_hud_smoke.gd"
## Staged final hits use production combat/death paths; native mode clicks real GUI.
var capture_frames := false
var output := "/tmp/blackwater-results"

func tick(seconds: float) -> void:
	for frame in ceili(seconds * 60.0):
		game._physics_process(1.0 / 60.0)
		game.cannon._physics_process(1.0 / 60.0)
		game.combat_particles.advance(1.0 / 60.0)
		hud._process(1.0 / 60.0)

func capture(label: String) -> void:
	if not capture_frames: return
	await settle()
	RenderingServer.force_draw(true, 1.0 / 60.0)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "captured " + label)

func click(button: Button) -> void:
	await settle()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	hud._process(0)

func ending(won: bool, number := 5) -> void:
	game.restart(true)
	begin()
	for previous in range(1, number): enemies.debug_skip_wave()
	# Seed real shots, pending volleys and mines to challenge immediate cleanup.
	game.cannon.fire()
	if number == 5:
		enemies.boss._prepare_volley(0.9)
		enemies.boss.deploy_mine()
	if won:
		while enemies.boss.hull > 0:
			game.cannon._impact(enemies.boss, enemies.boss.position + Vector3.UP * 2)
	else:
		game.damage_immunity = 0
		game.take_damage(game.hull_capacity, "result fixture")
	hud._process(0)

func clean(label: String, expected_wave: int) -> void:
	check(not game.result_active and game.result_elapsed == 0 and game.result_salutes == 0, label + " clears sequence state")
	check(game.hull == game.hull_capacity and game.damage_immunity == 0 and not game.cannon._fire_held and not game._fire_armed, label + " restores hull and releases fire")
	check(game.cannon.projectiles.is_empty() and not enemies.has_projectiles() and enemies.boss.mines.is_empty(), label + " clears all projectiles/mines")
	check(game.ocean.wave_field.waves.is_empty() and game.combat_particles.emitted == 0 and game.cannon.effects.is_empty(), label + " clears waves and effects")
	check(enemies.wave_number == expected_wave and enemies.living_ships().all(func(ship): return ship.get_meta("wave_id") == expected_wave), label + " contains only fresh encounter state")
	check(game.boat_visual.position.y > -1.0 and absf(game.boat_visual.rotation.z) < 0.2, label + " restores unsunk player pose")

func realtime_paths() -> void:
	# Here Godot owns all physics/process callbacks, at normal wall-clock speed.
	root.size = Vector2i(1280, 720)
	for won in [true, false]:
		for replay in [true, false]:
			ending(won)
			game.set_physics_process(true)
			game.cannon.set_physics_process(true)
			hud.set_process(true)
			await create_timer(0.5).timeout
			check(not hud.menu.visible and game.result_elapsed > 0.3, "real-time sequence advances without early menu")
			await create_timer(game.result_duration() + 0.1).timeout
			check(hud.menu.visible and game.result_ready() and not enemies.has_projectiles(), "real-time sequence completes with combat stopped")
			await click(hud.action_button if replay else hud.main_menu_button)
			check(game.state == (game.State.CASTING_OFF if replay else game.State.READY), "real-time %s %s click works" % ["victory" if won else "loss", "replay" if replay else "menu"])
			clean("real-time reset", (5 if not won else 0) if replay else 0)
			if replay:
				await create_timer(game.CAST_OFF_SECONDS + 0.1).timeout
				check(game.state == game.State.SAILING and not hud.menu.visible and not enemies.has_projectiles(), "real-time replay resumes without stale shots")
			game.set_physics_process(false)
			game.cannon.set_physics_process(false)
			hud.set_process(false)

func _run() -> void:
	capture_frames = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	create_game()
	game.set_process_unhandled_input(false)
	game.combat_particles.set_process(false)
	await physics_frame
	for dimensions in [Vector2i(1280, 720), Vector2i(900, 506), Vector2i(960, 540)]:
		root.size = dimensions
		await settle()
		for won in [true, false]:
			ending(won)
			var label := "%dx%d-%s" % [dimensions.x, dimensions.y, "victory" if won else "loss"]
			check(game.result_active and not game.result_ready() and not hud.menu.visible and not hud.gameplay_hud.visible, label + " holds unobscured killing frame")
			check(not enemies.has_projectiles() and enemies.living_ships().is_empty() and enemies.spawn_queue.is_empty() and game.cannon.projectiles.is_empty() and enemies.boss.mines.is_empty(), label + " stops combat immediately")
			var hull: int = game.hull
			var clock: float = enemies.clock
			var shots: int = game.cannon.shots_fired
			check(not game.take_damage(1, "late hit") and not game.cannon.fire(), label + " rejects late combat")
			hud._on_action_pressed()
			var retry := InputEventAction.new()
			retry.action = "restart_crossing"
			retry.pressed = true
			game._unhandled_input(retry)
			check(game.result_active, label + " blocks early replay and R")
			await capture(label + "-impact")
			tick(0.5)
			await capture(label + "-sinking")
			if won:
				tick(0.7)
				check(game.result_salutes == 1 and game.cannon.projectiles.is_empty(), label + " first salute is cosmetic")
				await capture(label + "-salute")
			tick(game.result_duration() - game.result_elapsed - 0.1)
			check(not hud.menu.visible, label + " menu stays hidden until sink hold ends")
			await capture(label + "-settled")
			tick(0.3)
			await settle()
			check(hud.menu.visible and game.result_ready() and hud.action_button.has_focus(), label + " result appears and focuses replay")
			check(hud.menu_title.text == ("VICTORY" if won else "SUNK") and hud.menu_details.text == ("All 5 waves cleared" if won else "Reached wave 5 of 5"), label + " exact headline/subtitle")
			check(hud.action_button.text == ("PLAY AGAIN" if won else "TRY AGAIN") and hud.main_menu_button.text == "MAIN MENU" and not hud.settings_button.visible and not hud.credits_button.visible, label + " has exactly two actions")
			check(hud.result_panel.visible and hud.result_ribbon.visible and hud.result_shade.visible, label + " uses Kenney card/banner over dim scene")
			for control: Control in [hud.menu_title, hud.menu_details, hud.action_button, hud.main_menu_button]:
				check(Rect2(Vector2.ZERO, hud.size).encloses(control.get_global_rect()) and absf(control.get_global_rect().get_center().x - hud.size.x * 0.5) < 2.0, label + " centered/visible " + control.name)
			check(game.hull == hull and enemies.clock == clock and game.cannon.shots_fired == shots, label + " no simulation or scored shots after result")
			if won:
				check(game.result_salutes == 2 and not enemies.boss.visible and enemies.victory_transitions == 1, label + " two salutes and complete flagship sinking once")
			else:
				check(game.boat_visual.position.y < -2.0, label + " player visibly sinks")
			var sea_time: float = game.sea_time
			var pose: Transform3D = game.camera.transform
			tick(1)
			check(game.sea_time == sea_time and game.camera.transform == pose, label + " finished scene freezes")
			await capture(label + "-menu")
			await click(hud.action_button)
			check(game.state == game.State.CASTING_OFF, label + " real replay click starts cast-off")
			clean(label + " replay", 0 if won else 5)
			tick(game.CAST_OFF_SECONDS + 0.05)
			check(game.state == game.State.SAILING and not hud.menu.visible and enemies.wave_number == (1 if won else 5), label + " replay resumes correct wave")
			ending(won)
			tick(game.result_duration() + 0.3)
			await click(hud.main_menu_button)
			check(game.state == game.State.READY and hud.menu_title.text == "BLACKWATER" and hud.action_button.has_focus(), label + " real Main Menu click returns to title")
			clean(label + " menu", 0)
			await click(hud.action_button)
			tick(game.CAST_OFF_SECONDS + 0.05)
			check(game.state == game.State.SAILING and enemies.wave_number == 1, label + " title Play starts clean first wave")
	# Actual reached-wave copy and checkpoint coverage, including before first spawn.
	for number in [1, 2, 3, 4]:
		ending(false, number)
		tick(game.LOSS_HOLD_SECONDS + 0.2)
		check(hud.menu_details.text == "Reached wave %d of 5" % number, "loss reports actual wave %d" % number)
	if OS.get_cmdline_user_args().has("--realtime"):
		await realtime_paths()
	print("RESULT FLOW: %d checks, %d failures; staged runtime fixtures, not a human playthrough" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

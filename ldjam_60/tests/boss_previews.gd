extends SceneTree
## Native gameplay-camera fixtures for each readable pattern, hazard and ending.
var game
var boss
var output := "/tmp/latitude-flagship-review"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()
func capture(label: String) -> void:
	# Static combat/model fixtures show settled ships; arrival stages have their own preview.
	for vessel in game.enemy_encounters.combat_ships():
		if vessel.visible:
			vessel.sea_effects.advance_arrival(1.0)
			vessel.sea_effects.apply_arrival()
	for i in 8:
		game._update_view(1.0 / 60)
		game.hud._process(1.0 / 60)
		await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
func stage() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.heading = PI / 2
	game.boat.rotation.y = -game.heading
	game.boat.position = game.arena_center() + Vector3(-10, 0, 80)
	game.boat.velocity = Vector3(7.5, 0, 0)
	for i in 5: game.enemy_encounters._begin_wave()
	game.enemy_encounters.spawn_queue.clear()
	boss.begin(game.arena_center() + Vector3(5, 0, 124))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5
	boss.velocity = boss.forward() * 7.5
	game._sailing_camera_initialized = false

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process_input(false)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	boss = game.enemy_encounters.boss
	stage()
	game.enemy_encounters.announcement_left = 1.0
	await capture("01-arrival")
	game.enemy_encounters.announcement_left = 0
	for kind in [boss.Pattern.ROLLING, boss.Pattern.DOUBLE, boss.Pattern.SCATTER]:
		stage()
		game.enemy_encounters.announcement_left = 0
		boss.pattern = kind
		if kind == boss.Pattern.SCATTER:
			for i in 5: boss.take_hit()
		boss.hit_reaction = 0.0
		boss._update_cloth()
		assert(boss._prepare_volley(1.6))
		boss._update_mines(0.0)
		boss.weapon_time = 0.8
		await capture("%02d-warning" % (2 + kind * 2))
		if kind == boss.Pattern.SCATTER:
			root.size = Vector2i(900, 506)
			await capture("06b-small-warning")
			root.size = Vector2i(1280, 720)
		boss.weapon_time = 0.0
		for i in (99 if kind == boss.Pattern.DOUBLE else 119):
			boss.position += boss.forward() * boss._speed / 60
			boss._update_weapon(1.0 / 60)
			boss._update_mines(1.0 / 60)
			boss._advance_shots(1.0 / 60)
			game.combat_particles.advance(1.0 / 60)
		await capture("%02d-fire" % (3 + kind * 2))
		if kind == boss.Pattern.DOUBLE:
			for i in 12:
				boss.position += boss.forward() * boss._speed / 60
				boss._update_weapon(1.0 / 60)
				boss._advance_shots(1.0 / 60)
			await capture("double-second-warning")
			for i in 42:
				boss.position += boss.forward() * boss._speed / 60
				boss._update_weapon(1.0 / 60)
				boss._advance_shots(1.0 / 60)
			await capture("double-second-fire")
	stage()
	game.enemy_encounters.announcement_left = 0
	boss.pattern = boss.Pattern.ROLLING
	assert(boss._prepare_volley(1.6))
	boss._update_mines(0.0)
	for i in 145:
		boss.position += boss.forward() * boss._speed / 60
		boss._update_weapon(1.0 / 60)
		boss._update_mines(1.0 / 60)
		boss._advance_shots(1.0 / 60)
	await capture("attack-with-mines")
	for i in 5:
		boss.position += boss.forward() * boss._speed / 60
		boss._update_weapon(1.0 / 60)
		boss._update_mines(1.0 / 60)
	await capture("reload-opening")
	root.size = Vector2i(900, 506)
	await capture("reload-small")
	root.size = Vector2i(1280, 720)
	stage()
	game.enemy_encounters.announcement_left = 0
	boss.position = game.boat.position + Vector3(22, 0, 28)
	assert(boss.deploy_mine())
	boss.mines[0].age = 2.0
	boss.mines[0].update_visuals()
	await capture("08-mine-radius")
	boss.mines[0].age = 3.0
	boss.mines[0].update_visuals()
	await capture("08b-mine-pulse")
	game.motion_setting = 1
	await capture("09-reduced-motion")
	root.size = Vector2i(960, 540)
	await capture("10-small-window")
	root.size = Vector2i(1280, 720)
	game.boat.position = boss.mines[0].position
	boss.mines[0].update_mine(0.01)
	await capture("mine-detonation")
	while boss.hull > 0: game.cannon._impact(boss, boss.position + Vector3.UP * 3)
	await capture("11-victory")
	game.queue_free()
	await process_frame
	quit()

extends SceneTree
## Matched boss deck views and a short real, warned rolling salvo.
var game
var boss
var output := "/tmp/blackwater-threat-review"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func capture(label: String) -> void:
	boss.update_visuals(0.0)
	boss._update_tell()
	game.hud._process(0)
	for i in 4: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	print("THREAT CAPTURE: " + output.path_join(label + ".png"))

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.set_process_unhandled_input(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.heading = PI / 2
	game.boat.rotation.y = -game.heading
	game.boat.position = game.arena_center() + Vector3(0, 0, 85)
	game.boat.velocity = Vector3.RIGHT * 7.5
	boss = game.enemy_encounters.boss
	boss.begin(game.boat.position + Vector3(0, 0, 42))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5
	boss.velocity = Vector3.RIGHT * 7.5
	boss.sea_effects.advance_arrival(1.0)
	boss.update_visuals(1.0)
	game.hud.hide()
	game.camera.position = boss.position + Vector3(-18, 14, -19)
	game.camera.look_at(boss.position + Vector3(0, 2, 0))
	game.camera.fov = 55
	for mount in boss.deck_guns: mount.gun.hide()
	await capture("01-deck-without-guns")
	for mount in boss.deck_guns: mount.gun.show()
	await capture("02-deck-with-guns")
	game.camera.position = boss.position + Vector3(19, 12, 18)
	game.camera.look_at(boss.position + Vector3(0, 2, 0))
	await capture("03-stern-and-starboard")
	game.hud.show()
	game.enemy_encounters.wave_number = 5
	game.enemy_encounters.announcement_left = 0
	game.camera.fov = 68
	game._sailing_camera_initialized = false
	for i in 60: game._update_view(1.0 / 60)
	boss.pattern = boss.Pattern.ROLLING
	assert(boss._prepare_volley(boss.telegraph_seconds))
	await capture("04-gameplay-warning")
	root.size = Vector2i(900, 506)
	await capture("05-gameplay-small")
	root.size = Vector2i(1280, 720)
	for tick in 105:
		var dt := 1.0 / 60
		game.sea_time += dt
		game.ocean.wave_time = game.sea_time
		game.boat.position += game.boat.velocity * dt
		boss.position += boss.forward() * boss._speed * dt
		boss._advance_shots(dt)
		boss._update_weapon(dt)
		game.combat_particles.advance(dt)
		game._update_view(dt)
		if tick in [55, 70, 90, 104]: await capture("fire-%03d" % tick)
	game.queue_free()
	await process_frame
	quit()

extends "res://tests/arcade_controls_smoke.gd"
## Comparable real-camera boost frames; also usable with the previous boat ribbons.
func capture(label: String) -> void:
	var held := label.ends_with("boost")
	await process_frame
	game.set_paused(false, false)
	game.boosting = held
	game.boost_wind.update_wind(held, game.sea_time, 0.2, game.camera, false, false)
	game.boost_trails.update_trails(game.boost_wind.strength, game.sea_time, game.camera, false, false)
	game.hud._process(0)
	RenderingServer.force_draw(true, 1.0 / 60)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "native capture " + label)

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	for resolution in [Vector2i(1280, 720), Vector2i(900, 506)]:
		root.size = resolution
		await process_frame
		fresh()
		game.sea_time = 18.0
		game.ocean.wave_time = 18.0
		for frame in 180: game._update_view(1.0 / 60)
		await capture("%d-cruise" % resolution.x)
		game.boosting = true
		for frame in 18: game._update_view(1.0 / 60)
		await capture("%d-boost" % resolution.x)
		key(KEY_E, true)
		key(KEY_E, false)
		for frame in 90: game._update_view(1.0 / 60)
		await capture("%d-close-boost" % resolution.x)
	await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	quit(1 if failures else 0)

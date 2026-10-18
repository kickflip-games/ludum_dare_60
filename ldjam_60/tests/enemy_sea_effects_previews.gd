extends SceneTree
## Matched native arrival stages and curved wakes in the actual ocean.
var game
var ship
var output := "/tmp/latitude-enemy-sea-effects"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()
func capture(label: String) -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
func advance(seconds: float, turn := 0.0) -> void:
	for tick in roundi(seconds * 60):
		game.sea_time += 1.0 / 60
		ship.heading += turn / 60
		ship.rotation.y = -ship.heading
		ship.position += ship.forward() * 9.0 / 60
		ship.sea_effects.advance_arrival(1.0 / 60)
		ship.sea_effects.update_trail(1.0 / 60, true)
		game._update_view(1.0 / 60)
func overview() -> void:
	var at: Vector3 = game.arena_center() + Vector3(40, 0, 78)
	game.camera.position = at + Vector3(22, 22, 32)
	game.camera.look_at(at)
	game.camera.fov = 58
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = game.arena_center() + Vector3(-10, 0, 100)
	game.heading = 0
	game.boat.rotation.y = 0
	game.hud._process(0)
	game.hud.visible = false
	ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(game.arena_center() + Vector3(40, 0, 90))
	ship.heading = 0
	ship.rotation.y = 0
	game._update_view(0.01)
	overview()
	await capture("01-arrival-water-cue")
	advance(0.15)
	overview()
	await capture("02-arrival-early")
	advance(0.30)
	overview()
	await capture("03-arrival-half")
	advance(0.50)
	overview()
	await capture("04-arrival-complete")
	advance(2)
	advance(1.5, 0.4)
	overview()
	await capture("05-curved-wake-and-stern-spray")
	# A matched no-effects frame makes the addition inspectable.
	ship.sea_effects.wake.visible = false
	ship.sea_effects.spray.visible = false
	await capture("06-wake-comparison-off")
	ship.sea_effects.wake.visible = true
	ship.sea_effects.spray.visible = true
	game._sailing_camera_initialized = false
	for i in 60: game._update_view(1.0 / 60)
	await capture("07-gameplay")
	root.size = Vector2i(900, 506)
	await capture("08-small-gameplay")
	root.size = Vector2i(1280, 720)
	ship.reset()
	ship = game.enemy_encounters.boss
	ship.begin(game.arena_center() + Vector3(40, 0, 90))
	ship.heading = 0
	ship.rotation.y = 0
	advance(4)
	overview()
	await capture("09-flagship-wake")
	game.queue_free()
	await process_frame
	quit()

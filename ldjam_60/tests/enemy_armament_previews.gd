extends SceneTree
## Native matched deck views plus the retained gameplay camera and mine ring.
var game
var output := "/tmp/latitude-enemy-armament"
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
	for i in 6: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
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
	game.boat.position = game.arena_center() + Vector3(-25, 0, 100)
	game.heading = 0
	game.boat.rotation.y = 0
	game.hud._process(0)
	game.hud.visible = false
	var ship = game.enemy_encounters.ship
	var at: Vector3 = game.arena_center() + Vector3(20, 0, 100)
	for kind in ["cutter", "skiff", "heavy"]:
		ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
		ship.begin(at)
		ship.heading = 0
		ship.rotation.y = 0
		game.camera.position = at + Vector3(10, 10, -14)
		game.camera.look_at(at + Vector3(0, 1, -1.8))
		game.camera.fov = 55
		if kind == "cutter":
			ship._build_armament(1, false, false)
			await capture("01-before-single-port-gun")
			ship.configure_archetype(load("res://game/enemies/cutter.tres"))
		await capture("02-" + kind + "-deck")
		if kind == "skiff":
			ship.active_battery = ship.Battery.BOW
			ship.weapon_state = ship.Weapon.TELEGRAPH
			ship.weapon_time = 0
			ship._update_tell()
			await capture("03-bow-warning")
	ship.begin(at)
	ship.heading = 0
	ship.rotation.y = 0
	assert(ship.mine_layer.deploy())
	ship.mine_layer.mines[0].age = 2
	ship.mine_layer.mines[0].update_visuals()
	ship.active_battery = ship.Battery.STARBOARD
	ship.weapon_state = ship.Weapon.TELEGRAPH
	ship.weapon_time = 0
	ship._update_tell()
	game.camera.position = at + Vector3(14, 12, 16)
	game.camera.look_at(at + Vector3(0, 0, 2))
	await capture("04-heavy-starboard-and-stern-mine")
	game.hud.visible = true
	game._sailing_camera_initialized = false
	for i in 60: game._update_view(1.0 / 60)
	game.hud._process(0)
	await capture("05-gameplay")
	root.size = Vector2i(900, 506)
	await capture("06-small-gameplay")
	game.queue_free()
	await process_frame
	quit()

extends SceneTree

var game
var output := "/tmp/latitude-combat/after"
var ships: Array[Node3D] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0.0)
	game.hud.queue_redraw()
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("CAPTURE " + label)

func stage() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.sea_time = 12.0
	game.ocean.wave_time = 12.0
	game.boat.transform = Transform3D(Basis.IDENTITY, Vector3(310, 0, 342))
	game.heading = 0.0
	game.boat.velocity = Vector3.FORWARD * game.SPEED
	game._update_view(1.0)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Combat captures require a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	stage()
	var ship = game.enemy_encounters.ship
	ships.append(ship)
	ship.begin(game.boat.position + Vector3(36, 0, -5))
	ship.heading = 0.0
	ship.rotation.y = 0.0
	ship.update_visuals(1.0)
	game._update_view(1.0)
	await physics_frame
	await capture("01-cutter-helm")
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	game._update_view(1.0)
	await physics_frame
	game.cannon.update_aim(0.0)
	ship.update_visuals(0.0)
	await capture("02-cutter-aim")
	game.cannon._impact(ship, ship.global_position + Vector3(0, 2, -1.8))
	ship.update_visuals(0.0)
	await capture("03-confirmed-hit")
	game.cannon._impact(ship, ship.global_position + Vector3(0, 2, -1.8))
	for frame in 150:
		ship.update_ship(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		if frame in [0, 30, 90, 149]:
			await capture("sink-%03d" % frame)
	stage()
	for index in 3:
		var attacker = ship if index == 0 else load("res://game/enemy_ship.tscn").instantiate()
		if index > 0:
			attacker.game = game
			game.add_child(attacker)
			ships.append(attacker)
		var kind: String = ["cutter", "skiff", "heavy"][index]
		var resource_path := "res://game/enemies/" + kind + ".tres"
		if ResourceLoader.exists(resource_path):
			attacker.configure_archetype(load(resource_path))
		attacker.begin(game.boat.position + Vector3(30 + index * 13, 0, -22 + index * 19))
		attacker.heading = 0.0
		attacker.rotation.y = 0.0
		attacker.update_visuals(1.0)
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	game._update_view(1.0)
	await physics_frame
	game.cannon.update_aim(0.0)
	for attacker in ships:
		attacker.update_visuals(0.0)
	await capture("04-three-silhouettes")
	game.queue_free()
	await process_frame
	quit()

extends SceneTree
var game
var output := "/tmp/latitude-combat-particles"
var fx

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func stage() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.sea_time = 12.0
	game.ocean.wave_time = 12.0
	game.boat.transform = Transform3D(Basis.IDENTITY, Vector3(310, 0, 342))
	game.heading = 0.0
	game._update_view(1.0)
	fx.set_process(false)

func capture(label: String, age := 0.16) -> void:
	fx.advance(age)
	fx.set_process(false)
	game.hud._process(0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("PARTICLE CAPTURE " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
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
	fx = game.combat_particles
	stage()
	await capture("01-idle")
	game.cannon.fire()
	await capture("02-player-shot")
	await capture("03-smoke", 0.25)
	stage()
	game.take_damage(1, "Hull struck")
	await capture("04-player-damage", 0.22)
	stage()
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + Vector3(16, 0, -13))
	ship.rotation.y = 0.0
	ship.update_visuals(0.0)
	ship.locked_point = game.boat.position
	ship._fire()
	await capture("05-enemy-shot")
	fx.reset()
	game.cannon._impact(ship, ship.global_position + Vector3(-1.8, 1.8, -1.8))
	await capture("06-enemy-hit", 0.25)
	game.cannon._impact(ship, ship.global_position + Vector3(-1.8, 1.8, -1.8))
	await capture("07-enemy-sunk", 0.2)
	stage()
	game.take_damage(3, "Hull struck")
	await capture("08-lethal-damage", 0.2)
	fx.advance(2.0)
	await capture("09-expired")
	game.queue_free()
	await process_frame
	quit()

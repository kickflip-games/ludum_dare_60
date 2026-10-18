extends SceneTree

var game
var output := "/tmp/latitude-combat/after"
var ships: Array[Node3D] = []
const Pilot = preload("res://tests/cannon_sweep_pilot.gd")
var baseline_mode := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument == "--baseline":
			baseline_mode = true
	_run.call_deferred()

func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(output.path_join(label).get_base_dir())
	game.hud._process(0.0)
	game.hud.queue_redraw()
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
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
	for attacker in ships:
		if attacker != ship:
			attacker.queue_free()
	await process_frame
	if not baseline_mode:
		await encounter("skiff", true)
		await encounter("heavy", false)
	game.queue_free()
	await process_frame
	quit()

func encounter(kind: String, choppy: bool) -> void:
	stage()
	game.sea_time = 0.0
	game.ocean.wave_time = 0.0
	game.enemy_encounters.enabled = true
	game.enemy_encounters.phase = game.enemy_encounters.Phase.STOPPED
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	if kind == "heavy":
		game.boat.position = Vector3(260, 0, 355)
	ship.begin(game.boat.position + Vector3(ship.broadside_separation, 0, -4))
	if kind == "heavy":
		ship.heading = 0.0
		ship.rotation.y = 0.0
	if choppy:
		game.ocean.wave_field.add_wave(Vector2(286, 323), Vector2.RIGHT, 0.85, 4.5, 35.0, 8.0, 0.0, 9.0)
	await physics_frame
	var pilot := Pilot.new()
	var warned := false
	var fired := false
	var hit := false
	for frame in 720 if choppy else 480:
		if choppy and frame >= 300:
			pilot.update(game, 1.0 / 60.0)
		elif choppy:
			var correction: float = -game.heading * 3.0 - (game.boat.position.x - 310.0) * 0.10 - game.wave_sailing.drift.x * 0.22
			pilot.action("steer_port", correction < -0.1)
			pilot.action("steer_starboard", correction > 0.1)
		elif not choppy:
			pilot.action("watch_starboard", true)
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		if frame % 6 == 0:
			await capture("%s-sequence/frame-%03d" % [kind, frame / 6])
		if choppy and frame == 180:
			await capture("05-skiff-crest")
		if not warned and ship.mode == ship.Mode.TELEGRAPH:
			warned = true
			await capture(kind + "-warning")
		if not fired and ship.shots_fired > 0:
			fired = true
			await capture(kind + "-firing")
		if not hit and ship.hull <= 0:
			hit = true
			await capture(kind + "-confirmed-sink")
		await physics_frame
	print("RENDERED ENCOUNTER " + JSON.stringify({"kind": kind, "hull": game.hull, "enemy_hull": ship.hull,
		"shots": game.cannon.shots_fired, "hits": game.cannon.targets_hit, "enemy_shots": ship.shots_fired,
		"warned": warned, "fired": fired, "wave_yaw": game.wave_sailing.yaw_rate}))
	pilot.release()

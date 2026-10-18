extends "res://tests/arcade_controls_smoke.gd"
## Deterministic rendered phases at rest, gameplay distance and turning in waves.
var fleet: Array = []

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "native capture " + label)

func pose_cloth(time: float, enabled := true) -> void:
	for ship in fleet:
		var model: Node3D = ship.flagship_model if ship == game.enemy_encounters.boss else ship.ship_model
		var cloth = model.get_node("ClothMotion")
		cloth.set_process(false)
		cloth.sail_degrees = 2.5 if enabled else 0
		cloth.flag_degrees = 6 if enabled else 0
		cloth._time = time
		cloth._process(0)
	var player = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail/ClothMotion")
	player.set_process(false)
	player.sail_degrees = 2.5 if enabled else 0
	player._time = time
	player._process(0)

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	if output.is_empty(): output = "/tmp/blackwater-ship-cloth"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	fresh()
	game.hud.visible = false
	fleet = [game.enemy_encounters.ships[0], game.enemy_encounters.ships[1], game.enemy_encounters.boss]
	for i in fleet.size():
		var ship = fleet[i]
		ship.begin(game.boat.position + Vector3(19 + i * 16, 0, -12 + i * 6))
		ship.heading = 0
		ship.rotation.y = 0
		ship.sea_effects.advance_arrival(1)
		ship.sea_effects.apply_arrival()
	for i in 60: game._update_view(1.0 / 60)
	var gameplay_pose: Transform3D = game.camera.transform
	var gameplay_fov: float = game.camera.fov
	for view in ["detail", "gameplay", "waves-turn"]:
		for frame in 16:
			var time := frame * 0.25
			if view == "waves-turn":
				for ship in fleet:
					ship.heading += 0.08
					ship.rotation.y = -ship.heading
					ship.position += ship.forward() * 1.5
					ship.sea_effects.advance_arrival(0.25)
				if frame == 0:
					var at: Vector3 = fleet[0].position
					game.ocean.wave_field.add_wave(Vector2(at.x, at.z + 6), Vector2(0, -1), 2, 9, 45, 8, game.sea_time)
				game.sea_time += 0.25
				game.ocean.wave_time = game.sea_time
				game._update_view(0.25)
			pose_cloth(time)
			if view == "detail":
				game.camera.position = fleet[0].position + Vector3(-17, 12, 20)
				game.camera.look_at(fleet[0].position + Vector3(7, 4, 0))
				game.camera.fov = 55
			else:
				game.camera.transform = gameplay_pose
				game.camera.fov = gameplay_fov
			await capture("%s-%02d" % [view, frame])
			if frame == 0:
				pose_cloth(time, false)
				await capture(view + "-off")
	root.size = Vector2i(900, 506)
	await capture("small-gameplay")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

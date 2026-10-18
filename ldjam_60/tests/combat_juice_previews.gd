extends "res://tests/combat_particles_previews.gd"
## Matched production-camera VFX timing; no gameplay clock runs between captures.
func stage() -> void:
	super.stage()
	game.weather_enabled = false
	game._sound_enabled = false
	game.cannon.update_cone_feedback()
	game.storm_blend = 0.0
	game.sky_material.set_shader_parameter("storm", 0.0)
	game._apply_night_illumination()
	for i in 60: game._update_view(1.0 / 60)

func tick(seconds: float) -> void:
	for frame in roundi(seconds * 60):
		game.cannon.advance(1.0 / 60)
		fx.advance(1.0 / 60)
	fx.set_process(false)

func fleet() -> void:
	for index in 5:
		var ship = game.enemy_encounters.ships[index]
		ship.configure_archetype(load("res://game/enemies/%s.tres" % ["skiff", "heavy", "cutter"][index % 3]))
		ship.begin(game.boat.position + Vector3(19 + index * 5, 0, -12 + index * 7))
		ship.heading = 0.0
		ship.rotation.y = 0.0
		ship.update_visuals(0.0)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process_input(false)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	fx = game.combat_particles
	for close in [false, true]:
		stage()
		game.arena_cannon_view = close
		for i in 60: game._update_view(1.0 / 60)
		await capture("%s-idle" % ["close" if close else "chase"], 0.0)
		game.cannon.fire()
		tick(0.033333)
		await capture("%s-flash-33ms" % ["close" if close else "chase"], 0.0)
		tick(0.066667)
		await capture("%s-sparks-100ms" % ["close" if close else "chase"], 0.0)
		tick(0.2)
		await capture("%s-smoke-300ms" % ["close" if close else "chase"], 0.0)
	stage()
	game.cannon.water_splash(game.boat.position + Vector3(10, 0, -6), false)
	tick(0.1)
	await capture("water-100ms", 0.0)
	game.cannon.water_splash(game.boat.position + Vector3(14, 0, -9), false)
	tick(0.2)
	await capture("water-overlap-300ms", 0.0)
	tick(0.3)
	await capture("water-rings-600ms", 0.0)
	stage()
	fleet()
	for index in [0, 1]:
		var ship = game.enemy_encounters.ships[index]
		game.cannon._impact(ship, ship.global_position + Vector3(0, 1.8, -1.8))
		ship.update_visuals(0.0)
		tick(0.066667)
		await capture("hit-%s" % ["skiff-sunk" if index == 0 else "heavy"], 0.0)
	stage()
	fleet()
	for ship in game.enemy_encounters.ships:
		ship.locked_point = game.boat.position
		ship._fire()
		ship.flash.visible = true
	game.cannon.fire()
	tick(0.033333)
	await capture("five-enemy-muzzles", 0.0)
	game.storm_blend = 1.0
	game.sky_material.set_shader_parameter("storm", 1.0)
	game._apply_night_illumination()
	await capture("storm-muzzles", 0.0)
	for lethal in [false, true]:
		stage()
		game.take_damage(3 if lethal else 1, "Preview hull hit")
		tick(0.066667)
		await capture("player-lethal" if lethal else "player-damage", 0.0)
	tick(1.5)
	await capture("expired", 0.0)
	if "--clip" in OS.get_cmdline_user_args():
		stage()
		fleet()
		DirAccess.make_dir_recursive_absolute(output.path_join("sequence"))
		for frame in 90:
			if frame == 0: game.cannon.fire()
			if frame == 18: game.cannon.water_splash(game.boat.position + Vector3(10, 0, -6), false)
			if frame == 27: game.cannon.water_splash(game.boat.position + Vector3(14, 0, -9), false)
			if frame == 36:
				var ship = game.enemy_encounters.ships[1]
				game.cannon._impact(ship, ship.global_position + Vector3(0, 1.8, -1.8))
			if frame == 54: game.take_damage(1, "Sequence hit")
			tick(1.0 / 30)
			await capture("sequence/frame-%03d" % frame, 0.0)
	game.queue_free()
	await process_frame
	quit()

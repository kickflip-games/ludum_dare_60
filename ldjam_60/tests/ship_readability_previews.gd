extends "res://tests/arcade_controls_smoke.gd"
## Matched 720p production cameras and five-ship combat-effects benchmark.
var metrics := {}

func settle() -> void:
	for i in 60:
		game._update_view(1.0 / 60)

func fleet(count: int = 3) -> void:
	for i in count:
		var ship = game.enemy_encounters.ships[i]
		ship.configure_archetype(load("res://game/enemies/%s.tres" % ["skiff", "cutter", "heavy"][i % 3]))
		ship.begin(game.boat.position + Vector3(26 + i * 7, 0, -16 + i * 10))
		ship.heading = -0.35
		ship.rotation.y = -ship.heading
		ship.update_visuals(0.0)

func benchmark() -> void:
	fresh()
	fleet(5)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 420:
		game.sea_time = 30.0 + frame / 60.0
		game._update_view(1.0 / 60)
		for ship in game.enemy_encounters.ships:
			ship.update_visuals(1.0 / 60)
			if frame % 15 == 0 and ship.visible:
				game.combat_particles.muzzle(ship.muzzle_position(), ship.port_direction(), true)
		game.combat_particles.set_process(false)
		game.combat_particles.advance(1.0 / 60)
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60)
		var now := Time.get_ticks_usec()
		if frame >= 120:
			times.append((now - previous) / 1000.0)
		previous = now
	times.sort()
	metrics = {"median_ms": times[150], "p95_ms": times[285], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "renderer": RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	print("READABILITY PERFORMANCE ", JSON.stringify(metrics))

func _run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty():
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
	fresh()
	fleet()
	settle()
	await capture("01-chase-fleet")
	for close in [false, true]:
		game.arena_cannon_view = close
		for yaw in [0, -45, 45]:
			game.look_target = yaw
			game.look_idle = -10
			settle()
			await capture("%s-look-%d" % ["close" if close else "chase", yaw])
	game.look_target = 0
	game.look_idle = -10
	settle()
	game.enemy_encounters.ships[1].set_aim_highlight(true)
	await capture("08-highlight")
	game.enemy_encounters.ships[1].take_hit()
	await capture("09-hit")
	game.enemy_encounters.ships[1].take_hit()
	game.enemy_encounters.ships[1].update_ship(0.65)
	await capture("10-sinking")
	fresh()
	fleet()
	game.arena_cannon_view = true
	key(KEY_D, true)
	key(KEY_SPACE, true)
	step(0.65)
	await capture("11-close-turn-fire")
	key(KEY_D, false)
	key(KEY_SPACE, false)
	game.ocean.wave_field.add_wave(Vector2(game.boat.position.x, game.boat.position.z + 8), Vector2(0, -1), 2, 9, 45, 8, game.sea_time)
	step(0.8)
	await capture("12-close-crest")
	fresh()
	fleet()
	game.arena_cannon_view = true
	key(KEY_A, true)
	key(KEY_SPACE, true)
	step(0.65)
	game.damage_immunity = 0
	game.take_damage(1, "Camera preview")
	step(0.05)
	await capture("12b-port-turn-damage")
	key(KEY_A, false)
	key(KEY_SPACE, false)
	game.storm_blend = 1
	game.sky_material.set_shader_parameter("storm", 1.0)
	game._apply_night_illumination()
	await capture("13-storm")
	fresh()
	game.boat.position = game.arena_center() + Vector3(0, 0, 174)
	game.heading = PI
	game.boat.rotation.y = -game.heading
	game.storm_blend = 0.8
	game.sky_material.set_shader_parameter("storm", 0.8)
	game._update_view(1.0)
	game.hud._process(0.0)
	await capture("14-storm-boundary-lighthouse")
	await benchmark()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

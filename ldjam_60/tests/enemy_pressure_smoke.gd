extends SceneTree
## Production spawns and real movement; immunity only keeps the measurement alive.
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	if render:
		assert(DisplayServer.get_name() != "headless")
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute("/tmp/latitude-enemy-pressure")
	for hz in ([60] if render else [30, 60, 120]):
		var game = load("res://game/crossing.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.cannon.set_physics_process(false)
		game.hud.set_process(false)
		if render:
			game.set_process_unhandled_input(false)
		game.restart()
		game.state = game.State.SAILING
		game.wave_encounters.enabled = false
		game.damage_immunity = 10000.0
		await physics_frame
		var captured_warning := false
		var first_close := -1.0
		var first_shot := -1.0
		var peak := 0
		var maximum_step := 0.0
		var nearest := INF
		var longest_stop := 0.0
		var stopped := {}
		for frame in 90 * hz:
			var previous := {}
			for ship in game.enemy_encounters.living_ships():
				previous[ship] = ship.position
			game.advance_sailing(1.0 / hz, 0.0)
			var living: Array = game.enemy_encounters.living_ships()
			peak = maxi(peak, living.size())
			for ship in living:
				var distance: float = ship.position.distance_to(game.boat.position)
				nearest = minf(nearest, distance)
				if distance < ship.firing_range and first_close < 0.0:
					first_close = float(frame + 1) / hz
				if ship.shots_fired > 0 and first_shot < 0.0:
					first_shot = float(frame + 1) / hz
				if previous.has(ship):
					maximum_step = maxf(maximum_step, ship.position.distance_to(previous[ship]) * hz)
				stopped[ship] = stopped.get(ship, 0.0) + 1.0 / hz if ship.velocity.length() < 0.7 else 0.0
				longest_stop = maxf(longest_stop, stopped[ship])
			if render:
				game._update_view(1.0 / hz)
				game.hud._process(1.0 / hz)
				var label := ""
				if not captured_warning and living.any(func(s): return s.mode == s.Mode.TELEGRAPH and s.timer > 0.5):
					captured_warning = true
					label = "first-warning"
				if frame in [6 * hz, 45 * hz, 70 * hz]: label = "combat-%ds" % (frame / hz)
				if not label.is_empty():
					await process_frame
					RenderingServer.force_draw(true, 1.0 / hz)
					root.get_texture().get_image().save_png("/tmp/latitude-enemy-pressure/" + label + ".png")
			if not render or frame % 12 == 0:
				await physics_frame
		var shots := 0
		for ship in game.enemy_encounters.ships: shots += ship.shots_fired
		print("PRESSURE " + JSON.stringify({"hz": hz, "first_close": first_close,
			"first_shot": first_shot, "shots": shots, "peak": peak,
			"nearest": nearest, "max_speed": maximum_step, "longest_stop": longest_stop}))
		if "--measure-only" not in OS.get_cmdline_user_args():
			check(first_close > 0 and first_close < 8.0, "%d Hz: production arrivals enter gun range within eight seconds" % hz)
			check(game.enemy_encounters.director.owners.size() <= game.enemy_encounters.director.slot_limit(),
				"%d Hz: production approaches respect the limited attack slots" % hz)
			check(peak == 5 and maximum_step < 18.0 and longest_stop < 5.0, "%d Hz: five arrivals recover within the explicit five-second safety maneuver" % hz)
			check(game.enemy_encounters.ships_sunk == 0 and game.state == game.State.SAILING, "elapsed time never kills an enemy or awards victory")
			game.restart()
			check(game.enemy_encounters.living_ships().is_empty() and not game.enemy_encounters.has_projectiles()
				and game.enemy_encounters.spawn_queue.is_empty(), "retry clears the larger encounter and incoming fire")
		game.queue_free()
		await process_frame
	if "--measure-only" not in OS.get_cmdline_user_args():
		await crossing_opportunities()
	print("ENEMY PRESSURE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func crossing_opportunities() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.heading = 0.0
	game.boat.position = Vector3(260, 0, 355)
	game.boat.velocity = Vector3.FORWARD * game.SPEED
	await physics_frame
	var ship = game.enemy_encounters.ship
	for kind in ["cutter", "skiff", "heavy"]:
		ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
		for blocked in [false, true]:
			ship.begin(game.boat.position + Vector3(42, 0, 14))
			ship.heading = 0.3
			ship.rotation.y = -ship.heading
			ship.cooldown = 2.0 if blocked else 0.0
			await physics_frame
			ship._change_navigation(ship.Navigation.ATTACK_RUN)
			ship.update_ship(1.0 / 60.0)
			check((ship.mode == ship.Mode.TELEGRAPH) == not blocked,
				kind + ": crossing broadside starts promptly only when reloaded")
			if not blocked:
				var point: Vector3 = ship.locked_point
				game.boat.position.x += 1.0
				ship.update_ship(1.0 / 60.0)
				check(ship.locked_point == point and ship.projectiles.is_empty(),
					kind + ": crossing warning stays fixed and cannot fire early")
				game.boat.position.x -= 1.0
		ship.begin(game.boat.position + Vector3(-42, 0, 14))
		ship.heading = 0.3
		ship.rotation.y = -ship.heading
		await physics_frame
		ship._change_navigation(ship.Navigation.ATTACK_RUN)
		ship.update_ship(1.0 / 60.0)
		check(ship.mode != ship.Mode.TELEGRAPH, kind + ": cannot fire through the wrong side of the hull")
		ship.reset()
	game.queue_free()
	await process_frame

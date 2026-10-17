extends SceneTree

const Pilot = preload("res://tests/voyage_pilot.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func make_game(seed_value: int):
	var game = load("res://game/crossing.tscn").instantiate()
	game.encounter_seed = seed_value
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	# Isolate sailing; integrated enemy playthroughs run in crossing_smoke.gd.
	game.enemy_encounters.enabled = false
	return game


func _run() -> void:
	var game = await make_game(60)
	var initial: int = game.obstacles.size()
	check(initial == 5, "only the distant first encounter is built at departure")
	var before: Vector3 = game.boat.position
	game.reading = true
	for frame in range(180):
		game.advance_sailing(1.0 / 60.0, 0.0)
		await physics_frame
	check(game.boat.position.distance_to(before) > 18.0 and absf(game.voyage.current) > 0.05,
		"motion and cross-current continue during astrolabe readings")
	check(absf(game.boat.velocity.normalized().dot(game.course_right())) > 0.01,
		"heading and travel direction differ under current")
	game.elapsed = 9.0
	game.voyage.update_forces(game, 0.01)
	check(game.voyage.gust_warning > 1.0 and game.voyage.gust_push == 0.0,
		"gust announces itself before any heading impulse")
	game.queue_free()
	await process_frame
	var straight_wins: int = 0
	for seed_value in [60, 61, 62]:
		for angle in [-0.04, 0.0, 0.04]:
			game = await make_game(seed_value)
			game.heading += angle
			for frame in range(9000):
				game.advance_sailing(1.0 / 60.0, 0.0)
				await physics_frame
				if game.state != game.State.SAILING:
					break
			straight_wins += int(game.state == game.State.ARRIVED)
			print("STRAIGHT seed=%d angle=%.2f state=%d t=%.1f distance=%.1f" % [seed_value, angle, game.state, game.elapsed, game.journey_distance()])
			game.queue_free()
			await process_frame
	check(straight_wins == 0, "unchanged heading fails across nine seed/heading combinations")
	for seed_value in [60, 61, 62]:
		game = await make_game(seed_value)
		var corrections: int = 0
		for frame in range(10000):
			var steer: float = Pilot.steering(game)
			corrections += int(absf(steer) > 0.2)
			game.advance_sailing(1.0 / 60.0, steer)
			await physics_frame
			if game.state != game.State.SAILING:
				break
		print("ACTIVE seed=%d state=%d t=%.1f distance=%.1f lane=%.1f" % [seed_value, game.state, game.elapsed, game.journey_distance(), game.boat.position.dot(game.course_right())])
		check(game.state == game.State.ARRIVED and corrections > 300, "active avoidance completes seed %d" % seed_value)
		game.queue_free()
		await process_frame
	print("SAILING TEST: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

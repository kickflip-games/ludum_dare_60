extends SceneTree
## Staged moving AI duels using hold-E aim, fresh-F fire and release-E steering.
const Pilot = preload("res://tests/cannon_sweep_pilot.gd")
var failures := 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for trial in range(3):
		var game = load("res://game/crossing.tscn").instantiate()
		game.encounter_seed = 60 + trial
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.cannon.set_physics_process(false)
		game.current_strength = 0.35 * trial
		game.gust_strength = 0.04 * trial
		game.start_crossing()
		game._physics_process(game.CAST_OFF_SECONDS)
		game.boat.position = Vector3(400, 0, 360)
		var ship = game.enemy_encounters.ship
		ship.begin()
		ship.position = game.boat.position + game.cannon.starboard_direction() * 34 + game.course_forward() * (trial - 1) * 8
		ship.territory = ship.position
		ship.heading = game.heading
		ship.rotation.y = -ship.heading
		var pilot := Pilot.new()
		var max_aim: float = 0
		var aim_seconds: float = 0
		for frame in range(1500):
			if game.state != game.State.SAILING or ship.hull <= 0 or ship.mode == ship.Mode.ESCAPED:
				break
			pilot.update(game, 1.0 / 60)
			game._physics_process(1.0 / 60)
			game.cannon.advance(1.0 / 60)
			max_aim = maxf(max_aim, absf(game.cannon.aim_degrees))
			if game.cannon.aiming:
				aim_seconds += 1.0 / 60
			await physics_frame
		var result := {"seed": 60 + trial, "seconds": snappedf(game.elapsed, 0.01), "shots": game.cannon.shots_fired, "hits": game.cannon.targets_hit, "hull": game.hull, "enemy_hull": ship.hull, "gun_seconds": snappedf(aim_seconds, 0.01), "max_aim": max_aim, "entries": pilot.entries, "steering_exits": pilot.steering_exits, "warned_dodge": pilot.evaded}
		results.append(result)
		var passed: bool = ship.hull == 0 and game.hull > 0
		if not passed:
			failures += 1
		print(("PASS: " if passed else "FAIL: ") + "SWEEP DUEL " + JSON.stringify(result))
		pilot.release()
		game.queue_free()
		await process_frame
	var output := FileAccess.open("/tmp/latitude-sweep-battles.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("SWEEP BATTLES: 3 trials, %d failures" % failures)
	quit(0 if failures == 0 else 1)

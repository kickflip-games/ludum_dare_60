extends SceneTree
## Scripted short duels through the hold/release inputs; not a human balance verdict.
var failures := 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


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
		game.boat.position = game.course_right() * -120
		var ship = game.enemy_encounters.ship
		ship.begin()
		ship.position = game.boat.position + game.cannon.starboard_direction() * 34 + game.course_forward() * (trial - 1) * 8
		ship.heading = game.heading
		ship.rotation.y = -ship.heading
		var max_aim: float = 0
		var aim_seconds: float = 0
		for frame in range(1500):
			if game.state != game.State.SAILING or ship.hull <= 0 or ship.mode == ship.Mode.ESCAPED:
				break
			var offset: Vector3 = ship.to_global(Vector3(0, 1, -1.8)) - game.cannon.shot_origin()
			offset += ship.velocity * offset.length() / game.cannon.SHOT_SPEED
			offset.y = 0
			var right: Vector3 = game.cannon.starboard_direction()
			var desired: float = rad_to_deg(atan2(right.cross(offset.normalized()).y, right.dot(offset.normalized())))
			if game.cannon.aiming:
				aim_seconds += 1.0 / 60
				var error: float = desired - game.cannon.aim_degrees
				action("steer_port", error > 0.5)
				action("steer_starboard", error < -0.5)
				if absf(error) < 1.2 or absf(desired) > 24:
					action("fire_starboard", false)
			elif absf(desired) < 18 and game.cannon.cooldown == 0:
				action("steer_port", false)
				action("steer_starboard", false)
				action("fire_starboard", true)
			else:
				action("steer_port", desired > 3)
				action("steer_starboard", desired < -3)
			game._physics_process(1.0 / 60)
			game.cannon.advance(1.0 / 60)
			max_aim = maxf(max_aim, absf(game.cannon.aim_degrees))
			await physics_frame
		var result := {"seed": 60 + trial, "seconds": snappedf(game.elapsed, 0.01), "shots": game.cannon.shots_fired, "hits": game.cannon.targets_hit, "hull": game.hull, "enemy_hull": ship.hull, "aim_seconds": snappedf(aim_seconds, 0.01), "max_aim": max_aim}
		results.append(result)
		var passed: bool = ship.hull == 0 and game.hull > 0
		if not passed:
			failures += 1
		print(("PASS: " if passed else "FAIL: ") + "HOLD/RELEASE DUEL " + JSON.stringify(result))
		for name in ["fire_starboard", "steer_port", "steer_starboard"]:
			action(name, false)
		game.queue_free()
		await process_frame
	var output := FileAccess.open("/tmp/latitude-aim-battles.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("AIM BATTLES: 3 trials, %d failures" % failures)
	quit(0 if failures == 0 else 1)

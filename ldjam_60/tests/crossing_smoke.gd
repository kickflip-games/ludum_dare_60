extends SceneTree
## Integrated scripted play: real input actions, physics, enemies, currents and progression.
const Pilot = preload("res://tests/voyage_pilot.gd")
var failures: int = 0
var results: Array[Dictionary] = []


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
	return game


func _run() -> void:
	var game = await make_game(60)
	check(game.state == game.State.READY and not game.cannon.fire(), "title waits for start and gates the cannon")
	await click_menu_button(game)
	check(game.state == game.State.CASTING_OFF, "actual Start mouse click begins cast-off transition")
	Input.action_press("steer_port")
	Input.action_press("astrolabe")
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	check(game.boat.position.length() < 0.01 and game.elapsed == 0 and not game.reading, "cast-off gates movement, steering, readings, and timer")
	Input.action_release("steer_port")
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	game._physics_process(0.4)
	check(game.reading and game.has_reading and game.camera.rotation.x > 0.8, "hold-to-use input raises astrolabe while boat keeps moving")
	var saved: float = game.last_reading
	Input.action_release("astrolabe")
	Input.action_press("steer_port")
	game._physics_process(0.4)
	Input.action_release("steer_port")
	check(game.heading < saved and game.last_reading == saved, "responsive steering leaves last sighting stale after lowering")
	var bow_heading: float = game.heading
	Input.action_press("watch_starboard")
	game._physics_process(0.3)
	check(game.look_blend > 0.9 and absf(game.heading - bow_heading) < 0.001,
		"held E exposes the broadside without changing the boat heading")
	Input.action_release("watch_starboard")
	game._physics_process(0.3)
	game.boat.position = game.course_right() * 80
	check(game.journey_distance() < 0.01, "sideways travel does not manufacture voyage progress")
	game.boat.position = game.target + game.course_right() * 100
	game.advance_sailing(0.01, 0)
	check(game.state != game.State.ARRIVED, "passing the lighthouse offshore cannot win")
	game.queue_free()
	await process_frame
	for seed_value in [60, 61, 62]:
		for strategy: String in ["straight", "evade", "combat", "frequent_sights", "recover"]:
			await voyage(seed_value, strategy)
	var combat_sinks: int = 0
	for result: Dictionary in results:
		if result.strategy == "combat":
			combat_sinks += result.sunk
	check(combat_sinks > 0, "integrated moving duels can be won with actual broadside shots")
	var file := FileAccess.open("/tmp/ld60-integrated-playthroughs.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("CROSSING CHECK: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func voyage(seed_value: int, strategy: String) -> void:
	var game = await make_game(seed_value)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	var phases: Dictionary = {}
	var shots: int = 0
	var reads: int = 0
	var max_lane: float = 0.0
	var storm_height: float = 0.0
	var departure_height: float = game.ocean_settings.height_multiplier
	var corrections: int = 0
	var previous_hits: int = 0
	for frame in range(10000):
		var steering: float = 0.0 if strategy == "straight" else Pilot.steering(game, -1.0 if seed_value == 61 else 1.0, strategy == "combat")
		if strategy == "recover" and game.elapsed < 12.0:
			steering = clampf(wrapf(game.TARGET_HEADING + 0.95 - game.heading, -PI, PI) * 3.0, -1.0, 1.0)
		Input.action_release("steer_port")
		Input.action_release("steer_starboard")
		if absf(steering) > 0.01:
			Input.action_press("steer_port" if steering < 0 else "steer_starboard", absf(steering))
		var sight: bool = strategy != "straight" and fmod(game.elapsed, 5.0 if strategy == "frequent_sights" else 11.0) < 1.8
		if sight:
			Input.action_press("astrolabe")
			reads += 1
		else:
			Input.action_release("astrolabe")
		game._physics_process(1.0 / 60.0)
		if strategy == "combat" and not game.reading:
			var target: Dictionary = game.cannon.aim_target()
			if not target.is_empty() and target.aligned and target.body.get_meta("target_kind") == "ship":
				game.cannon.fire()
		game.cannon.advance(1.0 / 60.0)
		if game.hits_taken > previous_hits:
			print("DAMAGE: %s seed=%d course=%.1f %s" % [strategy, seed_value, game.journey_distance(), game.hit_message])
			previous_hits = game.hits_taken
		shots = maxi(shots, game.cannon.shots_fired)
		corrections += int(absf(steering) > 0.2)
		max_lane = maxf(max_lane, absf(game.boat.position.dot(game.course_right())))
		phases[game.phase] = true
		if game.phase == 2:
			storm_height = maxf(storm_height, game.ocean_settings.height_multiplier)
		await physics_frame
		if game.state != game.State.SAILING:
			break
	for action: String in ["steer_port", "steer_starboard", "astrolabe"]:
		Input.action_release(action)
	var result := {"seed": seed_value, "strategy": strategy, "won": game.state == game.State.ARRIVED,
		"seconds": snappedf(game.elapsed, 0.1), "hull": game.hull, "sunk": game.enemy_encounters.ships_sunk,
		"shots": shots, "reading_seconds": snappedf(reads / 60.0, 0.1), "max_lane": snappedf(max_lane, 0.1),
		"correction_seconds": snappedf(corrections / 60.0, 0.1), "interceptions": game.enemy_encounters.encounter_index}
	results.append(result)
	print("VOYAGE: " + JSON.stringify(result))
	if strategy == "straight":
		check(not result.won, "straight sailing does not win seed %d" % seed_value)
	else:
		check(result.won, "%s completes seed %d" % [strategy, seed_value])
		check(game.elapsed >= 90.0 and game.elapsed <= 120.0, "competent route stays within 90–120 seconds")
		check(phases.size() == 4 and storm_height > departure_height * 1.4, "distance-driven phases build to stronger storm water")
		check(game.enemy_encounters.encounter_index == 2, "both interceptions occur without blocking arrival")
		check(game.hull > 0 and corrections > 300 and game.has_reading, "survivor actively steers and takes bearings")
		if strategy == "recover":
			check(max_lane > 45.0 and absf(game.boat.position.dot(game.course_right())) < 20.0, "off-course player can recover into the final approach")
		if result.won:
			var at: Vector3 = game.boat.position
			var elapsed: float = game.elapsed
			game._physics_process(1.0)
			check(game.boat.position == at and game.elapsed == elapsed and game.journey_progress() == 1.0, "arrival stops gameplay and completes progress")
			await click_menu_button(game)
			check(game.state == game.State.CASTING_OFF and game.hull == game.hull_capacity and game.enemy_encounters.encounter_index == 0 and not game.has_reading,
				"Play Again resets hull, navigation memory, and both duels")
	game.queue_free()
	await process_frame


func click_menu_button(game) -> void:
	await process_frame
	game.hud._sync_button()
	var center: Vector2 = game.hud.action_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = center
	press.global_position = center
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	root.push_input(release, true)
	await process_frame

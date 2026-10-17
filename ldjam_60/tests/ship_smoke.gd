extends SceneTree
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func make_game():
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.current_strength = 0.0
	game.gust_strength = 0.0
	game.enemy_encounters.triggers = [-1.0, 500.0]
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	# An open-water test arena beside the authored route, using the same game/physics.
	game.boat.position = game.course_right() * -85.0
	return game


func _run() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	var modes: Dictionary = {}
	var min_distance: float = INF
	var max_turn: float = 0.0
	var previous: float = 0.0
	var observed_shots: int = 0
	var observed_hits: int = 0
	for frame in range(1500):
		previous = ship.heading
		game.advance_sailing(1.0 / 60.0, 0.0)
		if frame > 0:
			max_turn = maxf(max_turn, absf(wrapf(ship.heading - previous, -PI, PI)))
		observed_shots = maxi(observed_shots, ship.shots_fired)
		observed_hits = maxi(observed_hits, ship.shots_hit)
		modes[ship.mode] = true
		if ship.age > 1.0:
			min_distance = minf(min_distance, ship.position.distance_to(game.boat.position))
		await physics_frame
	print("SHIP AI: modes=%s shots=%d hits=%d hull=%d min_range=%.1f max_turn_step=%.4f" % [modes.keys(), observed_shots, observed_hits, game.hull, min_distance, max_turn])
	check(modes.has(ship.Mode.APPROACH) and modes.has(ship.Mode.POSITION) and modes.has(ship.Mode.TELEGRAPH)
		and modes.has(ship.Mode.FIRE) and modes.has(ship.Mode.REPOSITION), "AI sails through Approach / Position / Telegraph / Fire / Reposition")
	check(max_turn <= ship.turning_speed / 60.0 + 0.001, "enemy turns gradually within its configured movement limit")
	check(min_distance > 9.0, "interception maintains separation instead of default ramming")
	check(observed_shots > 0 and game.hits_taken > 0, "non-homing enemy cannonballs can punish unchanged-course sailing")
	game.queue_free()
	await process_frame
	game = await make_game()
	ship = game.enemy_encounters.ship
	var dodged: bool = false
	for frame in range(1500):
		var steering: float = 0.0
		if ship.mode == ship.Mode.TELEGRAPH or not ship.projectiles.is_empty():
			steering = -0.75
			dodged = true
		game.advance_sailing(1.0 / 60.0, steering)
		await physics_frame
	check(ship.mode == ship.Mode.ESCAPED, "hostile disengages after a short encounter or successful escape")
	check(dodged and ship.shots_hit == 0 and game.hull == 3, "turning away from the warned firing line evades the duel without shooting")
	game.queue_free()
	await process_frame
	game = await make_game()
	ship = game.enemy_encounters.ship
	game.enemy_encounters.enabled = false
	ship.begin()
	ship.position = game.cannon.shot_origin() + game.cannon.starboard_direction() * 28.0
	ship.position.y = 0.0
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	ship.velocity = Vector3.ZERO
	ship.mode = ship.Mode.POSITION
	await physics_frame
	for attempt in range(2):
		game.cannon.cooldown = 0.0
		check(game.cannon.fire(), "broadside shot %d fires at the visible cutter" % (attempt + 1))
		for frame in range(50):
			game.cannon.advance(1.0 / 60.0)
			await physics_frame
	check(ship.hull == 0 and ship.mode == ship.Mode.SINKING, "two real projectile hits sink the configurable enemy hull")
	check(ship.collision_layer == 0 and ship.get_meta("destroyed"), "sinking immediately removes attack and target collision")
	for frame in range(240):
		ship.update_ship(1.0 / 60.0)
	check(ship.visual.position.y < -7.5, "enemy mast descends below the sea before the visual is removed")
	check(not ship.visible and ship.mode == ship.Mode.ESCAPED, "defeated cutter tilts and descends before removal")
	game.restart()
	check(game.enemy_encounters.encounter_index == 0 and ship.projectiles.is_empty(), "retry resets both interceptions and enemy cannonballs")
	game.queue_free()
	await process_frame
	print("SHIP CHECK: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

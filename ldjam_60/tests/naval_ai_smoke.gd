extends SceneTree

var checks := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failures += 1

func make_game():
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.hull_capacity = 30
	game.hull = 30
	game.boat.transform = Transform3D(Basis.IDENTITY, Vector3(310, 0, 342))
	game.heading = 0.0
	game.boat.velocity = Vector3.ZERO
	await physics_frame
	return game

func route(kind: String, hz: int) -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	ship.begin(game.arena_center() + Vector3(0, 0, -143))
	ship.heading = PI
	ship.rotation.y = -ship.heading
	await physics_frame
	var maximum_radius := 0.0
	var stopped := 0
	var longest_stop := 0
	var shore_frames := 0
	var maximum_step := 0.0
	var maximum_acceleration := 0.0
	var locked := true
	var nonhoming := true
	var warning_seen := false
	var minimum_distance := INF
	for frame in 65 * hz:
		var previous: Vector3 = ship.position
		var previous_rate: float = ship.turn_rate
		var telling: bool = ship.mode == ship.Mode.TELEGRAPH
		var point: Vector3 = ship.locked_point
		var velocity: Vector3 = ship.projectiles.front().velocity if not ship.projectiles.is_empty() else Vector3.ZERO
		game.sea_time += 1.0 / hz
		game.ocean.wave_time = game.sea_time
		game.damage_immunity = maxf(0.0, game.damage_immunity - 1.0 / hz)
		ship.update_ship(1.0 / hz)
		maximum_radius = maxf(maximum_radius, ship.position.distance_to(game.arena_center()))
		minimum_distance = minf(minimum_distance, ship.position.distance_to(game.boat.position))
		maximum_step = maxf(maximum_step, ship.position.distance_to(previous))
		maximum_acceleration = maxf(maximum_acceleration, absf(ship.turn_rate - previous_rate) * hz)
		stopped = stopped + 1 if ship.velocity.length() < 0.7 else 0
		longest_stop = maxi(longest_stop, stopped)
		if game.archipelago.get_node("Terrain").terrain_height_at(ship.position) > -1.0:
			shore_frames += 1
		if telling:
			warning_seen = true
			if ship.mode == ship.Mode.TELEGRAPH:
				locked = locked and ship.locked_point == point
		if velocity != Vector3.ZERO and not ship.projectiles.is_empty():
			var now: Vector3 = ship.projectiles.front().velocity
			nonhoming = nonhoming and Vector2(velocity.x, velocity.z).distance_to(Vector2(now.x, now.z)) < 0.001
		await physics_frame
	var result := {"kind": kind, "hz": hz, "max_radius": maximum_radius,
		"longest_stop": float(longest_stop) / hz, "shore_frames": shore_frames,
		"max_step": maximum_step, "shots": ship.shots_fired, "hits": ship.shots_hit,
		"warning_seen": warning_seen, "minimum_distance": minimum_distance, "distance": ship.position.distance_to(game.boat.position)}
	results.append(result)
	print("NAVAL ROUTE " + JSON.stringify(result))
	check(maximum_radius <= 165.001 and shore_frames == 0, kind + ": island/islet approach stays in navigable water inside the circle")
	check(float(longest_stop) / hz < 1.5, kind + ": blocked approaches recover without a prolonged stop")
	check(maximum_step <= ship.sailing_speed * 1.12 / hz + 0.01 and maximum_acceleration <= ship.turn_acceleration + 0.001,
		kind + ": obstacle and boundary recovery never teleports or snaps the rudder")
	check(ship.visible and ship.hull == ship.hull_capacity and ship.mode != ship.Mode.DISENGAGING,
		kind + ": no-fire elapsed time cannot sink, despawn or silently breach an arena attacker")
	check(locked and nonhoming, kind + ": terrain recovery never retargets a locked warning or launched shot")
	check(minimum_distance < 80.0, kind + ": a blocked approach eventually reaches the player instead of circling a remote edge")
	game.queue_free()
	await process_frame

func broadside(kind: String, dodge: bool) -> Dictionary:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	game.boat.position = Vector3(260, 0, 355)
	game.boat.velocity = Vector3.FORWARD * game.SPEED
	ship.begin(game.boat.position + Vector3(ship.broadside_separation, 0, -3))
	ship.heading = 0.0
	ship.rotation.y = 0.0
	await physics_frame
	var warning_seen := false
	var longest_warning := 0.0
	var warning_clock := 0.0
	var minimum_distance := INF
	for frame in 22 * 60:
		var steering := -0.7 if dodge and (ship.mode == ship.Mode.TELEGRAPH or not ship.projectiles.is_empty()) else 0.0
		if ship.mode == ship.Mode.TELEGRAPH:
			warning_seen = true
			warning_clock += 1.0 / 60.0
			longest_warning = maxf(longest_warning, warning_clock)
		else:
			warning_clock = 0.0
		game.advance_sailing(1.0 / 60.0, steering)
		ship.update_ship(1.0 / 60.0)
		minimum_distance = minf(minimum_distance, game.boat.position.distance_to(ship.position))
		await physics_frame
	var result := {"kind": kind, "dodge": dodge, "shots": ship.shots_fired,
		"hits": ship.shots_hit, "warning": longest_warning, "minimum_distance": minimum_distance}
	print("BROADSIDE " + JSON.stringify(result))
	check(warning_seen and ship.shots_fired > 0, kind + ": naturally moving attacker offers a visible warning and real broadside")
	check(minimum_distance > 12.0, kind + ": attack remains separated from the player")
	check(ship.hull == ship.hull_capacity and game.cannon.shots_fired == 0, kind + ": no-fire control never damages the attacker")
	game.queue_free()
	await process_frame
	return result

func _run() -> void:
	await route("cutter", 60)
	await route("skiff", 30)
	await route("heavy", 120)
	var stationary := await broadside("heavy", false)
	var dodged := await broadside("heavy", true)
	check(stationary.hits > 0 and dodged.hits < stationary.hits,
		"heavy: steering away from the longer warned line avoids real incoming fire")
	var output := FileAccess.open("/tmp/latitude-naval-ai.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("NAVAL AI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

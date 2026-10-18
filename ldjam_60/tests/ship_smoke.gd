extends SceneTree
## Movement, safety, real gun inputs/projectiles and encounter lifecycle.
var failures := 0
var checks := 0
var traces: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func make_game():
	var game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.wave_encounters.enabled = false
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	# A long open-water lane, clear of landmarks and the map boundary for 55 s.
	game.boat.position = Vector3(-425, 0, 320)
	game.heading = 0.0
	game.boat.rotation.y = 0.0
	game.boat.velocity = Vector3(0, 0, -game.SPEED)
	game._update_view(1.0 / 60.0)
	return game

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap() -> void:
	action("fire_starboard", true)
	action("fire_starboard", false)

func track_pass(fps: int) -> Dictionary:
	var game = await make_game()
	# Keep observing the whole encounter after unchanged-course fire would sink a player.
	game.hull_capacity = 20
	game.hull = 20
	var ship = game.enemy_encounters.ship
	ship.begin()
	var max_turn := 0.0
	var max_acceleration := 0.0
	var min_distance := INF
	var window := 0.0
	var best_window := 0.0
	var after_24 := false
	var max_shots := 0
	var modes := {}
	var trace: Array[Dictionary] = []
	var last_mode: int = -1
	for frame in range(46 * fps):
		var previous: float = ship.heading
		var rate: float = ship.turn_rate
		var at: Vector3 = ship.position
		game.advance_sailing(1.0 / fps, 0.0)
		max_turn = maxf(max_turn, absf(wrapf(ship.heading - previous, -PI, PI)) * fps)
		max_acceleration = maxf(max_acceleration, absf(ship.turn_rate - rate) * fps)
		min_distance = minf(min_distance, ship.position.distance_to(game.boat.position))
		check_no_teleport(at, ship.position, ship.sailing_speed * 1.13 / fps)
		var offset: Vector3 = ship.position - game.boat.position
		var shootable: bool = offset.x > 25.0 and offset.x < 45.0 and absf(offset.z) < offset.x * tan(deg_to_rad(30)) and ship.forward().dot(Vector3.FORWARD) > 0.98
		window = window + 1.0 / fps if shootable else 0.0
		best_window = maxf(best_window, window)
		max_shots = maxi(max_shots, ship.shots_fired)
		modes[ship.mode] = true
		if ship.age > 26.0 and ship.age < 27.0:
			after_24 = ship.visible and ship.hull == 2 and ship.mode != ship.Mode.DISENGAGING
		if ship.mode != last_mode:
			print("PHASE %d Hz t=%.2f mode=%d lateral=%.1f ahead=%.1f heading=%.2f" % [fps, ship.age, ship.mode, offset.x, -offset.z, ship.heading])
			last_mode = ship.mode
		if frame % (fps / 2) == 0:
			trace.append({"time": ship.age, "x": ship.position.x, "z": ship.position.z, "heading": ship.heading, "mode": ship.mode})
		await physics_frame
	check(after_24, "%d Hz: undamaged engaging cutter remains visible beyond 24 seconds" % fps)
	check(max_turn <= ship.turning_speed + 0.001 and max_acceleration <= ship.turn_acceleration + 0.001, "%d Hz: heading and rudder acceleration remain bounded" % fps)
	check(best_window >= 4.0, "%d Hz: sustained 25–45 m starboard window inside the real ±30° sweep (%.2fs)" % [fps, best_window])
	check(ship.passes >= 2 and modes.has(ship.Mode.REPOSITION), "%d Hz: complete first attack run, turn and second broadside (%d passes)" % [fps, ship.passes])
	check(min_distance > 18.0, "%d Hz: no point-blank pass or collision (minimum %.2fm)" % [fps, min_distance])
	check(max_shots >= 2 and ship.shots_hit > 0 and game.hits_taken > 0, "%d Hz: unchanged-course player is punished by real non-homing shots" % fps)
	check(ship.hull == 2 and game.cannon.targets_hit == 0, "%d Hz: elapsed time alone never damages the enemy" % fps)
	var result := {"fps": fps, "position": [ship.position.x, ship.position.z], "heading": ship.heading, "passes": ship.passes, "window": best_window, "shots": max_shots, "hits": ship.shots_hit, "trace": trace}
	traces.append(result)
	game.queue_free()
	await process_frame
	return result

func check_no_teleport(before: Vector3, after: Vector3, limit: float) -> void:
	if before.distance_to(after) > limit + 0.001:
		check(false, "active cutter never teleports")

func dodge() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.begin()
	var dodged := false
	var fixed_lock := true
	var fixed_ball := true
	for frame in range(25 * 60):
		var steering := 0.0
		if ship.mode == ship.Mode.TELEGRAPH or not ship.projectiles.is_empty():
			steering = -0.75
			dodged = true
		var was_telling: bool = ship.mode == ship.Mode.TELEGRAPH
		var locked: Vector3 = ship.locked_point
		var shot_velocity: Vector3 = ship.projectiles[0].velocity if not ship.projectiles.is_empty() else Vector3.ZERO
		game.advance_sailing(1.0 / 60.0, steering)
		if was_telling and ship.mode == ship.Mode.TELEGRAPH:
			fixed_lock = fixed_lock and ship.locked_point == locked
		if shot_velocity != Vector3.ZERO and not ship.projectiles.is_empty():
			var now: Vector3 = ship.projectiles[0].velocity
			fixed_ball = fixed_ball and Vector2(now.x, now.z).distance_to(Vector2(shot_velocity.x, shot_velocity.z)) < 0.001
		await physics_frame
	check(dodged and ship.shots_fired > 0 and ship.shots_hit == 0 and game.hull == 3, "steering off the telegraph dodges fired cannonballs without shooting")
	check(fixed_lock and fixed_ball, "warning point and launched horizontal velocity never home after player steering")
	game.queue_free()
	await process_frame

func real_duel() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.begin()
	var entered := false
	for frame in range(30 * 60):
		if ship.hull <= 0 or game.state != game.State.SAILING:
			break
		if ship.passes > 0 and not entered:
			action("watch_starboard", true)
			entered = true
		if game.cannon.aiming and game.cannon.cooldown <= 0.0:
			# A timing observer presses F; barrel direction and projectile physics are untouched.
			var offset: Vector3 = ship.to_global(Vector3(0, 1, -1.8)) - game.cannon.shot_origin()
			var flight: float = offset.length() / game.cannon.SHOT_SPEED
			var travel: Vector3 = (game.cannon.aimed_direction() * game.cannon.SHOT_SPEED + Vector3.UP * 0.35) * flight - Vector3.UP * 0.45 * flight * flight
			if (travel - offset - ship.velocity * flight).length() < 2.6:
				tap()
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
	check(entered and game.cannon.shots_fired == 2 and game.cannon.targets_hit == 2 and ship.hull == 0, "two F-fired cannonballs sink the naturally moving cutter without moving it into the shot")
	check(ship.mode == ship.Mode.SINKING and ship.collision_layer == 0 and ship.get_meta("destroyed"), "sinking clears attacks and target collision immediately")
	for frame in range(212):
		ship.update_ship(1.0 / 60.0)
	check(ship.visual.position.y < -7.5 and not ship.visible and ship.mode == ship.Mode.ESCAPED, "original tilt/descent completes before defeated-ship cleanup")
	game.restart()
	check(ship.mode == ship.Mode.DORMANT and ship.projectiles.is_empty() and ship.visual.transform == Transform3D.IDENTITY and ship.turn_rate == 0.0 and ship.velocity == Vector3.ZERO and ship.age == 0.0, "retry resets visual, rudder, velocity, clocks and enemy projectiles")
	check(game.cannon.projectiles.is_empty() and game.cannon.effects.is_empty() and game.enemy_encounters.visited.is_empty(), "retry resets player shots/effects and authored patrol visits")
	ship.begin()
	check(ship.visible and ship.hull == 2 and ship.passes == 0 and ship.visual.position.y == 0.0 and ship.shots_fired == 0, "reused cutter begins fresh above water after sinking/retry")
	game.queue_free()
	await process_frame

func retreat() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + Vector3(34, 0, 0))
	ship.disengage()
	var at: Vector3 = ship.position
	check(ship.visible and ship.mode == ship.Mode.DISENGAGING and ship.collision_layer == 4 and not ship.get_meta("destroyed"), "disengagement starts a visible, hittable sail-away instead of hiding")
	var no_shots := true
	for frame in range(45 * 60):
		ship.update_ship(1.0 / 60.0)
		no_shots = no_shots and ship.shots_fired == 0
		if ship.mode == ship.Mode.ESCAPED:
			break
		await physics_frame
	check(ship.mode == ship.Mode.ESCAPED and not ship.visible and ship.position.distance_to(at) > 100.0 and ship.position.distance_to(game.boat.position) > ship.cleanup_distance, "retreat physically opens a safe distance before cleanup")
	check(no_shots, "retreat cancels attack windups and never fires")
	# Prior cannonballs must drain before another authored patrol can reuse this hull.
	ship.begin(game.boat.position + Vector3(40, 0, 0))
	ship.locked_point = game.boat.position + Vector3(160, 0, -100)
	ship._fire()
	ship.take_hit()
	ship.take_hit()
	for frame in range(216):
		ship.update_ship(1.0 / 60.0)
		await physics_frame
	game.enemy_encounters.visited.clear()
	game.elapsed = 9.0
	game.voyage.stage = 0
	game.boat.position = Vector3(-30, 0, 100)
	game.heading = PI / 2
	game.enemy_encounters.update_encounters(0.01)
	check(game.enemy_encounters.encounter_index == 0 and not ship.projectiles.is_empty(), "next encounter cannot reset an in-flight previous broadside")
	ship.projectiles[0].ttl = 0.0
	game.enemy_encounters.update_encounters(0.01)
	check(game.enemy_encounters.encounter_index == 1 and ship.mode == ship.Mode.APPROACH and ship.projectiles.is_empty(), "next authored patrol starts once prior visuals and projectiles are clear")
	var right := Vector3(cos(game.heading), 0, sin(game.heading))
	check((ship.position - game.boat.position).dot(right) > 40.0, "authored patrol prefers an open-water starboard spawn")
	game.queue_free()
	await process_frame

func boundaries() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.age = ship.encounter_seconds - 0.01
	ship.update_ship(0.02)
	check(ship.mode == ship.Mode.DISENGAGING and ship.visible, "55-second budget begins a retreat while the cutter stays visible")
	ship.begin()
	game.boat.position += Vector3(0, 0, -300)
	for frame in range(10 * 60):
		ship.update_ship(1.0 / 60.0)
		await physics_frame
	check(ship.mode in [ship.Mode.DISENGAGING, ship.Mode.ESCAPED], "sustained genuine player escape initiates retreat without teleporting")
	game.queue_free()
	await process_frame

func safety() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	# A real authored shore: sail east into the western face of the central island.
	ship.begin(Vector3(-150, 0, 0))
	ship.heading = PI / 2
	ship.rotation.y = -ship.heading
	ship.run_heading = PI / 2
	game.boat.position = Vector3(-145, 0, 70)
	var terrain = game.archipelago.get_node("Terrain")
	var min_depth := -INF
	var travelled := 0.0
	var sign_changes := 0
	var last_sign := 0.0
	for frame in range(15 * 60):
		var at: Vector3 = ship.position
		ship.update_ship(1.0 / 60.0)
		travelled += ship.position.distance_to(at)
		min_depth = maxf(min_depth, terrain.terrain_height_at(ship.position))
		if absf(ship.turn_rate) > 0.1:
			var side: float = signf(ship.turn_rate)
			if last_sign != 0 and side != last_sign:
				sign_changes += 1
			last_sign = side
		await physics_frame
	check(min_depth < -2.5 and travelled > 45.0, "shore feelers keep the moving cutter in water without getting stuck (height %.2f, travel %.1f)" % [min_depth, travelled])
	check(sign_changes < 6, "shore avoidance holds a decision instead of oscillating every frame (%d reversals/15s)" % sign_changes)
	ship.begin(game.boat.position + Vector3(22, 0, 15))
	ship.heading = PI
	ship.rotation.y = -ship.heading
	var closest := INF
	for frame in range(5 * 60):
		ship.update_ship(1.0 / 60.0)
		closest = minf(closest, ship.position.distance_to(game.boat.position))
		await physics_frame
	check(closest > 12.0 and ship.shots_fired == 0, "predicted close pass yields rather than ramming or firing point-blank (%.1fm)" % closest)
	game.queue_free()
	await process_frame

func _run() -> void:
	var slow := await track_pass(30)
	var fast := await track_pass(60)
	var a := Vector2(slow.position[0], slow.position[1])
	var b := Vector2(fast.position[0], fast.position[1])
	check(a.distance_to(b) < 2.0 and absf(wrapf(slow.heading - fast.heading, -PI, PI)) < 0.1 and slow.passes == fast.passes, "30/60 Hz courses agree within 2m / 0.1rad and complete the same passes (%.3fm)" % a.distance_to(b))
	await dodge()
	await real_duel()
	await retreat()
	await boundaries()
	await safety()
	var report := FileAccess.open("/tmp/latitude-enemy-motion.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(traces, "\t"))
	print("SHIP CHECK: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

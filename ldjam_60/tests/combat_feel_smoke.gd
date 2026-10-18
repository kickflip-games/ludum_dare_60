extends SceneTree

const Pilot = preload("res://tests/cannon_sweep_pilot.gd")
const KINDS := ["cutter", "skiff", "heavy"]
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
	game.wave_encounters.enabled = false
	game.enemy_encounters.next_wave_in = 9999.0
	if game.enemy_encounters.has_method("_begin_wave"):
		game.enemy_encounters.phase = game.enemy_encounters.Phase.STOPPED
	game.boat.transform = Transform3D(Basis.IDENTITY, Vector3(310, 0, 342))
	game.heading = 0.0
	game.boat.velocity = Vector3.FORWARD * game.SPEED
	game._update_view(1.0)
	await physics_frame
	return game

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for name in ["watch_starboard", "fire_starboard", "steer_port", "steer_starboard"]:
		action(name, false)

func profile_hits() -> void:
	for kind in KINDS:
		var game = await make_game()
		game.enemy_encounters.enabled = false
		var ship = game.enemy_encounters.ship
		var profile = load("res://game/enemies/" + kind + ".tres")
		ship.configure_archetype(profile)
		ship.begin(game.boat.position + Vector3(30, 0, 0))
		check(ship.hull == profile.hull and ship.presentation.scale.is_equal_approx(Vector3.ONE * profile.size), kind + ": profile owns hull, scale and shared scene")
		check(ship.sailing_speed == profile.speed and ship.turning_speed == profile.turn_speed and ship.telegraph_seconds >= 1.65, kind + ": data-driven movement and fair warning")
		action("watch_starboard", true)
		game._physics_process(1.0 / 60.0)
		var at: Vector3 = game.cannon.shot_origin() + game.cannon.aimed_direction() * 30.0
		ship.position = Vector3(at.x, 0, at.z)
		ship.rotation.y = 0.0
		await physics_frame
		for frame in 120:
			game.cannon.advance(1.0 / 60.0)
		check(ship.hull == profile.hull and game.cannon.targets_hit == 0, kind + ": idle cannon sweep cannot cause a hit")
		var accurate := true
		for hit_index in profile.hull:
			game.cannon.update_aim(0.0)
			var direction: Vector3 = game.cannon.aimed_direction()
			action("fire_starboard", true)
			game.cannon.update_aim(0.0)
			action("fire_starboard", false)
			var velocity: Vector3 = game.cannon.projectiles.back().velocity
			accurate = accurate and velocity.is_equal_approx(direction * game.cannon.SHOT_SPEED + Vector3.UP * 0.35)
			for frame in 100:
				game.cannon.advance(1.0 / 60.0)
			check(ship.hull == profile.hull - hit_index - 1 and game.cannon.targets_hit == hit_index + 1,
				kind + ": real Space-fired ballistic hit %d has the expected hull effect" % (hit_index + 1))
			check(ship.hit_reaction > 0.45 and ship.sail_material.emission_energy_multiplier > profile.sail_fill + 0.4,
				kind + ": accepted hit immediately flashes the cloth")
		check(accurate, kind + ": illumination never redirects the rocking muzzle's launch vector")
		check(ship.mode == ship.Mode.SINKING and ship.get_meta("destroyed") and not ship.aim_highlight and ship.collision_layer == 0,
			kind + ": death cancels target illumination, collision and attacks")
		var accepted: int = game.cannon.targets_hit
		game.cannon._impact(ship, ship.position)
		check(game.cannon.targets_hit == accepted, kind + ": a sinking hull cannot award duplicate confirmed hits")
		var sinking_y: float = ship.visual.position.y
		for frame in 120:
			ship.update_ship(1.0 / 60.0)
		check(ship.visible and ship.visual.position.y < sinking_y - 4.5 and ship.visual.rotation.z > 0.3,
			kind + ": sinking is a visible tilted descent, not instant cleanup")
		for frame in 100:
			ship.update_ship(1.0 / 60.0)
		check(not ship.visible and ship.mode == ship.Mode.ESCAPED, kind + ": cleanup follows complete submersion")
		release()
		game.restart()
		check(not ship.aim_highlight and game.cannon.effects.is_empty() and ship.hit_reaction == 0.0,
			kind + ": retry clears feedback, illumination and transient effects")
		game.queue_free()
		await process_frame

func illumination() -> void:
	var game = await make_game()
	game.enemy_encounters.enabled = false
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(game.boat.position + Vector3(36, 0, -5))
	await physics_frame
	check(not ship.aim_highlight, "no target glow in normal helm view")
	action("watch_starboard", true)
	game._physics_process(1.0 / 60.0)
	game._update_view(1.0)
	game.cannon.update_aim(0.0)
	ship.position = game.cannon.shot_origin() + game.cannon.aimed_direction() * 30.0
	ship.position.y = 0.0
	await physics_frame
	check(game.cannon.predict_trajectory().enemy, "barrel trajectory intersects the enemy hull")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5, 20, 12)
	collision.shape = shape
	blocker.add_child(collision)
	game.add_child(blocker)
	blocker.position = game.cannon.shot_origin().lerp(ship.position, 0.5)
	await physics_frame
	check(not game.cannon.predict_trajectory().enemy, "solid obstruction stops the indicator before the enemy")
	blocker.queue_free()
	await physics_frame
	ship.position = game.boat.position + Vector3(-36, 0, -5)
	await physics_frame
	check(not game.cannon.predict_trajectory().enemy, "port-side enemy cannot colour the starboard trajectory")
	ship.position = game.boat.position + Vector3(110, 0, -5)
	await physics_frame
	check(not game.cannon.predict_trajectory().enemy, "beyond-lifetime target cannot colour the trajectory")
	ship.position = game.cannon.shot_origin() + game.cannon.aimed_direction() * 30.0
	ship.position.y = 0.0
	ship.take_hit()
	ship.take_hit()
	await physics_frame
	check(not game.cannon.predict_trajectory().enemy, "sinking hull no longer intercepts the trajectory")
	check(not ship.aim_highlight, "no broad-sector glow or targeting boxes in continuous chase view")
	release()
	game.queue_free()
	await process_frame

func duel(kind: String, choppy: bool) -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	ship.begin(game.boat.position + Vector3(ship.broadside_separation, 0, -4))
	if choppy:
		game.ocean.wave_field.add_wave(Vector2(286, 323), Vector2.RIGHT, 0.85, 4.5, 35.0, 8.0, 0.0, 9.0)
	var pilot := Pilot.new()
	var maximum_turn := 0.0
	var maximum_acceleration := 0.0
	var maximum_jump := 0.0
	var locked := true
	var nonhoming := true
	var maximum_wave_yaw := 0.0
	var maximum_drift := 0.0
	for frame in 60 * 60:
		if ship.hull <= 0 or game.state != game.State.SAILING:
			break
		if not choppy or frame >= 300:
			pilot.update(game, 1.0 / 60.0)
		var previous: Vector3 = ship.position
		var rate: float = ship.turn_rate
		var was_telling: bool = ship.mode == ship.Mode.TELEGRAPH
		var point: Vector3 = ship.locked_point
		var old_velocity: Vector3 = ship.projectiles.front().velocity if not ship.projectiles.is_empty() else Vector3.ZERO
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		maximum_turn = maxf(maximum_turn, absf(ship.turn_rate))
		maximum_acceleration = maxf(maximum_acceleration, absf(ship.turn_rate - rate) * 60.0)
		maximum_jump = maxf(maximum_jump, ship.position.distance_to(previous))
		maximum_wave_yaw = maxf(maximum_wave_yaw, absf(game.wave_sailing.yaw_rate))
		maximum_drift = maxf(maximum_drift, game.wave_sailing.drift.length())
		if was_telling and ship.mode == ship.Mode.TELEGRAPH:
			locked = locked and ship.locked_point == point
		if old_velocity != Vector3.ZERO and not ship.projectiles.is_empty():
			var new_velocity: Vector3 = ship.projectiles.front().velocity
			nonhoming = nonhoming and Vector2(old_velocity.x, old_velocity.z).distance_to(Vector2(new_velocity.x, new_velocity.z)) < 0.001
		await physics_frame
	var result := {"kind": kind, "choppy": choppy, "seconds": snappedf(game.elapsed, 0.01),
		"shots": game.cannon.shots_fired, "hits": game.cannon.targets_hit, "enemy_hull": ship.hull,
		"player_hull": game.hull, "passes": ship.passes, "helm_exits": pilot.steering_exits,
		"max_turn": maximum_turn, "max_acceleration": maximum_acceleration, "max_step": maximum_jump,
		"max_wave_yaw": maximum_wave_yaw, "max_drift": maximum_drift}
	results.append(result)
	print("DUEL " + JSON.stringify(result))
	check(ship.hull == 0 and game.hull > 0 and game.cannon.targets_hit >= ship.hull_capacity,
		kind + ": input-only timing pilot sinks the naturally moving ship with required actual hits")
	check(maximum_turn <= ship.turning_speed + 0.001 and maximum_acceleration <= ship.turn_acceleration + 0.001,
		kind + ": turning velocity and acceleration stay bounded during combat")
	check(maximum_jump <= ship.sailing_speed * 1.12 / 60.0 + 0.01, kind + ": live ship never teleports")
	check(locked and nonhoming, kind + ": warnings stay locked and cannonballs never home")
	if choppy:
		check(maximum_wave_yaw > 0.03 and maximum_drift > 0.2,
			"skiff: successful aiming follows a real crest-induced yaw/drift disturbance, not a calm fixture")
	pilot.release()
	game.queue_free()
	await process_frame

func _run() -> void:
	await profile_hits()
	await illumination()
	await duel("cutter", false)
	await duel("skiff", true)
	await duel("heavy", false)
	rudder_response()
	await combat_crests()
	var output := FileAccess.open("/tmp/latitude-combat-duels.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("COMBAT FEEL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func rudder_response() -> void:
	var sailing = load("res://game/ocean/wave_sailing.gd").new()
	var baseline = load("res://game/ocean/wave_sailing.gd").new()
	var field = load("res://game/ocean/wave_field.gd").new()
	sailing.rudder_response = 9.0
	var heading := 0.0
	var old_heading := 0.0
	for frame in 12:
		heading = sailing.step(field, Vector2.ZERO, heading, 1.0, (frame + 1.0) / 60.0, 1.0 / 60.0)
		old_heading = baseline.step(field, Vector2.ZERO, old_heading, 1.0, (frame + 1.0) / 60.0, 1.0 / 60.0)
	check(sailing.rudder_rate > baseline.rudder_rate + 0.04 and sailing.rudder_rate < 0.72,
		"arena rudder responds sooner without changing maximum turn authority or adding instant rotation")
	for frame in 30:
		heading = sailing.step(field, Vector2.ZERO, heading, 0.0, 0.2 + (frame + 1.0) / 60.0, 1.0 / 60.0)
	check(sailing.rudder_rate > 0.0 and sailing.rudder_rate < 0.01 and sailing.drift == Vector2.ZERO and sailing.yaw_rate == 0.0,
		"released helm settles smoothly with no hidden drift, yaw or current")
	field.add_wave(Vector2(-24, 0), Vector2.RIGHT, 0.9, 4.5, 24.0, 8.0, 0.0, 8.0)
	sailing.reset()
	baseline.reset()
	sailing._integrate_forces(field, Vector2.ZERO, 0.0, 0.0, 3.0, 1.0 / 60.0)
	baseline._integrate_forces(field, Vector2.ZERO, 0.0, 0.0, 3.0, 1.0 / 60.0)
	check(absf(sailing.drift.length() / baseline.drift.length() - 1.0) < 0.001
		and absf(sailing.yaw_rate / baseline.yaw_rate - 1.0) < 0.001,
		"arcade rudder response preserves the existing wave drift and yaw forces")

func combat_crests() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	game.boat.position = game.arena_center() + Vector3(0, 0, 150)
	game.boat.velocity = Vector3.FORWARD * game.SPEED
	ship.begin(game.arena_center() + Vector3(90, 0, 80))
	game.wave_encounters.enabled = true
	game.wave_encounters.next_event = 0.0
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	game.wave_encounters.update(game, 1.0 / 60.0)
	check(game.ocean.wave_field.waves.is_empty(), "existing combat gate still defers new crests during a battle")
	game.cannon.set_aim_held(false)
	ship.reset()
	game.wave_encounters.next_event = 0.0
	game.wave_encounters.update(game, 1.0 / 60.0)
	check(game.ocean.wave_field.waves.size() == 1 and game.ocean.wave_field.waves.front().height <= 0.6,
		"quiet water outside shelter can launch one existing small seeded crest")
	var wave: Dictionary = game.ocean.wave_field.waves.front()
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	game.sea_time = 2.0
	game.wave_encounters.update(game, 1.0 / 60.0)
	var crest: Vector2 = wave.origin + wave.direction * wave.speed * 2.0
	check(game.ocean.wave_field.waves.size() == 1 and game.ocean.wave_field.sample(crest, 2.0).x > 0.2,
		"continuous cannon sweep never erases or freezes an already visible wave")
	game.ocean.wave_field.clear()
	game.cannon.set_aim_held(false)
	game.boat.position = game.arena_center() + Vector3(0, 0, 75)
	game.wave_encounters.next_event = 0.0
	game.wave_encounters.update(game, 1.0 / 60.0)
	check(game.ocean.wave_field.waves.is_empty(), "inner lighthouse shelter stays calm even during combat")
	game.queue_free()
	await process_frame

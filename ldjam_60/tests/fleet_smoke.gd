extends SceneTree

const Pilot = preload("res://tests/combat_arena_pilot.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + label)

func make_game(count: int):
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	var config = game.enemy_encounters.survival_settings
	var roster := PackedStringArray()
	for index in count:
		roster.append("cutter")
	config.wave_rosters[0] = roster
	config.deadlines[0] = 1000.0
	config.spawn_interval = 0.5
	config.attack_slots[0] = 1 if count <= 2 else 2
	return game

func sail_orbit(game, pilot) -> void:
	var radial: Vector3 = game.boat.position - game.arena_center()
	var desired := atan2(radial.x, -radial.z) + PI / 2.0 + clampf((radial.length() - 138.0) * 0.04, -0.5, 0.5)
	pilot.helm(wrapf(desired - game.heading, -PI, PI) * 3.0)

func sustain(count: int, hz: int, seconds: int = 180) -> void:
	Engine.physics_ticks_per_second = hz
	var game = await make_game(count)
	game.hull_capacity = 100
	game.hull = 100
	game.boat.position = game.arena_center() + Vector3(0, 0, -138)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	var pilot := Pilot.new()
	var manager = game.enemy_encounters
	var peak := 0
	var slot_peak := 0
	var attack_peak := 0
	var valid_slots := true
	var visible_alive := true
	var minimum_separation := INF
	var minimum_clearance := INF
	var maximum_radius := 0.0
	var maximum_turn := 0.0
	var maximum_step := 0.0
	var grounded := false
	var holding_travel := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var longest_stop := 0.0
	var stopped := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var trace: Array[Dictionary] = []
	var state_seconds := {}
	var range_seconds := {}
	var shot_times := {}
	var last_shots := {}
	for frame in seconds * hz:
		var before: Array[Dictionary] = []
		for ship in manager.ships:
			before.append({"position": ship.position, "heading": ship.heading, "alive": ship.visible})
		game._window_focused = true
		sail_orbit(game, pilot)
		game._physics_process(1.0 / hz)
		game.cannon.advance(1.0 / hz)
		var living: Array = manager.living_ships()
		peak = maxi(peak, living.size())
		slot_peak = maxi(slot_peak, manager.director.owners.size())
		var attacking: Array = living.filter(func(ship): return ship.navigation_state == ship.Navigation.ATTACK_RUN)
		attack_peak = maxi(attack_peak, attacking.size())
		valid_slots = valid_slots and manager.director.owners.size() <= manager.director.slot_limit()
		valid_slots = valid_slots and attacking.all(func(ship): return manager.director.owners.has(ship))
		var snapshot: Array[Dictionary] = []
		for ship in living:
			var index: int = manager.ships.find(ship)
			var key := "%d:%d" % [index, ship.navigation_state]
			state_seconds[key] = state_seconds.get(key, 0.0) + 1.0 / hz
			if ship.position.distance_to(game.boat.position) < ship.firing_range:
				range_seconds[index] = range_seconds.get(index, 0.0) + 1.0 / hz
			if ship.shots_fired > last_shots.get(index, 0):
				if not shot_times.has(index): shot_times[index] = []
				shot_times[index].append(game.elapsed)
			last_shots[index] = ship.shots_fired
			var previous: Dictionary = before[index]
			var radius: float = ship.position.distance_to(game.arena_center())
			maximum_radius = maxf(maximum_radius, radius)
			visible_alive = visible_alive and ship.visible and ship.collision_layer == 4 and not ship.get_meta("destroyed")
			grounded = grounded or game.archipelago.get_node("Terrain").terrain_height_at(ship.position) > -1.0
			if previous.alive:
				maximum_turn = maxf(maximum_turn, absf(wrapf(ship.heading - previous.heading, -PI, PI)) * hz)
				maximum_step = maxf(maximum_step, ship.position.distance_to(previous.position) * hz)
				if ship.navigation_state == ship.Navigation.HOLDING:
					holding_travel[index] += ship.position.distance_to(previous.position)
			stopped[index] = stopped[index] + 1.0 / hz if ship.velocity.length() < 0.7 else 0.0
			longest_stop = maxf(longest_stop, stopped[index])
			if frame % (hz / 2) == 0:
				snapshot.append({"id": ship.get_meta("enemy_id"), "x": ship.position.x, "z": ship.position.z,
					"heading": ship.heading, "navigation": ship.navigation_state, "weapon": ship.weapon_state,
					"slot": manager.director.owners.has(ship), "radius": radius, "collisions": ship.collisions})
		for first_index in living.size():
			for second_index in range(first_index + 1, living.size()):
				var first = living[first_index]
				var second = living[second_index]
				minimum_separation = minf(minimum_separation, first.position.distance_to(second.position))
				minimum_clearance = minf(minimum_clearance, first.collision_shape.global_position.distance_to(second.collision_shape.global_position) - first.collision_shape.shape.radius - second.collision_shape.shape.radius)
		if not snapshot.is_empty():
			trace.append({"seconds": game.elapsed, "ships": snapshot})
		await physics_frame
	pilot.release()
	var warning_gaps := true
	var history: Array = manager.director.warning_history
	for index in range(1, history.size()):
		warning_gaps = warning_gaps and history[index].seconds - history[index-1].seconds >= manager.survival_settings.warning_interval - 0.001
	var identities := {}
	for identity in manager.director.assignments:
		identities[identity] = true
	var collision_count := 0
	for ship in manager.ships:
		collision_count += ship.collisions
	var metrics := {"count": count, "hz": hz, "seconds": seconds, "peak": peak, "slot_peak": slot_peak,
		"attack_peak": attack_peak, "minimum_separation": minimum_separation if count > 1 else null, "minimum_clearance": minimum_clearance if count > 1 else null,
		"max_radius": maximum_radius, "max_turn": maximum_turn, "max_speed": maximum_step,
		"longest_stop": longest_stop, "holding_travel": holding_travel, "collisions": collision_count,
		"assignments": manager.director.assignments.duplicate(), "warnings": history.duplicate(true),
		"state_seconds": state_seconds, "range_seconds": range_seconds, "shot_times": shot_times,
		"shots":manager.ships.reduce(func(total, s): return total + s.shots_fired, 0),
		"salvos":manager.ships.reduce(func(total, s): return total + s.salvos_fired, 0),
		"cancelled":manager.ships.reduce(func(total, s): return total + s.cancelled_shots, 0),
		"hits":game.hits_taken, "cannon_hits":manager.ships.reduce(func(total, s): return total + s.shots_hit, 0)}
	print("FLEET TRACE " + JSON.stringify(metrics))
	check(peak == count and living_count(manager) == count and visible_alive, "%d ships/%d Hz: all living ships persist, visible and hittable" % [count, hz])
	check(valid_slots and slot_peak == manager.director.slot_limit() and attack_peak <= 2, "%d ships: approaches/runs obey attack-slot ownership" % count)
	check(identities.size() == count, "%d ships: fair queue gives every ship a turn" % count)
	check(count == 1 or holding_travel.slice(0, count).all(func(distance): return distance > 15.0), "%d ships: waiting hulls sail real holding routes" % count)
	check(maximum_radius <= 165.01 and not grounded and longest_stop < 2.5, "%d ships: terrain and circle recovery never leave an unreachable hull" % count)
	check(maximum_turn <= manager.survival_settings.ARCHETYPES.cutter.turn_speed + 0.001
		and maximum_step <= manager.survival_settings.ARCHETYPES.cutter.speed * 1.12 + 0.01,
		"%d ships: no heading snaps, reversals or teleporting" % count)
	check(count == 1 or (minimum_clearance > -0.1 and collision_count <= count * 5), "%d ships: route crossings stay within 10 cm contact tolerance and at most five contacts per hull" % count)
	check(warning_gaps and (count == 1 or identities.size() > 1), "%d ships: separate warning starts obey the global stagger" % count)
	check(game.cannon.shots_fired == 0 and manager.ships_sunk == 0, "%d ships: no-fire control cannot earn wave kills" % count)
	results.append({"metrics": metrics, "trace": trace})
	game.restart()
	check(manager.director.owners.is_empty() and manager.director.waiting.is_empty() and manager.director.warning_history.is_empty()
		and manager.ships.size() == 6 and manager.living_ships().is_empty() and not manager.has_projectiles()
		and manager.ships.all(func(ship): return ship.visual.transform == Transform3D.IDENTITY and ship.navigation_state == ship.Navigation.DORMANT),
		"%d ships: retry clears all six pooled ships, slots, warnings, projectiles and transforms" % count)
	game.queue_free()
	await process_frame

func living_count(manager) -> int:
	return manager.living_ships().size()

func _run() -> void:
	if "--pressure" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("/tmp/blackwater-pressure")
		for hz in [30, 60]:
			Engine.physics_ticks_per_second = hz
			await sustain(4, hz, 90)
			var measured: Dictionary = results.back().metrics
			check(measured.salvos >= 3 and measured.cannon_hits > 0, "%d Hz: a sustained fleet launches repeated physical volleys and hits the player" % hz)
		var file := FileAccess.open("/tmp/blackwater-pressure/fleet-pressure.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "\t"))
		print("FLEET PRESSURE: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	for count in [1, 2, 4, 6]:
		await sustain(count, 60)
	await sustain(6, 30)
	var output := FileAccess.open("/tmp/latitude-fleet.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("FLEET CHECK: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

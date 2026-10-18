extends "res://tests/fleet_smoke.gd"

func staged_ship(game, index: int, at: Vector3):
	var manager = game.enemy_encounters
	var ship = manager.ships[index]
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(at, true)
	ship.set_meta("wave_id", 1)
	ship.set_meta("enemy_id", index + 1)
	manager.director.register(ship)
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	return ship

func simultaneous_runs() -> void:
	var game = await make_game(2)
	var manager = game.enemy_encounters
	manager.phase = manager.Phase.STOPPED
	manager.survival_settings.attack_slots[0] = 2
	game.boat.position = Vector3(215, 0, 325)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	var first = staged_ship(game, 0, game.boat.position + Vector3(-9, 0, 28))
	var second = staged_ship(game, 1, game.boat.position + Vector3(9, 0, 44))
	first.navigation_time = 1.0
	second.navigation_time = 1.0
	manager.director.update(1.0)
	for ship in [first, second]:
		ship.receive_attack_slot()
		ship.passes = 1
		ship._change_navigation(ship.Navigation.ATTACK_RUN)
	var peak := 0
	var committed := true
	var initial_target = manager.focus_ship()
	var stable_focus := true
	for frame in 5 * 60:
		var locks: Array[Vector3] = [first.locked_point, second.locked_point]
		var weapons: Array[int] = [first.weapon_state, second.weapon_state]
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		peak = maxi(peak, manager.living_ships().filter(func(ship): return ship.navigation_state == ship.Navigation.ATTACK_RUN).size())
		for index in 2:
			var ship = [first, second][index]
			if weapons[index] == ship.Weapon.TELEGRAPH and ship.weapon_state == ship.Weapon.TELEGRAPH:
				committed = committed and locks[index] == ship.locked_point
		if frame < 120:
			stable_focus = stable_focus and manager.focus_ship() == initial_target
		await physics_frame
	var history: Array = manager.director.warning_history
	check(peak == 2 and manager.director.owners.size() == 2, "two distinct ships can run parallel attacks under two owned slots")
	check(history.size() >= 2 and history[1].seconds - history[0].seconds >= 1.599,
		"simultaneous valid broadsides start warnings at least 1.6 seconds apart")
	check(first.shots_fired == 1 and second.shots_fired == 1 and committed,
		"both staggered warnings commit to fixed points and launch real non-homing shots")
	check(stable_focus, "combat focus remains stable during a nearby two-ship pass")
	results.append({"alternating_warnings": history.duplicate(true), "shots": [first.shots_fired, second.shots_fired]})
	game.queue_free()
	await process_frame

func holding_target(index: int) -> void:
	var game = await make_game(6)
	var manager = game.enemy_encounters
	manager._begin_wave()
	manager.records[0].spawned = 6
	manager.spawn_queue.clear()
	manager.phase = manager.Phase.STOPPED
	manager.enabled = false
	game.boat.position = Vector3(215, 0, 325)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	var target = staged_ship(game, index, game.boat.position + Vector3(0, 0, 34))
	for other_index in 6:
		if other_index == index:
			continue
		var angle := -PI * 0.7 + other_index * PI / 7.0
		staged_ship(game, other_index, game.arena_center() + Vector3(sin(angle), 0, -cos(angle)) * 143.0)
	manager.ship = target
	var pilot = load("res://tests/cannon_sweep_pilot.gd").new()
	var never_owned := true
	for frame in 15 * 60:
		if target.hull <= 0 or game.state != game.State.SAILING:
			break
		pilot.update(game, 1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
		for ship in manager.ships:
			ship.update_ship(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		never_owned = never_owned and not manager.director.owners.has(target)
		await physics_frame
	pilot.release()
	check(target.hull == 0 and game.cannon.targets_hit == 2 and game.cannon.shots_fired == 2,
		"pool hull %d: two ordinary fire-input projectiles sink a naturally moving holding cutter" % index)
	check(never_owned and manager.records[0].defeated == 1 and manager.ships_sunk == 1,
		"pool hull %d: killing a waiting enemy counts exactly once without an attack slot" % index)
	manager.on_ship_sunk(target)
	check(manager.ships_sunk == 1 and manager.records[0].defeated == 1 and manager.focus_ship() != target,
		"pool hull %d: duplicate death notification is inert and the camera rejects the sunk target" % index)
	results.append({"holding_target": index, "shots": game.cannon.shots_fired, "hits": game.cannon.targets_hit,
		"defeated": manager.ships_sunk, "seconds": game.elapsed})
	game.queue_free()
	await process_frame
	await process_frame
	check(get_nodes_in_group("cannon_targets").is_empty(), "pool hull %d: disposing the session leaves no ship/target nodes" % index)

func _run() -> void:
	await simultaneous_runs()
	for index in 6:
		await holding_target(index)
	var output := FileAccess.open("/tmp/latitude-fleet-interactions.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("FLEET INTERACTIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

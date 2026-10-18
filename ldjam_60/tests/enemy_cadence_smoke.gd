extends "res://tests/enemy_pressure_smoke.gd"
## Sustained broadside opportunities with real warnings, shots and reloads.

func _run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var ship = game.enemy_encounters.ship
	for hz in [30, 60, 120]:
		for kind in ["cutter", "skiff", "heavy"]:
			game.restart()
			game.state = game.State.SAILING
			game.damage_immunity = 10000
			game.enemy_encounters.enabled = false
			game.wave_encounters.enabled = false
			game.boat.position = Vector3(260, 0, 355)
			game.boat.velocity = Vector3.ZERO
			ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
			ship.begin(game.boat.position + Vector3(42, 0, 14))
			ship.heading = 0.3
			ship.rotation.y = -ship.heading
			ship.passes = 1
			ship._change_navigation(ship.Navigation.ATTACK_RUN)
			await physics_frame
			var warnings := 0
			var warning_started := -1.0
			var last_fired := -100.0
			var full_warning := true
			var full_reload := true
			var locked := true
			var fixed_point := Vector3.ZERO
			for tick in hz * 20:
				var time: float = float(tick) / hz
				var previous: int = ship.weapon_state
				var shots: int = ship.shots_fired
				ship.cooldown = maxf(0, ship.cooldown - 1.0 / hz)
				ship._update_weapon(1.0 / hz)
				if ship.weapon_state == ship.Weapon.TELEGRAPH and previous != ship.Weapon.TELEGRAPH:
					warnings += 1
					warning_started = time
					fixed_point = ship.locked_point
					full_reload = full_reload and time - last_fired >= ship.reload_seconds - 0.001
				if ship.weapon_state == ship.Weapon.TELEGRAPH:
					locked = locked and ship.locked_point == fixed_point
				if ship.shots_fired > shots:
					full_warning = full_warning and time - warning_started >= ship.telegraph_seconds - 0.001
					last_fired = time
				game.ocean.wave_time += 1.0 / hz
				ship._advance_shots(1.0 / hz)
			print("CADENCE %dHz %s: %d shots / 20 seconds" % [hz, kind, ship.shots_fired])
			check(ship.shots_fired >= 4 and warnings >= ship.salvos_fired and ship.salvos_fired >= 2,
				"%d Hz %s fires repeatedly during one valid arena pass" % [hz, kind])
			check(full_warning and full_reload and locked,
				"%d Hz %s retains full warnings, reloads and fixed aim on every repeat" % [hz, kind])
			ship.reset()
			ship.begin(game.boat.position + Vector3(-42, 0, 14))
			ship.heading = 0.3
			ship.rotation.y = -ship.heading
			ship._change_navigation(ship.Navigation.ATTACK_RUN)
			await physics_frame
			ship._update_weapon(0)
			check(ship.weapon_state == ship.Weapon.TELEGRAPH and ship.active_battery == ship.Battery.STARBOARD and ship.shots_fired == 0,
				"%d Hz %s can warn through its starboard battery with no instant shot" % [hz, kind])
	game.restart()
	check(ship.shots_fired == 0 and ship.projectiles.is_empty() and ship.salvos_fired == 0,
		"retry clears repeat-fire counters, shots and pass state")
	game.state = game.State.SAILING
	game.boat.position = Vector3(260, 0, 355)
	game.boat.velocity = Vector3.ZERO
	ship.begin(game.boat.position + Vector3(42, 0, 14), true)
	ship.heading = 0.3
	ship._lock_shot()
	var first_point: Vector3 = ship.locked_point
	check(Vector2(first_point.x - game.boat.position.x, first_point.z - game.boat.position.z).length() < 0.001,
		"first opportunistic shot uses accurate aim even before a parallel pass")
	ship.salvos_fired = 1
	ship._lock_shot()
	check(ship.locked_point.distance_to(first_point) < 0.001,
		"every salvo uses accurate aim without alternating deliberate misses")
	ship.salvos_fired = 0
	ship.turn_rate = 0.8
	await physics_frame
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.READY, "a hard-turning holding ship cannot start a warning")
	ship.turn_rate = 0
	ship.safety_priority = 2
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.READY, "an avoidance manoeuvre cannot start an opportunistic broadside")
	ship.safety_priority = 0
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.READY, "queued holding ships cannot start warnings")
	game.enemy_encounters.director.owners.append(ship)
	ship._change_navigation(ship.Navigation.APPROACH)
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.TELEGRAPH, "an active approach can warn without a perfect run")
	var other = game.enemy_encounters.ships[1]
	other.begin(game.boat.position + Vector3(50, 0, -5), true)
	other.heading = 0.3
	other.rotation.y = -other.heading
	game.enemy_encounters.director.owners.append(other)
	other._change_navigation(other.Navigation.APPROACH)
	await physics_frame
	other._update_weapon(0)
	check(other.weapon_state == other.Weapon.READY, "opportunistic guns retain the global warning stagger")
	game.enemy_encounters.director.clock += game.enemy_encounters.survival_settings.warning_interval
	other._update_weapon(0)
	check(other.weapon_state == other.Weapon.TELEGRAPH, "next permitted attacker can warn once the stagger expires")
	game.restart()
	check(game.enemy_encounters.director.warning_history.is_empty() and game.enemy_encounters.director.next_warning == 0,
		"retry clears opportunistic warning reservations")
	game.queue_free()
	await process_frame
	print("ENEMY CADENCE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

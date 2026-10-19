extends "res://tests/enemy_pressure_smoke.gd"
## Close-range self-defence, boss intercepts, dodging and shared weapon lifecycle.
var game
var boss

func fresh() -> void:
	game.restart()
	game.sailing_speed = 7.5
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(-55, 0, 105)
	game.boat.velocity = Vector3.ZERO
	game.heading = PI / 2
	game.boat.rotation.y = -game.heading

func boss_pass(hz: int, speed: float, dodge: bool, kind: int) -> Dictionary:
	fresh()
	game.sailing_speed = speed # Keep propulsion identical in straight/dodge pairs.
	game.hull_capacity = 30 # Extend observation only; normal immunity stays active.
	game.hull = 30
	game.boat.velocity = Vector3.RIGHT * speed
	boss.begin(game.boat.position + Vector3(0, 0, -42))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5
	boss.velocity = boss.forward() * boss._speed
	boss.pattern = kind
	boss.salvo = 0
	await physics_frame
	check(boss._prepare_volley(boss.telegraph_seconds), "boss commits a moving-target volley")
	var plan: Array = boss.volley.duplicate(true)
	var fixed := true
	var warning := true
	var first_fire := -1.0
	for tick in hz * 4:
		var dt := 1.0 / hz
		var time := float(tick + 1) / hz
		# Hold both courses except for a real bounded rudder response to the warning.
		if dodge:
			game.advance_sailing(dt, -1.0)
		else:
			game.boat.position += game.boat.velocity * dt
			game.sea_time += dt
			game.ocean.wave_time = game.sea_time
			game.damage_immunity = maxf(0, game.damage_immunity - dt)
		boss.position += boss.forward() * boss._speed * dt
		boss._advance_shots(dt)
		# Observe a single complete pattern, including the separately warned double.
		if boss.weapon_state != boss.Weapon.RELOAD:
			boss._update_weapon(dt)
		if boss.weapon_state == boss.Weapon.TELEGRAPH and boss.salvo == 0:
			fixed = fixed and boss.volley == plan
		if boss.shots_fired > 0 and first_fire < 0:
			first_fire = time
			warning = time >= boss.telegraph_seconds - 0.001
		await physics_frame
	var result := {"hz":hz, "speed":speed, "dodge":dodge, "pattern":kind, "shots":boss.shots_fired, "hits":boss.shots_hit, "first_fire":first_fire}
	print("BOSS THREAT " + JSON.stringify(result))
	check(fixed and warning and first_fire > 0, "full fixed warning precedes physical boss fire")
	check(boss.shots_fired == (4 if kind == boss.Pattern.DOUBLE else 5), "all warned boss rounds launch")
	return result

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	boss = game.enemy_encounters.boss
	var ship = game.enemy_encounters.ship
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		for kind in ["cutter", "skiff", "heavy"]:
			fresh()
			ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
			ship.begin(game.boat.position + Vector3(16, 0, 0), true)
			ship.heading = 0
			ship.rotation.y = 0
			ship.sea_effects.advance_arrival(1.0)
			await physics_frame
			ship._update_weapon(0)
			check(ship.weapon_state == ship.Weapon.TELEGRAPH and not game.enemy_encounters.director.owners.has(ship), "%s %dHz: closing on a queued hull provokes a warned broadside" % [kind, hz])
			var shots := 0
			for tick in hz * 8:
				ship.cooldown = maxf(0, ship.cooldown - 1.0 / hz)
				ship._update_weapon(1.0 / hz)
				ship._advance_shots(1.0 / hz)
				game.enemy_encounters.director.clock += 1.0 / hz
				shots = ship.salvos_fired
			check(shots >= 3, "%s %dHz: close self-defence repeats through shared reloads" % [kind, hz])
			ship.reset()
			ship.begin(game.boat.position + Vector3(8, 0, 0))
			ship.heading = 0
			ship.rotation.y = 0
			ship._change_navigation(ship.Navigation.ATTACK_RUN)
			await physics_frame
			ship._update_weapon(0)
			check(ship.weapon_state == ship.Weapon.READY, "overlapping hulls cannot start point-blank fire")
		fresh()
		boss.begin(game.boat.position + Vector3(0, 0, -22))
		boss.heading = PI / 2
		boss.rotation.y = -boss.heading
		boss.turn_rate = 0.25
		boss.cooldown = 0
		await physics_frame
		boss._update_weapon(0)
		check(boss.weapon_state == boss.Weapon.TELEGRAPH, "boss warns at 22 metres while turning")
		boss.clear_hazards()
		boss._change_weapon(boss.Weapon.READY)
		boss.position = game.boat.position + Vector3(0, 0, -10)
		boss._update_weapon(0)
		check(boss.weapon_state == boss.Weapon.READY, "boss retains a hull-clearance minimum")
		for speed in [7.5, 11.25]:
			var straight_hits := 0
			var dodge_hits := 0
			for pattern in [boss.Pattern.ROLLING, boss.Pattern.DOUBLE]:
				var straight := await boss_pass(hz, speed, false, pattern)
				var evade := await boss_pass(hz, speed, true, pattern)
				straight_hits += int(straight.hits)
				dodge_hits += int(evade.hits)
				check(straight.hits > 0, "boss intercept physically hits a steady cruise/boost course")
			check(dodge_hits < straight_hits, "steering after the warning avoids more boss fire than a steady course")
	# Run inherited navigation and production weapon acquisition together.
	Engine.physics_ticks_per_second = 60
	fresh()
	game.damage_immunity = 1000
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	boss.begin(game.boat.position + Vector3(0, 0, -42))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5
	boss.velocity = Vector3.RIGHT * 7.5
	await physics_frame
	for tick in 60 * 12:
		game.advance_sailing(1.0 / 60, 0)
		game.enemy_encounters.director.clock += 1.0 / 60
		boss.update_ship(1.0 / 60)
		await physics_frame
	print("BOSS SUSTAINED shots=%d patterns=%d" % [boss.shots_fired, boss.pattern_history.size()])
	check(boss.shots_fired >= 9 and boss.pattern_history.size() >= 2, "naturally sailing boss repeats attacks within twelve seconds")
	# Cannon meshes and launch markers remain on the same rocking deck.
	fresh()
	boss.begin(game.boat.position + Vector3(0, 0, -42))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss.pattern = boss.Pattern.ROLLING
	boss.visual.position.y = 0.8
	boss.visual.rotation.z = 0.1
	await physics_frame
	check(boss._prepare_volley(boss.telegraph_seconds), "rocking-deck fixture commits")
	check(boss.deck_guns.size() == 20 and boss.deck_guns.all(func(m): return m.gun.is_visible_in_tree()), "boss visibly carries both broadsides, bow and stern guns")
	check(boss.volley.all(func(s): return boss.deck_guns.any(func(m): return m.gun.to_global(boss.CANNON_MUZZLE).distance_to(boss._shot_lane(s).origin) < 0.001)), "rocking-deck launch points match visible cannon muzzles")
	game.restart()
	check(boss.volley.is_empty() and boss.projectiles.is_empty() and boss.mines.is_empty() and boss.cooldown == 0 and boss.weapon_state == boss.Weapon.READY, "retry clears faster boss attacks and hazards")
	check(game.cannon.RELOAD_SECONDS == 1.5 and game.hull_capacity == 30, "enemy tuning preserves the player reload and configured hull capacity")
	game.queue_free()
	await process_frame
	print("ENEMY THREAT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends "res://tests/enemy_pressure_smoke.gd"
## Degenerate intercepts, geometry, arrivals, physical blockers and dead weapons.
func _run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	for sample in [[Vector3(40,0,0), Vector3(0,0,-7.5)], [Vector3(40,0,0), Vector3(-24,0,0)], [Vector3(40,0,0), Vector3(-30,0,0)], [Vector3(0,0,-40), Vector3(2,0,11.25)]]:
		var t: float = ship.intercept_time(sample[0], sample[1], 24)
		check(t > 0 and absf((sample[0] + sample[1] * t).length() - 24 * t) < 0.001,
			"intercept solves moving, equal-speed and faster approaching targets")
	check(ship.intercept_time(Vector3(40,0,0), Vector3(24,0,0), 24) < 0,
		"equal-speed receding target rejects an impossible intercept")
	check(ship.intercept_time(Vector3(40,0,0), Vector3(0,0,30), 24) < 0,
		"negative-discriminant target rejects an impossible intercept")
	game.boat.position = game.arena_center() + Vector3(0,0,110)
	game.boat.velocity = Vector3.ZERO
	game.heading = 0
	ship.begin(game.boat.position + Vector3(40,0,0))
	ship.heading = 0
	ship.rotation.y = 0
	ship._speed = 0
	await physics_frame
	ship.update_ship(1.0 / 60)
	check(ship.weapon_state == ship.Weapon.READY, "arrival fade cannot hide a short warning")
	ship.sea_effects.advance_arrival(ship.SeaEffects.ARRIVAL_SECONDS)
	ship.update_ship(1.0 / 60)
	check(ship.weapon_state == ship.Weapon.TELEGRAPH and ship.flash.visible,
		"fully arrived approach advertises its warning immediately")
	for fraction in [0.0, 0.25, 0.5, 0.75, 0.99]:
		ship.weapon_time = ship.telegraph_seconds * fraction
		ship._update_tell()
		check(ship.flash.visible, "warning glow has no invisible phase")
	ship.reset()
	ship.begin(game.boat.position + Vector3(40,0,0))
	ship.heading = 0
	ship.rotation.y = 0
	for degrees in [-44.5, 44.5]:
		check(ship._select_battery(Vector3.LEFT.rotated(Vector3.UP, deg_to_rad(degrees))) == ship.Battery.PORT,
			"wide port arc accepts a physically plausible broadside")
	check(ship._select_battery(Vector3.LEFT.rotated(Vector3.UP, deg_to_rad(46.0))) < 0,
		"beyond the gun arc is rejected")
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 4 # Another ship, not an island.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,12,12)
	shape.shape = box
	obstacle.add_child(shape)
	game.add_child(obstacle)
	obstacle.position = ship.position.lerp(game.boat.position, 0.5)
	await physics_frame
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.READY, "intervening ship blocks acquisition")
	obstacle.position.z += 30
	await physics_frame
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.TELEGRAPH, "clear broadside can begin a committed warning")
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.shots_fired == 2, "one warning launches one bounded two-gun salvo")
	obstacle.position.z -= 30 # Move into flight after launch.
	await physics_frame
	for tick in 120: ship._advance_shots(1.0 / 60)
	check(ship.projectiles.is_empty() and game.hits_taken == 0,
		"physical shells stop on a ship entering the lane after launch")
	for tick in 120: ship._update_weapon(1.0 / 60)
	check(ship.shots_fired == 2, "weapon updates cannot bypass the shared cooldown")
	ship._change_navigation(ship.Navigation.SINKING)
	ship.cooldown = 0
	ship._change_weapon(ship.Weapon.READY)
	for tick in 120: ship._update_weapon(1.0 / 60)
	check(ship.shots_fired == 2 and ship.weapon_state == ship.Weapon.READY, "sinking weapons cannot acquire or fire")
	game.restart()
	check(game.hull_capacity == 3 and game.hull == 3 and ship.projectiles.is_empty(), "normal health and restart are preserved")
	game.queue_free()
	await process_frame
	print("ENEMY GUNNERY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

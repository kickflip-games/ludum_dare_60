extends "res://tests/starboard_cone_smoke.gd"
## Shallow physical arc, retained hits/obstructions and line-free enemy warnings.

func _run() -> void:
	if not output.is_empty():
		if DisplayServer.get_name() == "headless":
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var c = game.cannon
	var ship = game.enemy_encounters.ship
	for hz in [30, 60, 120]:
		fresh()
		c.fire()
		var origin: Vector3 = c.shot_origin()
		var peak := origin.y
		for tick in roundi(0.9 * hz):
			game.ocean.wave_time += 1.0 / hz
			c.advance(1.0 / hz)
			if c.projectiles.is_empty():
				break
			peak = maxf(peak, c.projectiles[0].physics_position.y)
			if hz == 60 and tick in [11, 35, 53]:
				await capture("arc-%02d" % tick)
		check(not c.projectiles.is_empty() and peak - origin.y > 1.3 and peak - origin.y < 1.6,
			"%d Hz: empty shot rises in a shallow arc without an early splash" % hz)
		check(not c.projectiles.is_empty() and c.projectiles[0].velocity.y < 0,
			"%d Hz: gravity brings the shot back down after its apex" % hz)
		for tick in hz:
			game.ocean.wave_time += 1.0 / hz
			c.advance(1.0 / hz)
		check(c.projectiles.is_empty(), "%d Hz: arcing miss still expires" % hz)
		for distance in [12.0, 35.0, 60.0]:
			fresh()
			place_target(ship, 0, distance)
			await sync()
			c.fire()
			for tick in hz * 2:
				c.advance(1.0 / hz)
				if c.projectiles.is_empty():
					break
			check(c.targets_hit == 1, "%d Hz: arcing shot physically hits hull at %.0f m" % [hz, distance])
	fresh()
	place_target(ship, 0, 35)
	await sync()
	c.fire()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 12, 12)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = c.cone_point(0, 15)
	await sync()
	for tick in 90:
		c.advance(1.0 / 60)
		if c.projectiles.is_empty():
			break
	check(c.projectiles.is_empty() and c.targets_hit == 0 and c.feedback.contains("SOLID REEF"),
		"intervening solid stops an already launched arc before the target")
	wall.queue_free()
	await physics_frame
	fresh()
	# Lift the real water surface above the muzzle to verify first-water collision.
	var settings = game.ocean.settings.duplicate()
	settings.sea_level = c.shot_origin().y + 0.5
	game.ocean.configure(settings)
	c.fire()
	c.advance(1.0 / 60)
	check(c.projectiles.is_empty() and c.feedback.contains("SPLASH"),
		"arc still collides with water covering the muzzle")
	game.ocean.configure(game.ocean_settings)
	fresh()
	place_target(ship, 0, 35)
	ship.weapon_state = ship.Weapon.TELEGRAPH
	ship.weapon_time = 0.6
	ship._lock_shot()
	var locked: Vector3 = ship.locked_point
	ship._update_tell()
	check(ship.flash.visible and ship.warning().contains("TURN TO EVADE") and not ship.warning().contains("LINE"),
		"enemy retains muzzle warning and evasive instruction without a line reference")
	await capture("enemy-warning")
	ship.weapon_time = 0.8
	ship._update_tell()
	check(not ship.flash.visible and ship.locked_point == locked,
		"warning still flashes and keeps its fixed aim point")
	ship._fire()
	check(ship.shots_fired == 1 and not ship.projectiles.is_empty(), "line-free enemy still fires a physical shot")
	c.cooldown = 0.0
	c.fire()
	game.restart()
	check(c.projectiles.is_empty() and ship.projectiles.is_empty() and not ship.flash.visible,
		"retry clears both arcing shots and enemy warning/shot effects")
	game.state = game.State.SAILING
	c.update_cone_feedback()
	c.fire()
	check(c.projectiles[0].velocity.y > 4.0, "first empty shot after retry restores upward launch")
	print("CANNON ARC: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

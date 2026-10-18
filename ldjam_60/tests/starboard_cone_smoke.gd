extends "res://tests/arcade_controls_smoke.gd"
## Geometry, deterministic target ranking, movement lead and real collision.
func place_target(ship, angle: float, distance: float, velocity := Vector3.ZERO) -> void:
	ship.begin(Vector3.ZERO)
	ship.rotation = Vector3.ZERO
	var point: Vector3 = game.cannon.cone_point(angle, distance)
	point.y = ship.collision_shape.position.y
	ship.position = point - ship.collision_shape.position
	ship.velocity = velocity

func sync() -> void:
	await physics_frame
	await process_frame
	game.cannon.update_cone_feedback()

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
	fresh()
	await capture("01-default-cone")
	var c = game.cannon
	var ships: Array = game.enemy_encounters.ships
	var ship = ships[0]
	step(3.0)
	check(c.aim_degrees == 0 and c.sweep_elapsed == 0, "idle arena cannon never sweeps")
	fresh()
	for sample in [[0.0, 30.0, true], [-24.9, 30.0, true], [24.9, 30.0, true], [-25.1, 30.0, false], [25.1, 30.0, false], [0.0, 64.99, true], [0.0, 65.1, false], [180.0, 20.0, false]]:
		place_target(ship, sample[0], sample[1])
		await sync()
		check((c.selected_target == ship) == sample[2] and ship.aim_highlight == sample[2], "angle %.1f range %.2f: eligibility and highlight share exact cone limits" % [sample[0], sample[1]])
	place_target(ship, 0, 55)
	place_target(ships[1], 12, 18)
	await sync()
	check(c.selected_target == ship and ships[1].aim_highlight, "centre alignment wins over a closer edge target; both eligible hulls glow")
	await capture("02-multiple-targets")
	c.fire()
	check(c.selected_target == ship and absf(c.aim_degrees) < 0.01, "firing selects centre alignment over the nearer target")
	fresh()
	place_target(ship, 8, 50)
	place_target(ships[1], -8, 25)
	await sync()
	check(c.selected_target == ships[1], "distance breaks equal-alignment ties")
	c.fire()
	check(c.selected_target == ships[1] and c.aim_degrees < 0, "firing uses the closer equally aligned target")
	var selected = c.selected_target
	var edge: Vector3 = c.cone_point(25, 65)
	mouse(900)
	game.camera.rotate_y(1.0)
	c.update_cone_feedback()
	check(c.selected_target == selected and c.cone_point(25, 65).is_equal_approx(edge), "camera movement cannot rotate the cone or change target selection")
	game._update_view(1.0)
	await capture("03-camera-independent-cone")
	var right: Vector3 = c.starboard_direction()
	var offset: Vector3 = c.cone_visual.water_point(25, 65) - c.cone_origin()
	var flat := Vector3(offset.x, 0, offset.z)
	check(absf(flat.length() - 65) < 0.001 and absf(rad_to_deg(acos(flat.normalized().dot(right))) - 25) < 0.001, "rendered far boundary matches the 25-degree, 65-metre acquisition limits")
	game.heading += PI * 0.7
	game.boat.rotation.y = -game.heading
	c.update_cone_feedback()
	offset = c.cone_visual.water_point(-25, 65) - c.cone_origin()
	flat = Vector3(offset.x, 0, offset.z)
	check(absf(rad_to_deg(acos(flat.normalized().dot(c.starboard_direction()))) - 25) < 0.001, "water cone follows a large boat turn")
	fresh()
	game.boat_visual.rotation = Vector3(0.2, 0, -0.2)
	c.update_cone_feedback()
	key(KEY_SPACE, true)
	step(1.0 / 60)
	var shot: Dictionary = c.projectiles[0]
	var launched: Vector3 = shot.velocity
	check(c.selected_target == null and Vector2(launched.x, launched.z).normalized().dot(Vector2(c.starboard_direction().x, c.starboard_direction().z)) > 0.9999, "empty cone fires straight starboard even on a rocking hull")
	check((launched + Vector3.UP * c.SHOT_GRAVITY / 60 - Vector3.UP * c.SHOT_LIFT).normalized().dot(c.aimed_direction()) > 0.9999, "real projectile leaves along the rotated visible barrel")
	key(KEY_SPACE, false)
	var radius: float = 0
	for tick in 120:
		if c.projectiles.is_empty():
			break
		var at: Vector3 = c.projectiles[0].physics_position
		var origin: Vector3 = c.projectiles[0].range_origin
		radius = maxf(radius, Vector2(at.x-origin.x, at.z-origin.z).length())
		c.advance(1.0 / 60)
	check(c.projectiles.is_empty() and radius <= 65.001, "real projectiles expire within the water cone range")
	fresh()
	place_target(ship, 24, 40, Vector3(0, 0, -14))
	await sync()
	c.fire()
	check(absf(c.aim_degrees) <= 25.0001, "movement lead is clamped when a target is leaving the cone")
	fresh()
	place_target(ship, 8, 35, Vector3(0, 0, -8))
	await sync()
	c.fire()
	check(c.aim_degrees > 8 and c.aim_degrees <= 25, "shot leads a moving enemy before launch")
	var velocity: Vector3 = c.projectiles[0].velocity
	var start: Vector3 = ship.position
	for tick in 80:
		ship.position += ship.velocity / 60.0
		await physics_frame
		await process_frame
		c.advance(1.0 / 60)
		if c.targets_hit > 0:
			break
	check(ship.position.distance_to(start) > 2 and c.targets_hit == 1 and ship.hull == ship.hull_capacity - 1, "led real projectile hits a translating enemy hull")
	fresh()
	place_target(ship, -8, 35, Vector3(0, 0, 6))
	await sync()
	c.fire()
	velocity = c.projectiles[0].velocity
	ship.velocity = Vector3(0, 0, -14)
	game.heading = 1.0
	game.camera.rotate_y(0.5)
	for tick in 8:
		ship.position += ship.velocity / 60.0
		c.advance(1.0 / 60)
	check(not c.projectiles.is_empty() and Vector2(c.projectiles[0].velocity.x, c.projectiles[0].velocity.z).distance_to(Vector2(velocity.x, velocity.z)) < 0.00001, "launched cannonball never homes after target, boat and camera turn")
	fresh()
	place_target(ship, 0, 30)
	await sync()
	ship.visible = false
	c.update_cone_feedback()
	check(c.selected_target == null and not ship.aim_highlight, "hidden hulls cannot be acquired or highlighted")
	ship.visible = true
	ship.take_hit()
	ship.take_hit()
	c.update_cone_feedback()
	check(c.selected_target == null and not ship.aim_highlight, "sinking hulls cannot be reacquired")
	game.restart()
	check(c.selected_target == null and not c.cone_visual.visible and c.projectiles.is_empty(), "retry clears cone selection, overlay and projectiles")
	await trajectory_cases()
	await moving_combat()
	print("STARBOARD CONE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

extends "res://tests/arcade_controls_smoke.gd"
## Isolate damage displacement from sea motion using a same-pose no-hit control.

func hit_offset() -> Vector3:
	var remaining: float = game.damage_shake_left
	game.damage_shake_left = 0.0
	game._update_view(0.0)
	var baseline: Vector3 = game.camera.position
	var basis: Basis = game.camera.basis
	game.damage_shake_left = remaining
	game._update_view(0.0)
	check(game.camera.basis.is_equal_approx(basis), "damage preserves camera aim and level horizon")
	return game.camera.position - baseline

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
	check(not game.take_damage(1, "title") and game.damage_shake_left == 0, "title rejects damage shake")
	for hz in [30, 60, 120]:
		fresh()
		check(hit_offset().is_zero_approx(), "no damage produces no hit displacement at %d Hz" % hz)
		check(not game.take_damage(0, "zero") and not game.take_damage(-1, "negative") and game.damage_shake_left == 0, "invalid hits cannot start shake")
		check(game.take_damage(1, "impact"), "accepted hit starts damage shake")
		var offset := hit_offset()
		check(offset.length() > 0.2 and offset.length() <= 0.3, "chase damage gives a readable bounded initial kick")
		var boat_pose: Transform3D = game.boat.transform
		game.motion_setting = 1
		var reduced := hit_offset()
		check(absf(reduced.length() / offset.length() - 0.28) < 0.001, "Reduced motion scales damage displacement")
		game.motion_setting = 0
		check(game.boat.transform == boat_pose, "damage camera never moves the physical hull")
		game._update_view(0.1)
		var remaining: float = game.damage_shake_left
		check(not game.take_damage(1, "immune") and game.damage_shake_left == remaining, "immune contacts cannot retrigger shake")
		check(hit_offset().length() < offset.length(), "hit oscillation decays")
		step(0.3, hz)
		check(game.damage_shake_left == 0 and hit_offset().is_zero_approx(), "shake fully settles at %d Hz" % hz)
	fresh()
	key(KEY_D, true)
	key(KEY_SPACE, true)
	mouse(80)
	game.take_damage(1, "combat impact")
	step(0.1)
	check(game.turn_input == 1 and game.cannon.shots_fired == 1 and game.look_yaw < 0 and game.damage_shake_left > 0, "held steering, fire and mouse look work during damage")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(0.05)
	check(game.turn_input == 0 and not game.cannon._fire_held, "focus loss still releases combat controls during shake")
	fresh()
	game.take_damage(99, "lethal")
	check(game.state == game.State.LOST and hit_offset().length() > 0.2, "killing blow shakes during the sinking transition")
	check(not game.take_damage(1, "late"), "lost state rejects additional hits")
	game.restart()
	check(game.damage_shake_left == 0 and game.shake_strength == 0, "retry clears damage and generic shake immediately")
	fresh()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = game._camera_shore_anchor().lerp(game.camera.position, 0.6)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await physics_frame
	game.take_damage(1, "shore impact")
	var safe := true
	for frame in 20:
		game._update_view(1.0 / 60.0)
		var at: Vector3 = game.camera.position
		var ray := PhysicsRayQueryParameters3D.create(game._camera_shore_anchor(), at, 1)
		safe = safe and game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		safe = safe and at.y >= game.ocean.height_at(Vector2(at.x, at.z)) + 1.19
	check(safe, "damage shake retains shore obstruction and water clearance throughout its lifetime")
	wall.queue_free()
	await physics_frame
	# Matched native views: only presentation time advances during this sequence.
	fresh()
	await capture("01-before-hit")
	game.take_damage(1, "preview impact")
	game._update_view(0.0)
	await capture("02-impact")
	game._update_view(0.05)
	await capture("03-shake-50ms")
	game._update_view(0.05)
	await capture("04-shake-100ms")
	game._update_view(0.25)
	check(game.damage_shake_left == 0, "native sequence settles")
	await capture("05-settled")
	print("DAMAGE CAMERA: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

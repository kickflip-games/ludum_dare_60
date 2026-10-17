extends SceneTree
## Input/state integration and real projectile collisions for the single sweeping gun.
var game
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func action(name: String, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap() -> void:
	action("fire_starboard", true)
	action("fire_starboard", false)


func step(seconds: float = 1.0 / 60) -> void:
	for i in range(maxi(1, roundi(seconds * 60))):
		game._physics_process(1.0 / 60)
		game.cannon.advance(1.0 / 60)
	game.hud._process(seconds)


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.current_strength = 0
	game.gust_strength = 0
	game.enemy_encounters.enabled = false
	game.start_crossing()
	step(1.3)
	game.boat.position = Vector3(400, 0, 360)
	var c = game.cannon
	tap()
	step()
	check(c.aiming and c.shots_fired == 0, "first F tap enters gun view without shooting")
	check(c.aim_degrees > 0 and c.aim_degrees < 2, "sweep starts immediately near centre toward the bow")
	var expected: Vector3 = c.aimed_direction()
	var origin: Vector3 = c.shot_origin()
	tap()
	step()
	check(c.shots_fired == 1 and c.aiming, "second F tap fires once and stays in cannon mode during camera entry")
	check(c.projectiles[0].velocity.normalized().dot(expected) > 0.999, "press captures current barrel direction")
	check(c.projectiles[0].node.global_position.distance_to(c.projectiles[0].physics_position) < 0.001, "visual and physical projectile positions coincide")
	check(game.aim_camera_blend < 0.5, "firing works before the camera transition finishes")
	var angle: float = c.aim_degrees
	step(0.3)
	check(c.aim_degrees > angle and c.cooldown > 0, "barrel continues sweeping while reloading")
	for i in range(6):
		tap()
	step()
	check(c.shots_fired == 1, "distinct taps during reload are discarded")
	action("fire_starboard", true)
	step(2)
	check(c.shots_fired == 1, "holding F across reload completion neither queues nor repeats fire")
	action("fire_starboard", false)
	tap()
	step()
	check(c.shots_fired == 2 and c.aiming, "fresh loaded press fires and retains gun view")
	for direction in ["steer_port", "steer_starboard"]:
		if not c.aiming:
			tap()
			step()
		step(0.5)
		var before: float = game.heading
		var blend: float = game.aim_camera_blend
		action(direction, true)
		step()
		check(not c.aiming and game.turn_input == (-1 if direction == "steer_port" else 1), direction + " exits and applies steering on the same tick")
		check((game.heading - before) * game.turn_input > 0, "hull turns during camera return: " + direction)
		check(game.aim_camera_blend < blend and game.aim_camera_blend > 0.5, "camera begins return without locking steering")
		action(direction, false)
		step()
	# Entry always wins over steering on the entry tick, regardless of event order.
	for fire_first in [true, false]:
		c.cancel_aim()
		if fire_first:
			tap()
			action("steer_port", true)
		else:
			action("steer_port", true)
			tap()
		step(0.3)
		check(c.aiming and game.turn_input == 0, "simultaneous entry/steer remains in gun view, fire first=%s" % fire_first)
		action("steer_starboard", true)
		step()
		action("steer_port", false)
		step()
		check(c.aiming, "opposing keys/net-zero cannot accidentally re-arm exit")
		action("steer_starboard", false)
		step()
		action("steer_starboard", true)
		step()
		check(not c.aiming and game.turn_input == 1, "neutral then fresh steering press exits")
		action("steer_starboard", false)
		step()
	# Held entry followed by a neutral/fresh press entirely between physics ticks.
	action("steer_port", true)
	tap()
	step()
	action("steer_port", false)
	action("steer_port", true)
	step()
	check(not c.aiming and game.turn_input == -1, "sub-tick release/repress reliably re-arms held-entry steering")
	action("steer_port", false)
	step()
	# Analog strength hysteresis: jitter below press threshold is harmless.
	action("steer_port", true, 0.8)
	tap()
	step()
	action("steer_port", true, 0.3)
	step()
	check(c.aiming, "analog must cross the neutral re-arm threshold")
	action("steer_port", true, 0.1)
	step()
	action("steer_port", true, 0.4)
	step()
	check(c.aiming, "analog jitter below 0.55 cannot exit")
	action("steer_port", true, 0.7)
	step()
	check(not c.aiming, "analog fresh crossing above 0.55 exits after re-arm")
	action("steer_port", false)
	step()
	for fire_first in [true, false]:
		tap()
		step()
		c.cooldown = 0
		var count: int = c.shots_fired
		if fire_first:
			tap()
			action("steer_port", true)
		else:
			action("steer_port", true)
			tap()
		step()
		check(not c.aiming and c.shots_fired == count, "steering beats simultaneous fire in either event order")
		action("steer_port", false)
		step()
	for i in range(12):
		tap()
		step()
		action("steer_port", true)
		step()
		action("steer_port", false)
		step()
	step(0.8)
	check(not c.aiming and game.aim_camera_blend < 0.001, "rapid switches settle to sailing with no stuck camera")
	tap()
	step()
	var start: Vector3 = game.boat.position
	var shots: int = c.shots_fired
	step(3)
	check(c.aiming and c.shots_fired == shots and game.boat.position.distance_to(start) > 18, "a full sweep preserves ship momentum and never auto-fires")
	# Delta-independent sweep, including both endpoints and easing/direction exports.
	for hz in [30, 60, 144]:
		c.sweep_elapsed = 0
		for i in range(hz * 3 / 4):
			c.update_aim(1.0 / hz)
		check(absf(c.aim_degrees - 30.0) < 0.02, "smooth +30 degree endpoint at %d Hz" % hz)
		for i in range(hz * 3 / 2):
			c.update_aim(1.0 / hz)
		check(absf(c.aim_degrees + 30.0) < 0.02, "smooth -30 degree endpoint at %d Hz" % hz)
	c.initial_sweep_direction = 1
	c.sweep_elapsed = 0
	c.update_aim(0.1)
	check(c.aim_degrees < 0, "Inspector initial direction reverses the predictable sweep")
	c.initial_sweep_direction = 0
	# Space cancels pending fire regardless of event order; held F cannot leak through.
	for fire_first in [true, false]:
		c.cooldown = 0
		shots = c.shots_fired
		if fire_first:
			action("fire_starboard", true)
			action("astrolabe", true)
		else:
			action("astrolabe", true)
			action("fire_starboard", true)
		step(0.4)
		check(not c.aiming and c.shots_fired == shots and game.camera_mode == game.CameraMode.STARGAZING, "Space has priority over pending shot")
		var bearing: float = game.last_reading
		game.shake(0.1)
		step(0.3)
		check(game.last_reading == bearing, "camera shake cannot change navigation bearing")
		action("astrolabe", false)
		step(0.6)
		check(not c.aiming and game.camera_mode == game.CameraMode.SAILING, "Space release returns to sailing despite held F")
		action("fire_starboard", false)
		step()
		tap()
		step()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step()
	check(not c.aiming, "focus loss clears gun mode and buffered shots")
	# Camera priority and first-tick steering with a nearby live hostile.
	game.enemy_encounters.enabled = true
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + c.starboard_direction() * 36
	step(0.7)
	check(game.camera_mode == game.CameraMode.COMBAT, "automatic combat framing remains available")
	tap()
	step(0.5)
	check(game.camera_mode == game.CameraMode.CANNON and game.aim_camera_blend > 0.97, "gunner view overrides automatic enemy framing")
	action("steer_starboard", true)
	var before: float = game.heading
	step()
	check(not c.aiming and game.heading > before, "steering works immediately beside live hostile")
	action("steer_starboard", false)
	game.enemy_encounters.enabled = false
	ship.reset()
	# Full world-space launch correspondence under pronounced rocking and arbitrary camera.
	for degrees in [0, 90, 180, -90]:
		game.heading = deg_to_rad(degrees)
		game.boat.rotation.y = -game.heading
		game.boat_visual.rotation = Vector3(0.2, 0, -0.25)
		c.cooldown = 0
		expected = c.aimed_direction()
		origin = c.muzzle.global_position
		game.camera.rotation = Vector3(0.4, 1.7, 0.1)
		c.fire()
		check(c.projectiles[-1].physics_position.is_equal_approx(origin) and (c.projectiles[-1].velocity - Vector3.UP * 0.35).normalized().dot(expected) > 0.99999, "heading %d: shot starts at actual rocking muzzle along visible barrel" % degrees)
	game.boat_visual.rotation = Vector3.ZERO
	game.heading = game.TARGET_HEADING
	game.boat.rotation.y = -game.heading
	tap()
	step(0.6)
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		for phase: float in [0.0, 0.75, 2.25]:
			c.sweep_elapsed = phase
			c.update_aim(0)
			game._update_view(0.5)
			var at: Vector2 = game.camera.unproject_position(c.shot_origin() + c.aimed_direction() * 32)
			check(root.get_visible_rect().grow(-24).has_point(at), "sight visible at %+.0f degrees / %s" % [c.aim_degrees, dimensions])
		check(game.camera.position.distance_to(c.global_position) < 4 and game.camera.position.y > game.ocean.height_at(Vector2(game.camera.position.x, game.camera.position.z)) + 1, "gunner camera close to mount and above water / %s" % dimensions)
	# Constant target poses converge identically at common display refresh rates.
	c.sweep_elapsed = 0
	c.update_aim(0)
	var poses: Array[Transform3D] = []
	for frames in [15, 30, 72]:
		game.aim_camera_blend = 0
		game.combat_camera_blend = 0
		game._camera_aim_degrees = 0
		var pose := Transform3D.IDENTITY
		for frame in range(frames):
			pose = game._sailing_camera_pose(Transform3D.IDENTITY, 0.5 / frames)
		poses.append(pose)
	check(poses[0].is_equal_approx(poses[1]) and poses[1].is_equal_approx(poses[2]), "gunner camera blend matches at 30, 60 and 144 Hz")
	game.aim_camera_blend = 1
	game.enemy_encounters.enabled = true
	ship.begin()
	ship.position = game.boat.position + c.starboard_direction() * 30
	var stable: Transform3D = game._sailing_camera_pose(Transform3D.IDENTITY, 0.5)
	ship.position += game.course_forward() * 15
	var biased: Transform3D = game._sailing_camera_pose(Transform3D.IDENTITY, 0.5)
	check(stable.is_equal_approx(biased), "enemy motion cannot bias the manual gunner viewpoint")
	ship.reset()
	game.enemy_encounters.enabled = false
	c.sweep_elapsed = 0.75
	c.update_aim(0)
	var left: Transform3D = game._sailing_camera_pose(Transform3D.IDENTITY, 1)
	c.sweep_elapsed = 2.25
	c.update_aim(0)
	var right_pose: Transform3D = game._sailing_camera_pose(Transform3D.IDENTITY, 1)
	check(rad_to_deg(left.basis.z.angle_to(right_pose.basis.z)) < 10, "camera tracks less than 10 degrees across the full 60 degree sweep")
	game._update_view(0.1)
	# Terrain feeler uses the same collision layer as the existing camera.
	var anchor: Vector3 = game.boat.position + Vector3.UP * 2.8
	var rock := StaticBody3D.new()
	rock.collision_layer = 1
	rock.position = anchor.lerp(game.camera.position, 0.6)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.5
	shape.shape = box
	rock.add_child(shape)
	game.add_child(rock)
	await physics_frame
	game._update_view(0.1)
	var ray := PhysicsRayQueryParameters3D.create(anchor, game.camera.position, 1)
	check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "camera feeler prevents clipping through nearby terrain")
	rock.queue_free()
	await physics_frame
	# Honest misses outside the arc; no target-based launch correction.
	c.cancel_aim()
	ship.begin()
	ship.position = c.shot_origin() + c.starboard_direction().rotated(Vector3.UP, deg_to_rad(60)) * 28
	ship.position.y = 0
	ship.rotation.y = -game.heading
	await physics_frame
	c.cooldown = 0
	c.fire()
	for i in range(60):
		c.advance(1.0 / 60)
		await physics_frame
	check(ship.hull == ship.hull_capacity, "outside-arc target cannot bend a shot or receive a hidden hit")
	ship.reset()
	# Real moving hull collisions at centre and both sides, using timed presses.
	for phase: float in [0.0, 0.25, 1.75]:
		c.reset()
		tap()
		step()
		c.sweep_elapsed = phase
		c.update_aim(0)
		ship.begin()
		ship.position = c.shot_origin() + c.aimed_direction() * 28
		ship.position.y = 0
		ship.rotation.y = -game.heading
		await physics_frame
		tap()
		c.update_aim(0)
		for frame in range(40):
			ship.position += Vector3(sin(game.heading), 0, -cos(game.heading)) * 2 / 60
			c.advance(1.0 / 60)
			await physics_frame
		check(ship.hull < ship.hull_capacity, "timed shot hits moving hull at sweep phase %.2f" % phase)
	ship.reset()
	game.damage_immunity = 0
	var hull: int = game.hull
	game.take_damage(1, "Gun view vulnerability")
	check(game.hull == hull - 1 and c.aiming, "taking damage remains active in cannon mode")
	game.damage_immunity = 0
	game.take_damage(game.hull_capacity, "Sinking in gun view")
	tap()
	step(0.5)
	check(game.state == game.State.LOST and not c.aiming and c.projectiles.is_empty(), "sinking cancels gun mode, buffered input and projectiles")
	game.restart()
	step(1.4)
	tap()
	step()
	check(c.aiming and game.hull == game.hull_capacity and c.shots_fired == 0, "retry restores clean working gun and ship")
	print("SWEEPING CANNON CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

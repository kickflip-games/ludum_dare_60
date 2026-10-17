extends SceneTree
## Real input edges, manual yaw, reload, camera priority and live hull collisions.
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


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func step(seconds: float) -> void:
	for i in range(maxi(1, roundi(seconds * 60))):
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
	game.hud._process(0.1)


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
	action("fire_starboard", true)
	check(c.aiming and c.shots_fired == 0, "press starts aiming immediately without firing")
	action("fire_starboard", false)
	check(c.shots_fired == 1 and not c.aiming, "sub-physics-tick quick tap fires once with no charge gate")
	for i in range(8):
		action("fire_starboard", true)
		action("fire_starboard", false)
	check(c.shots_fired == 1, "rapid taps cannot bypass reload")
	step(1.6)
	var heading: float = game.heading
	var start: Vector3 = game.boat.position
	action("fire_starboard", true)
	action("steer_port", true)
	step(0.6)
	check(c.aim_degrees == c.max_aim_degrees and c.yaw_pivot.rotation.y > 0, "A rotates visible cannon toward bow and clamps at +20 degrees")
	check(is_equal_approx(game.heading, heading) and game.turn_input == 0, "aim input cannot turn hull or retain rudder")
	check(game.boat.position.distance_to(start) > 3, "boat continues sailing throughout aim")
	check(c.preparation == 1 and c.shots_fired == 1, "visual preparation completes without auto-fire")
	action("steer_port", false)
	step(0.2)
	check(c.aim_degrees == c.max_aim_degrees, "releasing A preserves selected yaw")
	var front_screen: Vector2 = game.camera.unproject_position(c.shot_origin() + c.aimed_direction() * 32)
	action("steer_starboard", true)
	step(0.8)
	check(c.aim_degrees == -c.max_aim_degrees, "D clamps at rear limit")
	var rear_screen: Vector2 = game.camera.unproject_position(c.shot_origin() + c.aimed_direction() * 32)
	check(front_screen.x < rear_screen.x, "A and D move the sight intuitively left and right")
	var expected: Vector3 = c.aimed_direction()
	action("fire_starboard", false)
	check(c.shots_fired == 2 and c.projectiles[-1].velocity.normalized().dot(expected) > 0.999, "release fires in exact manual yaw direction")
	step(1.0 / 60)
	check(game.heading > heading and game.turn_input == 1, "steering returns on first tick after release")
	action("steer_starboard", false)
	action("fire_starboard", true)
	step(0.1)
	action("fire_starboard", false)
	var count: int = c.shots_fired
	step(2)
	check(c.shots_fired == count, "release during reload never queues a later shot")
	c.cooldown = 0.2
	action("fire_starboard", true)
	step(0.3)
	action("fire_starboard", false)
	check(c.shots_fired == count + 1, "reload finishing during hold permits release shot")
	step(1.6)
	action("fire_starboard", true)
	step(0.2)
	action("astrolabe", true)
	action("fire_starboard", false)
	check(not c.aiming and c.shots_fired == count + 1, "Space cancels immediately even before next physics tick")
	action("fire_starboard", true)
	step(0.4)
	check(game.camera_mode == game.CameraMode.STARGAZING, "stargazing outranks aim and combat")
	action("astrolabe", false)
	step(0.6)
	check(not c.aiming and game.camera_mode == game.CameraMode.SAILING, "held F cannot restart aiming when stargazing ends")
	action("fire_starboard", false)
	check(c.shots_fired == count + 1, "release of cancelled hold cannot fire")
	action("fire_starboard", true)
	step(0.4)
	check(c.aiming and game.aim_camera_blend > 0.95, "fresh press resumes aiming and reaches camera framing promptly")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	action("fire_starboard", false)
	check(not c.aiming and c.shots_fired == count + 1, "focus loss cancels pending shot")
	for i in range(12):
		action("fire_starboard", true)
		step(0.03)
		action("fire_starboard", false)
		step(0.03)
	step(1.3)
	check(game.aim_camera_blend < 0.001 and game.camera_mode == game.CameraMode.SAILING, "rapid transitions settle back to sailing")
	game.enemy_encounters.enabled = true
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + c.starboard_direction() * 36
	step(0.7)
	check(game.camera_mode == game.CameraMode.COMBAT and game.combat_camera_blend > 0.9, "nearby hostile enables third-person combat framing")
	action("fire_starboard", true)
	step(0.4)
	check(game.camera_mode == game.CameraMode.AIMING, "manual aiming outranks automatic combat")
	action("astrolabe", true)
	step(0.3)
	check(game.camera_mode == game.CameraMode.STARGAZING, "sky overrides aim during live combat")
	action("astrolabe", false)
	step(0.5)
	check(game.camera_mode == game.CameraMode.COMBAT and not c.aiming, "cancelled aim returns directly to combat")
	action("fire_starboard", false)
	game.enemy_encounters.enabled = false
	ship.reset()
	# Exact yaw at several headings, under pronounced cosmetic roll/pitch.
	for degrees in [0, 90, 180, -90]:
		game.heading = deg_to_rad(degrees)
		game.boat.rotation.y = -game.heading
		game.boat_visual.rotation = Vector3(0.2, 0, -0.25)
		c.cooldown = 0
		action("fire_starboard", true)
		c.update_aim(0.25, -1)
		expected = c.aimed_direction()
		game.camera.rotation = Vector3(0.4, 1.7, 0.1)
		action("fire_starboard", false)
		var velocity: Vector3 = c.projectiles[-1].velocity
		velocity.y = 0
		check(velocity.normalized().dot(expected) > 0.99999, "heading %d: camera and wave roll cannot redirect shot" % degrees)
	# Camera composition at both arc limits and common aspect ratios.
	game.heading = game.TARGET_HEADING
	game.boat.rotation.y = -game.heading
	c.cooldown = 0
	action("fire_starboard", true)
	var no_auto_shots: int = c.shots_fired
	step(8)
	check(c.aiming and c.shots_fired == no_auto_shots, "indefinite preparation never repeats or auto-fires")
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for angle in [-20.0, 0.0, 20.0]:
			c.aim_degrees = angle
			c.update_aim(0, 0)
			game._update_view(0.5)
			var at: Vector2 = game.camera.unproject_position(c.shot_origin() + c.aimed_direction() * 32)
			check(game.camera.get_viewport().get_visible_rect().grow(-24).has_point(at), "sight visible at %+.0f degrees / %s" % [angle, dimensions])
		check(game.camera.position.y > game.ocean.height_at(Vector2(game.camera.position.x, game.camera.position.z)) + 1, "aim camera stays above moving water / %s" % dimensions)
	# Exact exponential transition timing is independent of frame partition.
	var poses: Array[Transform3D] = []
	for frames in [15, 30, 72]:
		game.aim_camera_blend = 0
		game.combat_camera_blend = 0
		game._camera_aim_degrees = 0
		game._camera_target_offset = Vector3.ZERO
		var pose := Transform3D.IDENTITY
		for i in range(frames):
			pose = game._sailing_camera_pose(Transform3D.IDENTITY, 0.5 / frames)
		poses.append(pose)
	check(poses[0].is_equal_approx(poses[1]) and poses[1].is_equal_approx(poses[2]), "camera blend matches at 30, 60 and 144 Hz")
	var anchor: Vector3 = game.boat.position + Vector3.UP * 2.8
	var at: Vector3 = game.boat.position + Basis(Vector3.UP, -game.heading) * game.aim_camera_offset
	var rock := StaticBody3D.new()
	rock.collision_layer = 1
	rock.position = anchor.lerp(at, 0.6)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 2
	shape.shape = box
	rock.add_child(shape)
	game.add_child(rock)
	await physics_frame
	game._update_view(0.1)
	var ray := PhysicsRayQueryParameters3D.create(anchor, game.camera.position, 1)
	check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "terrain feeler keeps camera on the visible side of nearby rock")
	rock.queue_free()
	await physics_frame
	c.cancel_aim()
	action("fire_starboard", false)
	# Outside-arc target cannot rotate the cannon or bend the projectile.
	ship.begin()
	ship.position = c.shot_origin() + c.starboard_direction().rotated(Vector3.UP, deg_to_rad(40)) * 28
	ship.position.y = 0
	ship.heading = game.heading
	ship.rotation.y = -ship.heading
	ship.velocity = Vector3.ZERO
	c.cooldown = 0
	action("fire_starboard", true)
	c.update_aim(1, -1)
	check(not c.aim_target().get("aligned", false), "enemy outside the 20 degree arc is not marked aligned")
	await physics_frame
	action("fire_starboard", false)
	for i in range(60):
		c.advance(1.0 / 60)
		await physics_frame
	check(ship.hull == ship.hull_capacity, "out-of-arc enemy is not hit by hidden launch correction")
	ship.reset()
	# Three broadside cases use actual swept collisions against moving enemy hulls.
	for angle in [0.0, 15.0, -15.0]:
		game.heading = game.TARGET_HEADING
		game.boat.rotation.y = -game.heading
		ship.begin()
		ship.position = c.shot_origin() + c.starboard_direction().rotated(Vector3.UP, deg_to_rad(angle)) * 28
		ship.position.y = 0
		ship.heading = game.heading
		ship.rotation.y = -ship.heading
		ship.velocity = Vector3.ZERO
		c.cooldown = 0
		action("fire_starboard", true)
		c.update_aim(absf(angle) / c.aim_speed_degrees, -signf(angle))
		await physics_frame
		action("fire_starboard", false)
		for frame in range(40):
			ship.velocity = Vector3(sin(game.heading), 0, -cos(game.heading)) * 2
			ship.position += ship.velocity / 60
			c.advance(1.0 / 60)
			await physics_frame
		check(ship.hull < ship.hull_capacity, "actual projectile hits moving hull at %+.0f degrees" % angle)
	ship.reset()
	c.cooldown = 0
	action("fire_starboard", true)
	game.damage_immunity = 0
	var hull: int = game.hull
	game.take_damage(1, "Aim vulnerability")
	check(game.hull == hull - 1 and c.aiming, "damage remains active while aiming")
	game.damage_immunity = 0
	game.take_damage(game.hull_capacity, "Sinking during aim")
	action("fire_starboard", false)
	check(game.state == game.State.LOST and not c.aiming and c.projectiles.is_empty(), "sinking cancels shot and clears projectiles")
	print("CANNON AIM CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

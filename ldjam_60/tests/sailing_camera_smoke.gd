extends "res://tests/sailing_camera_previews.gd"
## Camera geometry, response and real physics checks; controls have separate suites.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func settle(seconds: float = 1.0) -> void:
	for i in range(roundi(seconds*60)):
		game._update_view(1.0/60)

func arena_step(seconds: float) -> void:
	for frame in roundi(seconds * 60):
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check_arena() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	check(game.arena_mode and game.sailing_camera_rig == game.SailingCameraRig.CHASE,
		"normal arena scene selects the restored chase rig by default")
	var sail: Node3D = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail")
	check(sail.is_visible_in_tree() and not game.boat_visual.has_node("PlankedDeck"),
		"original canvas is visible and the deck-view floor is absent")
	action("begin_crossing", true)
	action("begin_crossing", false)
	arena_step(1.4)
	var at: Vector3 = game.boat.position
	var bearing: float = game.heading
	arena_step(1.0)
	check(game.boat.position.distance_to(at) > 5 and absf(game.heading - bearing) < 0.0001,
		"without steering, automatic forward sailing preserves its course")
	action("steer_starboard", true)
	arena_step(1.0)
	action("steer_starboard", false)
	check(game.heading > bearing + 0.4 and game.camera_mode == game.CameraMode.SAILING,
		"held D turns the actual boat while the chase camera follows")
	for size: Vector2i in [Vector2i(960,720), Vector2i(1280,720), Vector2i(1440,720)]:
		root.size = size
		settle()
		var visible := true
		for point: Vector3 in ship_bounds(game.boat_visual):
			visible = visible and not game.camera.is_position_behind(point) and root.get_visible_rect().grow(-16).has_point(game.camera.unproject_position(point))
		check(visible, "whole restored sailboat fits the arena view at %s" % size)
	key(KEY_E, true)
	key(KEY_E, false)
	arena_step(0.5)
	check(game.arena_cannon_view and not game.cannon.aiming and game.camera_mode == game.CameraMode.CANNON and game.aim_camera_blend == 1,
		"E toggles close view without changing weapon mode")
	key(KEY_SPACE, true)
	arena_step(1.0 / 60.0)
	key(KEY_SPACE, false)
	check(game.cannon.shots_fired == 1, "Space fires the actual cannon in close view")
	check(not game.reading and game.arena_cannon_view, "Space preserves close view and never raises the sextant")
	action("steer_port", true)
	key(KEY_E, true)
	key(KEY_E, false)
	arena_step(0.5)
	check(not game.arena_cannon_view and not game.cannon.aiming and game.turn_input == -1 and game.aim_camera_blend == 0,
		"E restores chase while held A keeps steering")
	action("steer_port", false)
	game.damage_immunity = 0
	game.take_damage(3, "Camera retry check")
	arena_step(1.0)
	check(game.state == game.State.LOST and game.camera.transform.is_finite(), "loss retains its finite ending camera")
	action("restart_crossing", true)
	action("restart_crossing", false)
	arena_step(1.4)
	var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
	check(game.state == game.State.SAILING and game.hull == game.hull_capacity and game._sailing_anchor.distance_to(center) < 1.1 and sail.is_visible_in_tree(),
		"retry restores hull, sail and chase history at the arena spawn")
	game.queue_free()
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	await process_frame
	check(game.get_viewport().get_camera_3d() == game.camera, "the existing main Camera3D remains the active transform writer")
	var min_height := INF
	var max_height := 0.0
	for degrees in [0,90,180,-90]:
		place(Vector3(390,0,350),deg_to_rad(degrees))
		game.actual_speed = game.SPEED
		settle()
		var rect := Rect2()
		var first := true
		var all_visible := true
		for point: Vector3 in ship_bounds(game.boat_visual):
			all_visible = all_visible and not game.camera.is_position_behind(point)
			var at: Vector2 = game.camera.unproject_position(point)
			all_visible = all_visible and root.get_visible_rect().grow(-20).has_point(at)
			rect = Rect2(at,Vector2.ZERO) if first else rect.expand(at)
			first = false
		var fraction := rect.size.y/root.get_visible_rect().size.y
		min_height = minf(min_height,fraction)
		max_height = maxf(max_height,fraction)
		check(all_visible and fraction > 0.40 and fraction < 0.56, "whole sailboat including its tall mast fits within 40-56 percent height at heading %d (%.1f%%)" % [degrees,fraction*100])
		check(absf(game.camera.basis.x.y) < 0.00001, "level horizon at heading %d" % degrees)
	place(Vector3(390,0,350),0)
	settle()
	var rest_fov: float = game.camera.fov
	game.actual_speed = game.SPEED
	settle(2.0)
	check(game.camera.fov > rest_fov+2.5 and game.camera.fov < rest_fov+3.1, "speed eases in a restrained three-degree FOV increase")
	# Constant targets converge the same way regardless of the update frequency.
	var poses: Array[Transform3D] = []
	for hz in [30,60,144]:
		place(Vector3(390,0,350),0)
		game.boat.position += Vector3(8,0,-6)
		game.heading = PI/2
		game.actual_speed = game.SPEED
		var pose := Transform3D.IDENTITY
		for frame in range(hz/2):
			pose = game._normal_sailing_pose(1.0/hz)
		poses.append(pose)
	check(poses[0].is_equal_approx(poses[1]) and poses[1].is_equal_approx(poses[2]), "follow, rotation and speed response agree at 30, 60 and 144 Hz")
	place(Vector3(390,0,350),0)
	game.actual_speed = game.SPEED
	for frame in range(120):
		game.heading += game.TURN_SPEED/60.0
		game.boat.position += Vector3(sin(game.heading),0,-cos(game.heading))*game.SPEED/60.0
		game._update_view(1.0/60)
	var center: Vector3 = game.boat.position+Basis(Vector3.UP,-game.heading)*game.BoatWaveMotion.HULL_CENTER
	var lag: float = absf(wrapf(game.heading-game._sailing_heading,-PI,PI))
	check(game._sailing_anchor.distance_to(center) < 1.1, "follow lag stays below 1.1m at cruising speed")
	check(lag > deg_to_rad(2) and lag < deg_to_rad(8), "maximum-rate turns keep a responsive cinematic heading lag (%.2f degrees)" % rad_to_deg(lag))
	check(absf(game.camera.basis.x.y) < 0.00001, "turning does not tilt the horizon")
	# Real moving crests rock the visible ship while the camera stays level.
	place(Vector3(390,0,350),0)
	check(game.deck_response.impact_count == 0 and game.turbulence_effects.emitted == 0,
		"calm chase view does not invent wave contacts or spray bursts")
	game.ocean.wave_field.add_wave(Vector2(390,365),Vector2(0,-1),1.85,9,45,8,0)
	var previous_y: float = game.camera.position.y
	var max_y_step := 0.0
	var water_safe := true
	var horizon_safe := true
	var max_roll := 0.0
	for frame in range(240):
		game.sea_time = frame/60.0
		game._update_view(1.0/60)
		max_y_step = maxf(max_y_step,absf(game.camera.position.y-previous_y))
		previous_y = game.camera.position.y
		var at: Vector3 = game.camera.position
		water_safe = water_safe and at.y > game.ocean.height_at(Vector2(at.x,at.z))+1.19
		horizon_safe = horizon_safe and absf(game.camera.basis.x.y)<0.00001
		max_roll = maxf(max_roll,absf(game.boat_motion.pitch)+absf(game.boat_motion.roll))
	check(max_roll > 0.02 and horizon_safe, "moving wave crests rock the hull without inheriting camera pitch or roll")
	check(game.deck_response.impact_count > 0 and game.turbulence_effects.emitted == game.deck_response.impact_count,
		"actual descending crest still drives synchronized contact spray in chase view")
	check(water_safe and max_y_step < 0.06, "wave-following camera clears water without vertical jolts (max %.4fm/frame)" % max_y_step)
	# Stress the water floor with the maximum allowed simultaneous crests.
	game.ocean.wave_field.clear()
	for i in range(4):
		game.ocean.wave_field.add_wave(Vector2(game.camera.position.x,game.camera.position.z+0.1),Vector2(0,-1),2,20,60,0.1,0)
	game.sea_time = 1.0
	game._update_view(1.0/60)
	var camera_at: Vector3 = game.camera.position
	check(camera_at.y > game.ocean.height_at(Vector2(camera_at.x,camera_at.z))+1.19, "camera remains above four overlapping maximum-height crests")
	game.reading = true
	game.read_blend = 1.0
	game._update_view(0)
	camera_at = game.camera.position
	check(camera_at.y > game.ocean.height_at(Vector2(camera_at.x,camera_at.z))+1.19, "reframed sighting camera retains water clearance above four maximum-height crests")
	# A physical wall behind the boat must shorten the camera arm with margin.
	place(Vector3(390,0,350),0)
	settle()
	var wanted: Transform3D = game._normal_sailing_pose(0)
	var anchor: Vector3 = game._camera_shore_anchor()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = anchor.lerp(wanted.origin,0.6)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5,8,1)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await physics_frame
	game._update_view(1.0/60)
	var short_distance: float = anchor.distance_to(game.camera.position)
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(anchor,game.camera.position,1)
	check(short_distance < anchor.distance_to(wanted.origin)*0.65 and space.intersect_ray(ray).is_empty(), "actual terrain-layer obstacle retracts the chase camera before clipping")
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	probe.shape = sphere
	probe.collision_mask = 1
	probe.transform = Transform3D(Basis.IDENTITY,game.camera.position)
	check(space.intersect_shape(probe).is_empty(), "camera retains physical clearance for the near plane")
	wall.queue_free()
	await physics_frame
	game._update_view(1.0/60)
	var recovering: float = anchor.distance_to(game.camera.position)
	check(recovering > short_distance and recovering < anchor.distance_to(wanted.origin)*0.85, "clearing an obstacle eases outward instead of snapping")
	settle()
	check(anchor.distance_to(game.camera.position) > anchor.distance_to(wanted.origin)*0.98, "camera recovers its full sailing distance")
	# Several real coast poses, with the chase camera facing back toward shore.
	for at: Vector3 in [Vector3(-151,0,-40),Vector3(-149,0,-40),Vector3(142,0,15)]:
		place(at,-PI/2 if at.x<0 else PI/2)
		settle(0.25)
		var start: Vector3 = game._camera_shore_anchor()
		ray = PhysicsRayQueryParameters3D.create(start,game.camera.position,1)
		check(space.intersect_ray(ray).is_empty(), "real rocky shore stays outside the camera sight arm at %s" % at)
	# Check the same near-plane protection on the forward sighting arm.
	place(Vector3(390,0,350),0)
	game.reading = true
	game.read_blend = 1.0
	game._update_view(0)
	var sight_at: Vector3 = game.camera.position
	anchor = game._camera_shore_anchor()
	wall = StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = anchor.lerp(sight_at,0.6)
	shape = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await physics_frame
	game._update_view(1.0/60)
	ray = PhysicsRayQueryParameters3D.create(anchor,game.camera.position,1)
	probe.transform = Transform3D(Basis.IDENTITY,game.camera.position)
	check(anchor.distance_to(game.camera.position) < anchor.distance_to(sight_at)*0.6 and space.intersect_ray(ray).is_empty() and space.intersect_shape(probe).is_empty(), "sighting arm retracts before real terrain and retains near-plane clearance")
	wall.queue_free()
	await physics_frame
	game._update_view(1.0/60)
	check(game.camera.position.distance_to(sight_at) < 0.001, "sighting arm clears normally after the obstruction is removed")
	game.restart()
	var departure_center: Vector3 = game.boat.position+Basis(Vector3.UP,-game.heading)*game.BoatWaveMotion.HULL_CENTER
	departure_center.y += clampf((game.boat_motion.heave-game.ocean_settings.sea_level)*game.ocean_settings.camera_bob_strength,-0.18,0.18)*game.motion_amount()
	check(game._sailing_anchor.distance_to(departure_center)<0.02 and is_equal_approx(game._sailing_heading,game.START_HEADING) and is_equal_approx(game._camera_clear_fraction,1.0), "replay resets follow history to the actual departure")
	game.queue_free()
	await process_frame
	await check_arena()
	print("SAILING CAMERA: %d checks, %d failures; ship bounds %.1f-%.1f%%" % [checks,failures,min_height*100,max_height*100])
	quit(0 if failures == 0 else 1)

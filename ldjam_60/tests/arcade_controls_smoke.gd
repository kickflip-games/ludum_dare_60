extends SceneTree
## Physical input edges and live ballistics; optional native-renderer evidence.
var game
var checks := 0
var failures := 0
var output := ""
var captured_shot := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.echo = echo
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(amount: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(amount, 0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func step(seconds: float, hz: int = 60) -> void:
	for frame in roundi(seconds * hz):
		game._physics_process(1.0 / hz)
		game.cannon.advance(1.0 / hz)
	game.hud._process(seconds)

func fresh() -> void:
	for code in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_E, KEY_F, KEY_R]:
		key(code, false)
	click(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game.heading = 0.0
	step(0.05)
	game._update_view(1.0)
	game.cannon.update_cone_feedback()

func capture(label: String) -> void:
	if output.is_empty():
		return
	game.hud.queue_redraw()
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "native capture " + label)

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
	await capture("00-controls")
	for hz in [30, 60, 120]:
		fresh()
		key(KEY_A, true)
		step(0.5, hz)
		check(game.heading < -0.2 and game.turn_input == -1 and is_zero_approx(game.cannon.aim_degrees), "%d Hz: A steers with a fixed starboard cannon" % hz)
		key(KEY_A, false)
		key(KEY_D, true)
		key(KEY_SPACE, true)
		step(0.05, hz)
		check(game.cannon.shots_fired == 1 and game.turn_input == 1 and not game.reading, "%d Hz: Space fires while D steers, never raises sextant" % hz)
		var yaw: float = game.heading
		step(0.5, hz)
		check(game.heading > yaw + 0.2 and game.cannon.cooldown > 0 and game.cannon.shots_fired == 1, "%d Hz: steering remains live during reload" % hz)
		step(2.6, hz)
		check(game.cannon.shots_fired == 3, "%d Hz: held fire repeats at 1.5-second reload" % hz)
		key(KEY_SPACE, false)
		step(1.6, hz)
		check(game.cannon.shots_fired == 3, "%d Hz: release stops automatic fire" % hz)
	fresh()
	click(true)
	key(KEY_SPACE, true)
	step(0.1)
	check(game.cannon.shots_fired == 1, "both fire inputs together produce one shot")
	key(KEY_SPACE, false)
	step(1.5)
	check(game.cannon.shots_fired == 2, "releasing Space leaves held click firing")
	click(false)
	step(1.6)
	check(game.cannon.shots_fired == 2, "releasing both inputs stops firing")
	key(KEY_SPACE, true)
	click(true)
	step(0.1)
	click(false)
	step(1.5)
	check(game.cannon.shots_fired == 4, "releasing click leaves Space firing")
	fresh()
	key(KEY_E, true)
	key(KEY_F, true)
	step(0.5)
	check(game.cannon.shots_fired == 0 and not game.cannon.aiming and game.camera_mode == game.CameraMode.SAILING, "E/F have no arena action or camera mode")
	key(KEY_LEFT, true)
	step(0.4)
	check(game.turn_input == -1, "left arrow steers")
	key(KEY_RIGHT, true)
	step(0.1)
	check(game.turn_input == 0, "opposing steer inputs cancel")
	key(KEY_LEFT, false)
	step(0.4)
	check(game.turn_input == 1, "right arrow remains held after left release")
	fresh()
	await capture("01-default-sailing")
	var aim: float = game.cannon.aim_degrees
	var heading: float = game.heading
	mouse(100000)
	game._update_view(1.0 / 60)
	check(game.look_target == -45 and game.look_yaw < 0 and game.look_yaw > -45, "mouse yaw clamps target and approaches smoothly")
	check(game.heading == heading and game.cannon.aim_degrees == aim, "mouse changes neither heading nor barrel direction")
	for frame in 60:
		game._update_view(1.0 / 60)
	check(game.look_yaw < -44.9, "camera reaches its bounded maximum before recenter delay")
	await capture("02-maximum-look")
	for frame in 240:
		game._update_view(1.0 / 60)
	check(absf(game.look_yaw) < 0.1, "idle mouse smoothly recentres after 1.5 seconds")
	mouse(-100000)
	game._update_view(0.1)
	check(game.look_target == 45 and game.look_yaw > 0 and game.look_idle < 0.2, "new mouse input immediately interrupts recentering")
	var bounded := true
	for frame in 720:
		game.heading = frame * TAU / 360.0
		game._update_view(1.0 / 60)
		bounded = bounded and absf(game.look_yaw) <= 45.001 and absf(wrapf(game._sailing_heading - game.heading, -PI, PI)) < 0.25 and absf(game.camera.basis.x.y) < 0.00001
	check(bounded, "two full ship rotations preserve bounded relative look and level horizon")
	fresh()
	var expected: Dictionary = game.cannon.predict_trajectory()
	check(expected.points[0].distance_to(game.cannon.shot_origin()) < 0.00001, "trajectory starts at actual rocking muzzle")
	game.cannon.fire()
	var accurate := true
	for i in range(1, mini(expected.points.size() - 1, 60)):
		game.cannon.advance(1.0 / 60)
		if game.cannon.projectiles.is_empty():
			accurate = false
			break
		accurate = accurate and game.cannon.projectiles[0].physics_position.distance_to(expected.points[i]) < 0.0001
	check(accurate, "preview samples agree with actual integrated projectile positions")
	await trajectory_cases()
	await safety()
	await lifecycle()
	await moving_combat()
	print("ARCADE CONTROLS: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func trajectory_cases() -> void:
	fresh()
	game.boat_visual.rotation.z = -0.25
	game.boat_visual.rotation.x = 0.12
	game.cannon.update_cone_feedback()
	var predicted: Dictionary = game.cannon.predict_trajectory()
	check(predicted.points[1].is_equal_approx(game.cannon.shot_origin() + game.cannon.launch_velocity() / Engine.physics_ticks_per_second), "ballistic diagnostic uses the actual muzzle and launch lift")
	var end: Vector3 = predicted.points[predicted.points.size() - 1]
	check(Vector2(end.x - game.cannon.cone_origin().x, end.z - game.cannon.cone_origin().z).length() <= 65.001, "ballistic endpoint obeys the visible cone range")
	game.cannon.fire()
	for frame in 120:
		game.ocean.wave_time += 1.0 / 60
		game.cannon.advance(1.0 / 60)
	check(game.cannon.projectiles.is_empty() and game.cannon.feedback.contains("SPLASH"), "untargeted real shot ends in water or at its range limit")
	fresh()
	var ship = game.enemy_encounters.ship
	ship.begin(game.cannon.cone_point(0, 18))
	ship.position.y = 0
	ship.rotation.y = 0
	await physics_frame
	await process_frame
	game.cannon.update_cone_feedback()
	check(ship.aim_highlight and game.cannon.selected_target == ship, "eligible enemy receives subtle cone highlight")
	await capture("03-aiming-indicator")
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 10, 12)
	collision.shape = box
	obstacle.add_child(collision)
	game.add_child(obstacle)
	obstacle.position = game.cannon.cone_point(0, 12)
	await physics_frame
	await process_frame
	game.cannon.update_cone_feedback()
	check(not ship.aim_highlight and game.cannon.selected_target == null, "nearer obstacle blocks target selection and highlight")
	obstacle.queue_free()
	await physics_frame

func safety() -> void:
	fresh()
	mouse(-100000)
	step(0.5)
	var desired: Transform3D = game._normal_sailing_pose(0)
	var anchor: Vector3 = game._camera_shore_anchor()
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 12, 3)
	collision.shape = box
	obstacle.add_child(collision)
	game.add_child(obstacle)
	obstacle.position = anchor.lerp(desired.origin, 0.65)
	await physics_frame
	game._update_view(1.0 / 60)
	check(game.camera.position.distance_to(anchor) < desired.origin.distance_to(anchor) * 0.7, "obstructed mouse camera retracts before solid geometry")
	check(game.camera.position.y >= game.ocean.height_at(Vector2(game.camera.position.x, game.camera.position.z)) + 1.19, "camera retains ocean clearance")
	obstacle.queue_free()
	await physics_frame
	var before: float = game._camera_clear_fraction
	game._update_view(1.0 / 60)
	check(game._camera_clear_fraction > before and game._camera_clear_fraction < 1, "camera eases outward when obstruction clears")

func lifecycle() -> void:
	for ending in [game.State.LOST, game.State.ARRIVED, game.State.CASTING_OFF]:
		fresh()
		key(KEY_SPACE, true)
		click(true)
		key(KEY_D, true)
		mouse(400)
		step(0.1)
		if ending == game.State.LOST:
			game.take_damage(game.hull, "arcade lifecycle test")
		elif ending == game.State.ARRIVED:
			game.state = ending
			game.advance_sailing(0.001, 0)
			# Survival director's win calls the same cleanup from advance_sailing.
			game._clear_player_controls()
			game.cannon.reset()
		else:
			game.restart()
		step(2.0)
		check(game.look_yaw == 0 and game.cannon.shots_fired == 0 and game.cannon.projectiles.is_empty() and game.turn_input == 0, "ending/restart %d clears fire, look and steering" % ending)
		game.restart()
		step(2.0)
		check(game.state == game.State.SAILING and game.cannon.shots_fired == 0, "ending %d retry has no phantom shots" % ending)
	fresh()
	key(KEY_SPACE, true)
	click(true)
	key(KEY_A, true)
	mouse(200)
	step(0.1)
	var shots: int = game.cannon.shots_fired
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(2.0)
	mouse(900)
	check(game.cannon.shots_fired == shots and game.look_yaw == 0 and game.turn_input == 0 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus loss clears controls and releases mouse")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	key(KEY_SPACE, true, true)
	step(1.7)
	check(game.cannon.shots_fired == shots and game.look_yaw == 0, "focus return and OS key-repeat cannot revive held shots or mouse offset")
	key(KEY_SPACE, false)
	click(false)
	step(0.1)
	click(true)
	step(0.1)
	check(game.cannon.shots_fired == shots + 1, "fresh click works after focus return")

func moving_combat() -> void:
	fresh()
	game.boat.position = Vector3(310, 0, 342)
	game._update_view(1.0)
	game.enemy_encounters.enabled = true
	game.enemy_encounters.phase = game.enemy_encounters.Phase.STOPPED
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + Vector3(32, 0, -4))
	await physics_frame
	var pilot = load("res://tests/cannon_sweep_pilot.gd").new()
	var moved := false
	var simultaneous := false
	mouse(150)
	var start: Vector3 = ship.position
	var total_shots := 0
	var total_hits := 0
	for frame in 2400:
		if frame >= 6:
			pilot.update(game, 1.0 / 60)
		# Gentle live look adjustments throughout the encounter; no aim writes.
		mouse(sin(frame * 0.03) * 1.4)
		var before: int = game.cannon.shots_fired
		# Deliberate combined-input opening burst tests steering while firing.
		if frame < 6:
			mouse(1.4)
			key(KEY_A, true)
			key(KEY_SPACE, true)
		elif frame == 6:
			key(KEY_A, false)
			key(KEY_SPACE, false)
		step(1.0 / 60)
		total_shots = maxi(total_shots, game.cannon.shots_fired)
		total_hits = maxi(total_hits, game.cannon.targets_hit)
		moved = moved or ship.position.distance_to(start) > 2
		if game.cannon.shots_fired > before and absf(game.turn_input) > 0 and absf(game.look_target) > 0:
			simultaneous = true
		if game.cannon.shots_fired > before and not captured_shot and frame > 0:
			await capture("04-firing-at-moving-enemy")
			captured_shot = true
		if frame % 30 == 0:
			await process_frame
		if ship.hull == 0 or game.hull == 0:
			break
	print("MOVING COMBAT: shots=%d hits=%d player=%d enemy=%d simultaneous=%s" % [total_shots, total_hits, game.hull, ship.hull, simultaneous])
	check(simultaneous and moved, "in-engine moving enemy encounter includes simultaneous steering, mouse movement and fire")
	check(ship.hull == 0 and game.cannon.targets_hit >= 2 and game.hull > 0, "input timing pilot hits and sinks moving cutter with real cannonballs")
	pilot.release()

extends SceneTree
## Run: Godot --headless --path ldjam_60 --script res://tests/crossing_smoke.gd --fixed-fps 60

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		push_error("FAIL: " + message)
		failures += 1


func _run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ocean-preset="):
			var preset := argument.trim_prefix("--ocean-preset=")
			if preset in ["calm", "choppy", "stormy"]:
				game.ocean_settings = load("res://game/ocean/presets/" + preset + ".tres")
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	check(game.state == game.State.READY, "starts on the objective and controls screen")
	check(not game.cannon.fire(), "cannon cannot fire before cast off")
	game._physics_process(1.0)
	check(game.boat.position.length() < 0.01, "boat waits for cast off")
	await click_menu_button(game)
	check(game.state == game.State.CASTING_OFF, "clicking Start begins the camera transition")
	if game.state != game.State.CASTING_OFF:
		print("BUTTON DIAGNOSTIC: root=%s, rect=%s, visible=%s" % [root.size, game.hud.action_button.get_global_rect(), game.hud.action_button.is_visible_in_tree()])
		quit(1)
		return
	var title_position: Vector3 = game.camera.position
	Input.action_press("steer_port")
	Input.action_press("astrolabe")
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	check(game.boat.position.length() < 0.01 and game.elapsed == 0.0 and game.heading == game.START_HEADING,
		"movement, timer, and steering remain stopped during cast off")
	check(not game.reading and not game.cannon.fire(), "instrument and cannon are blocked during transition")
	Input.action_release("steer_port")
	Input.action_release("astrolabe")
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	check(game.state == game.State.SAILING and game.camera.position.distance_to(title_position) > 2.0,
		"short transition reaches the helm before sailing starts")
	Input.action_press("astrolabe")
	game._physics_process(1.0)
	check(absf(game.boat.position.length() - game.SPEED) < 0.1, "boat continues forward during a reading")
	check(game.has_reading and game.reading, "holding SPACE takes a bearing")
	check(not game.cannon.fire(), "instrument must be lowered before firing")
	check(game.camera.rotation.x > deg_to_rad(50.0), "reading tilts the helm camera into the sky")
	Input.action_release("astrolabe")
	var saved_reading: float = game.last_reading
	Input.action_press("steer_port")
	game._physics_process(0.5)
	Input.action_release("steer_port")
	check(game.heading < saved_reading, "port steering turns left responsively")
	check(game.last_reading == saved_reading, "lowered instrument retains only the last reading")
	check(game.camera.rotation.x < 0.0, "lowering the instrument restores the forward sea view")
	check(game.cannon.fire(), "F can fire the starboard cannon while sailing")
	var velocity: Vector3 = game.cannon.projectiles[0].velocity
	var forward := Vector3(sin(game.heading), 0.0, -cos(game.heading))
	check(absf(velocity.normalized().dot(forward)) < 0.001 and velocity.dot(game.cannon.starboard_direction()) > 0.0,
		"shot travels perpendicular to the bow, toward starboard")
	check(not game.cannon.fire(), "reload prevents immediate repeated shots")
	game.cannon.advance(0.5)
	check(not game.cannon.fire(), "cooldown remains active for the stated reload period")
	game.cannon.advance(1.1)
	check(game.cannon.fire(), "cannon can fire again after reload")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	var debris: StaticBody3D
	var rock: StaticBody3D
	for obstacle: Dictionary in game.obstacles:
		if obstacle.kind == "debris" and debris == null:
			debris = obstacle.body
		if obstacle.kind == "rock" and rock == null:
			rock = obstacle.body
	game.boat.position = debris.position - Vector3(22.0, 0.0, -2.6)
	game.heading = 0.0
	game._update_view(1.0)
	await physics_frame
	game.cannon.fire()
	for step in range(120):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
		if debris.get_meta("destroyed"):
			break
	check(debris.get_meta("destroyed") and not debris.visible and debris.collision_layer == 0,
		"swept cannonball hit destroys floating timber and clears its collision")
	check("SHATTERED" in game.cannon.feedback, "timber destruction gives readable impact feedback")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	await physics_frame
	check(debris.visible and debris.collision_layer == 1 and not debris.get_meta("destroyed"),
		"restart restores destroyed hazards")
	check(game.cannon.projectiles.is_empty() and game.cannon.cooldown == 0.0,
		"restart clears cannonballs and reload")
	game.boat.position = rock.position - Vector3(22.0, 0.0, -2.6)
	game.heading = 0.0
	game._update_view(1.0)
	await physics_frame
	game.cannon.fire()
	for step in range(120):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
		if game.cannon.projectiles.is_empty():
			break
	check(rock.visible and rock.collision_layer == 1 and not rock.get_meta("destroyed"),
		"cannonballs cannot destroy rocks or remove their collision")
	check("STEER AROUND" in game.cannon.feedback, "solid impacts tell the player to dodge")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	await physics_frame
	for step in range(1100):
		game.advance_sailing(1.0 / 60.0, 0.0)
		await physics_frame
		if game.state != game.State.SAILING:
			break
	check(game.state == game.State.LOST, "real physics collision with the first rock ends the crossing")
	check("rock" in game.failure_reason, "collision feedback identifies the hazard")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	await physics_frame
	check(game.state == game.State.SAILING and game.boat.position.length() < 0.01, "R restart clears the collision and resets the crossing")
	check(not game.beacon_seen and not game.has_reading, "restart clears beacon and bearing memory")
	# Progress measures displacement toward the destination, never total path length.
	game.boat.position = game.course_forward() * 100.0
	var progress: float = game.journey_progress()
	for lane in [50.0, -50.0, 0.0]:
		game.boat.position = game.course_forward() * 100.0 + game.course_right() * lane
		check(absf(game.journey_progress() - progress) < 0.001, "lateral travel does not add journey progress")
	game.boat.position = game.target + game.course_right() * 150.0
	game.advance_sailing(0.001, 0.0)
	check(game.state == game.State.SAILING and game.journey_progress() < 1.0,
		"passing the destination offshore cannot complete the crossing")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	var serpent: StaticBody3D = game.sea_creatures.creatures[0].body
	game.boat.position = serpent.position - Vector3(22.0, 0.0, -2.6)
	game.heading = 0.0
	game._update_view(1.0)
	await physics_frame
	var cue: Dictionary = game.cannon.aim_target()
	check(not cue.is_empty() and cue.aligned and cue.kind == "REEF SERPENT",
		"starboard cue identifies a creature and confirms a real broadside line")
	game.cannon.fire()
	for step in range(120):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
		if serpent.get_meta("destroyed"):
			break
	check(serpent.get_meta("destroyed") and not serpent.visible and serpent.collision_layer == 0,
		"cannonball destroys a creature and removes its threat")
	check("SERPENT DRIVEN UNDER" in game.cannon.feedback, "creature hit gives a visible defeat reaction")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	check(serpent.visible and not serpent.get_meta("destroyed") and serpent.collision_layer == 1,
		"retry restores creature visibility and collision")
	game.boat.position = serpent.position + Vector3(0.0, 0.0, 6.5)
	game.heading = 0.0
	game._update_view(1.0)
	await physics_frame
	check(game.sea_creatures.approach_warning() != "", "approaching creature gives a clear warning")
	for step in range(90):
		game.advance_sailing(1.0 / 60.0, 0.0)
		await physics_frame
		if game.state != game.State.SAILING:
			break
	check(game.state == game.State.LOST and "reef serpent" in game.failure_reason,
		"ignoring a nearby creature can cause an actual hull collision")
	await click_menu_button(game)
	check(game.state == game.State.CASTING_OFF, "failure Retry button cleanly starts another crossing")
	game._physics_process(game.CAST_OFF_SECONDS)
	# Follow a route with port and starboard detours, without shooting creatures.
	var route := [Vector2(45, -14), Vector2(100, -15), Vector2(145, -2),
		Vector2(195, -17), Vector2(235, -17), Vector2(278, 12),
		Vector2(335, 9), Vector2(377, -11), Vector2(417, -14),
		Vector2(449, -16), Vector2(490, -5), Vector2(530, 0)]
	var waypoint: int = 0
	game.heading = game.TARGET_HEADING
	var max_lateral: float = 0.0
	for step in range(9000):
		var goal: Vector3 = game.course_forward() * route[waypoint].x + game.course_right() * route[waypoint].y
		if game.boat.position.distance_to(goal) < 9.0 and waypoint < route.size() - 1:
			waypoint += 1
		var direction: Vector3 = goal - game.boat.position
		var desired: float = atan2(direction.x, -direction.z)
		var error: float = wrapf(desired - game.heading, -PI, PI)
		var steering: float = clampf(error * 3.0, -1.0, 1.0)
		game.advance_sailing(1.0 / 60.0, steering)
		max_lateral = maxf(max_lateral, absf(game.boat.position.dot(game.course_right())))
		await physics_frame
		if game.state != game.State.SAILING:
			break
	check(max_lateral > 10.0, "test route makes meaningful steering detours")
	check(game.beacon_seen, "lighthouse appears late in the approach")
	check(game.state == game.State.ARRIVED, "destination is reachable after multiple steering detours")
	print("Crossing result: state=%s, seconds=%.1f, position=%s" % [game.state, game.elapsed, game.boat.position])
	check(game.journey_progress() == 1.0, "actual harbour arrival completes the journey bar")
	var arrived_position: Vector3 = game.boat.position
	var arrived_time: float = game.elapsed
	game._physics_process(2.0)
	check(game.boat.position == arrived_position and game.elapsed == arrived_time,
		"arrival camera scene stops boat movement and preserves completion time")
	await click_menu_button(game)
	check(game.state == game.State.CASTING_OFF and game.boat.position.length() < 0.01 and game.elapsed == 0.0,
		"Play Again button resets position and timers before the new transition")
	check(not game.has_reading and not game.beacon_seen and game.cannon.projectiles.is_empty()
		and game.cannon.cooldown == 0.0 and game.journey_progress() == 0.0,
		"replay clears navigation memory, lighthouse, projectiles, reload, and journey bar")
	game.queue_free()
	await process_frame
	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func click_menu_button(game) -> void:
	await process_frame
	game.hud._sync_button()
	var center: Vector2 = game.hud.action_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = center
	press.global_position = center
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	root.push_input(release, true)
	await process_frame

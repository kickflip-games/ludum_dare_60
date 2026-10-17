extends SceneTree
## Independent vector checks and production input/state transitions; no route-solving HUD.
const Bearings = preload("res://game/navigation_bearings.gd")
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)


func step(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		game._physics_process(1.0 / 60.0)
	game.hud._process(0.0)


func _run() -> void:
	# Expected results are compass conventions, independent of implementation.
	for cardinal in [[Vector3(0, 50, -100), 0], [Vector3(100, -20, 0), 90], [Vector3(0, 20, 100), 180], [Vector3(-100, 0, 0), 270]]:
		check(Bearings.compass_degrees(Bearings.bearing_to(Vector3.ZERO, cardinal[0])) == cardinal[1], "world cardinal %s is %03d° regardless of height" % cardinal)
	for example in [[350, 10, 20], [10, 350, -20], [330, 10, 40], [10, 330, -40], [0, 180, -180], [180, 0, -180], [1070, -710, 20], [-710, 1070, -20]]:
		var correction := rad_to_deg(Bearings.signed_turn(deg_to_rad(example[0]), deg_to_rad(example[1])))
		check(is_equal_approx(correction, float(example[2])) and absf(correction) <= 180.0, "%s° to %s° gives signed turn %+d°" % example)
	for example in [[-720, 0], [-320, 40], [-40, 320], [359.4, 359], [359.9, 0], [360, 0], [720, 0]]:
		check(Bearings.compass_degrees(deg_to_rad(example[0])) == example[1], "absolute %s° displays %03d°" % example)
	for example in [[2.4, 0], [2.6, 5], [357.4, 355], [357.6, 0]]:
		check(Bearings.compass_degrees(deg_to_rad(example[0]), 5) == example[1], "approximate reading %s° rounds to %03d°" % example)
	check(Bearings.bearing_to(Vector3(2, 0, 3), Vector3(2, 30, 3), 0.73) == 0.73, "coincident planar destination retains the heading")
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.ocean.wave_field.clear()
	game.enemy_encounters.enabled = false
	var original_bearing: float = game.destination_bearing()
	game.position = Vector3(23, 0, -17)
	game.voyage.set_target(game)
	check(absf(angle_difference(original_bearing, game.destination_bearing())) < 0.00001, "boat and target use the same global coordinates")
	game.position = Vector3.ZERO
	game.voyage.set_target(game)
	game.boat.position = Vector3(0, 0, 104)
	check(absf(rad_to_deg(game.destination_bearing()) + 41.605) < 0.02, "requested original departure points 318.4 degrees toward Wreck, not north")
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		for at: Vector3 in [Vector3(24, 0, 148), Vector3(-221, 0, -109), Vector3(-145, 0, -205), Vector3(356, 0, 74), Vector3(139, 0, 82)]:
			game.boat.position = at
			var toward: Vector3 = (game.target - at).normalized()
			var ray: Vector3 = game.guiding_star_direction()
			check(Vector3(ray.x, 0, ray.z).normalized().dot(toward) > 0.99999 and is_equal_approx(ray.length(), 1.0), "stage %d at %s star azimuth matches actual destination" % [stage, at])
			check(is_equal_approx(ray.y, sin(deg_to_rad(60))), "stage %d retains sixty-degree elevation" % stage)
			for degrees in [0, 10, 90, 180, 270, 350]:
				game.heading = deg_to_rad(degrees)
				var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
				var right := Vector3(cos(game.heading), 0, sin(game.heading))
				var reference := atan2(toward.dot(right), toward.dot(forward))
				game.reading = true
				game.read_blend = 1.0
				game.focus_elapsed = 1.8
				game._update_view(0.0)
				check(absf(angle_difference(reference, game.destination_turn())) < 0.00001 and ray.is_equal_approx(game.guiding_star_direction()), "stage %d heading %d changes view, never the destination ray" % [stage, degrees])
				check(ray.is_equal_approx(game.sky_material.get_shader_parameter("guiding_star")), "stage %d heading %d shader uses the same live ray" % [stage, degrees])
	Input.action_press("astrolabe")
	# Independent expected screen sides: world target fixtures, actual A/D recovery.
	game.boat.position = Vector3(400, 0, -360)
	for example in [[0, 0, 0], [0, -45, -1], [0, 45, 1], [0, 180, -1], [359, 1, 1], [1, 359, -1], [0, 140, 1], [0, -140, -1], [179, -179, 1], [-179, 179, -1]]:
		game.heading = deg_to_rad(example[0])
		var bearing: float = deg_to_rad(example[1])
		game.target = game.boat.position + Vector3(sin(bearing), 0, -cos(bearing)) * 300
		game._update_view(0.0)
		var guidance: Dictionary = game.hud.star_guidance()
		var x: float = guidance.position.x - game.hud.size.x * 0.5
		check(absf(x) < 0.1 if example[2] == 0 else signf(x) == example[2], "heading %s / destination %s has correct projected or peripheral side" % [example[0], example[1]])
		if absf(example[1]) >= 140 and example[0] == 0:
			check(not guidance.visible, "astern destination uses peripheral assistance")
		if example[2] != 0:
			game.wave_sailing.reset()
			var error: float = absf(game.destination_turn())
			Input.action_press("steer_port" if example[2] < 0 else "steer_starboard")
			step(0.25)
			Input.action_release("steer_port")
			Input.action_release("steer_starboard")
			# Very small wrap errors can overshoot; signed heading motion still agrees.
			check(absf(game.destination_turn()) < error if error > 0.1 else signf(angle_difference(deg_to_rad(example[0]), game.heading)) == example[2], "actual rudder follows the visual indication across wrap/astern")
	# Force vertical frustum exits and a ray behind the actual camera. These
	# fixtures test projection geometry without changing the navigation target.
	game.heading = 0.0
	game.target = game.boat.position + Vector3.FORWARD * 300
	game._update_view(0.0)
	game.camera.fov = 30.0
	for pitch in [0.0, 89.0, -60.0]:
		game.camera.rotation.x = deg_to_rad(pitch)
		var guidance: Dictionary = game.hud.star_guidance()
		check(not guidance.visible and guidance.position.is_finite(), "pitch %s outside/behind ray gives finite edge assistance" % pitch)
		check(guidance.position.y < 30 if pitch != 89.0 else guidance.position.y > game.hud.size.y - 30, "pitch %s chooses actual top/bottom edge" % pitch)
	game._update_view(0.0)
	# Wrong direction is not silently treated as a correct northward course.
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		game.boat.position = Vector3(400, 0, -360)
		var before: float = game.boat.position.distance_to(game.target)
		game.heading = game.destination_bearing() + PI
		game.wave_sailing.reset()
		Input.action_press("astrolabe")
		step(1.9)
		check(game.boat.position.distance_to(game.target) > before + 10 and not game.hud.star_guidance().visible, "stage %d sailing away leaves the star astern" % stage)
		check(game.sky_material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()), "stage %d live shader follows wrong-direction movement" % stage)
		Input.action_release("astrolabe")
		step(1.0 / 60)
		check(game.hud.star_guidance().is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0, "release immediately clears star/edge assistance")
	game.restart()
	game.state = game.State.SAILING
	game.heading = 0.0
	game.wave_sailing.reset()
	Input.action_press("astrolabe")
	step(1.8)
	check(game.guiding_star_direction().x < -0.25 and game.hud.star_guidance().position.x < game.hud.size.x * 0.5, "due north from departure shows Wreck to port, never false north feedback")
	# A direct attempt can meet land: orientation is not a route planner.
	game.restart()
	game.state = game.State.SAILING
	var direct_hit := false
	for frame in range(3600):
		var error: float = game.destination_turn()
		Input.action_release("steer_port")
		Input.action_release("steer_starboard")
		Input.action_press("steer_port" if error < 0 else "steer_starboard", minf(1.0, absf(error) * 2.8))
		game._physics_process(1.0 / 60)
		if game.hits_taken > 0 or game.voyage.stage > 0:
			direct_hit = game.hits_taken > 0
			break
	Input.action_release("steer_port")
	Input.action_release("steer_starboard")
	Input.action_release("astrolabe")
	check(direct_hit and game.voyage.stage == 0, "direct star pursuit meets a shore; player must choose a detour")
	game.restart()
	game.state = game.State.SAILING
	for stage in range(3):
		Input.action_press("astrolabe")
		step(1.8)
		game.boat.position = game.target
		game.voyage.update_progress(game)
		check(game.voyage.stage == stage + 1, "real discovery region advances stage %d" % stage)
		if stage < 2:
			check(game.focus_strength == 0 and game.sky_material.get_shader_parameter("target_focus") == 0 and game.hud.star_guidance().is_empty(), "stage transition immediately erases the old star highlight")
			check(game.sky_material.get_shader_parameter("active_star") == stage + 1 and game.sky_material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()), "stage transition selects exactly one new destination star")
			step(0.5)
			check(game.focus_strength == 0, "new star requires a fresh search")
		else:
			game._update_view(0.0)
			check(game.state == game.State.ARRIVED and game.hud.star_guidance().is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0, "arrival removes all guidance")
	Input.action_release("astrolabe")
	print("NAVIGATION CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

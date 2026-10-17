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
	var catalog: PackedVector3Array = game.sky_material.get_shader_parameter("guiding_stars")
	var original_bearing: float = game.destination_bearing()
	game.position = Vector3(23, 0, -17)
	game.voyage.set_target(game)
	check(absf(angle_difference(original_bearing, game.destination_bearing())) < 0.00001, "target and boat bearings use the same world coordinate space")
	game.position = Vector3.ZERO
	game.voyage.set_target(game)
	# At separated water positions, compare with forward/right vector projections.
	# This oracle does not subtract two atan2 bearings.
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		for at: Vector3 in [Vector3(24, 0, 148), Vector3(-221, 0, -109), Vector3(-145, 0, -205), Vector3(356, 0, 74), Vector3(139, 0, 82)]:
			game.boat.position = at
			var toward: Vector3 = (game.target - at).normalized()
			for degrees in [0, 10, 90, 180, 270, 350]:
				game.heading = deg_to_rad(degrees)
				var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
				var starboard := Vector3(cos(game.heading), 0, sin(game.heading))
				var reference := atan2(toward.dot(starboard), toward.dot(forward))
				check(absf(angle_difference(reference, game.destination_turn())) < 0.00001 and game.course_forward().dot(toward) > 0.99999, "stage %d at %s / heading %d° agrees with hull axes" % [stage, at, degrees])
			game.reading = true
			game.focus_elapsed = 1.8
			game._update_view(0.0)
			game.hud._process(0.0)
			check(game.guiding_star_direction().is_equal_approx(catalog[stage]) and game.sky_material.get_shader_parameter("guiding_stars") == catalog, "stage %d celestial reference stays fixed at %s" % [stage, at])
			check(game.hud.alignment_label.text.begins_with("Bearing ~") and not game.hud.alignment_label.text.contains("-"), "stage %d focused absolute bearing has clear units and no signed correction" % stage)
	game.reading = false
	game._update_view(0.3)
	# The actual A/D actions and momentum model must agree with the sign convention.
	for example in [[350, 10, "steer_starboard"], [10, 350, "steer_port"], [330, 10, "steer_starboard"], [10, 330, "steer_port"]]:
		game.voyage.stage = 0
		game.boat.position = Vector3(400, 0, -360)
		game.heading = deg_to_rad(example[0])
		var bearing: float = deg_to_rad(example[1])
		game.target = game.boat.position + Vector3(sin(bearing), 0, -cos(bearing)) * 200
		game.wave_sailing.reset()
		var before: float = absf(game.destination_turn())
		Input.action_press(example[2])
		step(0.3)
		Input.action_release(example[2])
		check(absf(game.destination_turn()) < before and game.hits_taken == 0, "actual %s reduces %s°→%s° error while sailing" % [example[2], example[0], example[1]])
		check(game.hud._course_hint() == ("Starboard of the bow" if example[2] == "steer_starboard" else "Port of the bow"), "optional relative hint agrees with actual rudder")
	game.heading = 0.0
	game.target = game.boat.position + Vector3.BACK * 200
	check(game.hud._course_hint() == "Astern · either side", "astern does not invent a uniquely correct turn direction")
	# All stages: sailing away changes the live measurement, never the star catalog.
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		game.boat.position = Vector3(400, 0, -360)
		var before: float = game.boat.position.distance_to(game.target)
		game.heading = game.destination_bearing() + PI
		game.wave_sailing.reset()
		Input.action_press("astrolabe")
		step(1.9)
		check(game.boat.position.distance_to(game.target) > before + 10 and absf(game.destination_turn()) > deg_to_rad(175), "stage %d live bearing remains meaningful while sailing away" % stage)
		check(game.has_reading and absf(angle_difference(game.last_reading, game.destination_bearing())) < 0.001, "stage %d stored reading measures the landmark rather than the bow" % stage)
		Input.action_release("astrolabe")
		step(1.0 / 60.0)
		check(game.hud.bearing_label.text.is_empty() and game.hud.alignment_label.text.is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0.0, "stage %d release clears text and target glow on the first tick" % stage)
		step(0.4)
		check(not game.hud.instrument.visible and game.hud.compass.status.text.begins_with("Heading ") and not game.hud.notice.visible, "stage %d normal sailing retains only heading and essential instruments" % stage)
	# Visit the actual regions in order, with the previous reading already focused.
	game.voyage.stage = 0
	game.voyage.set_target(game)
	for stage in range(3):
		var old_name: String = game.guiding_star_name()
		game.reading = true
		game.focus_elapsed = 2.0
		game._update_view(0.0)
		game.hud._process(0.0)
		game.boat.position = game.target
		game.voyage.update_progress(game)
		check(game.voyage.stage == stage + 1, "real region %d advances the existing journey" % stage)
		if stage < 2:
			check(game.focus_strength == 0 and game.hud.bearing_label.text.is_empty() and game.hud.alignment_label.text.is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0.0, "discovery %d immediately erases old reading before another frame" % stage)
			check(game.guiding_star_name() != old_name and game.sky_material.get_shader_parameter("active_star") == stage + 1, "discovery %d immediately selects the next fixed star" % stage)
			game.reading = false
			game._update_view(0.4)
			game.hud._process(0.0)
			check(game.hud.notice.visible and game.hud.notice.text.ends_with("found") and game.discovery_left < 2.5, "discovery %d briefly names only the place found" % stage)
			game._update_view(3.0)
			game.hud._process(0.0)
			check(not game.hud.notice.visible, "discovery %d fades without persistent next-stop instructions" % stage)
			game.reading = true
			game._update_view(0.5)
			game.hud._process(0.0)
			check(game.focus_strength == 0 and game.hud.alignment_label.text.is_empty(), "new stage %d needs a fresh search" % (stage + 1))
			game._update_view(1.3)
			game.hud._process(0.0)
			check(game.hud.bearing_label.text == game.guiding_star_name() and game.focus_strength == 1, "new stage %d can be focused normally" % (stage + 1))
		else:
			game.hud._process(0.0)
			check(game.state == game.State.ARRIVED and not game.hud.instrument.visible, "lighthouse completion retains arrival and hides navigation")
	print("NAVIGATION CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

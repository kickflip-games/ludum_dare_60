extends SceneTree
## Focus timing, memory, live world projection and active threats; no pilot skill claims.
var failures := 0
var checks := 0
var game


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
	game.hud._process(0.1)


func wave_sighting(with_wave: bool, hz: int) -> Dictionary:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(-380, 0, -350)
	game.heading = 0.0
	game.wave_sailing.reset()
	if with_wave:
		var d := Vector2(1, -0.5).normalized()
		game.ocean.wave_field.add_wave(Vector2(-380, -350 - 18.9) - d * 24, d, 1.0, 4.0, 26.0, 8.0, 0.0, 8.0)
	Input.action_press("astrolabe")
	var max_yaw := 0.0
	var max_ray_error := 0.0
	for frame in range(hz * 6):
		game._physics_process(1.0 / hz)
		max_yaw = maxf(max_yaw, absf(game.heading))
		var ray: Vector3 = game.sky_material.get_shader_parameter("guiding_star")
		var desired: Vector3 = (game.target - game.boat.global_position).normalized()
		max_ray_error = maxf(max_ray_error, Vector3(ray.x, 0, ray.z).normalized().distance_to(desired))
	check(game.focus_strength == 1 and game.camera_mode == game.CameraMode.STARGAZING and max_ray_error < 0.00001, "wave=%s at %d Hz preserves focus/camera priority and accurate live ray" % [with_wave, hz])
	var result := {"max_yaw": max_yaw, "heading": game.heading, "position": game.boat.position}
	Input.action_release("astrolabe")
	game._physics_process(1.0 / hz)
	check(game.hud.star_guidance().is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0, "wave=%s at %d Hz releases all navigation assistance" % [with_wave, hz])
	return result


func camera_transitions(hz: int) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = Vector3(390, 0, 350)
	game.heading = 0.0
	game._sailing_camera_initialized = false
	for frame in range(hz):
		game._physics_process(1.0 / hz)
	var previous: Transform3D = game.camera.transform
	Input.action_press("astrolabe")
	game._physics_process(1.0 / hz)
	check(game.camera.rotation.x > previous.basis.get_euler().x and game.camera.rotation.x < deg_to_rad(0.0), "%d Hz fresh Space hold starts raising without jumping to the sky pose" % hz)
	var max_angle := 0.0
	var max_distance := 0.0
	for held in [true, false]:
		if not held:
			Input.action_release("astrolabe")
		for frame in range(hz * 2):
			previous = game.camera.transform
			game._physics_process(1.0 / hz)
			max_angle = maxf(max_angle, previous.basis.get_rotation_quaternion().angle_to(game.camera.basis.get_rotation_quaternion()))
			max_distance = maxf(max_distance, previous.origin.distance_to(game.camera.position))
			if not held and frame == 0:
				game.hud._process(0.0)
				check(game.read_blend > 0.0 and not game.hud.instrument.visible and game.hud.star_horizon_line().is_empty(), "%d Hz release removes guidance immediately while the camera eases back" % hz)
		if held:
			check(is_equal_approx(game.camera.rotation.x, deg_to_rad(game.stargazing_pitch_degrees)) and game.focus_strength == 1, "%d Hz uninterrupted hold reaches the tuned pitch and full focus" % hz)
	# The retained 0.22-second blend traverses the full chase-to-bow arm.
	# A direct pose jump exceeds these rate bounds even at 30 Hz.
	check(max_angle * hz < deg_to_rad(300) and max_distance * hz < 120, "%d Hz entry/return stay continuous (max %.2f degrees, %.2f m per frame)" % [hz, rad_to_deg(max_angle), max_distance])
	for frame in range(12):
		Input.action_press("astrolabe")
		game._physics_process(1.0 / hz)
		Input.action_release("astrolabe")
		game._physics_process(1.0 / hz)
	for frame in range(hz / 2):
		game._physics_process(1.0 / hz)
	game.hud._process(0.0)
	check(game.camera_mode == game.CameraMode.SAILING and game.camera.rotation.x < 0 and game.read_blend == 0.0 and game.focus_strength == 0.0 and not game.hud.instrument.visible, "%d Hz rapid Space holds/releases settle to the original sailing view" % hz)


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.elapsed = 8
	game.phase_banner_left = 0
	var hud = game.hud
	var start: Vector3 = game.boat.position
	Input.action_press("astrolabe")
	Input.action_press("watch_starboard")
	step(0.6)
	check(hud.star_horizon_line().is_empty(), "searching draws no star-to-horizon line")
	check(game.focus_strength == 0 and game.focus_elapsed > 0.5, "searching has no target assistance before delay")
	check(hud.instrument.get_child_count() == 0, "initial hold withholds star name and solution")
	check(game.boat.position.distance_to(start) > 3, "sailing continues while the instrument is raised")
	check(game.look_blend == 0 and game.camera.rotation.x > deg_to_rad(20) and game.camera.rotation.x < deg_to_rad(30) and is_equal_approx(game.camera.rotation.x, deg_to_rad(game.stargazing_pitch_degrees)), "tuned upward sky pitch takes precedence over held combat glance")
	step(0.6)
	check(game.focus_strength > 0.05 and game.focus_strength < 0.8, "focus ramps gradually after the short search")
	check(hud.instrument.get_child_count() == 0, "mid-focus still withholds exact bearing")
	step(0.6)
	check(game.focus_strength == 1 and game.sky_material.get_shader_parameter("target_focus") > 0.6, "continued hold identifies the star with light alone")
	check(not hud.star_guidance().is_empty() and hud.instrument.get_child_count() == 0, "fully focused sky contains no navigation text")
	step(1)
	check(hud.instrument.get_child_count() == 0, "extended holds never introduce text or numbers")
	var last: float = game.last_reading
	Input.action_release("astrolabe")
	step(1.0 / 60)
	check(game.focus_strength == 0 and game.focus_elapsed == 0, "release immediately erases focus, including its sky glow")
	check(hud.instrument.get_child_count() == 0 and hud.star_guidance().is_empty(), "release immediately clears all sighting text")
	check(not hud.instrument.visible and hud.star_horizon_line().is_empty(), "one-frame release removes the sextant and line before camera return")
	check(game.last_reading == last, "lowered instrument cannot update the remembered sighting")
	step(0.3)
	check(not hud.instrument.visible and game.look_blend == 1 and game.camera.rotation.x < 0, "release smoothly returns to the still-held combat glance")
	Input.action_release("watch_starboard")
	for i in range(3):
		Input.action_press("astrolabe")
		step(0.35)
		check(game.focus_strength == 0, "quick check %d starts with a fresh search" % (i + 1))
		Input.action_release("astrolabe")
		step(0.1)
	Input.action_press("astrolabe")
	step(1.8)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(900, 506), Vector2i(1440, 900)]:
		root.size = dimensions
		await process_frame
		game.heading = game.destination_bearing()
		game._update_view(0.0)
		var star: Vector2 = hud._star_screen_position()
		var horizon: Vector2 = game.camera.unproject_position(game.camera.global_position + Vector3(sin(game.heading), 0, -cos(game.heading)) * 700)
		check(star.y / hud.size.y >= 0.15 and star.y / hud.size.y <= 0.35 and absf(star.x / hud.size.x - 0.5) < 0.001, "aligned real star occupies upper 15-35 percent / %s" % dimensions)
		check(horizon.y / hud.size.y >= 0.65 and horizon.y / hud.size.y <= 0.78, "actual world horizon occupies lower 65-78 percent / %s" % dimensions)
		for degrees in [0, 90, 180, -90]:
			game.heading = deg_to_rad(degrees)
			game._update_view(0.0)
			hud._process(0.0)
			var guidance: Dictionary = hud.star_guidance()
			check(not guidance.is_empty() and Rect2(Vector2.ZERO, hud.size).has_point(guidance.position), "star or peripheral glimmer stays in view at %d degrees / %s" % [degrees, dimensions])
			var forward: Vector3 = -game.camera.basis.z
			check(Vector2(forward.x, forward.z).normalized().dot(Vector2(sin(game.heading), -cos(game.heading))) > 0.99999, "sky yaw follows the actual hull heading %d / %s" % [degrees, dimensions])
	# Turning with real input brings an astern star into the visible sky.
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(400, 0, -370)
	game.heading = game.destination_bearing() + PI
	game.wave_sailing.reset()
	game._update_view(0.0)
	check(hud.star_horizon_line().is_empty(), "offscreen star never creates a horizon line")
	check(not hud.star_guidance().visible, "wrong heading starts with peripheral guidance")
	var wrong_heading: float = game.heading
	step(0.6)
	check(is_equal_approx(game.heading, wrong_heading) and not hud.star_guidance().visible, "waiting without steering neither turns the boat nor brings the astern star into view")
	Input.action_press("steer_port")
	step(4.0)
	Input.action_release("steer_port")
	check(hud.star_guidance().visible, "actual port input brings the star into view and removes peripheral cue")
	# A key release and re-entry between physics ticks cannot retain focus.
	var release := InputEventAction.new()
	release.action = "astrolabe"
	release.pressed = false
	game._unhandled_input(release)
	check(game.focus_elapsed == 0 and game.focus_strength == 0 and hud.star_guidance().is_empty(), "between-tick release erases all guidance immediately")
	step(0.3)
	check(game.focus_strength == 0, "re-entry starts a fresh search despite no release physics tick")
	step(1.5)
	game.enemy_encounters.enabled = true
	game.boat.position = Vector3(400, 0, -370)
	game.heading = 0
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 40
	ship.territory = ship.position
	ship.heading = game.heading
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0
	ship.locked_point = game.boat.position
	game.hud._process(0.1)
	check(hud.threat_label.visible and not game.cannon.fire(), "incoming threat stays visible while the raised instrument gates cannon fire")
	var ship_at: Vector3 = ship.position
	step(2.0)
	check(ship.shots_fired > 0 and ship.position.distance_to(ship_at) > 1, "enemy movement and real cannon fire continue during focus")
	check(game.focus_strength == 1 and game.look_blend == 0, "enemy fire cannot take over the focused sky camera")
	game.damage_immunity = 0
	var hull_before: int = game.hull
	game.take_damage(1, "Sighting vulnerability check")
	check(game.hull == hull_before - 1 and game.reading, "the player remains vulnerable while stargazing")
	# Every stage uses the live target, with distinct colour and halo segments.
	var colors: Array[Color] = []
	for stage in 3:
		game.voyage.stage = stage
		game.voyage.set_target(game)
		var region: Marker3D = game.archipelago.get_node("NavigationRegions").get_child(stage)
		check(game.target == region.global_position and game.sky_material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()), "stage %d selects its destination ray" % stage)
		game._update_view(0.5)
		check(game.focus_strength == 0.0, "stage %d starts a fresh progressive search" % stage)
		game._update_view(1.3)
		hud._process(0.0)
		check(game.focus_strength == 1 and hud.instrument.get_child_count() == 0, "stage %d reveals light with no text" % stage)
		game.heading = game.destination_bearing()
		game._update_view(0.0)
		var aligned: Vector2 = hud._star_screen_position()
		check(hud.star_guidance().visible and aligned.y / hud.size.y >= 0.15 and aligned.y / hud.size.y <= 0.35, "stage %d retains the authored star above a visible sea horizon" % stage)
		game.heading = game.destination_bearing() + 0.5
		game._update_view(0.0)
		var guide: Dictionary = hud.star_horizon_line()
		var projected: Vector2 = game.camera.unproject_position(game.camera.global_position + game.guiding_star_direction() * 700.0)
		check(not guide.is_empty() and absf(guide.from.x - projected.x) < 0.01 and guide.from.x == guide.to.x and guide.from.y > projected.y and guide.to.y > guide.from.y, "stage %d guide descends vertically from the actual off-centre star" % stage)
		check(guide.to.y / hud.size.y >= 0.65 and guide.to.y / hud.size.y <= 0.78 and absf(game.camera.project_ray_normal(guide.to).y) < 0.0001, "stage %d guide meets the real visible horizon" % stage)
		game.camera.rotation.x = deg_to_rad(30.0)
		guide = hud.star_horizon_line()
		check(not guide.is_empty() and absf(game.camera.project_ray_normal(guide.to).y) < 0.0001, "stage %d guide ends at the real horizon when visible" % stage)
		game.camera.rotation.x = deg_to_rad(-60.0)
		check(hud.star_horizon_line().is_empty(), "stage %d behind-camera star has no line" % stage)
		game._update_view(0.0)
		colors.append(game.guiding_star_color())
	check(colors[0] != colors[1] and colors[1] != colors[2] and colors[0] != colors[2], "all three stages have distinct nighttime colours")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.reading and game.focus_strength == 0 and game.sky_material.get_shader_parameter("target_focus") == 0, "focus loss clears the hold and sky highlight")
	Input.action_press("astrolabe")
	step(1.8)
	game.damage_immunity = 0
	game.take_damage(game.hull, "guidance death reset")
	step(1.0 / 60)
	check(game.state == game.State.LOST and hud.star_guidance().is_empty() and game.sky_material.get_shader_parameter("target_focus") == 0, "sinking clears stage guidance")
	Input.action_release("astrolabe")
	game.restart()
	check(game.focus_elapsed == 0 and game.focus_strength == 0 and not game.reading, "retry clears assistance and hold history")
	var calm := wave_sighting(false, 60)
	var wave := wave_sighting(true, 60)
	var slow := wave_sighting(true, 30)
	var fast := wave_sighting(true, 120)
	check(calm.max_yaw < 0.0001 and wave.max_yaw > deg_to_rad(5), "real oblique wave changes heading during sighting; calm control does not")
	print("SIGHTING WAVE RATES: slow=%s fast=%s" % [slow, fast])
	check(absf(slow.heading - fast.heading) < 0.01 and slow.position.distance_to(fast.position) < 0.2, "sighting with wave forces remains consistent at 30/60/120 Hz")
	# Player countersteers while continuing to sight the updated world direction.
	Input.action_press("astrolabe")
	var before: float = absf(game.heading)
	for frame in range(120):
		Input.action_release("steer_port")
		Input.action_release("steer_starboard")
		Input.action_press("steer_port" if game.heading > 0 else "steer_starboard", minf(1.0, absf(game.heading) * 2))
		game._physics_process(1.0 / 60)
	check(absf(game.heading) < before and game.focus_strength == 1, "actual rudder input can recover wave yaw while the star remains focused")
	for action in ["astrolabe", "steer_port", "steer_starboard"]:
		Input.action_release(action)
	for hz in [30, 60, 120]:
		camera_transitions(hz)
	print("STARGAZING CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

extends SceneTree
## Routed screen events, live Input actions and the existing cannon; optional captures.
var game
var mobile
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func touch(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	e.canceled = canceled
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func drag(index: int, at: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func step(seconds: float) -> void:
	for frame in roundi(seconds * 60):
		game._physics_process(1.0 / 60)
		game.cannon.advance(1.0 / 60)
	mobile._process(seconds)
	game.hud._process(seconds)

func fresh() -> void:
	game._window_focused = true
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game.heading = 0
	step(0.05)

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	game.hud._process(0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func _run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.enemy_encounters.set_physics_process(false)
	game.cannon.set_physics_process(false)
	mobile = game.mobile_controls
	check(mobile.enabled and not Input.emulate_mouse_from_touch, "touch override enabled; mouse emulation disabled")
	check(not mobile.available(), "gameplay controls hidden on title")
	await capture("01-menu")
	touch(40, center(game.hud.settings_button), true)
	touch(40, center(game.hud.settings_button), false)
	check(game.hud.settings_open, "Settings works by touch")
	touch(40, center(game.hud.settings_back), true)
	touch(40, center(game.hud.settings_back), false)
	await process_frame
	game.application_focus_changed(true, "capture_harness")
	touch(40, center(game.hud.action_button), true)
	touch(40, center(game.hud.action_button), false)
	check(game.state == game.State.CASTING_OFF, "Play works by touch without a keyboard")
	step(1.4)
	check(mobile.available() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "sailing shows HUD without mouse capture")
	fresh()
	await capture("02-gameplay")
	var stick: Vector2 = center(mobile.joystick)
	var fire: Vector2 = center(mobile.fire)
	var boost: Vector2 = center(mobile.boost)
	var open := Vector2(470, 300)
	touch(3, stick, true)
	drag(3, stick + Vector2(-35, 0), Vector2(-35, 0))
	var partial := Input.get_axis("steer_port", "steer_starboard")
	check(partial < -0.1 and partial > -0.9, "joystick displacement gives analog port steering")
	drag(3, stick + Vector2(60, 0), Vector2(95, 0))
	check(Input.get_axis("steer_port", "steer_starboard") > 0.9, "joystick steers starboard")
	drag(3, stick + Vector2(0, -50), Vector2(-60, -50))
	check(is_zero_approx(Input.get_axis("steer_port", "steer_starboard")), "vertical stick motion does not steer")
	touch(3, stick, false)
	check(Input.get_axis("steer_port", "steer_starboard") == 0, "joystick release returns immediately to neutral")
	touch(7, open, true)
	drag(7, open + Vector2(120, 50), Vector2(120, 50))
	check(game.look_target < 0 and not game._fire_armed and game.cannon.shots_fired == 0, "open drag looks horizontally without arming or firing")
	touch(7, open, false)
	step(4)
	check(absf(game.look_yaw) < 0.1, "touch camera uses existing smooth recentering")
	fresh()
	touch(1, stick, true)
	drag(1, stick + Vector2(-45, 0), Vector2(-45, 0))
	touch(8, fire, true)
	touch(12, open, true)
	drag(12, open + Vector2(100, 0), Vector2(100, 0))
	touch(19, boost, true)
	step(0.1)
	check(game.turn_input < 0 and game.cannon.shots_fired == 1 and game.look_target < 0 and game.boosting, "four independent fingers steer, fire, look and boost")
	var protected_look: float = game.look_target
	touch(20, fire, true)
	drag(20, fire + Vector2(-100, 0), Vector2(-100, 0))
	touch(20, fire, false)
	check(game.look_target == protected_look and mobile.fingers.get(8) == "fire", "second finger on occupied FIRE cannot look or release its owner")
	await capture("03-steering-fire")
	step(1.7)
	check(game.cannon.shots_fired == 2, "holding FIRE repeats at existing reload cadence")
	touch(19, boost, false)
	step(0.05)
	check(not game.boosting and game.turn_input < 0 and mobile.fingers.get(8) == "fire", "releasing BOOST leaves steering and FIRE held")
	var look: float = game.look_target
	drag(8, fire + Vector2(-300, 0), Vector2(-300, 0))
	check(game.look_target == look, "FIRE gesture never transfers to camera")
	touch(8, fire, false)
	var shots: int = game.cannon.shots_fired
	step(2)
	check(game.cannon.shots_fired == shots and not game.cannon._fire_held, "releasing FIRE stops repeated shots")
	touch(8, fire, true)
	touch(8, fire, false)
	step(0.05)
	check(game.cannon.shots_fired == shots + 1, "quick FIRE tap queues exactly one shot")
	shots = game.cannon.shots_fired
	touch(8, fire, true)
	touch(8, fire, false)
	step(0.1)
	check(game.cannon.shots_fired == shots, "tap during cooldown does not bypass reload")
	touch(1, stick, false)
	touch(12, open, false)
	fresh()
	touch(1, stick, true)
	drag(1, stick + Vector2(45, 0), Vector2(45, 0))
	touch(2, fire, true)
	touch(3, boost, true)
	touch(4, open, true)
	touch(9, center(mobile.pause_button), true)
	check(game.paused and mobile.fingers.is_empty() and Input.get_axis("steer_port", "steer_starboard") == 0 and not Input.is_action_pressed("boost_sailing") and not game._fire_armed, "pause clears every held touch and fire gate")
	await capture("04-pause")
	touch(9, center(mobile.pause_button), false)
	touch(10, center(game.hud.action_button), true)
	touch(10, center(game.hud.action_button), false)
	step(0.1)
	check(not game.paused and game.cannon.shots_fired == 0, "Resume touch cannot fire")
	drag(2, fire, Vector2(20, 0))
	step(0.1)
	check(not game._fire_armed, "old finger cannot revive fire after Resume")
	for ending in ["focus", "victory", "defeat", "restart", "menu"]:
		fresh()
		touch(1, stick, true)
		drag(1, stick + Vector2(-50, 0), Vector2(-50, 0))
		touch(2, fire, true)
		touch(3, boost, true)
		touch(4, open, true)
		match ending:
			"focus": game.application_focus_changed(false, "touch_test")
			"victory": game.begin_result(true)
			"defeat": game.take_damage(game.hull, "touch_test")
			"restart": game.restart()
			"menu": game.restart(true)
		check(mobile.fingers.is_empty() and not game._fire_armed and not Input.is_action_pressed("boost_sailing") and Input.get_axis("steer_port", "steer_starboard") == 0 and not game.cannon._fire_held, ending + " releases all controls")
		if ending == "focus":
			game.application_focus_changed(true, "touch_test")
			check(game.paused, "restored focus still requires explicit Resume")
	fresh()
	touch(6, fire, true)
	touch(6, fire, false, true)
	step(0.1)
	check(not game.cannon._fire_held and mobile.fingers.is_empty() and game.cannon.shots_fired == 0, "touch cancellation releases FIRE and discards pending tap")
	# Complete the unchanged tutorial with touches, including its camera gate.
	fresh()
	game.walkthrough.begin(game)
	for stage in range(6):
		mobile._refresh()
		match stage:
			0:
				touch(1, stick, true)
				drag(1, stick + Vector2(50, 0), Vector2(50, 0))
				step(0.55)
			1:
				touch(2, boost, true)
				step(0.55)
			2:
				touch(3, open, true)
				drag(3, open + Vector2(100, 0), Vector2(100, 0))
				step(0.05)
			3:
				touch(4, fire, true)
				step(0.05)
			4:
				touch(5, center(mobile.camera_button), true)
				step(0.05)
		if stage < 5: check(game.walkthrough.practiced, "touch tutorial stage %d completes original condition" % stage)
		game.hud.walkthrough_card._process(0)
		await process_frame
		var next: Vector2 = center(game.hud.walkthrough_card.next_button)
		touch(30, next, true)
		touch(30, next, false)
	check(not game.walkthrough.active, "touch tutorial finishes and resets to scored game")
	fresh()
	touch(2, fire, true)
	touch(4, open, true)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	mobile._layout()
	check(mobile.fingers.is_empty() and not game._fire_armed and not game.cannon._fire_pending, "resize cancels held input and pending shots")
	mobile._refresh()
	check(mobile.fire.position.x > fire.x and mobile.fire.position.y > fire.y, "controls follow resized visible game area")
	root.size = Vector2i(900, 1200)
	await process_frame
	mobile._layout()
	mobile._refresh()
	check(mobile.portrait and mobile.rotate_hint.visible and not mobile.available(), "portrait shows Rotate your phone and disables gameplay touches")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await process_frame
	mobile._layout()
	mobile._refresh()
	check(not mobile.portrait and mobile.available(), "landscape restores controls with no old touches")
	for won in [false, true]:
		fresh()
		game.begin_result(won)
		step(4.3)
		await process_frame
		await process_frame
		var action: Vector2 = center(game.hud.action_button)
		touch(32, action, true)
		touch(32, action, false)
		check(game.state == game.State.CASTING_OFF and game.cannon.shots_fired == 0 and mobile.fingers.is_empty(), "touch %s starts cleanly" % ("Play Again" if won else "Try Again"))
	print("MOBILE CONTROLS: %d checks, %d failures" % [checks, failures])
	await load("res://game/audio_shutdown.gd").close_scene(game)
	quit(1 if failures else 0)

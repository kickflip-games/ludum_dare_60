extends SceneTree
## Advisory storm warnings must never steer, damage or contain the player.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func pose(distance: float) -> void:
	game.boat.global_position = game.arena_center() + Vector3(distance, 0, 0)
	game._update_view(0)
	game.hud._process(0)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	pose(180)
	check(game.storm_warning_strength() == 0 and not game.hud.storm_warning.visible, "menu has no storm warning even outside line")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	pose(100)
	check(game.storm_warning_strength() == 0 and not game.hud.storm_warning.visible, "inner arena has no warning clutter")
	pose(132)
	check(game.storm_warning_strength() == 0, "warning begins only inside configured approach margin")
	pose(145)
	var first: float = game.storm_warning_strength()
	check(first > 0 and first < 0.5 and not game.hud.storm_warning.visible, "red line fades in on approach without a message")
	check(not game.hud._storm_notice_seen, "approaching cannot consume the once-per-voyage message")
	check(game.hud.storm_screen_alpha() == 0, "approach does not flash the screen before crossing")
	pose(165)
	check(game.storm_warning_strength() > first and game.storm_warning_strength() < 1, "red line grows stronger nearer crossing")
	var ring: Vector4 = game.water_material.get_shader_parameter("storm_boundary")
	check(is_equal_approx(ring.z, 170) and is_equal_approx(ring.w, game.storm_warning_strength()), "shared water shader receives actual warning radius and opacity")
	check(Vector2(ring.x,ring.y) == Vector2(game.arena_center().x,game.arena_center().z), "red circle is centred on the lighthouse")
	pose(170)
	check(game.outside_storm_line() and game.storm_warning_strength() == 1, "exact line crossing activates full warning")
	check(game.hud.storm_warning.visible, "crossing the border displays the message")
	pose(195)
	check(game.hud.storm_instruction.text == "RETURN TO THE LIGHTHOUSE", "outside warning explicitly tells the player to return")
	game.elapsed = 0.45
	var bright: float = game.hud.storm_screen_alpha()
	game.elapsed = 1.35
	check(bright > game.hud.storm_screen_alpha() + 0.08, "screen pulses slowly red outside the line")
	game.motion_setting = 1
	var steady: float = game.hud.storm_screen_alpha()
	game.elapsed = 50
	check(steady > 0 and game.hud.storm_screen_alpha() == steady, "Reduced motion uses steady red tint")
	game.motion_setting = 0
	game.heading = 0
	game.wave_sailing.reset()
	await physics_frame
	key(KEY_D,true)
	key(KEY_SPACE,true)
	key(KEY_SHIFT,true)
	for frame in 120:
		game._physics_process(1.0/60)
		game.cannon.advance(1.0/60)
	check(game.heading > 1 and game.turn_input == 1, "held D keeps full manual rudder outside storm area")
	check(game.cannon.shots_fired >= 2, "held fire repeats outside storm area while steering")
	check(game.boosting and is_equal_approx(game.propulsion_speed(),game.sailing_speed * 1.5), "Shift boost remains independent of storm warning")
	check(game.hits_taken == 0 and game.state == game.State.SAILING, "storm warning causes no damage or automatic defeat")
	key(KEY_D,false)
	key(KEY_SPACE,false)
	key(KEY_SHIFT,false)
	game._physics_process(1.0/60)
	check(game.turn_input == 0 and not game.boosting, "input release remains responsive outside line")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.boosting and not game.arena_cannon_view, "focus loss retains control cleanup")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	# Going beyond the former voyage square must not reintroduce a second wall.
	pose(350)
	game.heading = PI/2
	game.wave_sailing.reset()
	game.advance_sailing(0.1,0)
	check(game.boat.global_position.x > 625 and game.actual_speed > 7, "no hidden square clamp beyond former arena circle")
	pose(125)
	check(not game.hud.storm_warning.visible and game.hud.storm_screen_alpha() == 0, "manual return clears title, red line and screen pulse")
	for ending in [game.State.LOST,game.State.ARRIVED,game.State.CASTING_OFF]:
		game.state = ending
		pose(190)
		check(game.storm_warning_strength() == 0 and not game.hud.storm_warning.visible and game.hud.storm_screen_alpha() == 0, "state %d clears storm presentation" % ending)
	game.restart()
	game.hud._process(0)
	check(not game.hud.storm_warning.visible and game.storm_warning_strength() == 0, "retry clears warning and restores safe spawn")
	game._physics_process(game.CAST_OFF_SECONDS)
	game.hud._process(0)
	check(not game.hud.storm_warning.visible and game.hud.storm_screen_alpha() == 0, "new run inherits no storm pulse")
	for hz in [30,60,120]:
		game.restart()
		game._physics_process(game.CAST_OFF_SECONDS)
		pose(169)
		check(not game.hud.storm_warning.visible, "%d Hz: just inside never shows a message" % hz)
		pose(171)
		for frame in roundi(9.9 * hz): game.hud._process(1.0 / hz)
		check(game.hud.storm_warning.visible, "%d Hz: message remains visible before ten seconds" % hz)
		for frame in roundi(0.1 * hz): game.hud._process(1.0 / hz)
		check(not game.hud.storm_warning.visible and game.hud.storm_screen_alpha() > 0, "%d Hz: ten-second timeout hides text while storm visuals remain" % hz)
		pose(100)
		pose(190)
		check(not game.hud.storm_warning.visible, "%d Hz: later crossing cannot replay the message" % hz)
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	pose(180)
	check(game.hud.storm_warning.visible, "retry permits one new border notice")
	game.hud._process(1)
	pose(169)
	check(not game.hud.storm_warning.visible, "returning just inside hides the message immediately")
	pose(180)
	check(not game.hud.storm_warning.visible, "early return still consumes the notice for this voyage")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	pose(180)
	game.hud._process(60)
	check(not game.hud.storm_warning.visible, "one long frame also expires the message")
	game.queue_free()
	await process_frame
	print("STORM BOUNDARY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

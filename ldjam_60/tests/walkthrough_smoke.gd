extends SceneTree
const Guide = preload("res://game/walkthrough.gd")
var game
var checks := 0
var failures := 0
var output := "res://../build/walkthrough"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func step(seconds: float, hz: int = 60) -> void:
	for frame in roundi(seconds * hz):
		game._physics_process(1.0 / hz)
		game.cannon.advance(1.0 / hz)
	game.hud._process(0)
	game.hud.walkthrough_card._process(0)

func settle() -> void:
	game.hud._process(0)
	game.hud.walkthrough_card._process(0)
	for frame in 6: await process_frame
	game.hud._process(0)
	game.hud.walkthrough_card._process(0)

func create_game() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.hud.walkthrough_card.set_process(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

func _run() -> void:
	create_game()
	await settle()
	var guide = game.walkthrough
	var hud = game.hud
	var card = hud.walkthrough_card
	check(hud.walkthrough_button.text == "TUTORIAL" and not hud.walkthrough_button.toggle_mode, "Walkthrough is a plain launch button with no On/Off state")
	check(hud.walkthrough_button.get_index() == hud.action_button.get_index() + 1 and hud.walkthrough_button.global_position.y >= hud.action_button.get_global_rect().end.y, "Walkthrough sits directly beneath Set Sail")
	click(hud.action_button)
	step(game.CAST_OFF_SECONDS + 0.1)
	check(not guide.active and not guide.pending and game.enemy_encounters.clock > 0, "Set Sail starts normal gameplay immediately")
	game.restart(true)
	await settle()
	click(hud.walkthrough_button)
	check(guide.pending and game.state == game.State.CASTING_OFF, "Walkthrough click launches the practice cast-off directly")
	step(game.CAST_OFF_SECONDS)
	await settle()
	check(guide.active and guide.step == Guide.Step.STEER and card.visible, "Walkthrough opens guided practice after cast-off")
	check(card.get_theme_stylebox("panel") is StyleBoxTexture and card.next_button.get_theme_stylebox("normal") is StyleBoxTexture, "tutorial shares Kenney panel and primary button textures")
	for cap in card.caps:
		for character in cap.get_child(0).text:
			check(hud.sans.has_char(character.unicode_at(0)), "practice keycap glyph is bundled: " + character)
	check(card.next_button.disabled and card.instruction.text == "Use A / D or the arrow keys to turn.", "steering instruction waits for practice")
	check(not hud.gameplay_hud.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "practice has a usable cursor and no fleet HUD")
	var start: Vector3 = game.boat.position
	var start_heading: float = game.heading
	step(5)
	check(game.boat.position.is_equal_approx(start) and game.enemy_encounters.clock == 0 and game.enemy_encounters.wave_number == 0, "no-input reading time cannot move the boat or start fleets")
	check(game.ocean.wave_field.waves.is_empty() and not game.wave_encounters.busy(), "encounter waves remain absent during practice")
	check(not game.take_damage(99, "practice collision") and game.hull == game.hull_capacity, "practice is protected from damage")
	guide.advance(game)
	check(guide.step == Guide.Step.STEER, "cannot advance before trying the requested action")
	key(KEY_SPACE, true)
	step(0.1)
	key(KEY_SPACE, false)
	check(game.cannon.shots_fired == 0 and not guide.practiced, "wrong action neither fires nor completes steering")
	key(KEY_A, true)
	key(KEY_D, true)
	step(0.2)
	check(guide.held_seconds == 0, "opposing steering keys do not count as a turn")
	key(KEY_D, false)
	step(0.2)
	check(card.caps[0].get_theme_stylebox("panel") == card.key_styles[1], "held steering visibly highlights its keycap")
	var partial: float = guide.held_seconds
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(2)
	check(guide.held_seconds == partial and not guide.practiced, "focus loss freezes progress and releases held controls")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	key(KEY_D, true)
	step(0.4)
	check(guide.practiced and absf(game.heading - start_heading) > 0.01, "real steering completes the first exercise")
	check(not card.next_button.disabled and card.progress.text.ends_with("COMPLETE"), "completed practice enables Continue and shows success")
	var parked: Vector3 = game.boat.position
	step(10)
	check(game.boat.position.is_equal_approx(parked), "completed exercise stops drifting even while the key remains held")
	await settle()
	click(card.next_button)
	step(0)
	check(guide.step == Guide.Step.BOOST and not guide.practiced and not Input.is_action_pressed("steer_starboard"), "Continue changes step and clears held input")
	key(KEY_SHIFT, true)
	var boost_start: Vector3 = game.boat.position
	step(0.6)
	check(guide.practiced and absf(boost_start.distance_to(game.boat.position) - game.sailing_speed * 0.75) < 0.05, "real held Shift demonstrates boosted travel before parking")
	key(KEY_SHIFT, false)
	guide.advance(game)
	step(0)
	var bearing: float = game.heading
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(100, 0)
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	step(0.1)
	check(guide.practiced and absf(game.look_yaw) > 1 and game.heading == bearing, "mouse exercise turns only the view")
	guide.advance(game)
	step(0)
	key(KEY_SPACE, true)
	step(0.1)
	check(guide.practiced and game.cannon.shots_fired == 1, "Space exercise launches an actual physical shot")
	step(3)
	check(game.cannon.shots_fired == 1, "practice stops repeated fire while waiting to continue")
	guide.advance(game)
	step(0)
	key(KEY_E, true)
	step(0.5)
	key(KEY_E, true, true)
	check(guide.practiced and game.arena_cannon_view, "E exercise uses the real toggle and ignores key repeat")
	guide.advance(game)
	step(0)
	check(guide.step == Guide.Step.READY and not game.arena_cannon_view, "ready card restores chase view")
	for dimensions: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(960,540), Vector2i(900,506)]:
		root.size = dimensions
		await settle()
		check(is_equal_approx(card.size.x, 360) and is_equal_approx(card.get_global_rect().end.x, hud.size.x - 24) and is_equal_approx(card.get_global_rect().end.y, hud.size.y - 24), "practice card stays compact at bottom right %s" % dimensions)
		check(Rect2(Vector2.ZERO, hud.size).grow(1).encloses(card.get_global_rect()) and Rect2(Vector2.ZERO, hud.size).grow(1).encloses(card.next_button.get_global_rect()), "practice card and buttons fit %s" % dimensions)
	game.motion_setting = 1
	click(card.next_button)
	step(0)
	check(not guide.active and not guide.pending and game.state == game.State.CASTING_OFF, "Begin Voyage finishes practice and casts off normally")
	check(game.elapsed == 0 and game.cannon.shots_fired == 0 and game.flow_zones.collected.is_empty() and game.enemy_encounters.clock == 0 and game.hull == game.hull_capacity, "scored voyage inherits no practice time, shots, pickups or damage")
	check(game.motion_setting == 1 and not game.boosting and not game.cannon._fire_held, "motion preference survives; held practice controls do not")
	step(game.CAST_OFF_SECONDS + 0.5)
	check(not guide.active and game.enemy_encounters.clock > 0, "normal fleet clock starts after practice")
	game.restart(true)
	await settle()
	check(hud.walkthrough_button.visible and hud.walkthrough_button.text == "TUTORIAL", "return to title offers the same Walkthrough action for replay")
	check(Rect2(Vector2.ZERO, hud.size).grow(1).encloses(hud.walkthrough_button.get_global_rect()), "Walkthrough button remains inside the menu after resizing and practice")
	hud.walkthrough_button.grab_focus()
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.physical_keycode = KEY_ENTER
	accept.pressed = true
	root.push_input(accept)
	accept = accept.duplicate()
	accept.pressed = false
	root.push_input(accept)
	check(guide.pending and game.state == game.State.CASTING_OFF, "focused Walkthrough consumes Enter as its own launch action")
	step(game.CAST_OFF_SECONDS)
	await settle()
	check(guide.active, "keyboard activation of Walkthrough starts a fresh practice")
	click(card.skip_button)
	step(0)
	check(not guide.active and not guide.pending and game.state == game.State.CASTING_OFF, "Skip starts a clean voyage without repeating practice")
	check(game.elapsed == 0 and game.cannon.shots_fired == 0 and game.enemy_encounters.clock == 0, "Skip clears practice clocks and shots")
	game.restart(true)
	await settle()
	click(hud.action_button)
	step(game.CAST_OFF_SECONDS + 0.1)
	check(not guide.active and game.enemy_encounters.clock > 0, "Set Sail still bypasses practice after a previous walkthrough")
	for hz in [30, 60, 120]:
		game.restart(true)
		game.start_crossing(true)
		step(game.CAST_OFF_SECONDS + 0.1, hz)
		start = game.boat.position
		key(KEY_D, true)
		step(1, hz)
		check(guide.practiced and start.distance_to(game.boat.position) <= game.sailing_speed * 0.5 + 0.02 and game.enemy_encounters.clock == 0, "%d Hz bounds practice travel and holds the fleet" % hz)
		game.restart(true)
		step(0)
		check(not guide.active and not Input.is_action_pressed("steer_starboard") and not card.visible, "%d Hz cancellation clears practice and held controls" % hz)
	print("WALKTHROUGH: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

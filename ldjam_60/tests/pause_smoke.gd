extends SceneTree
## Real input + SceneTree pause: gameplay freezes while menu input remains live.
var game
var hud
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = ProjectSettings.globalize_path(arg.trim_prefix("--output="))
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int = 6) -> void:
	for frame in count: await process_frame

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func capture(label: String) -> void:
	if output.is_empty(): return
	await frames()
	RenderingServer.force_draw(true, 1.0 / 60)
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native capture " + label)

func _run() -> void:
	root.size = Vector2i(1280,720)
	if not output.is_empty():
		if DisplayServer.get_name() == "headless":
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	hud = game.hud
	await frames()
	check(hud.menu_actions.get_node_or_null("Quit") == null, "no Quit button is constructed")
	check(hud.settings_panel.get_node("FullControls/Action7").text == "Pause / resume", "controls describe pause rather than exit")
	tap(KEY_ESCAPE)
	await frames()
	check(game.state == game.State.READY and not game.paused and not paused, "Esc on the title keeps the game open without pausing")
	await capture("01-title-no-quit")
	# Casting off is a resumable transition, not a new run on Resume.
	click(hud.action_button)
	tap(KEY_ESCAPE)
	check(game.paused and paused and game.state == game.State.CASTING_OFF, "Esc pauses casting off")
	var transition: float = game.transition_elapsed
	await frames(20)
	check(game.transition_elapsed == transition, "cast-off transition clock freezes")
	click(hud.action_button)
	check(not game.paused and not paused and game.state == game.State.CASTING_OFF, "Resume continues casting off")
	for frame in 120:
		await physics_frame
		if game.state == game.State.SAILING: break
	game.damage_immunity = 30
	game.wave_encounters.enabled = false
	await frames()
	check(game.state == game.State.SAILING and game.enemy_encounters.wave_number == 1, "sailing and authoritative wave launch still work")
	# Simultaneous steering, held fire, boost and close view must clear safely.
	tap(KEY_E)
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	key(KEY_SPACE, true)
	await frames(12)
	check(game.cannon.shots_fired > 0 and game.boosting and game.turn_input > 0, "steering, held fire and boost work before pause")
	var view: bool = game.arena_cannon_view
	var yaw: float = game.look_yaw
	tap(KEY_ESCAPE)
	await frames()
	check(game.paused and paused and not game.can_process() and hud.can_process(), "SceneTree freezes gameplay while HUD still processes")
	check(hud.menu.visible and hud.menu_title.text == "PAUSED" and hud.action_button.text == "RESUME" and hud.action_button.has_focus(), "pause menu displays focused Resume")
	check(not hud.gameplay_hud.visible and not hud.walkthrough_button.visible and hud.main_menu_button.visible, "pause displays only relevant menu actions")
	check(not game.cannon._fire_held and not game.boosting and game.turn_input == 0 and game.restart_elapsed == 0, "pause clears held movement, firing, boost and restart")
	check(game.arena_cannon_view == view and game.look_yaw == yaw, "pausing preserves camera mode and look direction")
	var at: Vector3 = game.boat.position
	var clock: float = game.elapsed
	var sea: float = game.sea_time
	var deadline: float = game.enemy_encounters.wave_remaining
	var banner: float = hud._fleet_banner_left
	var reload: float = game.cannon.cooldown
	var shots: int = game.cannon.shots_fired
	var shell_positions: Array = game.cannon.projectiles.map(func(shot): return shot.node.position)
	var enemy_positions: Array = game.enemy_encounters.living_ships().map(func(ship): return ship.position)
	await frames(45)
	check(game.boat.position == at and game.elapsed == clock and game.sea_time == sea, "boat, sea and voyage clocks freeze during a no-input pause")
	check(game.enemy_encounters.wave_remaining == deadline and hud._fleet_banner_left == banner and game.cannon.cooldown == reload, "wave deadline, banner and reload timers freeze")
	check(game.cannon.projectiles.map(func(shot): return shot.node.position) == shell_positions and game.enemy_encounters.living_ships().map(func(ship): return ship.position) == enemy_positions, "live cannonballs and enemies freeze")
	key(KEY_ESCAPE, true, true)
	key(KEY_SPACE, true, true)
	key(KEY_R, true)
	await frames()
	check(game.paused and game.cannon.shots_fired == shots and game.elapsed == clock, "repeats and gameplay inputs cannot resume, shoot or restart behind pause")
	key(KEY_D, false)
	key(KEY_SHIFT, false)
	key(KEY_SPACE, false)
	key(KEY_R, false)
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(900,506)]:
		root.size = dimensions
		await frames()
		for control: Control in [hud.menu_title, hud.action_button, hud.settings_button, hud.main_menu_button, hud.credits_button]:
			check(Rect2(Vector2.ZERO, hud.size).grow(1).encloses(control.get_global_rect()), "paused %s fits %s" % [control.name, dimensions])
		await capture("02-paused-%dx%d" % [dimensions.x, dimensions.y])
	click(hud.credits_button)
	await frames()
	check(game.paused and hud.credits_open and hud.credits_back.has_focus() and not hud.settings_open, "Credits remains usable without resuming the paused run")
	check(game.elapsed == clock and hud._fleet_banner_left == banner, "Credits keeps gameplay and banner clocks frozen")
	await capture("03-paused-credits-small")
	tap(KEY_ESCAPE)
	await frames()
	check(game.paused and not hud.credits_open and hud.menu_title.text == "PAUSED" and hud.credits_button.has_focus(), "Esc closes Credits to the paused menu")
	click(hud.settings_button)
	await frames()
	check(game.paused and hud.settings_open and hud.settings_back.has_focus(), "Settings stays usable while the game is paused")
	await capture("03-paused-settings-small")
	tap(KEY_ESCAPE)
	await frames()
	check(game.paused and not hud.settings_open and hud.menu_title.text == "PAUSED", "first Esc closes Settings and remains paused")
	tap(KEY_ESCAPE)
	await frames()
	check(not game.paused and not paused and not hud.menu.visible and game.elapsed > clock, "second Esc resumes the existing run")
	check(game.arena_cannon_view == view and not game.cannon._fire_held and not game.boosting and game.cannon.shots_fired == shots, "resume preserves view without replaying held fire or boost")
	check(hud._announced_fleet == 1 and hud._fleet_banner_left < banner and game.enemy_encounters.wave_remaining < deadline, "HUD and wave timers resume without replaying the banner")
	for frame in 100: await physics_frame
	key(KEY_SPACE, true)
	await frames(3)
	check(game._fire_armed and game.cannon.shots_fired > shots, "fresh fire input shoots normally after resume and reload")
	key(KEY_SPACE, false)
	tap(KEY_ESCAPE)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames()
	check(game.paused and not game.cannon._fire_held, "focus loss while paused clears inputs without resuming")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	click(hud.main_menu_button)
	await frames()
	check(not game.paused and not paused and game.state == game.State.READY and game.elapsed == 0 and game.enemy_encounters.records.is_empty(), "Main Menu unpauses the tree and clears the run")
	# Walkthrough cards and Enter shortcuts must not cover or bypass pause.
	game.start_crossing(true)
	game._physics_process(game.CAST_OFF_SECONDS)
	await frames()
	check(game.walkthrough.active, "walkthrough still starts normally")
	tap(KEY_ESCAPE)
	await frames()
	var guide_step: int = game.walkthrough.step
	tap(KEY_ENTER) # Focused Resume, not the hidden walkthrough Continue button.
	await frames()
	check(not game.paused and game.walkthrough.step == guide_step, "Enter resumes without advancing the hidden walkthrough card")
	tap(KEY_ESCAPE)
	await frames()
	check(game.paused and not hud.walkthrough_card.visible, "walkthrough card hides during pause")
	game.restart(true)
	await frames()
	check(not game.paused and not paused and not game.walkthrough.active, "restart from paused practice clears pause and walkthrough")
	game.state = game.State.LOST
	hud._process(0)
	tap(KEY_ESCAPE)
	check(game.state == game.State.LOST and not game.paused and hud.menu.visible, "Esc on defeat keeps the result open without quitting")
	game.state = game.State.ARRIVED
	hud._process(0)
	tap(KEY_ESCAPE)
	check(game.state == game.State.ARRIVED and not game.paused and hud.menu.visible, "Esc on victory keeps the result open without quitting")
	game.restart()
	game.set_paused(true)
	game.queue_free()
	await frames()
	check(not paused, "freeing a paused game cannot leave the SceneTree paused")
	print("PAUSE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

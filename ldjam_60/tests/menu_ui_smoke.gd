extends SceneTree
## First-pass menu layout, real GUI input, settings and reset regression checks.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func settle() -> void:
	for frame in 5: await process_frame
	game.hud._process(0.5)

func inside(control: Control) -> bool:
	var rect := control.get_global_rect()
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(rect)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await settle()
	var hud = game.hud
	check(inside(hud.menu) and inside(hud.menu_title) and inside(hud.action_button), "initial menu fits before any resize or settings visit")
	check(hud.action_button.has_focus() and hud.action_button.text == "SET SAIL", "title starts with focused Set Sail")
	check(hud.menu_kicker.text == "FIVE WAVES AT SEA" and hud.menu_body.text == "Five waves. One last light.", "title has focused arena copy")
	check(not hud.motion_choice.is_visible_in_tree() and not hud.main_menu_button.visible, "settings hidden on title; no Continue or result action")
	check(not hud.menu_footer.is_visible_in_tree(), "arena menu has no bottom instructions; full controls remain in Settings")
	for font: Font in [hud.serif, hud.sans]:
		for character in "LATITUDE Lines 0123456789·/+":
			check(font.has_char(character.unicode_at(0)), "bundled glyph: " + character)
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(900, 506)]:
		root.size = dimensions
		await settle()
		for control: Control in [hud.menu_title, hud.action_button, hud.quit_button]:
			check(inside(control), "title %s fits %s" % [control.name, dimensions])
		click(hud.settings_button)
		await settle()
		check(hud.settings_open and hud.motion_choice.has_focus(), "Settings click moves keyboard focus")
		for control: Control in [hud.menu_title, hud.motion_choice, hud.settings_back]:
			check(inside(control), "settings %s fits %s" % [control.name, dimensions])
		# Even a stray unhandled Enter cannot start a run behind settings.
		var begin := InputEventAction.new()
		begin.action = "begin_crossing"
		begin.pressed = true
		game._unhandled_input(begin)
		check(game.state == game.State.READY, "settings blocks underlying keyboard start")
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		await settle()
		check(not hud.settings_open and hud.settings_button.has_focus(), "Escape returns from settings without quitting")
	hud._show_settings(true)
	hud.motion_choice.select(1)
	hud.motion_choice.item_selected.emit(1)
	check(game.motion_setting == 1 and game.motion_amount() < 1.0, "Reduced retains authoritative camera setting")
	click(hud.settings_back)
	await settle()
	click(hud.action_button)
	await settle()
	check(game.state == game.State.CASTING_OFF and not hud.menu.visible, "mouse Set Sail begins existing cast-off")
	game._physics_process(game.CAST_OFF_SECONDS)
	await settle()
	check(game.state == game.State.SAILING and hud.gameplay_hud.visible, "cast-off reaches sailing HUD")
	game.elapsed = 102.0
	game.enemy_encounters.wave_number = 3
	game.hull = 1
	game.damage_immunity = 0
	game.take_damage(1, "The last shot found its mark.")
	await settle()
	check(hud.menu_title.text == "LOST\nAT SEA" and hud.action_button.text == "RETRY", "real lethal damage presents defeat/retry")
	check(hud.menu_details.text.contains("WAVE 3 / 5") and hud.menu_details.text.contains("01:42"), "defeat reports actual reached wave and elapsed time")
	check(not hud.gameplay_hud.visible and not hud.wave_announcement.visible and not hud.wave_countdown.visible, "defeat hides wave transients")
	check(hud._menu_alpha == 1.0, "Reduced results appear without entrance motion")
	for control: Control in [hud.menu_title, hud.main_menu_button]:
		check(inside(control), "small result %s fits" % control.name)
	click(hud.main_menu_button)
	await settle()
	check(game.state == game.State.READY and hud.action_button.has_focus(), "Main Menu resets and focuses Set Sail without casting off")
	check(game.hull == game.hull_capacity and game.elapsed == 0 and game.enemy_encounters.wave_number == 0 and game.sea_time == 0, "Main Menu resets hull, clock, waves and sea")
	check(game.cannon.shots_fired == 0 and not game.cannon._fire_held and not game.boosting and game.failure_reason.is_empty(), "Main Menu clears input, shots and failure text")
	check(game.motion_setting == 1, "Main Menu preserves motion preference")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await settle()
	check(game.state == game.State.CASTING_OFF, "keyboard Enter still starts from title")
	game._physics_process(game.CAST_OFF_SECONDS)
	game.state = game.State.ARRIVED
	game.elapsed = 245
	game.enemy_encounters.wave_number = 5
	game._clear_player_controls()
	await settle()
	check(hud.menu_title.text == "YOU HELD\nTHE LIGHT" and hud.action_button.text == "SAIL AGAIN", "victory has shared treatment and Sail Again")
	check(hud.menu_details.text.contains("ALL 5 WAVES COMPLETE") and not hud.gameplay_hud.visible, "victory result has no gameplay HUD")
	click(hud.action_button)
	await settle()
	check(game.state == game.State.CASTING_OFF and game.hull == game.hull_capacity and game.enemy_encounters.wave_number == 0, "Sail Again fully resets and casts off")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.cannon._fire_held and not game.boosting, "focus loss keeps controls cleared after menu navigation")
	print("MENU UI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

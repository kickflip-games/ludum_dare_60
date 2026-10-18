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
	check(ProjectSettings.get_setting("application/config/name") == "Blackwater" and hud.menu_title.text == "BLACKWATER", "project and start screen use Blackwater")
	check(hud.menu_column.get_node_or_null("LighthouseMark") == null, "start menu has no lighthouse icon")
	check(hud.menu_actions.get_node_or_null("Quit") == null, "Web menu has no Quit button")
	check(inside(hud.menu) and inside(hud.menu_title) and inside(hud.action_button), "initial menu fits before any resize or settings visit")
	check(hud.action_button.has_focus() and hud.action_button.text == "PLAY", "title starts with focused Set Sail")
	check(hud.menu_column.get_node_or_null("Kicker") == null and hud.menu_column.get_node_or_null("WaveRule") == null
		and not hud.menu_body.visible and hud.menu_body.text.is_empty(), "title has no decorative slogans or divider")
	check(not hud.settings_panel.is_visible_in_tree() and not hud.main_menu_button.visible, "settings hidden on title; no Continue or result action")
	check(hud.settings_panel.find_children("*", "OptionButton", true, false).is_empty(), "Settings has no motion options")
	check(game.motion_setting == 0 and game.motion_amount() == 1.0, "normal play starts with full motion")
	for property in game.get_property_list():
		if property.name == "motion_setting":
			check((property.usage & PROPERTY_USAGE_EDITOR) == 0, "motion preference is not exposed in the editor")
	check(hud.action_button.get_theme_stylebox("normal") is StyleBoxTexture and hud.settings_frame.get_theme_stylebox("panel") is StyleBoxTexture, "buttons and panels use scalable Kenney textures")
	check(not hud.menu_footer.is_visible_in_tree(), "arena menu has no bottom instructions; full controls remain in Settings")
	for font: Font in [hud.serif, hud.sans]:
		for character in "BLACKWATER 0123456789·/+":
			check(font.has_char(character.unicode_at(0)), "bundled glyph: " + character)
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(900, 506)]:
		root.size = dimensions
		await settle()
		for control: Control in [hud.menu_title, hud.action_button, hud.walkthrough_button, hud.settings_button, hud.credits_button]:
			check(inside(control), "title %s fits %s" % [control.name, dimensions])
		check(is_equal_approx(hud.menu_title.get_global_rect().get_center().x, hud.size.x * 0.5) and is_equal_approx(hud.action_button.get_global_rect().get_center().x, hud.size.x * 0.5) and is_equal_approx(hud.settings_button.get_global_rect().get_center().x, hud.size.x * 0.5) and hud.action_button.size.x == 300 and hud.settings_button.size.x == 260, "centered title and buttons retain primary/secondary hierarchy at %s" % dimensions)
		click(hud.settings_button)
		await settle()
		check(not hud.walkthrough_button.is_visible_in_tree(), "Settings hides Walkthrough launch")
		check(hud.settings_open and hud.settings_back.has_focus() and not hud.menu_body.visible, "Settings opens without a slogan and focuses Back")
		for control: Control in [hud.menu_title, hud.settings_panel.get_node("FullControls"), hud.settings_back]:
			check(inside(control), "settings %s fits %s" % [control.name, dimensions])
		check(hud.settings_panel.get_node("FullControls/Action7").text == "Pause / resume", "Escape reference describes Web pause")
		check(game.motion_amount() == 1.0, "Settings navigation keeps full motion")
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
		click(hud.credits_button)
		await settle()
		check(hud.credits_open and not hud.settings_open and hud.menu_title.text == "CREDITS" and hud.credits_back.has_focus(), "Credits opens with focused Back at %s" % dimensions)
		for pair in [["ModelsNames", "Kenney · Quaternius"], ["CodingNames", "Mehdi Zahroui\nAvi Vajpeyi"], ["DiscussionNames", "Kieran Davidson\nRachel Coxhead"], ["MusicNames", "YD GDeshko"], ["SfxNames", "jdsherbert"]]:
			check(hud.credits_panel.get_node(pair[0]).text == pair[1], "requested %s credit is exact" % pair[0])
		for control: Control in [hud.menu_title, hud.credits_panel, hud.credits_back]:
			check(inside(control), "credits %s fits %s" % [control.name, dimensions])
		game._unhandled_input(begin)
		hud._on_action_pressed()
		check(game.state == game.State.READY and not hud.action_button.is_visible_in_tree(), "Credits blocks start shortcuts and hidden Set Sail")
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		await settle()
		check(not hud.credits_open and hud.credits_button.has_focus() and hud.menu_title.text == "BLACKWATER", "Esc returns from Credits to title")
	hud._show_credits(true)
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await settle()
	check(not hud.credits_open and game.state == game.State.READY and hud.credits_button.has_focus(), "Enter on Credits Back returns without starting")
	hud._show_settings(true)
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await settle()
	check(not hud.settings_open and game.state == game.State.READY and hud.settings_button.has_focus(), "focused Back closes Settings with Enter without starting the game")
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
	check(hud.menu_title.text == "SUNK" and hud.action_button.text == "RETRY", "real lethal damage presents defeat/retry")
	check(hud.menu_details.text.contains("WAVE REACHED 3 / 5") and hud.menu_details.text.contains("01:42"), "defeat reports actual reached wave and elapsed time")
	check(not hud.gameplay_hud.visible and not hud.wave_announcement.visible and not hud.wave_countdown.visible, "defeat hides wave transients")
	check(not hud.menu_body.visible and hud.menu_body.text.is_empty(), "results omit flavour text and show only wave/time")
	for control: Control in [hud.menu_title, hud.main_menu_button]:
		check(inside(control), "small result %s fits" % control.name)
	click(hud.credits_button)
	await settle()
	key(KEY_R, true)
	key(KEY_R, false)
	await settle()
	check(hud.credits_open and game.state == game.State.LOST, "Credits is available after defeat and blocks underlying Retry shortcut")
	click(hud.credits_back)
	await settle()
	check(hud.menu_title.text == "SUNK" and not hud.credits_open, "Credits Back restores the defeat result")
	click(hud.main_menu_button)
	await settle()
	check(game.state == game.State.READY and hud.action_button.has_focus() and hud.menu_title.text == "BLACKWATER", "Main Menu restores Blackwater and focuses Set Sail without casting off")
	check(game.hull == game.hull_capacity and game.elapsed == 0 and game.enemy_encounters.wave_number == 0 and game.sea_time == 0, "Main Menu resets hull, clock, waves and sea")
	check(game.motion_amount() == 1.0, "returning to Main Menu retains full motion")
	check(game.cannon.shots_fired == 0 and not game.cannon._fire_held and not game.boosting and game.failure_reason.is_empty(), "Main Menu clears input, shots and failure text")
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
	check(hud.menu_title.text == "VICTORY" and hud.action_button.text == "PLAY AGAIN", "victory has shared treatment and Sail Again")
	check(hud.menu_details.text.contains("WAVE REACHED 5 / 5") and not hud.gameplay_hud.visible, "victory result has no gameplay HUD")
	check(not hud.menu_body.visible, "victory has no decorative subtitle")
	click(hud.action_button)
	await settle()
	check(game.state == game.State.CASTING_OFF and game.hull == game.hull_capacity and game.enemy_encounters.wave_number == 0, "Sail Again fully resets and casts off")
	check(game.motion_amount() == 1.0, "retry retains full motion")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.cannon._fire_held and not game.boosting, "focus loss keeps controls cleared after menu navigation")
	print("MENU UI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

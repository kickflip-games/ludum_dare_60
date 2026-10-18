extends SceneTree
## Native, staged menu captures. No gameplay shortcuts are installed in the game.
var game
var output := "res://../build/menu_ui/after"
var dimensions := Vector2i(1280, 720)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0.5)
	for frame in 6: await process_frame
	print("LAYOUT %s: menu=%s title=%s visible=%s alpha=%s" % [label, game.hud.menu.get_global_rect(), game.hud.menu_title.get_global_rect(), game.hud.menu.is_visible_in_tree(), game.hud.menu.modulate.a])
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("MENU CAPTURE: " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = dimensions
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.set_process_unhandled_input(false)
	await capture("title")
	# Capture real hover and pressed GUI states before activating the start action.
	game.hud.action_button.release_focus()
	var hover := InputEventMouseMotion.new()
	hover.position = game.hud.action_button.get_global_rect().get_center()
	root.push_input(hover, true)
	await capture("primary-hover")
	game.hud.action_button.set_block_signals(true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = hover.position
	press.pressed = true
	root.push_input(press, true)
	await capture("primary-pressed")
	# Cancel this held click outside the button.
	press = press.duplicate()
	press.position = Vector2(2, 2)
	press.pressed = false
	root.push_input(press, true)
	game.hud.action_button.set_block_signals(false)
	hover.position = game.hud.settings_button.get_global_rect().get_center()
	root.push_input(hover, true)
	game.hud.settings_button.grab_focus()
	await capture("secondary-focused")
	game.hud._show_credits(true)
	await capture("credits")
	game.hud._show_credits(false)
	if game.hud.has_method("_show_settings"):
		game.hud._show_settings(true)
		await capture("settings")
		game.hud._show_settings(false)
	game.state = game.State.LOST
	game.failure_reason = "The last shot found its mark."
	game.elapsed = 102.0
	game.enemy_encounters.wave_number = 3
	game._update_view(1.0)
	await capture("defeat")
	game.state = game.State.ARRIVED
	game.enemy_encounters.wave_number = 5
	game._update_view(1.0)
	await capture("victory")
	game.motion_setting = 1
	await capture("victory-reduced")
	game.queue_free()
	await process_frame
	quit()

extends "res://tests/walkthrough_smoke.gd"
## Staged native layouts; practice interaction is exercised in walkthrough_smoke.
func capture(label: String) -> void:
	game.hud._process(0)
	game.hud.walkthrough_card._process(0)
	for frame in 8: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("WALKTHROUGH CAPTURE: " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	create_game()
	await settle()
	await capture("menu-walkthrough-button")
	game.start_crossing(true)
	step(game.CAST_OFF_SECONDS)
	for index in range(6):
		game.walkthrough.step = index
		game.walkthrough._reset_step(game)
		step(0)
		await capture("practice-%d" % index)
		if index == 0:
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			key(KEY_A, true)
			step(0.2)
			await capture("steer-pressed")
			step(0.4)
			key(KEY_A, false)
			await capture("steer-complete")
		if index == 4:
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			key(KEY_E, true)
			step(0.5)
			key(KEY_E, false)
			assert(game.arena_cannon_view and game.walkthrough.practiced)
			await capture("camera-active")
	game.motion_setting = 1
	await capture("reduced-ready")
	game.queue_free()
	await process_frame
	quit()

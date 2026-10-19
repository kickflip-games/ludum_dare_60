extends "res://tests/fleet_hud_smoke.gd"
## Actual GPU frames for cloth, transparency/fade and small-window review.
var output := "res://../build/ribbon-cloth-review/1280x720"
var dimensions := Vector2i(1280,720)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]),int(parts[1]))
	_run.call_deferred()

func capture(label: String) -> void:
	hud._process(0)
	for frame in 3: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("CLOTH CAPTURE: " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = dimensions
	create_game()
	game.set_process_unhandled_input(false)
	await settle()
	begin()
	await capture("wave-bright")
	hud._process(2.2)
	await capture("wave-fading")
	hud._process(0.21)
	await capture("wave-dismissed")
	for fleet in 4:
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0)
	hud._process(3)
	for frame in (36 if dimensions.x == 1280 else 12):
		hud._process(0.08)
		await capture("cloth-%02d" % frame)
	game.set_paused(true)
	await capture("paused")
	game.set_paused(false)
	game.restart(true)
	await capture("reset")
	game.queue_free()
	await process_frame
	quit()

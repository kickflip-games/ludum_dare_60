extends "res://tests/fleet_hud_smoke.gd"
## Native frozen captures; real encounter accounting with scripted visual states.
var output := "res://../build/fleet-hud"

func capture(label: String) -> void:
	hud._process(0)
	await settle()
	RenderingServer.force_draw(true, 1.0 / 60)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("FLEET CAPTURE: " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			root.size = Vector2i(int(parts[0]),int(parts[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	create_game()
	# Frozen fixtures must ignore unrelated keyboard events from other test windows.
	game.set_process_unhandled_input(false)
	await physics_frame
	begin()
	await capture("01-wave-I")
	hud._process(2.41)
	await capture("02-circles-only")
	var first = enemies.living_ships()[0]
	for hit in first.hull: first.take_hit()
	await capture("03-one-destroyed")
	enemies.wave_remaining = 0
	enemies._update_arena(0)
	await capture("04-overlapping-wave-II")
	# Clean maximum 17-circle backlog, without a previous defeat.
	begin()
	for fleet in 4:
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0)
	await capture("05-final-wave-backlog")
	game.boat.position = game.arena_center() + Vector3(180,0,0)
	game._update_view(1)
	await capture("06-final-wave-storm")
	hud._process(2.41)
	await capture("07-final-circles-health-storm")
	for hit in enemies.boss.hull: enemies.boss.take_hit()
	hud._process(0.3) # Finish the result-menu fade before its rendered capture.
	await capture("08-victory")
	begin()
	await capture("09-restart-wave-I")
	game.restart(true)
	await capture("10-menu-cleared")
	begin()
	game.motion_setting = 1
	hud._process(2.2)
	await capture("11-reduced-motion")
	hud._process(0.21)
	await capture("12-reduced-motion-cleared")
	game.queue_free()
	await process_frame
	quit()

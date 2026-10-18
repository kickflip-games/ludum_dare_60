extends "res://tests/fleet_hud_smoke.gd"
## Native frozen review of launch, kills and maximum outstanding fleet count.
var output := "res://../build/fleet-hud"

func capture(label: String) -> void:
	hud._process(0.3)
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
	await physics_frame
	begin()
	hud._process(0.3)
	await capture("first-fleet")
	var first = enemies.living_ships()[0]
	while first.hull > 0: first.take_hit()
	hud._process(3.1)
	await capture("one-remaining")
	enemies.wave_remaining = 0
	enemies._update_arena(0)
	hud._process(0.3)
	await capture("second-fleet")
	for fleet in 3:
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0.3)
	await capture("final-backlog")
	game.boat.position = game.arena_center() + Vector3(180,0,0)
	hud._process(0)
	await capture("storm-and-launch")
	game.queue_free()
	await process_frame
	quit()

extends SceneTree
## Frozen native incoming-warning states; detection is tested in hud_events_smoke.
var game
var output := "res://../build/threat-icon-review/1280x720"
var dimensions := Vector2i(1280,720)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]),int(parts[1]))
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0)
	for frame in 6: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("THREAT CAPTURE: " + path)

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
	game.set_process_unhandled_input(false)
	game.hud.set_process(false)
	game.start_crossing()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(0,0,100)
	game.heading = 0
	game._update_view(1)
	var waves = game.enemy_encounters
	waves.wave_number = 1
	var ship = waves.ship
	for side in [-1, 1]:
		ship.begin(game.boat.position + game.cannon.starboard_direction() * 24 * side)
		ship.mode = ship.Mode.TELEGRAPH
		waves.enabled = true
		game.hud._process(3)
		await capture("left-bright" if side == -1 else "right-bright")
		game.hud._process(0.45)
		await capture("left-dim" if side == -1 else "right-dim")
	ship.reset()
	await capture("cleared")
	game.queue_free()
	await process_frame
	quit()

extends SceneTree
## Actual renderer captures after advancing the real game. This is scripted play.

const Pilot = preload("res://tests/voyage_pilot.gd")
var game
var output: String = "/tmp/last-bearing-gameplay"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()


func capture(label: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result: int = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("CAPTURE %s: %s" % [label, result])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await capture("01-title")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	for i in range(900):
		game.sea_time += 1.0 / 60.0
		game.advance_sailing(1.0 / 60.0, Pilot.steering(game))
		game.cannon.advance(1.0 / 60.0)
		game._update_view(1.0 / 60.0)
		await physics_frame
	await capture("02-current-and-hull")
	game.reading = true
	for i in range(20):
		game.advance_sailing(1.0 / 60.0, 0.0)
		game._update_view(1.0 / 60.0)
		await physics_frame
	await capture("03-astrolabe")
	game.queue_free()
	await process_frame
	quit()

extends "res://tests/arcade_controls_smoke.gd"
## Real-renderer input-driven combat; safety/lifecycle assertions live in smoke.
func _run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await process_frame
	await capture("00-controls")
	fresh()
	await capture("01-default-sailing")
	mouse(100000)
	for frame in 60:
		game._update_view(1.0 / 60)
	await capture("02-maximum-look")
	mouse(-100000)
	for frame in 60:
		game._update_view(1.0 / 60)
	await capture("02b-opposite-limit")
	await trajectory_cases()
	await moving_combat()
	print("NATIVE ARCADE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

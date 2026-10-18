extends "res://tests/arena_previews.gd"
## Repeatable arena scenery views; helm shots use the normal chase camera.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	await physics_frame
	await capture("01-menu")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	helm(Vector2(0, -75), Vector2(100, -57))
	await capture("02-spawn")
	helm(Vector2(65, -70), Vector2(152, -168))
	await capture("03-northeast-grove")
	helm(Vector2(65, 90), Vector2(148, 171))
	await capture("04-southeast-grove")
	helm(Vector2(-75, 40), Vector2(-150, 181))
	await capture("05-southwest-grove")
	helm(Vector2(-75, -30), Vector2(-233, -14))
	await capture("06-west-grove")
	helm(Vector2(20, -100), Vector2(-10, -235))
	await capture("07-north-grove")
	game.hud.hide()
	game.world_environment.environment.fog_enabled = false
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 570
	game.camera.position = game.arena_center() + Vector3(0, 600, 0.1)
	game.camera.look_at(game.arena_center(), Vector3.FORWARD)
	ring(170, Color("e7c893"))
	await capture("08-overhead")
	game.free()
	await process_frame
	quit()

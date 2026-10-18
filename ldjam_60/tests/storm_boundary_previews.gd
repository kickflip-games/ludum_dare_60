extends SceneTree
## Actual gameplay camera and shared water shader, staged for visual comparison.
var game
var output := "/tmp/latitude-storm-review"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	game._update_view(0)
	game.hud._process(0)
	await process_frame
	RenderingServer.force_draw(true,1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	print("STORM CAPTURE: " + label)

func pose(distance: float, heading: float = PI/2) -> void:
	game.boat.global_position = game.arena_center() + Vector3(distance,0,0)
	game.heading = heading
	game.boat.rotation.y = -heading
	game._sailing_camera_initialized = false
	game._update_view(1)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	await physics_frame
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.sea_time = 18
	game.ocean.wave_time = 18
	game.elapsed = 0.45
	pose(110)
	await capture("01-safe-water")
	pose(145)
	await capture("02-approach")
	pose(165)
	await capture("03-near-line")
	pose(180)
	await capture("04-outside")
	pose(195,-PI/2)
	await capture("05-return-course")
	game.motion_setting = 1
	await capture("06-reduced")
	root.size = Vector2i(900,506)
	await capture("07-small-window")
	game.motion_setting = 0
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	await capture("08-retry")
	game.queue_free()
	await process_frame
	quit()

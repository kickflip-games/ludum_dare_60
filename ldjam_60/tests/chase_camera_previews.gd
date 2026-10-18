extends "res://tests/sailing_camera_previews.gd"
## Matched arena views: real steering/aim inputs, with enemies disabled for framing.
var baseline_script := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-script="):
			baseline_script = arg.trim_prefix("--baseline-script=")
	super._initialize()

func capture(label: String) -> void:
	RenderingServer.force_draw(true, 1.0 / 60.0)
	await super.capture(label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	if not baseline_script.is_empty():
		game.set_script(load(baseline_script))
		game.arena_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	place(game.boat.position, game.heading)
	game.wave_encounters.enabled = false
	await advance(0.6)
	await capture("01-sailing")
	action("steer_starboard", true)
	await advance(1.0)
	await capture("02-steering")
	action("steer_starboard", false)
	action("watch_starboard", true)
	await advance(0.6)
	await capture("03-cannon")
	action("watch_starboard", false)
	# Arena play deliberately has no sextant mode; check release back to sailing.
	await advance(1.0)
	await capture("04-return-to-sailing")
	await advance(1.0)
	game.take_damage(1, "Camera review fixture")
	game._update_view(0.2)
	await capture("05-damage")
	for size: Vector2i in [Vector2i(960, 720), Vector2i(1440, 720)]:
		root.size = size
		await advance(0.6)
		await capture("06-aspect-%d" % size.x)
	var file := FileAccess.open(output.path_join("framing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(frames, "\t"))
	game.queue_free()
	await process_frame
	await process_frame
	quit()

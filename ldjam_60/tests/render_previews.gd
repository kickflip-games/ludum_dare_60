extends SceneTree
## Optional visual QA. Captures the actual game viewport; does not modify the course.
## Godot --path ldjam_60 --script res://tests/render_previews.gd -- --output=/tmp/last-bearing

var output_dir: String = "/tmp/last-bearing"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	_run.call_deferred()


func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output_dir.path_join(filename + ".png"))
	print("CAPTURE: %s (%s)" % [filename, result])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.sea_time = 18.0
	game._update_view(1.0)
	await capture("01-title")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	game.hud.queue_redraw()
	await capture("02a-casting-off")
	game._physics_process(game.CAST_OFF_SECONDS * 0.5)
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("02-helm")
	game.reading = true
	game.last_reading = game.heading
	game.has_reading = true
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("03a-starting-bearing")
	game.heading = deg_to_rad(30.0)
	game.last_reading = game.heading
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("03-astrolabe")
	game.reading = false
	game.boat.position = game.course_forward() * 45.0
	game.elapsed = 7.2
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("04-hazards")
	game.sea_time = 24.0
	game._update_view(1.0)
	await capture("04b-waves-later")
	game.boat.position = game.course_forward() * 105.0 + game.course_right() * -6.0
	game.elapsed = 18.0
	game._update_view(1.0)
	game.cannon.fire()
	game.hud.queue_redraw()
	await capture("08-cannon-fire")
	for step in range(60):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
	game.hud.queue_redraw()
	await capture("09-cannon-impact")
	game.cannon.reset()
	game.elapsed = 27.0
	game.sea_creatures.update_creatures()
	game.boat.position = game.course_forward() * 160.0 + game.course_right() * 20.0
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("10-creature-approach")
	var serpent: StaticBody3D = game.sea_creatures.creatures[0].body
	game.boat.position = serpent.position - game.course_right() * 25.0 - game.course_forward() * 2.6
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("11-creature-abeam")
	game.cannon.fire()
	for step in range(40):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
	game.hud.queue_redraw()
	await capture("12-creature-hit")
	game.cannon.reset()
	game.boat.position = game.course_forward() * 410.0 + game.course_right() * -15.0
	game.elapsed = 67.0
	game.beacon.visible = true
	game.beacon_seen = true
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("05-lighthouse")
	game.boat.position = game.course_forward() * 480.0 + game.course_right() * -12.0
	game.elapsed = 78.0
	game.advance_sailing(1.0 / 60.0, 0.0)
	game._update_view(1.0)
	game.hud.queue_redraw()
	game.hud._sync_button()
	await capture("06-arrived")
	game.state = game.State.LOST
	game.failure_reason = "The hull struck a rock."
	game.end_view_blend = 1.0
	game._update_view(1.0)
	game.hud.queue_redraw()
	await capture("07-collision")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game._update_view(1.0)
	game.hud.queue_redraw()
	for frame in range(120):
		game.sea_time += 1.0 / 60.0
		game._update_view(1.0 / 60.0)
		await process_frame
	print("HELM RENDER SAMPLE: %d FPS" % Engine.get_frames_per_second())
	game.reading = true
	game._update_view(1.0)
	game.hud.queue_redraw()
	for frame in range(120):
		game.sea_time += 1.0 / 60.0
		game._update_view(1.0 / 60.0)
		await process_frame
	print("SKY RENDER SAMPLE: %d FPS, %d primitives" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.queue_free()
	await process_frame
	quit()

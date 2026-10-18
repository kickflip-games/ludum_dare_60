extends SceneTree
## Native input sequence: menu, sailing, gun entry/fire/return, focused sextant.
var game
var output := "/tmp/latitude-controls/after"
var frames := 0
var failures := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap_fire() -> void:
	action("fire_starboard", true)
	action("fire_starboard", false)


func advance(seconds: float) -> void:
	for frame in range(roundi(seconds * 60)):
		game._physics_process(1.0 / 60)
		game.cannon.advance(1.0 / 60)
		game.hud._process(1.0 / 60)
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60)
		if frames % 3 == 0:
			root.get_texture().get_image().save_png(output.path_join("sequence/frame-%04d.png" % (frames / 3)))
		frames += 1


func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	var valid: bool = result == OK
	match label:
		"01-sailing", "07-sailing-again":
			valid = valid and game.camera_mode == game.CameraMode.SAILING and not game.hud.instrument.visible and game.hud.star_guidance().is_empty()
		"02-cannon":
			valid = valid and game.cannon.aiming and game.aim_camera_blend == 1.0 and game.cannon.shots_fired == 0
		"03-firing":
			valid = valid and game.cannon.aiming and game.cannon.shots_fired == 1 and game.cannon.flash.visible
		"04-returning":
			valid = valid and not game.cannon.aiming and game.turn_input == -1 and game.aim_camera_blend > 0 and game.aim_camera_blend < 1
		"05-sextant":
			valid = valid and game.focus_strength > 0.999 and game.hud.instrument.visible and not game.hud.star_horizon_line().is_empty()
		"06-opening-controls":
			valid = valid and game.hud.menu.visible and game.state == game.State.READY
	if not valid:
		failures += 1
		push_error("Capture does not show its expected input-driven state: " + label)
	print("CONTROL CAPTURE %s: error=%d mode=%d aim=%s focus=%.2f shots=%d" % [label, result, game.camera_mode, game.cannon.aiming, game.focus_strength, game.cannon.shots_fired])


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("sequence"))
	var sequence := DirAccess.open(output.path_join("sequence"))
	for filename in sequence.get_files():
		if filename.begins_with("frame-") and filename.ends_with(".png"):
			sequence.remove(filename)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.hud._process(0)
	await capture("06-opening-controls")
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.start_crossing()
	await advance(1.3)
	game.heading = game.destination_bearing()
	await advance(1)
	await capture("01-sailing")
	action("watch_starboard", true)
	await advance(0.4)
	await capture("02-cannon")
	tap_fire()
	await advance(0.05)
	await capture("03-firing")
	action("watch_starboard", false)
	action("steer_port", true)
	await advance(0.12)
	await capture("04-returning")
	await advance(0.5)
	action("steer_port", false)
	action("astrolabe", true)
	await advance(0.8)
	await capture("05-sextant")
	action("astrolabe", false)
	await advance(0.5)
	await capture("07-sailing-again")
	print("CONTROL SEQUENCE: %d rendered frames, %d failures" % [frames, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

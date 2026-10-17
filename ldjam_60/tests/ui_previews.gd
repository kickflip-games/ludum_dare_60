extends SceneTree
## Reproducible UI fixtures rendered by Godot. Not a human playthrough.
var game
var output := "/tmp/last-bearing-ui/before"
var requested_size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run.call_deferred()


func capture(label: String) -> void:
	for frame in range(24):
		game.hud.queue_redraw()
		await process_frame
	# Explicit drawing also works while another review window covers this one.
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var pixels := root.get_texture().get_image()
	var result := pixels.save_png(output.path_join(label + ".png"))
	print("UI CAPTURE %s: %d (%s)" % [label, result, pixels.get_size()])
	if pixels.get_size() != requested_size or result != OK:
		push_error("UI capture did not match the requested window size.")
		quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI previews require a real renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = requested_size
	await process_frame
	print("UI WINDOW: pixels=%s logical=%s" % [root.size, root.get_visible_rect()])
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await capture("01-title")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.elapsed = 14.0
	game.phase_banner_left = 0.0
	game._update_view(1.0)
	await capture("02-sailing")
	Input.action_press("astrolabe")
	game._physics_process(1.8)
	Input.action_release("astrolabe")
	await capture("03-astrolabe")
	game._physics_process(0.3)
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 24.0 + Vector3(0, 0, -6)
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0.5
	ship.locked_point = game.boat.position
	game.starboard_look = true
	game._update_view(0.4)
	await capture("04-combat-ready")
	game.cannon.fire()
	game.cannon.advance(0.4)
	await capture("05-combat-reload")
	game.take_damage(1, "Enemy broadside hit")
	game._update_view(0.1)
	await capture("06-damage")
	game.damage_immunity = 0.0
	game.take_damage(1, "Hull struck reef")
	game._update_view(0.7)
	await capture("07-low-hull")
	game.reading = true
	game._update_view(1.8)
	await capture("08-astrolabe-danger")
	game.reading = false
	ship.reset()
	game.starboard_look = false
	game.wave_encounters.enabled = false
	# Keep these staged UI captures in open water with authored patrols consumed.
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.boat.position = Vector3(400, 0, -360)
	game.heading = 0.0
	for frame in range(240):
		game.advance_sailing(1.0 / 60.0, 0.0)
		game.cannon.advance(1.0 / 60.0)
		game._update_view(1.0 / 60.0)
	await capture("08b-repair-progress")
	for frame in range(240):
		game.advance_sailing(1.0 / 60.0, 0.0)
		game.cannon.advance(1.0 / 60.0)
		game._update_view(1.0 / 60.0)
	await capture("08c-hull-restored")
	for frame in range(480):
		game.advance_sailing(1.0 / 60.0, 0.0)
		game.cannon.advance(1.0 / 60.0)
		game._update_view(1.0 / 60.0)
	await capture("08d-fully-repaired")
	game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
	game.voyage.set_target(game)
	game.boat.position = game.target + Vector3(0, 0, -5)
	game.advance_sailing(0.001, 0.0)
	game._update_view(1.0)
	await capture("09-victory")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	for hit in range(game.hull_capacity):
		game.damage_immunity = 0.0
		game.take_damage(1, "Hull struck reef")
	game._update_view(1.0)
	await capture("10-defeat")
	game.queue_free()
	await process_frame
	quit()

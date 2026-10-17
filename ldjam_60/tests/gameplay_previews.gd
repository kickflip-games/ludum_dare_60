extends SceneTree
## Actual native-rendered scripted voyage. No screenshots or positions are fabricated.
const Pilot = preload("res://tests/voyage_pilot.gd")
var game
var output: String = "/tmp/last-bearing-gameplay"
var captured: Dictionary = {}
var glance_left: float = 0.0
var clip_frame: int = 0
var clip_enabled: bool = true


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-clip":
			clip_enabled = false
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()


func capture(label: String) -> void:
	if captured.has(label):
		return
	captured[label] = true
	game.hud.queue_redraw()
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var result: int = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("CAPTURE %s: %s" % [label, result])


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Gameplay captures need the actual renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	capture("01-departure-title")
	for i in range(60):
		game._physics_process(1.0 / 60.0)
		await process_frame
	game.start_crossing()
	while game.state == game.State.CASTING_OFF:
		game._physics_process(1.0 / 60.0)
		await process_frame
	var cadences: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame in range(10000):
		var steer: float = Pilot.steering(game, 1.0, true)
		Input.action_release("steer_port")
		Input.action_release("steer_starboard")
		if absf(steer) > 0.01:
			Input.action_press("steer_port" if steer < 0 else "steer_starboard", absf(steer))
		if fmod(game.elapsed, 11.0) < 1.8:
			Input.action_press("astrolabe")
		else:
			Input.action_release("astrolabe")
		glance_left = maxf(0, glance_left - 1.0 / 60.0)
		var ship = game.enemy_encounters.ship
		if ship.mode == ship.Mode.TELEGRAPH and ship.timer > 0.25:
			glance_left = 0.3
		if glance_left > 0 and not game.reading:
			Input.action_press("watch_starboard")
		else:
			Input.action_release("watch_starboard")
		game._physics_process(1.0 / 60.0)
		if not game.reading:
			var target: Dictionary = game.cannon.aim_target()
			if not target.is_empty() and target.aligned and target.body.get_meta("target_kind") == "ship":
				if game.cannon.fire():
					glance_left = 1.2
		game.cannon.advance(1.0 / 60.0)
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
		var now: int = Time.get_ticks_usec()
		cadences.append((now - previous) / 1000.0)
		previous = now
		if frame % 300 == 0:
			print("RENDER PROGRESS: frame=%d t=%.1f course=%.1f" % [frame, game.elapsed, game.journey_distance()])
		if clip_enabled and game.enemy_encounters.encounter_index == 1 and ship.age > 2 and ship.age < 18 and ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED] and clip_frame < 240 and frame % 4 == 0:
			root.get_texture().get_image().save_png(output.path_join("clip/frame-%04d.png" % clip_frame))
			clip_frame += 1
		var progress: float = game.journey_progress()
		if progress > 0.18 and game.look_blend < 0.1 and not game.reading:
			capture("02-rock-gate")
		if game.reading and progress > 0.2 and game.focus_strength >= 1.0:
			capture("03-astrolabe")
		if ship.mode == ship.Mode.TELEGRAPH and game.look_blend > 0.9:
			capture("04-cutter-broadside-warning")
		if ship.hit_reaction > 0.4 and game.look_blend > 0.9:
			capture("05-cutter-impact")
		if ship.mode == ship.Mode.SINKING and game.look_blend > 0.9:
			capture("06-cutter-sinking")
		if progress > 0.64 and game.look_blend < 0.1 and not game.reading:
			capture("07-storm-passage")
		if game.phase == 3 and not game.reading and game.look_blend < 0.1:
			capture("08-lighthouse-approach")
		if game.state != game.State.SAILING:
			break
	for action: String in ["steer_port", "steer_starboard", "astrolabe", "watch_starboard"]:
		Input.action_release(action)
	for i in range(120):
		game._physics_process(1.0 / 60.0)
		await process_frame
	capture("09-safe-harbour" if game.state == game.State.ARRIVED else "09-lost-at-sea")
	print("RENDERED VOYAGE: state=%d seconds=%.2f hull=%d cutters_sunk=%d" % [game.state, game.elapsed, game.hull, game.enemy_encounters.ships_sunk])
	# Renderer cadence includes script-driving/encoding if Movie Maker is enabled.
	cadences.sort()
	print("RENDERED PHYSICS CADENCE: median=%.3fms p95=%.3fms (includes scripted pilot; movie encoding when enabled)" % [cadences[cadences.size() / 2], cadences[int(cadences.size() * 0.95)]])
	var won: bool = game.state == game.State.ARRIVED
	game.queue_free()
	await process_frame
	quit(0 if won else 1)

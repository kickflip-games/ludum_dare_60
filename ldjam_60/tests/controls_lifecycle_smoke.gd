extends SceneTree
## Real input edges, restart timing and lifecycle cleanup; deterministic simulation.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func step(seconds: float, hz: int = 60) -> void:
	for frame in range(roundi(seconds * hz)):
		game._physics_process(1.0 / hz)
		game.cannon.advance(1.0 / hz)
	game.hud._process(0.0)


func fresh() -> void:
	for name: String in ["watch_starboard", "fire_starboard", "astrolabe", "steer_port", "steer_starboard", "restart_crossing"]:
		action(name, false)
	game.restart()
	step(1.3)
	game.boat.position = Vector3(400, 0, 320)
	game.heading = 0.0
	game.wave_sailing.reset()
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	for hz in [30, 60, 120]:
		fresh()
		action("restart_crossing", true)
		step(0.1, hz)
		action("restart_crossing", false)
		step(0.7, hz)
		check(game.state == game.State.SAILING and game.elapsed > 0.7 and game.restart_elapsed == 0.0, "%d Hz brief R tap never restarts" % hz)
		action("restart_crossing", true)
		step(0.4, hz)
		check(game.hud.notice.visible and game.hud.notice.text == "Hold R to restart", "%d Hz only the held restart shows its temporary hint" % hz)
		action("restart_crossing", false)
		step(0.1, hz)
		check(game.restart_elapsed == 0.0 and not game.hud.notice.visible, "%d Hz release cancels timer and hint" % hz)
		action("restart_crossing", true)
		step(0.4, hz)
		check(game.state == game.State.SAILING, "%d Hz partial holds cannot accumulate" % hz)
		step(0.2, hz)
		check(game.state == game.State.CASTING_OFF and game.elapsed == 0.0 and game.restart_elapsed == 0.0, "%d Hz 0.6-second continuous hold restarts" % hz)
		step(3.0, hz)
		check(game.state == game.State.SAILING and game.elapsed > 1.5, "%d Hz continuous R hold restarts only once" % hz)
		action("restart_crossing", false)
		step(0.1, hz)
		action("restart_crossing", true)
		step(0.6, hz)
		check(game.state == game.State.CASTING_OFF, "%d Hz release then fresh full hold can restart again" % hz)
	fresh()
	action("restart_crossing", true)
	step(0.4)
	action("restart_crossing", false)
	action("restart_crossing", true)
	step(0.4)
	check(game.state == game.State.SAILING, "sub-tick R release/repress starts a fresh continuous hold")
	action("restart_crossing", false)
	# Focus loss cancels an incomplete hold, pending shot and camera/input flags.
	fresh()
	action("watch_starboard", true)
	step(0.4)
	action("fire_starboard", true)
	action("restart_crossing", true)
	step(0.3)
	game.cannon.cooldown = 0.0
	action("fire_starboard", false)
	action("fire_starboard", true)
	var shots: int = game.cannon.shots_fired
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(1.0)
	check(game.state == game.State.SAILING and game.restart_elapsed == 0 and not game.cannon.aiming and game.cannon.shots_fired == shots and game.aim_camera_blend == 0, "focus loss clears incomplete R, held E/F and pending shot; camera returns")
	action("restart_crossing", true)
	step(0.4)
	check(game.state == game.State.SAILING, "R after focus loss needs a fresh full hold")
	action("restart_crossing", false)
	# Retired Space does not affect E/F ordering or create a camera mode.
	for order in [["watch_starboard", "fire_starboard", "astrolabe"], ["watch_starboard", "astrolabe", "fire_starboard"], ["fire_starboard", "watch_starboard", "astrolabe"], ["fire_starboard", "astrolabe", "watch_starboard"], ["astrolabe", "watch_starboard", "fire_starboard"], ["astrolabe", "fire_starboard", "watch_starboard"]]:
		fresh()
		for name: String in order:
			action(name, true)
		action("steer_starboard", true)
		step(0.3)
		var expected_shots := 1 # Same physics tick has held E and one fresh F edge.
		check(not game.reading and game.cannon.aiming and game.cannon.shots_fired == expected_shots and game.turn_input == 0,"E/F preserve event ordering while retired Space has no effect: %s" % str(order))
		action("steer_starboard", false)
		action("astrolabe", false)
		step(0.5)
		check(game.cannon.aiming and game.cannon.shots_fired == expected_shots and game.hud.instrument.visible,"held E and permanent sextant remain available without repeated fire: %s" % str(order))
	# Sub-tick Space hold/release discards an old F press even if no sighting tick ran.
	fresh()
	action("watch_starboard", true)
	step(0.1)
	action("fire_starboard", true)
	action("astrolabe", true)
	action("astrolabe", false)
	step(0.5)
	check(game.cannon.aiming and game.cannon.shots_fired == 1,"sub-tick retired Space transition does not swallow a fresh F press")
	# Active crests and collision hazards remain effective while aiming.
	fresh()
	action("watch_starboard", true)
	var d := Vector2(1, -0.5).normalized()
	game.ocean.wave_field.add_wave(Vector2(400, 320-game.SPEED*3.0) - d * 24, d, 1.0, 4.0, 26.0, 8.0, game.sea_time, 8.0)
	step(6.0)
	check(game.cannon.aiming and absf(game.heading) > deg_to_rad(5) and game.turn_input == 0, "existing oblique crest still changes heading during held E")
	fresh()
	action("watch_starboard", true)
	game._add_hazard(Vector3(400, 0, 302), 3.0, "rock")
	await physics_frame
	step(3.0)
	check(game.cannon.aiming and game.hits_taken > 0 and game.hull < game.hull_capacity, "real rock contact still damages the automatically moving aiming boat")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		fresh()
		action("watch_starboard", true)
		step(0.4)
		action("fire_starboard", true)
		action("restart_crossing", true)
		step(0.2)
		action("fire_starboard", false)
		action("fire_starboard", true)
		if ending == game.State.LOST:
			game.damage_immunity = 0
			game.take_damage(game.hull, "input lifecycle regression")
		else:
			game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
			game.voyage.leg = game.voyage.POINTS.size()-1
			game.voyage.set_target(game)
			game.boat.position = game.target
			game.advance_sailing(0.001, 0.0)
		step(0.7)
		check(game.state == ending and not game.cannon.aiming and game.cannon.projectiles.is_empty() and game.restart_elapsed == 0.0 and not game.reading and game.hud.star_guidance().is_empty(), "ending %d clears held controls, pending shots, projectiles and partial restart" % ending)
		action("restart_crossing", false)
		action("restart_crossing", true)
		check(game.state == game.State.CASTING_OFF, "ending %d fresh R press retries immediately" % ending)
		step(2.5)
		check(game.state == game.State.SAILING and not game.cannon.aiming and game.cannon.shots_fired == 0 and game.hull == game.hull_capacity, "ending %d retry restores clean controls and does not repeat held R" % ending)
	# Returning to title then casting off cannot retain a previous restart timer.
	fresh()
	action("restart_crossing", true)
	step(0.4)
	game.state = game.State.READY
	game.start_crossing()
	step(2.0)
	check(game.state == game.State.SAILING and game.restart_elapsed == 0.0, "title/cast-off clears an incomplete hold and consumes already-held R")
	fresh()
	print("CONTROLS LIFECYCLE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

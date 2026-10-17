extends SceneTree
## Rendered input-driven response comparisons and a complete accelerated scripted voyage.
const Pilot = preload("res://tests/archipelago_pilot.gd")
var game
var output_dir := "../artifacts/water_review/wave_implementation"
var results: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	_run.call_deferred()

func steer(value: float) -> void:
	Input.action_release("steer_port")
	Input.action_release("steer_starboard")
	if absf(value) > 0.0001:
		Input.action_press("steer_port" if value < 0 else "steer_starboard", absf(value))

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	for counter in [false, true]:
		game.restart()
		game.state = game.State.SAILING
		game.enemy_encounters.enabled = false
		game.wave_encounters.enabled = false
		game.boat.position = Vector3(-300, 0, -350)
		game.heading = 0
		game.boat.rotation.y = 0
		var d := Vector2(1, -0.5).normalized()
		game.ocean.wave_field.add_wave(Vector2(-300, -371) - d * 24, d, 1, 4.8, 26, 8, 0, 8)
		for frame in range(480):
			var input_value := 0.0
			if counter:
				input_value = clampf(-game.heading * 3 - (game.boat.position.x + 300) * 0.12 - game.wave_sailing.drift.x * 0.22, -1, 1)
			steer(input_value)
			game._physics_process(1.0 / 60.0)
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
			if counter and frame in [120, 180, 240]:
				root.get_texture().get_image().save_png(output_dir.path_join("steering-%d.png" % frame))
		results.append({"countersteering": counter, "sideways_m": game.boat.position.x + 300,
			"heading_degrees": rad_to_deg(game.heading), "hull": game.hull})
		print("RENDERED RESPONSE: %s" % results.back())
	steer(0)
	if absf(results[1].sideways_m) >= absf(results[0].sideways_m) * 0.5:
		failures += 1
	game.enemy_encounters.enabled = true
	game.wave_encounters.enabled = true
	game.restart()
	game.state = game.State.SAILING
	var pilot := Pilot.new()
	var previous_phase := -1
	var captures := 0
	var actual_frames := 0
	var frame_ms: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	var shore_hits := 0
	var last_hits := 0
	for frame in range(24000):
		steer(pilot.steering(game))
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		if game.hits_taken > last_hits and game.hit_message.begins_with("HULL STRUCK"):
			shore_hits += 1
		last_hits = game.hits_taken
		if frame % 8 == 0:
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
			actual_frames += 1
			var now := Time.get_ticks_usec()
			frame_ms.append((now - previous_tick) / 1000.0)
			previous_tick = now
			if game.wave_encounters.phase != previous_phase:
				previous_phase = game.wave_encounters.phase
				root.get_texture().get_image().save_png(output_dir.path_join("voyage-%02d-phase-%d.png" % [captures, previous_phase]))
				captures += 1
		if game.state != game.State.SAILING:
			break
	steer(0)
	await capture("voyage-result")
	frame_ms.sort()
	var voyage := {"arrived": game.state == game.State.ARRIVED, "seconds": game.elapsed,
		"hull": game.hull, "shore_hits": shore_hits, "wave_history": game.wave_encounters.history,
		"total_waves": game.wave_encounters.total_launched, "rendered_frames": actual_frames,
		"median_frame_ms": frame_ms[frame_ms.size() / 2], "p95_frame_ms": frame_ms[int(frame_ms.size() * 0.95)],
		"note": "Eight fixed physics steps per rendered frame; scripted input, not a human balance assessment or normal gameplay benchmark."}
	print("RENDERED VOYAGE: %s" % voyage)
	if not voyage.arrived or shore_hits > 0:
		failures += 1
	var file := FileAccess.open(output_dir.path_join("playtest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"response": results, "voyage": voyage}, "\t"))
	game.queue_free()
	await process_frame
	print("WAVE PLAYTEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

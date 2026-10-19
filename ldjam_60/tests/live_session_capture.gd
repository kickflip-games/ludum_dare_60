extends SceneTree
## Real-time production scene, normal focus/HUD/audio/resize. Optional scripted pilot.
## No fixed FPS, manual render loop, focus override or gameplay clock acceleration.
const Pilot = preload("res://tests/boss_pilot.gd")
var game
var output := "/tmp/blackwater-session.json"
var duration := 65.0
var audio_mode := 0
var record := true
var protected := false
var scripted := false
var resolution := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): duration = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--audio="): audio_mode = int(arg.trim_prefix("--audio="))
		if arg.begins_with("--resolution="): resolution = int(arg.trim_prefix("--resolution="))
		if arg == "--recorder-off": record = false
		if arg == "--protected": protected = true
		if arg == "--pilot": scripted = true
	_run.call_deferred()

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.diagnostics.set_enabled(record)
	game.set_diagnostic_audio(audio_mode)
	if resolution >= 0: game.diagnostics.set_resolution(resolution)
	game.start_crossing()
	var pilot := Pilot.new()
	var started := Time.get_ticks_usec()
	var previous := started
	var intervals := []
	var waves := []
	var last_wave := 0
	while Time.get_ticks_usec() - started < duration * 1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append([now / 1000.0, (now - previous) / 1000.0])
		previous = now
		if game.enemy_encounters.wave_number != last_wave:
			last_wave = game.enemy_encounters.wave_number
			waves.append({"number": last_wave, "game_seconds": game.elapsed})
		if game.state == game.State.SAILING and not game.paused:
			if protected: game.damage_immunity = 2.0
			if scripted: pilot.update(game, game.get_process_delta_time())
		if game.state in [game.State.LOST, game.State.ARRIVED]: break
	pilot.release()
	# Let normal HUD/render processing present a terminal state before readback.
	await process_frame
	await process_frame
	var data: Dictionary = game.diagnostics.report()
	data["capture"] = {"protected": protected, "scripted_pilot": scripted, "requested_seconds": duration,
		"waves": waves,
		"real_time_summary": game.diagnostics.summarize(intervals), "real_time_frames": intervals,
		"display_server": DisplayServer.get_name(), "audio_mix_rate": AudioServer.get_mix_rate(),
		"game_elapsed_s": game.elapsed, "outcome": game.State.keys()[game.state]}
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output + ".png")
	if scripted and game.state in [game.State.LOST, game.State.ARRIVED]:
		var retry := InputEventKey.new()
		retry.keycode = KEY_R
		retry.physical_keycode = KEY_R
		retry.pressed = true
		Input.parse_input_event(retry)
		Input.flush_buffered_events()
		retry = retry.duplicate()
		retry.pressed = false
		Input.parse_input_event(retry)
		await create_timer(1.6).timeout
		data.capture["retry"] = {"state": game.State.keys()[game.state], "hull": game.hull, "wave": game.enemy_encounters.wave_number}
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output + ".retry.png")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(data))
	var brief: Dictionary = data.capture.duplicate()
	brief.erase("real_time_frames")
	print("LIVE SESSION " + JSON.stringify(brief))
	game.queue_free()
	await process_frame
	quit()

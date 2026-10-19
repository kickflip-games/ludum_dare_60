extends SceneTree
## Production scene: focus/pause, no-lock steering, isolation and bounded recorder.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int = 6) -> void:
	for i in n: await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await frames()
	var d = game.diagnostics
	var native_size := root.content_scale_size
	var native_mode := root.content_scale_mode
	var native_aspect := root.content_scale_aspect
	check(native_size == Vector2i(1280, 720) and native_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and native_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "native rendering defaults stay unchanged")
	for index in [0, 1, 2, -1, 3, 999]:
		d._apply_web_resolution(index)
		var expected = d.WEB_RESOLUTIONS[index] if index in [0, 1, 2] else Vector2i(960, 540)
		check(root.content_scale_size == expected and root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Web preset %d is fixed, bounded and keeps aspect" % index)
	root.size = Vector2i(3360, 1822)
	await frames()
	d.open_panel()
	d.close_panel()
	game.restart(true)
	check(root.content_scale_size == Vector2i(960, 540) and root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "resize, diagnostics reopen and restart preserve safe Web scaling")
	root.content_scale_size = native_size
	root.content_scale_mode = native_mode
	root.content_scale_aspect = native_aspect
	root.size = Vector2i(1280, 720)
	check(not d.enabled and d.samples.is_empty() and d.events.is_empty(), "diagnostics starts off without retaining input/history")
	check(game.hud.settings_panel.find_child("Diagnostics", true, false) != null, "Settings exposes diagnostics without query parameters")
	check(game._sound.stream is AudioStreamWAV and game._sound.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ocean uses a looping sample")
	check(game._sound.stream.loop_end == 705600 and game._audio_playback == null, "32 second loop has no frame-driven generator")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.damage_immunity = 30
	key(KEY_A, true)
	key(KEY_SPACE, true)
	key(KEY_W, true)
	await frames(12)
	check(game.turn_input < 0 and game.boosting and game.cannon.shots_fired > 0, "simultaneous steering/fire/boost works before focus loss")
	game.application_focus_changed(false, "test_canvas_blur")
	check(game.paused and paused and not game._window_focused, "genuine canvas loss automatically pauses the SceneTree")
	check(not game.boosting and game.turn_input == 0 and not game.cannon._fire_held, "focus loss clears held movement and fire")
	check(not Input.is_action_pressed("steer_port") and not Input.is_action_pressed("boost_sailing"), "InputMap holds are released")
	await frames()
	check(game._music.stream_paused and game._sound.stream_paused, "native pause suspends both continuous audio players")
	var at: Vector3 = game.boat.position
	var elapsed: float = game.elapsed
	var sea: float = game.sea_time
	var wave: float = game.enemy_encounters.wave_remaining
	var shots: Array = game.cannon.projectiles.map(func(p): return p.node.position)
	var enemies: Array = game.enemy_encounters.living_ships().map(func(s): return s.position)
	await frames(25)
	check(game.boat.position == at and game.elapsed == elapsed and game.sea_time == sea, "focus pause freezes boat and sea clocks")
	check(game.enemy_encounters.wave_remaining == wave and game.cannon.projectiles.map(func(p): return p.node.position) == shots and game.enemy_encounters.living_ships().map(func(s): return s.position) == enemies, "focus pause freezes wave timer, live projectiles and AI")
	for i in 3:
		game.application_focus_changed(true, "test_canvas_focus")
		game.application_focus_changed(false, "test_canvas_blur")
	game.application_focus_changed(true, "test_canvas_focus")
	check(game.paused and paused and game.elapsed == elapsed, "repeated focus restoration never auto-resumes")
	key(KEY_A, false)
	key(KEY_SPACE, false)
	key(KEY_W, false)
	game.set_paused(false)
	game.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Denied capture must not be an input gate.
	key(KEY_D, true)
	game._physics_process(1.0 / 60)
	check(game.turn_input > 0 and not game.paused, "keyboard steering works without pointer lock")
	key(KEY_D, false)
	key(KEY_LEFT, true)
	game._physics_process(1.0 / 60)
	check(game.turn_input < 0, "arrow steering also works after explicit resume")
	key(KEY_LEFT, false)
	game._window_focused = false
	game._physics_process(1.0 / 60)
	check(game.paused, "an unfocused gameplay tick cannot silently suppress steering while sailing")
	game.application_focus_changed(true, "test_restore")
	game.set_paused(false)
	d.set_enabled(true)
	await frames(20)
	d.note("test_audio_transition")
	var report: Dictionary = d.report()
	check(not report.engine_frames.is_empty() and not report.samples.is_empty(), "recorder captures real intervals and InputMap/audio snapshots")
	check(report.samples[-1].has("movement_steering") and report.samples[-1].has("physics_ms"), "report joins movement and measured physics cost")
	check(report.build.has("git_sha") and report.godot.has("string"), "report identifies build and engine")
	check(JSON.parse_string(JSON.stringify(report)) is Dictionary, "report serializes as compact JSON")
	var summary: Dictionary = d.summarize([[0, 10], [10, 20], [30, 50], [80, 100]])
	check(summary.p99_ms == 100 and summary.max_ms == 100 and summary.slow_frames_over_33_ms == 2, "frame summary percentiles and slow counts use real intervals")
	for i in 2100: d.note("bounded", {"i": i})
	check(d.events.size() == d.EVENT_LIMIT, "event storage has a hard cap")
	d.events.push_front({"t_ms": -999999, "kind": "expired", "data": {}})
	d.note("prune")
	check(d.report().events.all(func(e): return e.kind != "expired"), "export omits events outside retention window")
	game.set_diagnostic_audio(1)
	check(game._music.volume_db == -18 and game._sound.volume_db == -80 and not game.effects_enabled(), "music-only isolation excludes ambience and combat")
	game.set_diagnostic_audio(2)
	check(game._music.volume_db == -80 and game._sound.volume_db > -40 and not game.effects_enabled(), "ocean-only isolation excludes music and combat")
	game.set_diagnostic_audio(0)
	check(game.effects_enabled() and game._music.volume_db == -18, "both restores normal combat audio")
	game.set_ocean_generator(true)
	check(game._sound.stream is AudioStreamGenerator and game.audio_diagnostic_state().generator_skips != null, "legacy comparison exposes actual generator skips")
	game.set_ocean_generator(false)
	check(game._audio_playback == null and game._sound.stream is AudioStreamWAV and d.events.any(func(e): return e.kind == "generator_stopped"), "switching away records underruns before removing generator")
	d.open_panel()
	check(game.paused and d.panel.visible and d.can_process(), "diagnostic controls remain usable while paused")
	d.close_panel()
	check(game.paused and not d.panel.visible, "closing diagnostics requires a separate Resume")
	d.set_enabled(false)
	var count: int = d.events.size()
	await frames(20)
	check(d.events.size() == count, "disabled recorder stops collecting")
	game.restart(true)
	check(not paused and not game.paused and game.state == game.State.READY and game.turn_input == 0, "menu restart clears pause/input and leaves diagnostics preference intact")
	game.queue_free()
	await frames()
	print("WEB STABILITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends "res://tests/arcade_controls_smoke.gd"
## Real =/+ input, next-wave banners, preserved survivors and retry cleanup.

func prepare() -> void:
	fresh()
	game.development_tools = false
	game.enemy_encounters.enabled = true

func plus(code: Key = KEY_PLUS, shift := false, echo := false, pressed := true, control := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = control
	event.echo = echo
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	if not output.is_empty():
		if DisplayServer.get_name() == "headless":
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var e = game.enemy_encounters
	prepare()
	check(not game.development_tools, "hidden shortcut suite runs with development tools disabled")
	for binding in [[KEY_EQUAL, false], [KEY_EQUAL, true], [KEY_PLUS, false], [KEY_KP_ADD, false]]:
		var code: Key = binding[0]
		var shift: bool = binding[1]
		prepare()
		plus(code, shift)
		check(e.wave_number == 1 and e.records[0].spawned == 2, "key %d starts wave one without development tools" % code)
		check(e.announcement == "WAVE 1" and e.announcement_left == 2.0, "first wave shows its normal banner")
		var survivors: Array = e.living_ships().duplicate()
		var hull: float = game.hull
		plus(code, shift, false, false)
		plus(code, shift)
		check(e.wave_number == 2 and e.records[1].spawned == 3 and e.spawn_queue.is_empty(), "next press immediately starts and releases wave two")
		check(e.announcement == "WAVE 2" and e.announcement_left == 2.0, "next wave shows its normal banner")
		check(survivors.all(func(ship): return e.living_ships().has(ship)) and e.ships_sunk == 0 and game.hull == hull,
			"skip preserves survivors and grants no free kills or repair")
		check(e.wave_remaining == e.survival_settings.deadlines[1] and e.records[0].expired, "next wave resets its deadline and expires the previous wave")
	prepare()
	plus(KEY_PLUS, false, true)
	plus(KEY_PLUS, false, false, false)
	plus(KEY_PLUS, false, false, true, true)
	plus(KEY_EQUAL, false, true)
	plus(KEY_EQUAL, false, false, false)
	plus(KEY_EQUAL, false, false, true, true)
	check(e.wave_number == 0, "key repeat, release and Ctrl shortcuts cannot advance waves")
	prepare()
	e._begin_wave()
	e.phase = e.Phase.EARLY_CLEAR
	plus(KEY_EQUAL)
	check(e.wave_number == 2 and e.announcement == "WAVE 2", "skip bypasses the early-clear wait and shows the next banner")
	prepare()
	for wave in 5:
		plus(KEY_EQUAL)
		plus(KEY_EQUAL, false, false, false)
	check(e.wave_number == 5 and e.boss_active() and e.records.size() == 5, "repeated presses reach the flagship")
	plus(KEY_EQUAL)
	check(e.wave_number == 5 and e.records.size() == 5, "final wave cannot advance beyond the flagship")
	game.restart()
	await process_frame
	check(e.wave_number == 0 and e.records.is_empty() and e.ships.size() == e.POOL_SIZE and e._debug_release_wave == 0,
		"retry clears skipped waves, temporary ship slots and pending release")
	for ending in [game.State.READY, game.State.CASTING_OFF, game.State.LOST, game.State.ARRIVED]:
		prepare()
		game.state = ending
		plus()
		check(e.wave_number == 0, "state %d ignores the debug shortcut" % ending)
	prepare()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	plus()
	check(e.wave_number == 0, "focus loss blocks debug spawns")
	prepare()
	game.hud.settings_open = true
	plus()
	check(e.wave_number == 0, "settings block debug spawns")
	game.hud.settings_open = false
	prepare()
	game.walkthrough.active = true
	plus()
	check(e.wave_number == 0, "walkthrough practice blocks debug spawns")
	game.walkthrough.active = false
	prepare()
	game.paused = true
	plus()
	check(e.wave_number == 0, "pause blocks the hidden shortcut")
	game.paused = false
	print("DEBUG WAVE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

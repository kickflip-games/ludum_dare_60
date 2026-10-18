extends "res://tests/arcade_controls_smoke.gd"
## Real + input, current-wave accounting, debug overflow and retry cleanup.

func prepare() -> void:
	fresh()
	game.development_tools = true
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
	game.development_tools = false
	plus()
	e.debug_release_wave()
	check(e.wave_number == 0 and e.living_ships().is_empty(), "shortcut and direct call are inert with development tools disabled")
	for code in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
		prepare()
		e._update_arena(0.0)
		var remaining: float = e.wave_remaining
		check(e.records[0].spawned == 1 and e.spawn_queue.size() == 1, "normal arrival still staggers before debug input")
		plus(code, code == KEY_EQUAL)
		check(e.wave_number == 1 and e.spawn_queue.is_empty() and e.records[0].spawned == 2,
			"key %d releases all current-wave ships immediately" % code)
		check(e.wave_remaining == remaining and e.ships_sunk == 0 and e.records[0].defeated == 0,
			"debug release preserves deadline, wave number and defeat accounting")
		plus(code, code == KEY_EQUAL, false, false)
		plus(code, code == KEY_EQUAL)
		check(e.records[0].spawned == 2 and e.wave_number == 1, "repeated press on a fully spawned wave cannot duplicate ships or advance")
	prepare()
	e._begin_wave()
	plus(KEY_PLUS, false, true)
	plus(KEY_PLUS, false, false, false)
	plus(KEY_PLUS, false, false, true, true)
	plus(KEY_EQUAL)
	check(e.records[0].spawned == 0, "key repeat, release, Ctrl+plus and bare equals do not release ships")
	prepare()
	plus()
	check(e.wave_number == 1 and e.records[0].spawned == 2, "plus before the first arrival starts and releases wave one")
	prepare()
	e._begin_wave()
	e._begin_wave()
	plus()
	check(e.records[0].spawned == 0 and e.spawn_queue == [1, 1] and e.records[1].spawned == 3,
		"only the current wave is released; older queued arrivals remain tracked")
	prepare()
	e.survival_settings.maximum_living = 1
	for wave in 3:
		e._begin_wave()
		plus()
	check(e.living_ships().size() == 9 and e.ships.size() == 9 and e.spawn_queue.is_empty(),
		"debug release creates temporary slots beyond the full ordinary pool without evicting survivors")
	check(e.records.all(func(record): return record.spawned == record.count and record.defeated == 0),
		"overflow ships retain exact wave counts and no free kills")
	var safe := true
	for a in e.living_ships():
		safe = safe and game.archipelago.water_clear(a.position, 12) and a.position.distance_to(game.boat.position) >= 65
		for b in e.living_ships():
			if a != b: safe = safe and a.position.distance_to(b.position) >= e.survival_settings.ship_spawn_separation
	check(safe, "immediate debug arrivals retain water, player and ship separation")
	game.hud._process(0)
	await capture("debug-full-wave")
	game.restart()
	await process_frame
	check(e.ships.size() == e.POOL_SIZE and e.spawn_queue.is_empty() and e._debug_release_wave == 0
		and e.living_ships().is_empty() and e.records.is_empty(), "retry removes temporary slots and clears pending release/accounting")
	prepare()
	e._begin_wave()
	e.survival_settings.player_spawn_separation = 10000
	plus()
	check(e.records[0].spawned == 0 and e._debug_release_wave == 1 and e.spawn_queue.size() == 2,
		"blocked safe spawn retains the request and queue without dropping enemies")
	e.survival_settings.player_spawn_separation = 65
	e._update_arena(0.0)
	check(e.records[0].spawned == 2 and e._debug_release_wave == 0, "pending release retries once safe water is available")
	prepare()
	for wave in 5: e._begin_wave()
	plus()
	check(e.boss_active() and e.records[4].spawned == 2 and not e.spawn_queue.has(5) and e.wave_number == 5,
		"final wave releases both escorts and retains its independent flagship")
	await capture("debug-final-wave")
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
	e.phase = e.Phase.EARLY_CLEAR
	plus()
	check(e.wave_number == 0, "early-clear pause cannot accidentally start another wave")
	print("DEBUG WAVE: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

extends "res://tests/enemy_pressure_smoke.gd"
## Real sailing/navigation and collision rays. Extra hull only extends measurement;
## production immunity, waves, projectiles and damage handling stay active.
var observations: Array[Dictionary] = []
var render := false
var captured := {}
var sample_wave := 1
var render_kind := "cutter"

func encounter(kind: String, course: float, distance: float, dodge: bool, hz: int) -> Dictionary:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.enemy_encounters.wave_number = sample_wave
	game.wave_encounters.enabled = false
	game.hull_capacity = 30
	game.hull = 30
	game.heading = course
	var ahead := Vector3(sin(course), 0, -cos(course))
	var right := Vector3(cos(course), 0, sin(course))
	game.boat.position = game.arena_center() - ahead * 112 - right * 65
	game.boat.rotation.y = -course
	game.boat.velocity = ahead * game.SPEED
	var ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	ship.begin(game.boat.position + right * distance)
	ship.heading = course
	ship.rotation.y = -course
	ship.velocity = ahead * game.SPEED
	ship._speed = game.SPEED
	await physics_frame
	var warnings := 0
	var range_time := 0.0
	var states := {}
	var ready_seconds := {}
	var fire_times := []
	var fixed := Vector3.ZERO
	var committed := true
	var ballistic := true
	var warning_start := 0.0
	var full_warning := true
	var turn_left := 0.0
	var maximum_step := 0.0
	for tick in 16 * hz:
		if render:
			# This fixture advances physics manually, including background captures.
			# A focus-loss pause would stop collision-world synchronisation.
			game._window_focused = true
			game.set_paused(false, false)
		var dt := 1.0 / hz
		var time := float(tick) / hz
		var previous: int = ship.weapon_state
		var shots: int = ship.shots_fired
		var hits: int = ship.shots_hit
		var old_position: Vector3 = ship.position
		var flying: Array = ship.projectiles.duplicate()
		var velocities: Array = flying.map(func(s): return s.velocity * Vector3(1, 0, 1))
		if previous == ship.Weapon.TELEGRAPH: committed = committed and ship.locked_point == fixed
		if dodge and previous == ship.Weapon.TELEGRAPH: turn_left = 1.8
		turn_left = maxf(0, turn_left - dt)
		game.advance_sailing(dt, -1.0 if turn_left > 0 else 0.0)
		ship.update_ship(dt)
		if ship.weapon_state == ship.Weapon.READY:
			var reason := "clear_lane_or_intercept"
			if ship.cooldown > 0: reason = "cooldown"
			elif ship.safety_priority >= 3: reason = "safety"
			elif absf(ship.turn_rate) >= 0.9 and ship.navigation_state != ship.Navigation.ATTACK_RUN: reason = "turn_rate"
			elif ship.position.distance_to(game.boat.position) >= ship.firing_range: reason = "range"
			elif ship._select_battery(game.boat.position - ship.position) < 0: reason = "angle"
			ready_seconds[reason] = ready_seconds.get(reason, 0.0) + dt
		maximum_step = maxf(maximum_step, old_position.distance_to(ship.position))
		for i in flying.size():
			ballistic = ballistic and (flying[i].velocity * Vector3(1, 0, 1)).is_equal_approx(velocities[i])
		if ship.weapon_state == ship.Weapon.TELEGRAPH and previous != ship.Weapon.TELEGRAPH:
			warnings += 1
			fixed = ship.locked_point
			warning_start = time
		if ship.shots_fired > shots:
			fire_times.append(time)
			full_warning = full_warning and time - warning_start >= ship.telegraph_seconds - dt * 0.01
		if ship.position.distance_to(game.boat.position) < ship.firing_range: range_time += dt
		states[ship.navigation_state] = states.get(ship.navigation_state, 0.0) + dt
		if render:
			game._update_view(dt)
			game.hud._process(dt)
			var label := ""
			if tick == hz: label = "approach"
			if warnings > 0 and ship.weapon_state == ship.Weapon.TELEGRAPH and not captured.has("warning"): label = "warning"
			if ship.shots_fired > shots and not captured.has("fire"): label = "fire"
			if kind == "heavy" and ship.projectiles.size() == 3 and ship.projectiles[0].ttl < 3.3 and not captured.has("heavy-spread"): label = "heavy-spread"
			if ship.shots_hit > hits and not captured.has("hit"): label = "hit"
			if dodge and not ship.projectiles.is_empty() and ship.projectiles[0].position.distance_to(game.boat.position) < 12 and not captured.has("dodge"): label = "dodge"
			if not label.is_empty():
				await process_frame
				RenderingServer.force_draw(true, dt)
				root.get_texture().get_image().save_png("/tmp/blackwater-pressure/" + ("small-" if "--small" in OS.get_cmdline_user_args() else "") + label + ".png")
				captured[label] = true
		await physics_frame
	var result := {"kind":kind, "heading":course, "distance":distance, "dodge":dodge, "hz":hz,
		"wave":sample_wave, "ready_seconds":ready_seconds, "warnings":warnings, "shots":ship.shots_fired, "salvos":ship.salvos_fired, "hits":ship.shots_hit, "all_damage":game.hits_taken,
		"cancelled":ship.cancelled_shots, "range_seconds":range_time, "states":states, "fire_times":fire_times}
	print("ACCURACY " + JSON.stringify(result))
	check(committed and ballistic and full_warning, "fixed warning, full duration and non-homing physical flight")
	check(maximum_step <= ship.sailing_speed * 1.12 / hz + 0.01 and ship.visible, "bounded motion and persistent attacker")
	game.restart()
	check(ship.projectiles.is_empty() and ship.cooldown == 0 and ship.weapon_state == ship.Weapon.READY and not ship.flash.visible, "retry clears warning, reload and physical shots")
	game.queue_free()
	await process_frame
	observations.append(result)
	return result

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/blackwater-pressure")
	render = "--render" in OS.get_cmdline_user_args()
	if render:
		assert(DisplayServer.get_name() != "headless")
		root.size = Vector2i(900,506) if "--small" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wave="): sample_wave = int(arg.trim_prefix("--wave="))
		if arg.begins_with("--kind="): render_kind = arg.trim_prefix("--kind=")
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	for hz in ([60] if render else [30, 60]):
		Engine.physics_ticks_per_second = hz
		for kind in ([render_kind] if render else ["cutter", "skiff", "heavy"]):
			var straight_hits := 0
			var evade_hits := 0
			for fixture in [[0.0, 32.0], [0.35, 42.0], [-0.35, 52.0]]:
				var straight := await encounter(kind, fixture[0], fixture[1], false, hz)
				var evade := await encounter(kind, fixture[0], fixture[1], true, hz)
				straight_hits += int(straight.hits)
				evade_hits += int(evade.hits)
				if not baseline:
					check(straight.salvos >= 2 and straight.hits > 0, "%s %dHz heading %.2f: repeated fire physically hits a steady course" % [kind, hz, fixture[0]])
			if not baseline:
				check(evade_hits < straight_hits and evade_hits <= straight_hits / 2.0, "%s %dHz: warning response avoids most incoming damage" % [kind, hz])
	var file := FileAccess.open("/tmp/blackwater-pressure/" + ("before" if baseline else "after-render" if render else "after") + "-wave%d-accuracy.json" % sample_wave, FileAccess.WRITE)
	file.store_string(JSON.stringify(observations, "\t"))
	print("ENEMY ACCURACY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

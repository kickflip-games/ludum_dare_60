extends SceneTree

const Pilot = preload("res://tests/boss_pilot.gd")
var output := "/tmp/latitude-combat/playthrough"
var capture_enabled := false
var straight := false
var hold_fire := false
var maximum_retries := 0
var maximum_seconds := 600.0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--seconds="): maximum_seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--retries="): maximum_retries = int(argument.trim_prefix("--retries="))
		if argument == "--straight": straight = true
		if argument == "--hold-fire": hold_fire = true
		if argument == "--capture":
			capture_enabled = true
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func _run() -> void:
	if capture_enabled and DisplayServer.get_name() == "headless":
		push_error("Gameplay captures require a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	var evasion := "--no-evasion" not in OS.get_cmdline_user_args()
	var pilot = Pilot.new() if evasion else load("res://tests/combat_arena_pilot.gd").new()
	var seen_wave := 0
	var peak_living := 0
	var ship_hits := 0
	var shots := 0
	var all_impacts := 0
	var enemy_shots := 0
	var enemy_warnings := 0
	var trace: Array[Dictionary] = []
	var capture_counts := {"Cutter": 0, "Skiff": 0, "Heavy": 0, "Flagship": 0}
	var max_yaw := 0.0
	var max_roll := 0.0
	var damage_trace: Array[Dictionary] = []
	var retries: Array[Dictionary] = []
	var phase_two := false
	var pool_peak := 0
	var boss_peak := 0
	for frame in int(maximum_seconds * 60):
		if game.state == game.State.LOST and retries.size() < maximum_retries:
			pilot.release()
			retries.append({"wave":game.enemy_encounters.wave_number, "seconds":game.elapsed, "phase_two":game.enemy_encounters.boss.phase_two})
			while not game.result_ready():
				game._physics_process(1.0 / 60)
				await physics_frame
			pilot.action("restart_crossing", true)
			pilot.action("restart_crossing", false)
			while game.state == game.State.CASTING_OFF:
				game._window_focused = true
				game._physics_process(1.0 / 60)
				await physics_frame
			pilot = Pilot.new() if evasion else load("res://tests/combat_arena_pilot.gd").new()
			print("INPUT RETRY " + JSON.stringify({"wave":game.enemy_encounters.wave_number,"hull":game.hull,"state":game.state}))
			seen_wave = 0
		if game.state != game.State.SAILING:
			break
		game._window_focused = true # Deterministic input fixture, including background captures.
		if straight:
			pilot.helm(0.0)
		else:
			pilot.update(game, 1.0 / 60.0)
		if hold_fire or straight: pilot.action("fire_starboard", true)
		var before: Array[Dictionary] = []
		var previous_hits: int = game.hits_taken
		for ship in game.enemy_encounters.combat_ships():
			before.append({"hull": ship.hull, "wave": ship.get_meta("wave_id", -1), "shots": ship.shots_fired})
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		phase_two = phase_two or game.enemy_encounters.boss.phase_two
		pool_peak = maxi(pool_peak, game.cannon.projectile_visuals.leased.size())
		boss_peak = maxi(boss_peak, game.enemy_encounters.boss.projectiles.size())
		if game.hits_taken > previous_hits:
			damage_trace.append({"seconds": game.elapsed, "reason": game.hit_message, "hull": game.hull})
		shots = maxi(shots, game.cannon.shots_fired)
		all_impacts = maxi(all_impacts, game.cannon.targets_hit)
		for index in game.enemy_encounters.combat_ships().size():
			var ship = game.enemy_encounters.combat_ships()[index]
			if before[index].wave == ship.get_meta("wave_id", -1):
				ship_hits += maxi(0, before[index].hull - ship.hull)
				enemy_shots += maxi(0, ship.shots_fired - before[index].shots)
		enemy_warnings = maxi(enemy_warnings, game.enemy_encounters.director.warning_history.size())
		peak_living = maxi(peak_living, game.enemy_encounters.living_ships().size())
		max_yaw = maxf(max_yaw, absf(game.wave_sailing.yaw_rate))
		max_roll = maxf(max_roll, absf(game.boat_motion.roll))
		game.hud._process(1.0 / 60.0)
		if seen_wave != game.enemy_encounters.wave_number:
			seen_wave = game.enemy_encounters.wave_number
			var entry := {"wave": seen_wave, "seconds": game.elapsed, "hull": game.hull,
				"kills": game.enemy_encounters.ships_sunk, "shots": game.cannon.shots_fired}
			trace.append(entry)
			print("PLAY WAVE " + JSON.stringify(entry))
			if capture_enabled:
				await capture("wave-%d" % seen_wave)
		if capture_enabled and pilot.target != null and frame % 6 == 0:
			var kind: String = pilot.target.archetype.resource_name if pilot.target.archetype != null else "Flagship"
			if capture_counts[kind] < 80 and game.cannon.aiming:
				await capture("%s-%03d" % [kind.to_lower(), capture_counts[kind]])
				capture_counts[kind] += 1
		await physics_frame
	pilot.release()
	var result := {"evasion":evasion, "straight":straight, "held_fire":hold_fire, "boss_hull":game.enemy_encounters.boss.hull, "budget_seconds":maximum_seconds, "phase_two":phase_two, "retries":retries, "pool_peak":pool_peak, "boss_pool_peak":boss_peak, "pool_exhaustion":game.cannon.projectile_visuals.exhaustion_count, "state": game.state, "won": game.state == game.State.ARRIVED,
		"seconds": game.elapsed, "wave": game.enemy_encounters.wave_number,
		"kills": game.enemy_encounters.ships_sunk, "hull": game.hull, "hits_taken": game.hits_taken,
		"shots": shots, "ship_hits": ship_hits, "all_impacts": all_impacts,
		"enemy_shots": enemy_shots, "enemy_warnings": enemy_warnings,
		"peak_living": peak_living, "helm_exits": pilot.helm_exits, "max_wave_yaw": max_yaw,
		"max_roll_degrees": rad_to_deg(max_roll), "waves": trace, "capture_counts": capture_counts,
		"damage": damage_trace}
	print("INPUT PLAYTHROUGH " + JSON.stringify(result))
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	if capture_enabled:
		for frame in 60:
			game._update_view(1.0 / 60.0)
			game.hud._process(1.0 / 60.0)
			await process_frame
		await capture("ending")
	await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	quit(0 if result.won else 1)

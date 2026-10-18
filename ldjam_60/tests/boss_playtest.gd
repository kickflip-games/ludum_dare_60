extends SceneTree
## Input-only final-wave pilot. Optional native captures always use the gameplay camera.
const Pilot = preload("res://tests/boss_pilot.gd")
var output := "/tmp/latitude-flagship-play"
var render := false
var protected := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--render": render = true
		if arg == "--protected": protected = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()
func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func _run() -> void:
	if render and DisplayServer.get_name() == "headless": quit(2); return
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
	var manager = game.enemy_encounters
	for i in 5: manager._begin_wave()
	# Stage final wave directly; do not spend the pilot run replaying Waves 1-4.
	manager.spawn_queue.assign([5, 5])
	for record in manager.records:
		if record.wave < 5: record.defeated = record.count
	var boss = manager.boss
	if not is_instance_valid(boss) or not boss.has_method("update_ship"):
		quit(2)
		return
	var pilot := Pilot.new()
	var seen: Dictionary = {}
	var shots := 0
	var hits := 0
	var mine_peak := 0
	var boss_shots := 0
	var patterns: Array = []
	var contacts := 0
	var recoveries := 0
	var distance_sum := 0.0
	var in_range := 0
	var elapsed := 0.0
	var steer_frames := 0
	for frame in 240 * 60:
		if game.state != game.State.SAILING: break
		if protected: game.damage_immunity = 2.0
		# Keep the deterministic fixture focused even when a capture backgrounds its window.
		game._window_focused = true
		pilot.update(game, 1.0 / 60)
		if Input.is_action_pressed("steer_port") or Input.is_action_pressed("steer_starboard"): steer_frames += 1
		shots = maxi(shots, game.cannon.shots_fired)
		boss_shots = maxi(boss_shots, boss.shots_fired)
		if boss.pattern_history.size() > patterns.size(): patterns.assign(boss.pattern_history)
		contacts = maxi(contacts, boss.contact_frames)
		recoveries = maxi(recoveries, boss.recoveries)
		var before: int = boss.hull
		game._physics_process(1.0 / 60)
		game.cannon.advance(1.0 / 60)
		hits += maxi(0, before - boss.hull)
		mine_peak = maxi(mine_peak, boss.mines.size())
		elapsed += 1.0 / 60
		var distance: float = boss.position.distance_to(game.boat.position)
		distance_sum += distance
		if distance <= 65: in_range += 1
		game.hud._process(1.0 / 60)
		if render:
			var label := ""
			if frame == 0: label = "arrival"
			elif boss.weapon_state == boss.Weapon.TELEGRAPH: label = ["rolling-warning", "double-%d-warning" % boss.salvo, "scatter-warning"][boss.pattern]
			elif boss.weapon_state == boss.Weapon.FIRE or (boss.projectiles.size() > 0 and boss.weapon_state == boss.Weapon.RELOAD): label = ["rolling-fire", "double-fire", "scatter-fire"][boss.pattern]
			elif boss.mines.size() > 0 and boss.mines[0].armed(): label = "mines"
			if label != "" and not seen.has(label):
				seen[label] = true
				await capture(label)
		if frame % 1800 == 0: print("BOSS PILOT %.1fs hull=%d boss=%d volleys=%d" % [elapsed, game.hull, boss.hull, boss.pattern_history.size()])
		await physics_frame
	pilot.release()
	var result := {"won":game.state == game.State.ARRIVED, "state":game.state, "seconds":elapsed, "physical_boss_hits":hits, "shots":shots, "hull":game.hull, "player_hits":game.hits_taken, "protected":protected, "steering_frames":steer_frames, "boss_shots":boss_shots, "patterns":patterns, "mine_peak":mine_peak, "mean_distance":distance_sum / maxf(1, elapsed * 60), "range_fraction":float(in_range) / maxf(1, elapsed * 60), "boss_contacts":contacts, "boss_recoveries":recoveries, "captures":seen.keys()}
	print("BOSS INPUT PLAY " + JSON.stringify(result))
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	if render:
		game._update_view(1.0 / 60)
		game.hud._process(0)
		await capture("ending")
	game.queue_free()
	await process_frame
	quit(0 if result.won else 1)

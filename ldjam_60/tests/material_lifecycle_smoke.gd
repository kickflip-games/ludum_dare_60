extends SceneTree
## Native Compatibility check for material errors during combat and slot reuse.
var game
var checks := 0
var failures := 0
class ErrorCapture extends Logger:
	var messages: Array[String] = []
	var lock := Mutex.new()
	func _log_error(function: String, _file: String, _line: int, code: String, _rationale: String, _notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == 1: return # Warnings are reported separately by the engine.
		lock.lock()
		messages.append(function + ": " + code)
		lock.unlock()
var capture := ErrorCapture.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	OS.add_logger(capture)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	var started := Time.get_ticks_msec()
	while not game.cannon.combat_warmup.complete and Time.get_ticks_msec() - started < 10000:
		await process_frame
	check(game.cannon.combat_warmup.complete, "Menu warm-up completes")
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	var ship = game.enemy_encounters.ship
	for cycle in 12:
		ship.reset()
		ship.configure_archetype(load("res://game/enemies/" + ["cutter", "skiff", "heavy"][cycle % 3] + ".tres"))
		game.state = game.State.SAILING
		ship.begin(game.arena_center() + Vector3(35, 0, 95))
		for phase in 3:
			ship.sea_effects.advance_arrival(0.35)
			ship.update_visuals(0.35)
			await process_frame
		game.cannon.cooldown = 0.0
		check(game.cannon.fire(), "Player fire succeeds after slot reuse")
		ship._launch_ball(ship.position + Vector3.UP * 3)
		while ship.hull > 0: game.cannon._impact(ship, ship.position)
		check(ship.get_meta("destroyed"), "Impact reaches the sinking lifecycle")
		var mine = game.enemy_encounters.boss.mine_pool[0]
		mine.activate(game.arena_center() + Vector3(20, 0, 80))
		game.cannon._impact(mine, mine.position)
		check(mine.spent and not mine.visible, "Destroyed mine returns to its pool")
		for tick in 90:
			game.cannon.advance(1.0 / 60)
			ship.update_ship(1.0 / 60)
			game._update_view(1.0 / 60)
			await process_frame
		if cycle % 5 == 0:
			game.restart()
			check(game.cannon.projectile_visuals.leased.is_empty(), "Retry returns all projectiles")
			check(game.enemy_encounters.boss.mine_pool.all(func(m): return m.spent), "Retry clears mines")
	# Render every tick of the flagship's actual volley methods. Sparse static
	# previews can miss material dependency updates between warning and fire.
	var boss = game.enemy_encounters.boss
	for second_phase in [false, true]:
		for kind in [boss.Pattern.ROLLING, boss.Pattern.DOUBLE, boss.Pattern.SCATTER]:
			game.restart()
			game.state = game.State.SAILING
			game.damage_immunity = 1000.0
			game.boat.position = game.arena_center() + Vector3(-10, 0, 80)
			game.heading = PI / 2
			game.boat.rotation.y = -game.heading
			game.boat.velocity = Vector3(7.5, 0, 0)
			boss.begin(game.arena_center() + Vector3(5, 0, 124))
			boss.heading = PI / 2
			boss.rotation.y = -boss.heading
			boss._speed = 7.5
			boss.velocity = boss.forward() * 7.5
			if second_phase:
				for hit in 5: boss.take_hit()
				check(boss.phase_two and boss.phase_bursts == 1, "Flagship crosses half health once")
			boss.pattern = kind
			check(boss._prepare_volley(1.6), "Flagship commits its attack lanes")
			for tick in 240:
				var delta := 1.0 / 60
				game.sea_time += delta
				game.ocean.wave_time = game.sea_time
				boss.position += boss.forward() * boss._speed * delta
				game.boat.position += game.boat.velocity * delta
				boss.sea_effects.advance_arrival(delta)
				boss.sea_effects.update_trail(delta, true)
				boss._update_weapon(delta)
				boss._update_mines(delta)
				boss._advance_shots(delta)
				game.combat_particles.advance(delta)
				if second_phase:
					boss.smoke_clock += delta
					if boss.smoke_clock > 0.65:
						boss.smoke_clock = 0.0
						game.combat_particles.smoke(boss.visual.to_global(Vector3(0, 3, 2)))
				game._update_view(delta)
				await process_frame
			check(boss.shots_fired == (4 if kind == boss.Pattern.DOUBLE else 5), "Flagship renders every intended projectile")
			check(boss.weapon_state == boss.Weapon.RELOAD and not boss.warnings[0].visible, "Reload clears the rendered warning")
			check(not boss.mines.is_empty(), "Flagship attack deploys visible mines")
			# Sink while hazards are still present, then render the cleanup and retry.
			while boss.hull > 0: game.cannon._impact(boss, boss.position)
			check(boss.mines.is_empty() and boss.projectiles.is_empty(), "Flagship death clears active hazards")
			for tick in 3:
				game._update_view(1.0 / 60)
				await process_frame
			game.restart()
			check(not boss.phase_two and boss.hull == boss.hull_capacity, "Retry restores flagship phase and materials")
			await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	OS.remove_logger(capture)
	check(capture.messages.is_empty(), "Combat and cleanup produce no engine or script errors")
	print("MATERIAL LIFECYCLE: %d checks, %d failures, %d engine/script errors" % [checks, failures, capture.messages.size()])
	quit(0 if failures == 0 else 1)

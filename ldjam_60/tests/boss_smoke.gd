extends SceneTree
## Real scene, movement, ballistic volleys, hazards and authoritative ending checks.
var game
var manager
var boss
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func fresh() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 112)
	game.boat.velocity = Vector3(7.5, 0, 0)
	game.heading = PI / 2

func final_wave() -> void:
	for i in 5: manager._begin_wave()

func setup_guns(kind: int) -> void:
	fresh()
	boss.begin(game.arena_center() + Vector3(0, 0, 70))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss._speed = 7.5
	boss.velocity = boss.forward() * boss._speed
	boss.pattern = kind
	boss.salvo = 0
	boss.projectiles.clear()

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	manager = game.enemy_encounters
	boss = manager.boss
	if not is_instance_valid(boss) or not boss.has_method("update_ship"):
		quit(2)
		return
	await physics_frame
	fresh()
	check(is_instance_valid(boss.flagship_model) and is_equal_approx(boss.collision_shape.shape.radius, 4.8) and boss.get_meta("target_radius") == 6.2, "imported large ship and matching hull/target metadata load")
	check(boss.FLAGSHIP.resource_path == "res://assets/kenney_ships/ship-pirate-large.glb"
		and boss.flagship_model.has_node("ship-pirate-large/sail-b"), "boss uses the supplied large two-mast pirate ship")
	check(boss.hull == 9 and boss.sailing_speed == 8.7 and boss.turning_speed < manager.ship.turning_speed, "nine-hit flagship has heavier tunable navigation")
	for i in 6:
		manager.ships[i].begin(game.arena_center() + Vector3(-100 + i * 20, 0, -100), true)
	final_wave()
	check(manager.boss_active() and boss.visible and boss.hull == 9, "Wave 5 flagship spawns immediately with six earlier survivors")
	check(manager.ships.size() == 6 and manager.living_ships().size() == 7 and not manager.director.owners.has(boss), "dedicated boss keeps all ordinary pool slots and uses no director slot")
	check(manager._boss_spawn_clear(boss.position) and boss.position.distance_to(game.boat.position) >= 65, "arrival clears water, lighthouse and player")
	check(manager.ships.all(func(ship): return ship.position.distance_to(boss.position) >= 34), "arrival separates from all surviving hulls")
	check(manager.survival_settings.wave_rosters[4] == PackedStringArray(["skiff", "cutter"]), "final roster adds just two tunable staggered escorts")
	manager.director.clock = 10
	manager.director.next_warning = 0
	check(manager.director.request_boss_warning(2.8) and manager.director.next_warning >= 12.8, "boss reserves readable warning spacing without an attack slot")

	for hz in [30, 60, 120]:
		for kind in [boss.Pattern.ROLLING, boss.Pattern.DOUBLE, boss.Pattern.SCATTER]:
			setup_guns(kind)
			await physics_frame
			check(boss._prepare_volley(1.6), "%d Hz pattern %d commits clear ballistic lanes" % [hz, kind])
			boss._update_mines(0.0)
			check(boss.mines.size() == 1, "attack warning starts concurrent mine laying")
			var snapshot: Array = boss.volley.duplicate(true)
			boss._update_tell()
			check(boss.warnings.size() == 1 and boss.warnings[0].visible and boss.warnings[0].mesh is ImmediateMesh, "whole volley uses one filled triangular warning")
			var geometry: Dictionary = boss.warning_geometry()
			var side: Vector3 = geometry.direction.cross(Vector3.UP)
			var contained := true
			for planned in snapshot:
				for point: Vector3 in [planned.origin, planned.end]:
					var offset: Vector3 = point - geometry.origin
					var along: float = offset.dot(geometry.direction)
					contained = contained and along > 0 and along <= geometry.length + 0.001 and absf(offset.dot(side)) <= geometry.half_width * along / geometry.length
			check(contained, "filled warning contains every committed muzzle-to-endpoint lane")
			var overlapped := false
			var previous: Vector3 = boss.position
			var frames := roundi((2.6 if kind != boss.Pattern.DOUBLE else 3.1) * hz)
			for tick in frames:
				boss.position += boss.forward() * boss._speed / hz
				game.boat.position += game.boat.velocity / hz
				boss._update_weapon(1.0 / hz)
				boss._update_mines(1.0 / hz)
				overlapped = overlapped or (boss.mines.any(func(hazard): return hazard.armed()) and boss.shots_fired > 0 and boss.weapon_state in [boss.Weapon.TELEGRAPH, boss.Weapon.FIRE])
			check(boss.shots_fired == (4 if kind == boss.Pattern.DOUBLE else 5), "%d Hz pattern %d launches intended physical projectile count" % [hz, kind])
			check(overlapped, "%d Hz pattern %d has armed mines while cannon sequence is firing" % [hz, kind])
			check(boss.weapon_state == boss.Weapon.RELOAD and boss.position.distance_to(previous) > 10, "pattern completes and recovers while sailing")
			boss._update_tell()
			check(not boss.warnings[0].visible and boss.cooldown <= (boss.double_reload if kind == boss.Pattern.DOUBLE else boss.volley_reload), "completed volley clears its cone and uses the shorter reload")
			check(boss.passes > 0 and boss.navigation_state == boss.Navigation.ATTACK_RUN, "broadside commits a sustained navigation pass")
			var matched := true
			for shot in boss.launch_history:
				var flat: Vector3 = shot.velocity * Vector3(1, 0, 1)
				matched = matched and flat.normalized().dot(shot.direction) > 0.9999 and shot.origin.distance_to(shot.warning_origin) < 0.3
			check(matched, "origins and physical travel match committed warnings")
			if kind == boss.Pattern.ROLLING:
				check(snapshot[0].origin.distance_to(snapshot[4].origin) > 10 and snapshot[4].time > 0.8, "rolling shots traverse five separated hull muzzles over 0.84 seconds")
			if kind == boss.Pattern.SCATTER:
				check((snapshot[0].origin + snapshot[0].direction * boss.minimum_attack_distance).distance_to(snapshot[1].origin + snapshot[1].direction * boss.minimum_attack_distance) > 7.0, "scatter leaves over seven metres between rays at minimum attack range")
			var shot: Dictionary = boss.projectiles[0]
			var velocity: Vector3 = shot.velocity
			game.boat.position += Vector3(30, 0, 20)
			boss._advance_shots(1.0 / hz)
			check(shot.velocity.x == velocity.x and shot.velocity.z == velocity.z, "moving player never homes a launched shot")
			boss.clear_hazards()
	setup_guns(boss.Pattern.ROLLING)
	await physics_frame
	check(not boss._volley_lane_clear(game.arena_center() + Vector3(-50, 2, 0), game.arena_center() + Vector3(50, 2, 0)), "solid lighthouse obstructs cannon lanes")
	for hit in 5: boss.take_hit()
	check(boss.phase_two and boss.phase_bursts == 1 and boss.hull == 4, "half-health phase transition bursts once and remains vulnerable")
	boss.take_hit()
	check(boss.hull == 3 and boss.phase_bursts == 1, "phase transition grants no invulnerability or repeat burst")

	fresh()
	game.boat.position += Vector3(65, 0, 0)
	boss.begin(game.arena_center() + Vector3(0, 0, 100))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	await physics_frame
	check(boss.deploy_mine() and boss.mines.size() == 1, "safe stern water accepts an imported mine")
	var mine = boss.mines[0]
	var fixed: Vector3 = mine.position
	boss.position += Vector3(20, 0, 0)
	mine.update_mine(0.79)
	check(not mine.armed() and mine.position == fixed and is_equal_approx(mine.get_meta("ring_radius"), 7.0), "arming delay, stationary planar position and exact seven-metre ring")
	mine.update_mine(0.02)
	check(mine.armed(), "mine arms after 0.8 seconds")
	game.sea_time += 1
	game.ocean.wave_time = game.sea_time
	mine.update_visuals()
	check(is_equal_approx(mine.model.position.y, game.ocean.height_at(Vector2(fixed.x, fixed.z)) + 0.65), "mine bobs with actual ocean height; ring uses shared wave shader")
	check(mine.is_in_group("cannon_targets"), "mines can be acquired by the player cannon")
	game.boat.position = mine.position + Vector3(7.1, 0, 0)
	mine.update_mine(0.01)
	check(not mine.spent, "outside the advertised trigger ring is safe")
	var hull: int = game.hull
	game.boat.position = mine.position + Vector3(6.9, 0, 0)
	mine.update_mine(0.01)
	mine.update_mine(0.1)
	check(mine.spent and game.hull == hull - 1, "armed entry detonates once through normal damage pathway")
	var extra = boss.MINE.instantiate()
	extra.game = game
	manager.add_child(extra)
	extra.position = game.boat.position
	extra.age = 1
	extra.update_mine(0.01)
	check(extra.spent and game.hull == hull - 1, "immunity consumes a second mine without extra damage")
	check(not boss.mine_position_valid(game.boat.position) and not boss.mine_position_valid(game.arena_center()) and not boss.mine_position_valid(game.arena_center() + Vector3(200, 0, 0)), "mine deployment rejects player, lighthouse and outside arena")
	await process_frame
	fresh()
	game.boat.position += Vector3(65, 0, 0)
	boss.begin(game.arena_center() + Vector3(0, 0, 100))
	boss.heading = PI / 2
	boss.rotation.y = -boss.heading
	boss.maximum_mines = 2
	await physics_frame
	for i in 3:
		boss.position = game.arena_center() + Vector3(-35 + i * 22, 0, 100)
		check(boss.deploy_mine() == (i < 2), "separated mine %d respects the active cap" % i)
	check(boss.mines.size() == 2, "active cap preserves existing mines")
	boss.mines[0].update_mine(3600)
	check(not boss.mines[0].spent, "flagship mines have no lifetime expiry")
	game.cannon._impact(boss.mines[0], boss.mines[0].model.global_position)
	check(boss.deploy_mine(), "destroying a flagship mine permits a replacement drop")
	boss.maximum_mines = 6

	setup_guns(boss.Pattern.ROLLING)
	await physics_frame
	boss.cooldown = 0.0
	boss.weapon_state = boss.Weapon.READY
	boss._update_weapon(0.0)
	check(boss.pattern == boss.Pattern.ROLLING and boss.weapon_state == boss.Weapon.TELEGRAPH, "production rotation starts with rolling broadside")
	var phase_plan: Array = boss.volley.duplicate(true)
	for i in 5: boss.take_hit()
	check(boss.phase_two and boss.volley == phase_plan and boss.weapon_state == boss.Weapon.TELEGRAPH, "phase transition preserves the active locked warning")
	boss._finish_pattern()
	boss.cooldown = 0.0
	boss.weapon_state = boss.Weapon.READY
	manager.director.clock += 10
	boss._update_weapon(0.0)
	check(boss.pattern == boss.Pattern.SCATTER and boss.weapon_state == boss.Weapon.TELEGRAPH, "production phase-two rotation introduces scatter on next valid attack")

	for second_phase in [false, true]:
		setup_guns(boss.Pattern.ROLLING)
		boss.phase_two = second_phase
		await physics_frame
		check(boss._prepare_volley(1.6), "mine cadence fixture commits a clear attack")
		boss._update_mines(0.0)
		var interval: float = boss.phase_two_mine_interval if second_phase else boss.mine_interval
		boss.position += Vector3(25, 0, 0)
		boss._update_mines(interval - 0.01)
		check(boss.mines.size() == 1, "mine burst respects the phase interval")
		boss._update_mines(0.02)
		check(boss.mines.size() == 2, "mine burst lays again during the cannon warning")
		boss._update_mines(interval)
		check(boss.mines.size() == 2, "blocked stern skips an overlapping mine")
		boss.position += Vector3(25, 0, 0)
		boss._update_mines(0.01)
		check(boss.mines.size() == 3, "blocked drop retries when safe space opens")

	for hz in [30, 60, 120]:
		for second_phase in [false, true]:
			setup_guns(boss.Pattern.ROLLING)
			boss.phase_two = second_phase
			await physics_frame
			check(boss._prepare_volley(1.6), "reload fixture commits a clear attack")
			boss._update_mines(0.0)
			manager.phase = manager.Phase.ACTIVE
			manager.wave_number = 5
			var reload_mine = boss.mines[0]
			boss._finish_pattern()
			var reload_seconds: float = boss.cooldown
			var mine_count: int = boss.mines.size()
			var shot_count: int = boss.shots_fired
			# Approach while the boss is reloading; existing mines still arm.
			for tick in int((reload_seconds - 0.1) * hz):
				boss.position += boss.forward() * boss._speed / hz
				game.boat.position += Vector3(0, 0, -2.0) / hz
				boss.cooldown = maxf(0.0, boss.cooldown - 1.0 / hz)
				boss._update_weapon(1.0 / hz)
				boss._update_mines(1.0 / hz)
			check(boss.weapon_state == boss.Weapon.RELOAD and boss.mines.size() == mine_count and boss.shots_fired == shot_count, "%d Hz phase %s reload allows approach without new attacks" % [hz, second_phase])
			check(reload_mine.armed() and reload_mine.age > 2.0, "reload keeps existing mine hazards active")
			game.hud._process(0.0)
			check(game.hud.boss_label.text == "FLAGSHIP · RELOADING", "health bar identifies the reload opening")
			boss.cooldown = 0.0
			boss._update_weapon(1.0 / hz)
			check(boss.weapon_state == boss.Weapon.READY, "full reload returns guns to ready")
			game.hud._process(0.0)
			check(game.hud.boss_label.text == "FLAGSHIP", "reload cue clears when guns are ready")
			boss._update_mines(10.0)
			check(boss.mines.size() == mine_count and boss.mine_clock == 0.0, "ready navigation never lays mines or banks a burst")

	for leg in [boss.Navigation.TURN_AWAY, boss.Navigation.REPOSITION]:
		setup_guns(boss.Pattern.ROLLING)
		await physics_frame
		boss.navigation_state = leg
		boss.cooldown = 0.0
		manager.director.clock += 10.0
		boss._update_weapon(0.0)
		check(boss.weapon_state == boss.Weapon.TELEGRAPH, "clear steady return leg can start a warned attack")
		boss._finish_pattern()
		boss.weapon_state = boss.Weapon.READY
		boss.cooldown = 0.0
		boss.turn_rate = 0.3
		boss._update_weapon(0.0)
		boss._update_mines(10.0)
		check(boss.weapon_state == boss.Weapon.READY and boss.mines.is_empty(), "hard turn cannot begin an unsafe volley or mine burst")
	fresh()
	boss.begin(game.arena_center() + Vector3(-107, 0, -42))
	boss.heading = PI
	boss.rotation.y = -boss.heading
	game.damage_immunity = 1000
	await physics_frame
	var blocked_start: Vector3 = boss.position
	for i in 30 * 60:
		game.sea_time += 1.0 / 60
		boss.update_ship(1.0 / 60)
	check(boss.position.distance_to(blocked_start) > 15 and boss.contact_frames < 30 and game.archipelago.get_node("Terrain").terrain_height_at(boss.position) < -3, "blocked reef approach recovers into water without repeated obstacle contact")

	for hz in [30, 60, 120]:
		fresh()
		final_wave()
		game.damage_immunity = 1000
		var start: Vector3 = boss.position
		var max_step := 0.0
		var max_turn := 0.0
		var bounds := true
		for tick in 25 * hz:
			var previous: Vector3 = boss.position
			var heading: float = boss.heading
			game.advance_sailing(1.0 / hz, 0.12)
			max_step = maxf(max_step, boss.position.distance_to(previous))
			max_turn = maxf(max_turn, absf(wrapf(boss.heading - heading, -PI, PI)))
			bounds = bounds and boss.position.distance_to(game.arena_center()) <= game.arena_radius - 4.5
		check(max_step <= boss.sailing_speed * 1.13 / hz + 0.02 and max_turn <= boss.turning_speed / hz + 0.001, "%d Hz navigation neither teleports nor snaps heading" % hz)
		check(bounds and boss.position.distance_to(start) > 10, "%d Hz flagship sails sustained bounded routes" % hz)
		print("BOSS NAV %dHz shots=%d passes=%d contacts=%d recoveries=%d" % [hz, boss.shots_fired, boss.passes, boss.contact_frames, boss.recoveries])

	fresh()
	final_wave()
	# Drain the two escort arrivals while leaving the boss alive.
	for tick in 400: manager._update_arena(1.0 / 60)
	for ship in manager.ships:
		if ship.visible:
			while ship.hull > 0: ship.take_hit()
	check(game.state == game.State.SAILING and boss.hull == 9, "killing normal escorts never wins with flagship alive")
	game.hud._process(0)
	check(game.hud.boss_health.visible and game.hud.boss_health.value == 9, "boss HUD reads actual health")
	# Live escort + real incoming shot must be cleared immediately on boss defeat.
	manager.ships[0].begin(game.arena_center() + Vector3(-90, 0, 80))
	boss.pattern = boss.Pattern.ROLLING
	boss._prepare_volley(1.6)
	boss.deploy_mine()
	var ball = game._box(game, Vector3.ONE, game.boat.position + Vector3.UP, game._material(Color.WHITE))
	manager.ships[0].projectiles.append({"node":ball, "position":ball.position, "velocity":Vector3.ZERO, "ttl":4.0})
	while boss.hull > 0: boss.take_hit()
	check(game.state == game.State.ARRIVED and manager.phase == manager.Phase.COMPLETE and boss.navigation_state == boss.Navigation.SINKING, "boss defeat immediately wins with living escort and pending projectile; sinking starts")
	check(not manager.has_projectiles() and boss.mines.is_empty() and boss.volley.is_empty() and manager.spawn_queue.is_empty(), "victory cancels all shots, pending volleys, mines and arrivals")
	boss.update_ship(10.0)
	check(boss.projectiles.is_empty() and boss.volley.is_empty(), "boss death prevents any pending firing sequence from resuming")
	manager.on_ship_sunk(boss)
	manager._complete_boss_encounter()
	check(manager.victory_transitions == 1, "repeated defeat callbacks leave one victory transition")
	check(not game.take_damage(1, "late hazard"), "late hazards cannot damage after victory")
	game.hud._process(0)
	check(not game.hud.boss_health.visible and game.hud.menu_title.text == "VICTORY", "flagship victory uses simple result heading and hides boss HUD")
	fresh()
	final_wave()
	game.damage_immunity = 0
	game.take_damage(game.hull_capacity, "prior fatal hit")
	while boss.hull > 0:
		# A queued external defeat notification must also respect already lost state.
		boss.hull -= 1
	manager.on_ship_sunk(boss)
	check(game.state == game.State.LOST and manager.victory_transitions == 0, "already fatal player damage takes priority over boss callback")
	fresh()
	check(boss.hull == 9 and not boss.phase_two and boss.pattern_index == 0 and boss.volley.is_empty() and boss.mines.is_empty() and boss.mine_clock == 0.0 and boss.navigation_state == boss.Navigation.DORMANT, "retry restores health, phases, weapon sequence, rotation, mines and navigation")
	game.hud._process(0)
	check(not game.hud.boss_health.visible and manager.wave_number == 0, "retry hides boss health and restores wave one scheduler")
	print("BOSS CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

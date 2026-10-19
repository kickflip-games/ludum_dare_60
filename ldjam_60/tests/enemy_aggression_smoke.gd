extends "res://tests/enemy_pressure_smoke.gd"
## Unscaled reloads, wave carry-over and three physical diverging Heavy lanes.
var game
var ship
func stage(kind: String, distance := 42.0, starboard := false) -> void:
	game.restart(true)
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.damage_immunity = 10000
	game.boat.position = game.arena_center() + Vector3(0, 0, 112)
	game.boat.velocity = Vector3.ZERO
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	ship.begin(game.boat.position + Vector3(-distance if starboard else distance, 0, 0))
	ship.heading = 0
	ship.rotation.y = 0
	ship._speed = 0
	ship.velocity = Vector3.ZERO
	ship._change_navigation(ship.Navigation.ATTACK_RUN)
func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	ship = game.enemy_encounters.ship
	for hz in [30, 60, 120]:
		for kind in ["cutter", "skiff", "heavy"]:
			var previous := 0
			var previous_gap := INF
			for wave in range(1, 6):
				stage(kind)
				game.enemy_encounters.wave_number = wave
				await physics_frame
				var base: float = ship.reload_seconds
				for i in 5:
					check(is_equal_approx(ship.firing_reload_seconds(), base * [1.0, 0.9, 0.8, 0.7, 0.65][wave - 1]), "reload reads base profile once at wave %d" % wave)
				var fire_times: Array[float] = []
				for tick in hz * 20:
					var salvos: int = ship.salvos_fired
					ship.cooldown = maxf(0, ship.cooldown - 1.0 / hz)
					ship._update_weapon(1.0 / hz)
					ship._advance_shots(1.0 / hz)
					if ship.salvos_fired > salvos: fire_times.append(float(tick) / hz)
				var mean_gap: float = (fire_times.back() - fire_times.front()) / (fire_times.size() - 1)
				check(ship.salvos_fired >= previous and mean_gap < previous_gap, "%dHz %s wave %d increases completed salvos" % [hz, kind, wave])
				previous = ship.salvos_fired
				previous_gap = mean_gap
				print("WAVE CADENCE %dHz %s wave=%d salvos=%d shots=%d mean_gap=%.4f" % [hz, kind, wave, ship.salvos_fired, ship.shots_fired, mean_gap])
	stage("cutter")
	await physics_frame
	ship.safety_priority = 2
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.TELEGRAPH, "clear ordinary battery can warn while navigation avoids terrain")
	ship.safety_priority = 3
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.weapon_state == ship.Weapon.RELOAD and ship.shots_fired == 0, "actual collision recovery cancels an ordinary warning before launch")
	stage("cutter")
	game.enemy_encounters.wave_number = 1
	await physics_frame
	ship._update_weapon(0)
	var aim: Vector3 = ship.locked_point
	var timer: float = ship.weapon_time
	game.enemy_encounters._begin_wave()
	check(ship.weapon_state == ship.Weapon.TELEGRAPH and ship.weapon_time == timer and ship.locked_point == aim and ship.shots_fired == 0, "timed wave advance preserves a survivor's full in-progress warning")
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.shots_fired == 2 and is_equal_approx(ship.cooldown, 1.6 * 0.9), "survivor starts new wave's reload after its actual shot")
	var cooldown: float = ship.cooldown
	game.enemy_encounters._begin_wave()
	check(ship.cooldown == cooldown and ship.shots_fired == 2, "wave advance never rescales or clears a running cooldown")
	ship._change_weapon(ship.Weapon.READY)
	ship._update_weapon(0)
	check(ship.shots_fired == 2 and ship.weapon_state == ship.Weapon.READY, "wave advance cannot bypass unfinished recovery")
	for side in [false, true]:
		for distance in [25.0, 42.0, 65.0]:
			stage("heavy", distance, side)
			await physics_frame
			ship._update_weapon(0)
			check(ship.weapon_state == ship.Weapon.TELEGRAPH, "Heavy acquires a real facing battery")
			var target: Vector3 = ship.locked_point
			var axis: Vector3 = ship.locked_spread_axis
			ship._update_weapon(ship.telegraph_seconds)
			check(ship.projectiles.size() == 3, "three physical muzzles launch exactly three Heavy rounds")
			var impact_offsets: Array[float] = []
			var origin_offsets: Array[float] = []
			for shot in ship.projectiles:
				var origin: Vector3 = shot.position
				var velocity: Vector3 = shot.velocity * Vector3(1, 0, 1)
				var normal := axis.cross(Vector3.UP)
				var time: float = (target - origin).dot(normal) / velocity.dot(normal)
				impact_offsets.append((origin + velocity * time - target).dot(axis))
				origin_offsets.append((origin - target).dot(axis))
			check(absf(impact_offsets[0] - 2.75) < 0.01 and absf(impact_offsets[1]) < 0.01 and absf(impact_offsets[2] + 2.75) < 0.01, "actual horizontal trajectories reach symmetric ±2.75m and central predicted impact")
			check(impact_offsets[0] - impact_offsets[2] > origin_offsets[0] - origin_offsets[2] and ship.projectiles[0].velocity != ship.projectiles[1].velocity, "outer trajectories diverge from separate barrels instead of converging")
	stage("heavy")
	game.boat.velocity = Vector3(0, 0, -7.5)
	ship.velocity = game.boat.velocity
	await physics_frame
	ship._update_weapon(0)
	var moving_prediction: Vector3 = ship.locked_point
	ship.position += ship.velocity * ship.telegraph_seconds
	game.boat.position += game.boat.velocity * ship.telegraph_seconds
	ship.heading += 0.15
	ship.rotation.y = -ship.heading
	await physics_frame
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.projectiles.size() == 3 and ship.locked_point == moving_prediction, "moving Heavy retains its central prediction through the warning")
	if ship.projectiles.size() == 3:
		var central: Vector3 = ship.projectiles[1].velocity * Vector3(1, 0, 1)
		check(absf(central.normalized().dot(ship.locked_spread_axis)) < 0.00001, "spread stays perpendicular to the actual central firing direction after hull movement")
	for kind in ["cutter", "skiff"]:
		stage(kind)
		await physics_frame
		ship._update_weapon(0)
		for mount in ship.gun_mounts:
			check(ship._mount_target(mount, ship.locked_point) == ship.locked_point, "one/two-gun batteries retain the original prediction")
	game.restart(true)
	check(ship.cooldown == 0 and ship.projectiles.is_empty() and game.hull == 3 and game.enemy_encounters.wave_number == 0, "retry clears shots and difficulty; production health remains three")
	await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	print("ENEMY AGGRESSION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

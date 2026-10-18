extends SceneTree
## Facing batteries, committed physical volleys, stern mines and lifecycle gates.
var game
var ship
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func fresh(kind := "cutter") -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 112)
	game.boat.velocity = Vector3.ZERO
	ship.configure_archetype(load("res://game/enemies/" + kind + ".tres"))
	ship.begin(game.boat.position + Vector3(40, 0, 0))
	ship.heading = 0
	ship.rotation.y = 0
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
			for side in [ship.Battery.PORT, ship.Battery.STARBOARD, ship.Battery.BOW]:
				fresh(kind)
				var expected: int = 3 if kind == "heavy" else 2
				check(ship.gun_mounts.size() == expected * 2 + (1 if kind == "skiff" else 0), kind + " mounts actual guns on both sides")
				var direction: Vector3 = ship._battery_direction(side)
				game.boat.position = ship.position + direction * 42
				await physics_frame
				ship._update_weapon(0)
				if side == ship.Battery.BOW and kind != "skiff":
					check(ship.weapon_state == ship.Weapon.READY, kind + " cannot fire through an unarmed bow")
					continue
				check(ship.weapon_state == ship.Weapon.TELEGRAPH and ship.active_battery == side, "%d Hz %s selects battery %d" % [hz, kind, side])
				ship._update_tell()
				check(ship.gun_mounts.all(func(mount): return mount.flash.visible == (mount.battery == side)), "only the advertised battery flashes")
				var point: Vector3 = ship.locked_point
				for tick in ceili(ship.telegraph_seconds * hz) - 1:
					ship._update_weapon(1.0 / hz)
				check(ship.projectiles.is_empty() and ship.locked_point == point, "full warning elapses with fixed aim before any shell")
				ship._update_weapon(2.0 / hz)
				var count: int = 1 if side == ship.Battery.BOW else expected
				check(ship.shots_fired == count and ship.projectiles.size() == count and ship.salvos_fired == 1, "facing guns launch one physical shell each in a shared salvo")
				var origins := []
				for mount in ship.gun_mounts:
					if mount.battery == side: origins.append(ship._mount_position(mount))
				var matched := true
				for shot in ship.projectiles:
					matched = matched and origins.any(func(at): return at.distance_to(shot.position) < 0.001)
					matched = matched and shot.velocity.normalized().dot(direction) > 0.9
				check(matched, "physical launch positions and directions match the visible battery")
				ship._update_weapon(0.2)
				ship._update_weapon(0.1)
				check(ship.weapon_state == ship.Weapon.RELOAD and ship.cooldown == ship.reload_seconds, "all guns share one reload and cannot bypass it")
				var horizontal: Vector3 = ship.projectiles[0].velocity * Vector3(1, 0, 1)
				game.boat.position += Vector3(10, 0, 10)
				ship._advance_shots(0.02)
				check(ship.projectiles[0].velocity * Vector3(1, 0, 1) == horizontal, "launched cannonballs never home")
	fresh()
	game.boat.position = ship.position - ship.forward() * 42
	await physics_frame
	ship._update_weapon(0)
	check(ship.weapon_state == ship.Weapon.READY, "no stern cannon fires backwards")
	fresh("skiff")
	game.boat.position = ship.position + ship.forward() * 42
	await physics_frame
	ship._update_weapon(0)
	ship.heading = PI
	ship.rotation.y = -PI
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.shots_fired == 0 and ship.cancelled_shots == 1, "turning away cancels a committed bow shot rather than firing backwards")
	fresh()
	await physics_frame
	ship._update_weapon(0)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 12, 12)
	shape.shape = box
	obstacle.add_child(shape)
	game.add_child(obstacle)
	obstacle.position = ship.position.lerp(game.boat.position, 0.5)
	await physics_frame
	ship._update_weapon(ship.telegraph_seconds)
	check(ship.shots_fired == 0 and ship.cancelled_shots == 1, "a new obstruction cancels the whole advertised battery")
	obstacle.queue_free()
	await physics_frame
	for hz in [30, 60, 120]:
		fresh("heavy")
		ship.position = game.arena_center() + Vector3(40, 0, 95)
		ship.velocity = ship.forward() * 10
		game.boat.position = ship.position - ship.forward() * 45
		for tick in hz * 8 - 1: ship.mine_layer.update(1.0 / hz)
		check(ship.mine_layer.mines.is_empty(), "%d Hz mine interval has full initial grace" % hz)
		ship.mine_layer.update(2.0 / hz)
		check(ship.mine_layer.mines.size() == 1, "%d Hz pursuit automatically lays a stern mine after eight seconds" % hz)
		var mine = ship.mine_layer.mines[0]
		check(mine.position.distance_to(ship.position - ship.forward() * 9) < 0.01 and mine.get_parent() != ship, "mine stays in the water astern rather than following its hull")
		check(not mine.armed() and mine.trigger_radius == 5 and mine.arming_delay == 1.2, "ordinary mine has a matching five-metre ring and longer arming delay")
		var fixed_position: Vector3 = mine.position
		ship.position += Vector3(18, 0, 0)
		mine.update_mine(1.2)
		check(mine.armed() and mine.position == fixed_position, "mine arms at a fixed planar location")
		game.boat.position = mine.position + Vector3(5.1, 0, 0)
		var hull: int = game.hull
		mine.update_mine(0.01)
		check(game.hull == hull and not mine.spent, "outside the advertised ring is safe")
		game.boat.position = mine.position
		mine.update_mine(0.01)
		check(mine.spent and game.hull == hull - 1, "entering the ring damages through the normal immunity pathway")
		mine.update_mine(0.01)
		check(game.hull == hull - 1, "one mine cannot hit twice")
	fresh("heavy")
	ship.position = game.arena_center() + Vector3(40, 0, 95)
	game.boat.position = ship.position - ship.forward() * 9
	check(not ship.mine_layer.deploy(), "mine drop rejects the player underneath its stern")
	game.boat.position = game.arena_center() + Vector3(-60, 0, 110)
	ship.position = game.arena_center() + Vector3(0, 0, -9)
	check(not ship.mine_layer.deploy(), "mine drop rejects lighthouse geometry")
	ship.position = game.arena_center() + Vector3(190, 0, 0)
	check(not ship.mine_layer.deploy(), "mine drop rejects the arena edge")
	for x in [20, 40, 60]:
		ship.position = game.arena_center() + Vector3(x, 0, 100)
		check(ship.mine_layer.deploy(), "separated stern mine deploys")
	check(not ship.mine_layer.deploy(), "overlapping mine drop is rejected")
	ship.position.x += 20
	check(not ship.mine_layer.deploy() and ship.mine_layer.mines.size() == 3, "ordinary trail is capped at three live mines")
	ship.mine_layer.mines[0].update_mine(16)
	ship.mine_layer.update(0)
	check(not ship.mine_layer.deploy(), "time cannot expire a mine or free a full trail slot")
	game.cannon._impact(ship.mine_layer.mines[0], ship.mine_layer.mines[0].model.global_position)
	check(ship.mine_layer.deploy(), "shooting a mine frees a trail slot")
	var trail: Array = ship.mine_layer.mines.duplicate()
	for i in ship.hull_capacity: ship.take_hit()
	check(ship.mine_layer.mines.size() == 3 and trail.all(func(mine): return not mine.spent and mine.visible), "sinking leaves every ordinary mine in the water")
	check(not ship.mine_layer.deploy(), "sunk minelayer cannot lay new mines")
	ship.update_ship(1.3)
	check(trail.all(func(mine): return mine.armed()), "sunk ship's mines continue arming")
	ship.update_ship(2.3)
	check(ship.navigation_state == ship.Navigation.ESCAPED and trail.all(func(mine): return not mine.spent), "mines outlive the sinking hull")
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(game.arena_center() + Vector3(80, 0, 90))
	check(ship.mine_layer.mines.size() == 3 and trail.all(func(mine): return not mine.spent), "reusing the hull as a cutter preserves its old trail")
	game.boat.position = trail[0].position
	game.damage_immunity = 0.0
	var hull_before: int = game.hull
	ship.update_ship(0.01)
	check(trail[0].spent and game.hull == hull_before - 1, "orphaned armed mine still damages the player")
	game.boat.position = game.arena_center() + Vector3(-60, 0, 110)
	ship.navigation_state = ship.Navigation.DORMANT
	ship.update_ship(3600.0)
	check(not trail[1].spent and not trail[2].spent, "remaining mines persist for an hour while their pooled hull is dormant")
	fresh("heavy")
	ship.position = game.arena_center() + Vector3(40, 0, 95)
	game.boat.position = game.arena_center() + Vector3(-60, 0, 110)
	check(ship.mine_layer.deploy(), "live trail exists before retry")
	var retry_mine = ship.mine_layer.mines[0]
	for i in ship.hull_capacity: ship.take_hit()
	game.restart()
	check(retry_mine.spent and ship.mine_layer.mines.is_empty() and ship.mine_layer.clock == 0 and ship.projectiles.is_empty() and ship.salvos_fired == 0, "retry clears a sunk ship's mines, clocks, volleys and shots")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		fresh("heavy")
		ship.position = game.arena_center() + Vector3(40, 0, 95)
		game.boat.position = game.arena_center() + Vector3(-60, 0, 110)
		check(ship.mine_layer.deploy(), "live trail exists before ending")
		var ending_mine = ship.mine_layer.mines[0]
		for i in ship.hull_capacity: ship.take_hit()
		game.state = ending
		game.enemy_encounters.stop()
		check(ending_mine.spent and ship.mine_layer.mines.is_empty() and ship.projectiles.is_empty(), "loss/victory cancels sunk ships' hazards")
	fresh("heavy")
	game.boat.position = game.arena_center() + Vector3(-60, 0, 110)
	for x in [20, 40, 60]:
		ship.position = game.arena_center() + Vector3(x, 0, 100)
		check(ship.mine_layer.deploy(), "fatal-contact trail deploys")
	var fatal_trail: Array = ship.mine_layer.mines.duplicate()
	for i in ship.hull_capacity: ship.take_hit()
	game.hull = 1
	game.damage_immunity = 0.0
	game.boat.position = fatal_trail.back().position
	game.enemy_encounters.enabled = true
	game.enemy_encounters.update_encounters(1.3)
	check(game.state == game.State.LOST and ship.mine_layer.mines.is_empty() and fatal_trail.all(func(mine): return mine.spent), "fatal orphaned mine safely clears the whole trail during its update")
	fresh("cutter")
	check(not ship.mine_layer.deploy() and ship.gun_mounts.size() == 4, "pool reuse replaces heavy armament and disables mine laying")
	game.queue_free()
	await process_frame
	print("ENEMY ARMAMENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Real sailing updates with staged duels, incoming projectiles and hull damage.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func reset_voyage() -> void:
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.wave_encounters.enabled = false
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.boat.position = Vector3(400, 0, -360)
	game.heading = 0.0


func sail(seconds: float, fps: int = 60) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var delta := minf(remaining, 1.0 / fps)
		game.advance_sailing(delta, 0.0)
		game._update_view(delta)
		remaining -= delta


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	check(not game.restore_hull(1) and not game.is_repairing_hull(), "title cannot repair hull")
	reset_voyage()
	var ship = game.enemy_encounters.ship
	sail(20.0)
	check(game.hull == game.hull_capacity and game.hull_repair_elapsed == 0.0, "full hull cannot bank future repairs")
	game.take_damage(2, "battle damage")
	for mode in [ship.Mode.APPROACH, ship.Mode.POSITION, ship.Mode.TELEGRAPH, ship.Mode.FIRE, ship.Mode.REPOSITION]:
		ship.begin()
		ship.mode = mode
		game._update_hull_recovery(20.0)
		check(game.hull == 1 and game.hull_repair_elapsed == 0.0 and not game.is_repairing_hull(), "active battle mode %d blocks healing" % mode)
	ship.take_hit()
	ship.take_hit()
	check(ship.mode == ship.Mode.SINKING and game.is_repairing_hull(), "defeating a cutter allows recovery without waiting for its sinking animation")
	sail(7.99)
	check(game.hull == 1, "a damaged hull stays vulnerable until eight safe seconds pass")
	sail(0.01)
	game.hud._process(0.01)
	check(game.hull == 2 and game.hits_taken == 1 and game.damage_immunity == 0.0, "first safe interval restores one point without changing hit history or granting immunity")
	check(game.hud.hull_gauge.status.text == "Hull repaired" and game.hud.hull_gauge.pulse > 0.0, "repair completion gives accurate text and a positive hull pulse")
	sail(4.0)
	game.hud._process(0.01)
	check(game.hud.hull_gauge.status.text == "Repairing · 4s", "damaged hull displays an accurate countdown at a whole-second boundary")
	sail(4.0)
	check(game.hull == 3 and game.hull_repair_elapsed == 0.0, "a second full interval restores the remaining hull and clears progress")
	sail(12.0)
	check(game.hull == 3 and game.hull_repair_notice_left == 0.0, "repairs stop at capacity and completion feedback fades")
	reset_voyage()
	game.take_damage(1, "first hit")
	sail(7.5)
	game.take_damage(1, "interrupt repair")
	check(game.hull == 1 and game.hull_repair_elapsed == 0.0 and game.hull_repair_notice_left == 0.0, "new damage discards partial progress and old repair feedback")
	sail(0.5)
	check(game.hull == 1 and is_equal_approx(game.hull_repair_elapsed, 0.5), "interrupted repairs require a fresh full interval")
	check(not game.take_damage(1, "immune contact") and is_equal_approx(game.hull_repair_elapsed, 0.5), "rejected immune contact does not interrupt recovery")
	sail(7.0)
	ship.begin()
	game.advance_sailing(0.1, 0.0)
	check(game.hull == 1 and game.hull_repair_elapsed == 0.0, "a new cutter cancels a nearly complete repair")
	ship.disengage()
	sail(8.0)
	check(game.hull == 2, "escaping a cutter earns the same recovery as defeating it")
	reset_voyage()
	game.take_damage(1, "collision fixture")
	sail(7.5)
	game._add_hazard(Vector3(400, 0, -430), 3.0, "rock")
	game.boat.position = Vector3(400, 0, -424)
	await physics_frame
	game.advance_sailing(1.0, 0.0)
	check(game.hull == 1 and game.hull_repair_elapsed == 0.0, "real collision damage cannot count its own sailing step toward recovery")
	# Defeat and escape both leave real cannonballs alive until impact/expiry.
	for defeated in [false, true]:
		reset_voyage()
		game.take_damage(1, "duel damage")
		ship.begin(game.boat.position + Vector3(40, 0, 0))
		ship.locked_point = game.boat.position
		ship._fire()
		if defeated:
			ship.take_hit()
			ship.take_hit()
		else:
			ship.disengage()
		game._update_hull_recovery(20.0)
		check(game.enemy_encounters.battle_active() and game.hull == 2 and game.hull_repair_elapsed == 0.0, "lingering cannonball blocks repairs after %s" % ("defeat" if defeated else "escape"))
		ship.projectiles[0].ttl = 0.0
		ship.update_ship(0.01)
		check(ship.projectiles.is_empty() and game.is_repairing_hull(), "last cannonball clearing unlocks recovery")
		sail(7.99)
		check(game.hull == 2, "clearing incoming fire starts a fresh repair interval")
		sail(0.01)
		check(game.hull == 3, "hull repairs after a full interval clear of incoming fire")
	reset_voyage()
	game.take_damage(2, "salvage fixture")
	game.boat.position = game.archipelago.get_node("OptionalDiscoveries/HiddenCove").position
	game.archipelago.update_discoveries()
	game.archipelago.update_discoveries()
	check(game.hull == 2 and game.archipelago.discoveries.size() == 1, "salvage retains its immediate once-per-voyage repair")
	check(game.restore_hull(99) and game.hull == 3 and not game.restore_hull(1), "all restoration clamps to capacity")
	check(not game.restore_hull(0) and not game.restore_hull(-1), "non-positive restoration is ignored")
	for fps in [30, 60, 120]:
		reset_voyage()
		game.take_damage(2, "frame-rate fixture")
		sail(7.99, fps)
		check(game.hull == 1, "no early repair at %d Hz" % fps)
		sail(8.01, fps)
		check(game.hull == 3, "two repairs take sixteen safe seconds at %d Hz" % fps)
	reset_voyage()
	game.take_damage(1, "retry fixture")
	sail(4.0)
	game.restart()
	check(game.hull == 3 and game.hull_repair_elapsed == 0.0 and game.hull_repair_notice_left == 0.0, "retry clears repair progress and feedback")
	for state in [game.State.READY, game.State.CASTING_OFF, game.State.ARRIVED, game.State.LOST]:
		game.state = state
		game.hull = 1
		game._update_hull_recovery(30.0)
		check(game.hull == 1 and not game.restore_hull(1), "non-sailing state %d cannot recover" % state)
	reset_voyage()
	game.take_damage(3, "fatal broadside")
	sail(30.0)
	check(game.hull == 0 and game.state == game.State.LOST and not game.restore_hull(3), "fatal damage cannot be undone by automatic or salvage healing")
	print("RECOVERY CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

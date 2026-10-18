extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.damage_immunity = 1000
func run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	fresh()
	var pool = game.cannon.projectile_visuals
	check(pool.free_nodes.size() == pool.CAPACITY, "Visual pool preallocated")
	var nodes: Array = []
	for i in pool.CAPACITY:
		var node = pool.acquire(Vector3(i,10,0),i%2 == 1)
		nodes.append(node)
		check(node != null and node.visible and node.mesh == pool.sphere, "Every overlapping visual has shared geometry")
	check(pool.acquire(Vector3.ZERO) == null and pool.leased.size() == pool.CAPACITY, "Exhaustion preserves all active leases")
	for node in nodes: pool.release(node)
	pool.release(nodes[0])
	check(pool.free_nodes.size() == pool.CAPACITY and pool.leased.is_empty(), "Release idempotent and bounded")
	var enemy = pool.acquire(Vector3(1,2,3),true)
	check(enemy.material_override == pool.hostile and enemy.scale == Vector3.ONE, "Enemy visual palette and size retained")
	pool.release(enemy)
	var player = pool.acquire(Vector3(4,5,6))
	check(player.material_override == pool.friendly and player.scale.is_equal_approx(Vector3.ONE*0.8) and player.position == Vector3(4,5,6), "Recycled visual fully reconfigured for player")
	pool.release(player)
	for repeat in 8:
		game.cannon.cooldown = 0
		check(game.cannon.fire(), "First and repeated player shots launch")
		check(game.cannon.projectiles.back().node.visible, "Player projectile always visible")
		game.cannon.projectiles.back().ttl = 0
		game.cannon.advance(1.0/60)
	check(game.cannon.projectiles.is_empty() and pool.leased.is_empty(), "Expiry returns every visual")
	for i in 6:
		var ship = game.enemy_encounters.ships[i]
		ship.configure_archetype(load("res://game/enemies/heavy.tres"))
		ship.begin(game.arena_center()+Vector3(-70+i*15,0,90))
		ship.locked_point = game.boat.position+Vector3.UP*2
		ship._fire()
	check(pool.leased.size() >= 18 and pool.exhaustion_count == 1, "Six simultaneous full heavy salvos never exhaust legal budget")
	for ship in game.enemy_encounters.ships: ship.reset()
	check(pool.leased.is_empty(), "Ship reset releases its own projectiles")
	var boss = game.enemy_encounters.boss
	check(boss.mine_pool.size() == boss.maximum_mines, "Flagship maximum prebuilt")
	var mine = boss.mine_pool[0]
	var sibling = boss.mine_pool[1]
	check(mine.spent and not mine.visible and not mine.is_processing(), "Inactive mine does no per-frame work")
	check(mine.ring.mesh == sibling.ring.mesh and mine.material != sibling.material, "Ring geometry shared; shader state independent")
	var model_id: int = mine.model.get_instance_id()
	var material_id: int = mine.material.get_instance_id()
	var ring_id: int = mine.ring.mesh.get_instance_id()
	var baseline_nodes := get_node_count()
	for repeat in 100:
		mine.activate(game.boat.position+Vector3(35,0,0))
		check(not mine.spent and mine.age == 0 and not mine.armed(), "Recycled mine starts unarmed")
		mine.age = mine.arming_delay
		mine.update_mine(mine.lifetime)
		check(mine.spent and not mine.visible and not mine.is_processing(), "Expired mine returns to inactive state")
		check(mine.model.get_instance_id() == model_id and mine.material.get_instance_id() == material_id and mine.ring.mesh.get_instance_id() == ring_id, "Mine activation allocates no model/material/ring")
	check(get_node_count() == baseline_nodes, "100 mine cycles keep node count fixed")
	var hull: int = game.hull
	mine.position = game.boat.position
	mine.age = 100
	mine.update_mine(0.1)
	check(game.hull == hull and not mine.armed(), "Inactive mine overlapping player cannot damage")
	mine.activate(game.boat.position)
	mine.age = mine.arming_delay
	game.damage_immunity = 0
	mine.update_mine(0.01)
	check(game.hull == hull-1 and mine.spent, "Armed recycled mine deals one real hit")
	mine.update_mine(0.01)
	check(game.hull == hull-1, "Spent mine cannot hit twice")
	mine.activate(game.boat.position+Vector3(40,0,0))
	game.ocean.settings.sea_level += 0.1
	mine.update_visuals()
	check(is_equal_approx(mine.material.get_shader_parameter("sea_level"),game.ocean.settings.sea_level), "Settings changes invalidate mine shader cache")
	mine.expire()
	for ending in [game.State.LOST,game.State.ARRIVED]:
		fresh()
		game.cannon.cooldown = 0
		game.cannon.fire()
		boss.begin(game.arena_center()+Vector3(65,0,100))
		boss.deploy_mine()
		game.state = ending
		game.enemy_encounters.stop()
		game.cannon.reset()
		check(pool.leased.is_empty() and boss.mine_pool.all(func(m): return m.spent and not m.visible), "Ending releases all projectiles and mines")
		fresh()
		check(pool.leased.is_empty() and boss.mines.is_empty(), "Retry has no phantom projectiles/mines")
	fresh()
	game.boat.position = game.arena_center()+Vector3(65,0,80)
	game.boat.reset_physics_interpolation()
	var attacker = game.enemy_encounters.ships[0]
	attacker.begin(game.boat.position+Vector3(30,0,0))
	attacker.locked_point = game.boat.position+Vector3.UP
	await physics_frame
	game.hull = 1
	game.damage_immunity = 0
	attacker._launch_ball(game.boat.position+Vector3(6,1,0))
	attacker._advance_shots(0.3)
	print("FATAL DEBUG ", game.state, " hull ",game.hull," shots ",attacker.projectiles.size()," leased ",pool.leased.size()," layer ",game.boat.collision_layer)
	check(game.state == game.State.LOST and attacker.projectiles.is_empty() and pool.leased.is_empty(), "Fatal real projectile collision safely clears every lease during callback")
	fresh()
	await process_frame
	var stable_nodes := get_node_count()
	var shared_mesh: int = pool.sphere.get_instance_id()
	for repeat in 100:
		game.cannon.cooldown = 0
		game.cannon.fire()
		game.cannon.reset()
	check(get_node_count() == stable_nodes and pool.sphere.get_instance_id() == shared_mesh and pool.free_nodes.size() == pool.CAPACITY, "100 projectile cycles preserve node/resource identity and pool capacity")
	var shots: int = game.cannon.shots_fired
	for tick in 60: game.cannon.update_aim(1.0/60)
	check(game.cannon.shots_fired == shots and pool.leased.is_empty(), "No input creates no projectile")
	check(game.cannon.combat_warmup.complete and game.hull == game.hull_capacity, "Warm-up never fires, damages or alters hull")
	game.queue_free()
	await process_frame
	print("RUNTIME POOLS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

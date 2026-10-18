extends SceneTree
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.restart()
	game.state = game.State.SAILING
	var fx = game.combat_particles
	check(not fx.batch.visible and not fx.is_processing() and fx.emitted == 0, "idle particles cost no draw or process callback")
	check(game.cannon.fire() and fx.emitted == 12, "accepted player shot emits sparks and smoke")
	var emitted: int = fx.emitted
	check(not game.cannon.fire() and fx.emitted == emitted, "reload rejection emits nothing")
	check(game.cannon.projectiles.size() == 1 and game.cannon.cooldown == 1.5, "effects preserve ball and reload")
	fx.smoke(game.boat.position + Vector3.UP * 3)
	check(fx.emitted == emitted + 3, "damaged flagship smoke reuses three bounded rising cubes")
	fx.reset()
	check(game.take_damage(1, "test") and fx.emitted == 25, "accepted hull damage emits timber, smoke and foam")
	emitted = fx.emitted
	check(not game.take_damage(1, "immune") and not game.take_damage(0, "zero") and fx.emitted == emitted, "immune and zero hits have no duplicate particles")
	game.damage_immunity = 0.0
	game.take_damage(3, "lethal")
	check(game.state == game.State.LOST and fx.batch.visible and fx.emitted > emitted, "lethal burst survives projectile cleanup")
	fx.advance(2.0)
	check(not fx.batch.visible and not fx.is_processing(), "particles expire even after loss")
	game.restart()
	check(fx.emitted == 0 and not fx.batch.visible and game.cannon.projectiles.is_empty(), "retry clears batch and projectiles")
	game.state = game.State.SAILING
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + Vector3(20, 0, 0))
	ship.locked_point = game.boat.position
	ship._fire()
	check(fx.emitted == 12 and ship.projectiles.size() == 1, "enemy launch emits its own orange muzzle burst")
	ship._advance_shots(0.08)
	check(fx.emitted > 12, "moving enemy shot leaves short orange trail")
	fx.reset()
	game.cannon._impact(ship, ship.global_position + Vector3.UP)
	check(fx.emitted >= 17 and ship.hull == 1, "confirmed enemy hit emits splinters without changing damage")
	game.cannon._impact(ship, ship.global_position + Vector3.UP)
	emitted = fx.emitted
	game.cannon._impact(ship, ship.global_position)
	check(ship.hull == 0 and fx.emitted == emitted, "sinking enemy cannot produce repeated hit bursts")
	game.restart()
	await process_frame
	var nodes := get_node_count()
	for i in 1000:
		fx.damage(game.boat.position, true)
		fx.muzzle(game.boat.position, Vector3.RIGHT, true)
		fx.trail(game.boat.position)
	check(get_node_count() == nodes and fx.mesh.instance_count == 192 and fx.cursor < 192,
		"50,000 particle emissions keep one fixed batch and constant node count")
	fx.advance(2.0)
	check(not fx.batch.visible and not fx.is_processing(), "saturated batch drains and sleeps")
	for hz in [30, 60, 120]:
		fx.reset()
		fx.damage(game.boat.position)
		for frame in hz * 2: fx.advance(1.0 / hz)
		check(not fx.batch.visible, "expiry is frame-rate independent at %d Hz" % hz)
	game.cannon.reset()
	for i in 40: game.cannon.water_splash(game.boat.position, false)
	check(game.cannon.effects.size() <= 24, "simultaneous water impacts are capped at 24 existing meshes")
	game.cannon.advance(0.6)
	for i in 40: game.cannon.water_splash(game.boat.position, false)
	check(game.cannon.effects.size() <= 24, "partial splash expiry cannot exceed cap")
	game.cannon.advance(2.0)
	check(game.cannon.effects.is_empty(), "bounded water splashes fully expire")
	game.restart()
	check(not fx.batch.visible and fx.emitted == 0, "retry after saturation clears all cosmetic feedback")
	var cannon = game.cannon
	game.state = game.State.SAILING
	var ids: Array[int] = []
	var materials: Array[int] = []
	for group in cannon.splash_pool:
		for effect in group:
			ids.append(effect.node.get_instance_id())
			materials.append(effect.node.material_override.get_instance_id())
	check(ids.size() == 24 and materials.size() == 24, "four preallocated six-mesh splash groups")
	var unique := {}
	for id in materials: unique[id] = true
	check(unique.size() == 24, "independent preallocated opacity materials")
	nodes = get_node_count()
	for cycle in 250:
		cannon.water_splash(game.boat.position + Vector3(cycle % 5, 0, 5), false)
		cannon.advance_effects(0.02)
	check(get_node_count() == nodes and cannon.effects.size() <= 24, "250 overlapping impacts allocate no nodes")
	var same := true
	var count := 0
	for group in cannon.splash_pool:
		for effect in group:
			same = same and effect.node.get_instance_id() == ids[count] and effect.node.material_override.get_instance_id() == materials[count]
			count += 1
	check(same, "saturation reuses original nodes and materials")
	var ring: Dictionary = cannon.splash_pool[(cannon.splash_cursor + 3) % 4][0]
	var before_scale: float = ring.node.scale.x
	game.ocean.wave_time += 0.1
	cannon.advance_effects(0.1)
	var ring_at: Vector3 = ring.node.position
	check(ring.node.scale.x > before_scale and absf(ring_at.y - game.ocean.height_at(Vector2(ring_at.x, ring_at.z)) - 0.045) < 0.001, "ring expands on authoritative moving water")
	cannon.advance_effects(2.0)
	var hidden := true
	for group in cannon.splash_pool:
		for effect in group: hidden = hidden and not effect.node.visible
	check(hidden and cannon.effects.is_empty(), "expired pool is hidden with no draw calls")
	for hz in [30, 60, 120]:
		cannon.water_splash(game.boat.position, false)
		for frame in hz: cannon.advance_effects(1.0 / hz)
		check(cannon.effects.is_empty(), "splash lifetime settles at %d Hz" % hz)
	# A range/lifetime expiry in the air removes the ball without inventing water.
	cannon.reset()
	cannon.fire()
	cannon.projectiles[0].physics_position = game.boat.position + Vector3(0, 50, 0)
	cannon.projectiles[0].velocity = Vector3.RIGHT
	cannon.projectiles[0].ttl = 0.001
	cannon.projectiles[0].range = 0.0
	cannon.advance(0.01)
	check(cannon.effects.is_empty() and cannon.projectiles.is_empty(), "air expiry never makes a splash")
	cannon.reset()
	cannon.fire()
	var rest_origin: Vector3 = cannon.shot_origin()
	var rest_direction: Vector3 = cannon.aimed_direction()
	cannon.advance(0.045)
	check(cannon.barrel.position.x < -0.29, "barrel reaches full kick in 45ms")
	check(cannon.shot_origin().is_equal_approx(rest_origin) and cannon.aimed_direction().is_equal_approx(rest_direction), "cosmetic recoil cannot move launch origin or axis")
	cannon.advance(0.205)
	check(absf(cannon.barrel.position.x) < 0.001 and not cannon.flash.visible and not cannon.flash_light.visible, "recoil and light settle in 250ms")
	# Real water crossing retains physical collision and produces one full splash.
	cannon.reset()
	cannon.fire()
	var point: Vector3 = game.boat.position + Vector3(15, 0, 0)
	point.y = game.ocean.height_at(Vector2(point.x, point.z)) + 0.1
	cannon.projectiles[0].physics_position = point
	cannon.projectiles[0].velocity = Vector3.DOWN * 20
	cannon.projectiles[0].range = 0.0
	cannon.advance(0.02)
	check(cannon.projectiles.is_empty() and cannon.effects.size() == 6, "actual water intersection produces a six-mesh splash")
	game.restart()
	game.state = game.State.SAILING
	ship = game.enemy_encounters.ship
	ship.configure_archetype(load("res://game/enemies/heavy.tres"))
	ship.begin(game.boat.position + Vector3(20, 0, 0))
	fx.reset()
	cannon._impact(ship, ship.global_position + Vector3.UP * 4)
	check(ship.hull == 2 and cannon.effects.is_empty(), "mid-hull hit creates wood feedback without a false water burst")
	var ordinary: int = fx.emitted
	cannon._impact(ship, ship.global_position + Vector3.UP * 4)
	var previous: int = fx.emitted
	cannon._impact(ship, ship.global_position + Vector3.UP * 4)
	check(fx.emitted - previous > ordinary and cannon.effects.size() == 6, "final blow has larger pooled burst and waterline foam")
	previous = fx.emitted
	cannon._impact(ship, ship.global_position)
	check(fx.emitted == previous, "destroyed ship rejects repeat destruction burst")
	game.restart()
	check(cannon.effects.is_empty() and cannon.barrel.position == Vector3.ZERO and not cannon.flash.visible and not cannon.flash_light.visible, "retry clears pooled water, flash and recoil")
	print("COMBAT PARTICLES: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

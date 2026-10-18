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
	print("COMBAT PARTICLES: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

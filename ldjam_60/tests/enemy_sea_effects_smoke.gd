extends SceneTree
## Actual spawn lifecycle and movement history; no commands or combat bypasses.
var game
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func fresh(ship) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(-30, 0, 115)
	ship.begin(game.arena_center() + Vector3(35, 0, 95))
	ship.heading = 0
	ship.rotation.y = 0
func travel(ship, seconds: float, hz: int, speed := 9.0, turn := 0.0) -> void:
	for tick in roundi(seconds * hz):
		ship.heading += turn / hz
		ship.rotation.y = -ship.heading
		ship.position += ship.forward() * speed / hz
		game.ocean.wave_time += 1.0 / hz
		ship.sea_effects.advance_arrival(1.0 / hz)
		ship.sea_effects.update_trail(1.0 / hz, true)
		ship.update_visuals(1.0 / hz)
func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	for ship in [game.enemy_encounters.ship, game.enemy_encounters.boss]:
		var label: String = ship.display_name()
		for hz in [30, 60, 120]:
			fresh(ship)
			var fx = ship.sea_effects
			var start: Vector3 = ship.position
			check(fx.opacity == 0 and fx.active_drops > 0 and ship.visible, label + " arrives through water spray with an initially absent silhouette")
			check(ship.collision_layer == 4 and not ship.get_meta("destroyed") and ship.hull == ship.hull_capacity, "arrival preserves physical targeting and combat health")
			check(fx.fade_materials.all(func(mat): return mat.albedo_color.a == 0), "hull, sail and every gun share the arrival opacity")
			travel(ship, 0.3, hz, 0)
			var partial: float = fx.opacity
			check(partial > 0 and partial < 0.5 and ship.position == start, "%d Hz arrival fades smoothly without moving the physical root" % hz)
			ship.set_aim_highlight(true)
			check(fx.fade_materials.all(func(mat): return is_equal_approx(mat.albedo_color.a, partial)), "highlight and damage materials cannot interrupt the fade")
			travel(ship, 0.7, hz, 0)
			check(fx.opacity == 1 and fx.fade_materials.all(func(mat): return mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1), "arrival restores opaque night materials without persistent transparency")
			check(fx.wake.count == 0 and fx.active_drops == 0, "idle hull leaves no wake and arrival spray expires")
			var ids := [fx.wake.meshes[0].get_instance_id(), fx.wake.meshes[1].get_instance_id(), fx.pool.get_instance_id()]
			var nodes := get_node_count()
			travel(ship, 3, hz)
			check(fx.wake.count >= 40 and fx.active_drops > 0 and fx.emitted > 20, "%d Hz measured sailing leaves foam and stern particles" % hz)
			check(fx.wake.global_transform.is_equal_approx(Transform3D.IDENTITY) and fx.spray.global_transform.is_equal_approx(Transform3D.IDENTITY), "foam and spray stay in world coordinates behind the moving ship")
			var slot: int = fx.wake.cursor
			var fixed_point: Vector3 = fx.wake.points[slot]
			travel(ship, 1, hz, 9, 0.45)
			check(fx.wake.points[slot] == fixed_point, "turning leaves the existing curved trail fixed in the water")
			check(fx.wake.materials[0].get_shader_parameter("wave_time") == game.ocean.wave_time and fx.wake.materials[0].get_shader_parameter("focus_xz") == game.ocean.focus_xz, "enemy wake follows the current shared wave time and ocean focus")
			var previous_emitted: int = fx.emitted
			ship.velocity = ship.forward() * 20 # Stale command while the real hull is blocked.
			travel(ship, 6, hz, 0)
			check(fx.emitted == previous_emitted and fx.active_drops == 0, "blocked hull stops spray despite stale velocity")
			var colors: PackedColorArray = fx.wake.buffers[0][Mesh.ARRAY_COLOR]
			check(Array(colors).all(func(color): return color.a == 0), "old stationary foam fades completely")
			check(fx.wake.count <= fx.wake.CAPACITY and fx.pool.instance_count == 16 and get_node_count() == nodes and ids == [fx.wake.meshes[0].get_instance_id(), fx.wake.meshes[1].get_instance_id(), fx.pool.get_instance_id()], "sustained effects reuse fixed meshes, nodes and sixteen spray slots")
			ship.position += Vector3(45, 0, 0)
			fx.update_trail(1.0 / hz, true)
			check(fx.wake.count == 0 and fx.active_drops == 0, "teleport clears trails instead of drawing a foam bridge")
			fresh(ship)
			travel(ship, 1.5, hz)
			var emitted: int = fx.emitted
			for i in ship.hull_capacity: ship.take_hit()
			ship.update_ship(0.2)
			check(fx.emitted <= emitted and ship.navigation_state == ship.Navigation.SINKING, "sinking stops new stern emissions and keeps the descent")
			ship.reset()
			check(fx.wake.count == 0 and fx.active_drops == 0 and fx.opacity == 1 and not fx.spray.visible and not fx.wake.visible, "pool reset clears foam, spray and partial arrival materials")
	# Verify two simultaneous arrivals cannot fade each other's supplied atlas.
	fresh(game.enemy_encounters.ship)
	var first = game.enemy_encounters.ship
	first.sea_effects.advance_arrival(0.4)
	first.sea_effects.apply_arrival()
	var other = game.enemy_encounters.ships[1]
	other.begin(game.arena_center() + Vector3(-55, 0, 70))
	check(first.sail_material != other.sail_material and first.sail_material.albedo_color.a > 0 and other.sail_material.albedo_color.a == 0, "overlapping spawns keep private material fades")
	game.restart()
	check(game.enemy_encounters.combat_ships().all(func(ship): return ship.sea_effects.wake.count == 0 and ship.sea_effects.active_drops == 0 and ship.sea_effects.opacity == 1), "retry clears the whole fleet's arrivals and wakes")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		fresh(first)
		travel(first, 2, 60)
		game.state = ending
		game.enemy_encounters.stop()
		check(first.sea_effects.wake.count == 0 and first.sea_effects.active_drops == 0, "endings cancel fleet trails and spawn effects")
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = true
	game.boat.position = game.arena_center() + Vector3(0, 0, 110)
	game.enemy_encounters._begin_wave()
	check(game.enemy_encounters._spawn_queued(), "production queue still finds a safe separated arrival")
	var arrival = game.enemy_encounters.living_ships()[0]
	check(arrival.sea_effects.opacity == 0 and game.enemy_encounters.records[0].spawned == 1 and game.enemy_encounters.spawn_queue.size() == 1, "spawn animation retains roster accounting and staggered arrivals")
	var early_fire := false
	for tick in 60:
		game.enemy_encounters.update_encounters(1.0 / 60)
		if arrival.sea_effects.opacity < 1 and arrival.shots_fired > 0: early_fire = true
	check(arrival.sea_effects.opacity == 1 and not early_fire and arrival.sea_effects.wake.count > 1, "real enemy updates complete arrival and leave a trail before any physical shot")
	game.ocean_quality = 0
	game.motion_setting = 1
	fresh(first)
	check(first.sea_effects.active_drops <= 6 and first.sea_effects.active_drops > 0, "Low quality and Reduced motion retain a smaller visible arrival spray")
	travel(first, 2, 60)
	check(first.sea_effects.wake.count > 1 and first.sea_effects.active_drops <= 16 and first.hull == first.hull_capacity, "Low/Reduced keeps the trail bounded without affecting hull health")
	game.queue_free()
	await process_frame
	print("ENEMY SEA EFFECTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

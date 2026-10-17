extends SceneTree
const Pilot = preload("res://tests/archipelago_pilot.gd")
var game
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)
func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in range(30):
		await process_frame
	var terrain = game.archipelago.get_node("Terrain")
	check(terrain.get_dims() == Vector2i(257, 257), "baked LiteTerrain loads 257x257 data")
	check(not terrain._col_active and not terrain.collision.disabled, "full-map collision covers boat, enemies and untracked projectiles")
	check(terrain.terrain_height_at(game.boat.position) < -8, "departure is open water")
	check(not game.beacon.visible, "lighthouse concealed at departure")
	for p in [Vector3(-512,0,0), Vector3(512,0,512), Vector3(0,0,-512)]:
		check(terrain.terrain_height_at(p) < -10, "map edge remains underwater %s" % p)
	# Bearings are recomputed from any position. The stars never move with targets.
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		var star: Vector3 = game.guiding_star_direction()
		for p in [Vector3(0,0,104), Vector3(-180,0,-180), Vector3(350,0,140)]:
			game.boat.position = p
			var desired: Vector3 = (game.target - p).normalized()
			check(game.course_forward().dot(desired) > 0.999, "stage %d recovers bearing from %s" % [stage, p])
			check(game.guiding_star_direction().is_equal_approx(star), "star direction stays fixed")
	# Every stage projects the exact same direction used by the rendered sky.
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		for angle in [0.0, PI/2, PI, -PI/2]:
			game.state = game.State.SAILING
			game.heading = angle
			game.reading = true
			game.read_blend = 1.0
			game.focus_elapsed = 2.0
			game._update_view(0.0)
			game.hud._process(0.0)
			check(root.get_visible_rect().has_point(game.hud._star_screen_position()), "stage %d star projection visible at heading %.0f" % [stage,rad_to_deg(angle)])
		game.reading = false
		game._update_view(0.2)
		game.hud._process(0.1)
		check(game.hud.alignment_label.text.is_empty() and game.focus_strength == 0.0, "stage %d lowering erases bearing assistance" % stage)
	game.restart()
	game.state = game.State.SAILING
	game.boat.position = Vector3(140,0,10)
	game.heading = 0.0
	game.boat.rotation.y = 0.0
	check(game.cannon.fire(), "real broadside launches toward eastern island")
	for i in range(90):
		game.cannon.advance(1.0/60.0)
		if game.cannon.projectiles.is_empty():
			break
		if i % 10 == 0:
			await process_frame
	check(game.cannon.projectiles.is_empty() and game.cannon.feedback.contains("REEF"), "actual swept cannonball stops against terrain")
	# Every authored route has water clearance, including alternate destination approaches.
	for alternate in [false, true]:
		var pilot := Pilot.new()
		pilot.alternate = alternate
		for stage in range(3):
			var points: Array = pilot.route(stage)
			var previous := Vector2(0,104) if stage == 0 else Vector2(-230,-155) if stage == 1 else Vector2(226,-205)
			var safe := true
			for point: Vector2 in points:
				for i in range(101):
					var p := previous.lerp(point, i / 100.0)
					if terrain.terrain_height_at(Vector3(p.x,0,p.y)) > -2.5:
						if safe:
							print("ROUTE SHORE stage=%d at=%s h=%.2f" % [stage,p,terrain.terrain_height_at(Vector3(p.x,0,p.y))])
						safe = false
				previous = point
			check(safe, "stage %d route %s continuous water clearance" % [stage, "alternate" if alternate else "outer"])
	# Actual collider blocks a line through the central island and catches cannon-height rays.
	var query := PhysicsRayQueryParameters3D.create(Vector3(0,1,100), Vector3(0,1,-180), 1)
	check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "central land physically blocks a direct line")
	query = PhysicsRayQueryParameters3D.create(Vector3(140,2,10), Vector3(290,2,10), 1)
	check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "cannon-height rays hit island collision")
	if "--geometry-only" in OS.get_cmdline_user_args():
		game.free()
		quit(0 if failures == 0 else 1)
		return
	for alternate in [false, true]:
		game.restart()
		game.state = game.State.SAILING
		var pilot := Pilot.new()
		pilot.alternate = alternate
		var transitions: Array[int] = [0]
		var min_enemy_ground := -INF
		var terrain_hits := 0
		var last_hits := 0
		for frame in range(26000):
			var steering: float = pilot.steering(game)
			game.advance_sailing(1.0 / 60.0, steering)
			if game.hits_taken > last_hits:
				print("HIT at=%s reason=%s t=%.2f" % [game.boat.position, game.hit_message, game.elapsed])
				if game.hit_message.begins_with("HULL STRUCK"):
					terrain_hits += 1
				last_hits = game.hits_taken
			game.cannon.advance(1.0 / 60.0)
			if transitions.back() != game.voyage.stage:
				transitions.append(game.voyage.stage)
			var ship = game.enemy_encounters.ship
			if ship.visible and ship.mode != ship.Mode.SINKING:
				min_enemy_ground = maxf(min_enemy_ground, terrain.terrain_height_at(ship.position))
			if frame % 6 == 0:
				await process_frame
			if game.state != game.State.SAILING:
				break
		print("VOYAGE alternate=%s state=%d time=%.2f hull=%d hits=%d encounters=%d stages=%s position=%s enemy_ground_max=%.2f" % [alternate, game.state, game.elapsed, game.hull, game.hits_taken, game.enemy_encounters.encounter_index, transitions, game.boat.position, min_enemy_ground])
		check(game.state == game.State.ARRIVED and transitions == [0,1,2,3], "complete physical voyage %s visits all stages in order" % alternate)
		print("WAVE HISTORY: %s total=%d" % [game.wave_encounters.history, game.wave_encounters.total_launched])
		check(terrain_hits == 0, "authored route %s needs no terrain impacts" % alternate)
		check(min_enemy_ground < -1.0, "active pirates stay in water on route %s" % alternate)
	game.restart()
	game.state = game.State.SAILING
	game.boat.position = game.archipelago.get_node("OptionalDiscoveries/HiddenCove").position
	game.hull = 2
	game.archipelago.update_discoveries()
	game.archipelago.update_discoveries()
	check(game.hull == 3 and game.archipelago.discoveries.size() == 1, "salvage heals once per voyage")
	game.restart()
	check(game.voyage.stage == 0 and game.archipelago.discoveries.is_empty() and not game.beacon.visible, "restart resets progression, salvage, encounters and beacon")
	game.state = game.State.SAILING
	game.boat.position = game.archipelago.get_node("NavigationRegions/Lighthouse").position
	game.voyage.update_progress(game)
	check(game.voyage.stage == 0 and game.state == game.State.SAILING, "visiting final harbour early cannot skip stages")
	game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
	game.voyage.set_target(game)
	game.boat.position = game.target
	game.state = game.State.LOST
	game.voyage.update_progress(game)
	check(game.voyage.stage == game.voyage.Stage.LIGHTHOUSE and game.state == game.State.LOST, "a sunk vessel cannot unlock victory in a discovery region")
	print("ARCHIPELAGO: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

extends SceneTree
## Real collision, held-input, lifecycle and survival regressions for normal play.
var game
var checks := 0
var failures := 0
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func radius() -> float:
	return game.boat.global_position.distance_to(game.arena_center())

func stage(offset: Vector2, bearing: float) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.boat.global_position = game.arena_center() + Vector3(offset.x, 0, offset.y)
	game.heading = bearing
	game.boat.rotation.y = -bearing

func sail(seconds: float, hz: int, steering: float = 0.0, resist := false) -> Dictionary:
	var maximum := radius()
	var turn := 0.0
	var max_step := 0.0
	var longest_stop := 0
	var stop := 0
	for frame in roundi(seconds * hz):
		var before: float = game.heading
		var at: Vector3 = game.boat.position
		var rudder := steering
		if resist:
			var offset: Vector3 = game.boat.position - game.arena_center()
			rudder = clampf(wrapf(atan2(offset.x, -offset.z) - game.heading, -PI, PI) * 4.0, -1.0, 1.0)
		game.advance_sailing(1.0 / hz, rudder)
		maximum = maxf(maximum, radius())
		turn = maxf(turn, absf(wrapf(game.heading - before, -PI, PI)))
		max_step = maxf(max_step, at.distance_to(game.boat.position))
		stop = stop + 1 if game.actual_speed < 0.1 else 0
		longest_stop = maxi(longest_stop, stop)
	var result := {"hz": hz, "max_radius": maximum, "max_turn": turn,
		"max_step": max_step, "longest_stop": float(longest_stop) / hz, "hits": game.hits_taken}
	measurements.append(result)
	return result

func route(points: Array) -> bool:
	for point in points:
		var goal: Vector3 = game.arena_center() + Vector3(point.x, 0, point.y)
		var reached := false
		for frame in 1600:
			var delta: Vector3 = goal - game.boat.position
			if delta.length() < 5.0:
				reached = true
				break
			var error: float = wrapf(atan2(delta.x, -delta.z) - game.heading, -PI, PI)
			action("steer_port", error < -0.025)
			action("steer_starboard", error > 0.025)
			game._physics_process(1.0 / 60.0)
		if not reached or game.hits_taken > 0:
			print("ROUTE BLOCKED: goal=%s at=%s hits=%d" % [point, game.boat.position-game.arena_center(),game.hits_taken])
			return false
	action("steer_port", false)
	action("steer_starboard", false)
	return true

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	var spawn: Transform3D = game.archipelago.get_node("SpawnPoints/ArenaSpawn").global_transform
	check(game.arena_mode and game.arena_radius == 170.0 and radius() >= 60 and radius() <= 80,
		"normal arena is 170 m; initial spawn is 60–80 m from the central lighthouse")
	check(game.boat.global_position.is_equal_approx(spawn.origin) and (-game.boat.global_basis.z).dot(-spawn.basis.z) > 0.999,
		"player uses the editable spawn position and combat heading")
	check(game.beacon.visible and game.beacon_seen and game.obstacles.size() == 10,
		"lit atmospheric lighthouse and ten authored obstacle pieces; no distant voyage hazards")
	check(game.archipelago.water_clear(game.boat.position, 10), "spawn has safe water around the entire six-metre boat")
	game.hud._process(0)
	check(game.hud.menu_kicker.text == "FIVE WAVES AT SEA", "introduction states survival rather than lighthouse defence")
	var terrain = game.archipelago.get_node("Terrain")
	check(terrain.terrain_height_at(Vector3.ZERO) < -10 and terrain.terrain_height_at(game.arena_center()) > 17,
		"distant voyage terrain removed; lighthouse foundation retained")
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	sail(12, 60)
	check(game.hits_taken == 0 and game.state == game.State.SAILING, "initial combat course sails 75 m without unavoidable collision")
	# All important gaps within each rocky cluster exceed 30 m, using authored
	# normalized mesh footprints; additionally sweep a 30 m diameter clearance.
	for name in ["JaggedReef", "LowIslets"]:
		var markers: Array[Node] = game.archipelago.arena_layout.get_node("Obstacles/" + name).get_children()
		for i in range(markers.size()-1):
			var a: Marker3D = markers[i]
			var b: Marker3D = markers[i+1]
			var gap: float = a.position.distance_to(b.position) - a.get_meta("radius") - b.get_meta("radius")
			var middle := (a.global_position+b.global_position)*0.5
			var along := (b.global_position-a.global_position).normalized()
			var cross := Vector3(-along.z, 0, along.x)
			check(gap >= 30 and game.archipelago.sailing_lane_clear(middle-cross*7, cross, 14, 15),
				"%s gap %d: >=30 m clear passage confirmed by physical sweep" % [name,i])
	for sector in game.archipelago.arena_layout.get_node("EnemySectors").get_children():
		check(game.archipelago.water_clear(sector.global_position,12), "%s enemy sector has 12 m solid-obstacle clearance" % sector.name)
	# Both sides of each major cluster; steering uses real held A/D actions.
	var paths := [
		[Vector2(-65,-90),Vector2(-65,-40),Vector2(-70,30),Vector2(-45,95)],
		[Vector2(-126,-45),Vector2(-130,5),Vector2(-120,55),Vector2(-92,90)],
		[Vector2(65,10),Vector2(65,45),Vector2(45,80),Vector2(25,95)],
		[Vector2(113,15),Vector2(116,48),Vector2(100,82),Vector2(70,98)],
		[Vector2(-32,-72),Vector2(15,-70),Vector2(52,-65)],
		[Vector2(-35,-126),Vector2(15,-128),Vector2(65,-112),Vector2(100,-85)]]
	var starts := [Vector2(-65,-115),Vector2(-123,-75),Vector2(65,-15),Vector2(113,-10),Vector2(-57,-72),Vector2(-60,-120)]
	for i in paths.size():
		var bearing: float = PI if i < 4 else PI/2
		stage(starts[i],bearing)
		await physics_frame
		check(route(paths[i]), "held steering completes cluster %d route %d without collision" % [i/2,i%2])
		await process_frame
	stage(Vector2(0,-126),PI/2)
	await physics_frame
	var circle: Array[Vector2] = []
	for i in range(1,49):
		var a := i*TAU/48.0
		circle.append(Vector2(sin(a),-cos(a))*126.0)
	check(route(circle), "full arena circumnavigation with input; no reef contact or boundary trap")
	for hz in [30,60,120]:
		for sector in range(8):
			var bearing := sector*TAU/8
			stage(Vector2(sin(bearing),-cos(bearing))*136, bearing)
			await physics_frame
			var result := sail(28,hz)
			check(result.max_radius <= 170.001 and radius() < 150 and game.hits_taken == 0 and result.longest_stop < 0.3,
				"%d Hz sector %d: automatic curve stays clear of rocks and contains ship" % [hz,sector])
			check(result.max_turn < 1.3/hz and result.max_step < 11.0/hz,
				"%d Hz sector %d: no heading snap or position teleport" % [hz,sector])
		stage(Vector2(169.95,0),PI/2)
		await physics_frame
		game.wave_sailing.drift = Vector2(3.6,1.2)
		for crest in 4:
			game.ocean.wave_field.add_wave(Vector2(420+crest*5,250),Vector2.RIGHT,2,4.8,52,8,0,14)
		var result := sail(16,hz,0,true)
		check(result.max_radius <= 170.001 and game.wave_sailing.drift.is_finite() and game.hits_taken == 0,
			"%d Hz maximum crests, drift and outward-seeking helm stay contained" % hz)
		await process_frame
	stage(Vector2(169.99,0),PI/4)
	await physics_frame
	game.wave_sailing.drift=Vector2(2,-1)
	game.advance_sailing(1.0/60,0)
	var radial: Vector3 = (game.boat.position-game.arena_center()).normalized()
	check(radius()<=170.001 and game.boat.velocity.dot(radial)<=0.001
		and game.wave_sailing.drift.dot(Vector2(radial.x,radial.z))<=0.001 and game.actual_speed>3,
		"hard limit removes outward velocity and drift while preserving tangible forward/tangent motion")
	var at: Vector3 = game.boat.position
	game.advance_sailing(2.0,0)
	check(radius()<=170.001 and at.distance_to(game.boat.position)<20 and game.hits_taken==0,
		"stalled two-second frame is substepped without edge escape, snapping or obstacle impact")
	stage(Vector2(75,0),0)
	await physics_frame
	var before: float = game.heading
	sail(2,60)
	check(not game.arena_return.active and absf(game.heading-before)<0.0001, "no automatic helm correction without the outer trigger")
	stage(Vector2(150,0),-PI/2)
	await physics_frame
	sail(2,60)
	check(not game.arena_return.active and radius()<140, "inward-facing helm remains responsive in warning zone")
	stage(Vector2(136,0),PI/2)
	await physics_frame
	action("watch_starboard",true)
	action("steer_port",true)
	var contained := true
	for frame in 720:
		game._physics_process(1.0/60)
		contained = contained and radius()<=170.001
	check(game.cannon.aiming and game.turn_input==0 and contained and radius()<150 and game.hits_taken==0,
		"holding E and A cannot bypass return; gun camera follows the physical hull")
	action("fire_starboard",true)
	game._physics_process(1.0/60)
	check(game.cannon.shots_fired==1 and game.cannon.projectiles.size()==1, "fresh F still fires during the return turn")
	check(game.cannon.projectiles[0].velocity.normalized().dot(game.cannon.aimed_direction())>0.99, "cannon shot follows the actual barrel")
	action("watch_starboard",false)
	action("fire_starboard",false)
	game._physics_process(1.0/60)
	check(game.turn_input==-1 and not game.cannon.aiming, "release E immediately restores held steering")
	action("steer_port",false)
	stage(Vector2(-15,-67),0)
	await physics_frame
	game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
	game.voyage.set_target(game)
	game.voyage.update_progress(game)
	check(game.state==game.State.SAILING, "old destination victory remains disabled")
	stage(Vector2(-110,-45),PI)
	await physics_frame
	sail(6,60)
	check(game.hits_taken>0 and game.boat.position.z<game.arena_center().z-10, "no steering into the reef causes a real visible-rock collision; cannot pass through")
	await _cannon_checks()
	await _enemy_checks()
	game.restart()
	await physics_frame
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.take_damage(1,"recovery test")
	sail(8.1,60)
	check(game.hull==game.hull_capacity, "post-combat hull repair remains available")
	game.damage_immunity=0
	game.take_damage(3,"loss test")
	check(game.state==game.State.LOST, "normal hull damage still causes defeat")
	action("restart_crossing",true)
	await process_frame
	action("restart_crossing",false)
	await physics_frame
	check(game.state==game.State.CASTING_OFF and game.boat.global_position.is_equal_approx(spawn.origin)
		and game.hull==3 and game.cannon.projectiles.is_empty() and game.enemy_encounters.wave_number==0
		and game.ocean.wave_field.waves.is_empty() and not game.arena_return.active
		and game.obstacles.size()==10 and game.ocean.floating_visuals.size()==3,
		"retry restores spawn, obstacles, clean waves/projectiles and survival progress without duplicate floats")
	var file := FileAccess.open("/tmp/latitude-arena-revision/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":measurements},"\t"))
	print("ARENA CHECK: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _cannon_checks() -> void:
	# Actual segment integration against the authored mesh colliders. The fixture
	# stages a projectile, rather than faking an impact or destroying the target.
	for obstacle in game.obstacles:
		var body: StaticBody3D = obstacle.body
		if obstacle.kind == "rock" and body.get_meta("arena_marker", "") not in ["WestTooth","MiddleIslet"]:
			continue
		for hostile in [false,true]:
			if body.get_meta("destroyed",false):
				body.visible=true
				body.collision_layer=1
				body.set_meta("destroyed",false)
			await physics_frame
			var start: Vector3 = body.position + Vector3(-14, 1.0-body.position.y, -3.0 if obstacle.kind=="wreck" else 0.0)
			var ray := PhysicsRayQueryParameters3D.create(start, start+Vector3(28,0,0), 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider == body, "visible %s waterline is the first solid on the projectile lane" % body.name)
			var mesh: MeshInstance3D = game._box(game,Vector3.ONE*0.2,start,game._material(Color.WHITE))
			if hostile:
				game.enemy_encounters.ship.projectiles.append({"node":mesh,"position":start,"velocity":Vector3(40,0,0),"ttl":2.0})
			else:
				game.cannon.projectiles.append({"node":mesh,"physics_position":start,"velocity":Vector3(40,0,0),"ttl":2.0,"trail_clock":0.0})
			for tick in 60:
				if hostile:
					game.enemy_encounters.ship._advance_shots(1.0/60)
				else:
					game.cannon.advance(1.0/60)
			var destroyed: bool = body.get_meta("destroyed",false)
			check(destroyed == (obstacle.kind in ["debris","barrels"]),
				"%s shot: %s %s" % ["enemy" if hostile else "player",body.name,"shatters" if destroyed else "remains solid"])
			check((game.enemy_encounters.ship.projectiles if hostile else game.cannon.projectiles).is_empty(), "shot is stopped by obstacle/water without tunnelling")
	game.cannon.reset()
	# No shot means no destruction.
	game.restart()
	await physics_frame
	check(game.obstacles.all(func(o): return not o.body.get_meta("destroyed")), "retry rebuilds destructible props; no-shot control leaves all intact")

func _enemy_checks() -> void:
	stage(Vector2(0,-75),PI/2)
	await physics_frame
	var enemies = game.enemy_encounters
	var ship = enemies.ship
	enemies.enabled=true
	# Spawn sectors are rotated and each choice must pass live physical clearance.
	for index in 4:
		enemies.sector_index=index
		var at: Vector3 = enemies.arena_spawn()
		check(at.is_finite() and at.distance_to(game.boat.position)>=65 and game.archipelago.water_clear(at,12), "sector %d selects a separated clear-water spawn" % index)
	var sectors: Array[Node] = game.archipelago.arena_layout.get_node("EnemySectors").get_children()
	var positions: Array[Vector3] = []
	for sector in sectors:
		positions.append(sector.position)
		sector.global_position=game.arena_center()
	check(not enemies.arena_spawn().is_finite(), "all obstructed sectors defer spawn instead of using an unsafe fallback")
	for i in sectors.size():
		sectors[i].position=positions[i]
	# Do not allow elapsed time alone to clear a wave or despawn its target.
	for tick in 5400:
		enemies.update_encounters(1.0/60)
		game.sea_time+=1.0/60
	check(enemies.wave_number==1 and enemies.cleared_waves==0 and game.state==game.State.SAILING
		and ship.mode not in [ship.Mode.ESCAPED,ship.Mode.DISENGAGING], "90 seconds without firing cannot clear a wave or trigger retreat victory")
	# Exercise actual cutter navigation against each cluster from both approaches.
	for offset in [Vector2(-65,-90),Vector2(-130,20),Vector2(60,30),Vector2(120,70),Vector2(0,-135),Vector2(70,-70)]:
		ship.begin(game.arena_center()+Vector3(offset.x,0,offset.y))
		ship.heading=atan2(-offset.x,offset.y)
		ship.rotation.y=-ship.heading
		await physics_frame
		var max_radius := 0.0
		var stopped := 0
		var max_stopped := 0
		var shore_frames := 0
		for tick in 1800:
			game.sea_time+=1.0/60
			ship.update_ship(1.0/60)
			max_radius=maxf(max_radius,ship.position.distance_to(game.arena_center()))
			stopped=stopped+1 if ship.velocity.length()<0.7 else 0
			max_stopped=maxi(max_stopped,stopped)
			if game.archipelago.get_node("Terrain").terrain_height_at(ship.position)>-1:
				shore_frames+=1
		check(max_stopped<90 and max_radius<=165.001 and shore_frames==0,
			"cutter approach %s navigates solids without grounding, edge escape or prolonged stop" % offset)
		print("ENEMY NAV: start=%s max_radius=%.2f max_stop=%.2f shore=%d shots=%d" % [offset,max_radius,max_stopped/60.0,shore_frames,ship.shots_fired])
	# Real E/F input and ballistic flight must damage a cutter; no F must not.
	stage(Vector2(0,100),0)
	await physics_frame
	ship.begin(game.boat.position+Vector3(30,0,-2))
	await physics_frame
	action("watch_starboard",true)
	game._physics_process(1.0/60)
	ship.position=game.cannon.shot_origin()+game.cannon.aimed_direction()*28
	ship.position.y=0
	ship.rotation.y=-game.heading
	await physics_frame
	for tick in 30:
		game.cannon.advance(1.0/60)
	check(ship.hull==ship.hull_capacity, "aiming without F never damages the cutter")
	action("fire_starboard",true)
	game._physics_process(1.0/60)
	action("fire_starboard",false)
	for tick in 100:
		game.cannon.advance(1.0/60)
	check(ship.hull==ship.hull_capacity-1 and game.cannon.targets_hit==1, "real held E/fresh F launches a physical cannonball that damages the arena cutter")
	action("watch_starboard",false)
	# Restart for full five-wave state lifecycle; kill via the real cannon impact.
	stage(Vector2(0,-75),PI/2)
	await physics_frame
	enemies.enabled=true
	for wave in range(1,6):
		for tick in 700:
			enemies.update_encounters(1.0/60)
			if enemies.wave_in_progress:
				break
		check(enemies.wave_number==wave and enemies.wave_in_progress, "wave %d begins after clear-water intermission" % wave)
		while ship.hull>0:
			game.cannon._impact(ship,ship.position+Vector3.UP)
		for tick in 220:
			enemies.update_encounters(1.0/60)
		check(enemies.cleared_waves==wave and (game.state==game.State.ARRIVED)==(wave==5),
			"wave %d requires sunk cutter and finished sinking; only fifth awards survival" % wave)
	game.hud._process(0)
	check(game.hud.menu_title.text=="Waters clear.", "ending describes surviving all five waves")

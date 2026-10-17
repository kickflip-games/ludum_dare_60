extends SceneTree
## World authoring regression checks beyond the complete-voyage suite.
const Pilot = preload("res://tests/archipelago_pilot.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in range(30):
		await process_frame
	var terrain = game.archipelago.get_node("Terrain")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var spawn: Vector3 = game.archipelago.get_node("SpawnPoints/Departure").position
	# Compare all baked data, and every rendered vertex against the collision grid.
	var image: Image = load("res://game/world/archipelago_height.res")
	var image_heights := image.get_data().to_float32_array()
	check(image_heights == terrain.md, "R32F heightmap and full collision have identical samples")
	var vertices: PackedVector3Array = terrain.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var synchronized := true
	for vertex: Vector3 in vertices:
		var index := roundi(vertex.z + 128) * 257 + roundi(vertex.x + 128)
		if absf(vertex.y - terrain.md[index]) > 0.001:
			synchronized = false
			break
	check(synchronized, "every LiteTerrain mesh vertex matches the physical heightmap")
	var forward := Vector3(sin(game.START_HEADING), 0, -cos(game.START_HEADING))
	var right := Vector3(cos(game.START_HEADING), 0, sin(game.START_HEADING))
	var clear_helm := true
	for side: float in [-10.0, 0.0, 10.0]:
		for distance in range(0, 85, 4):
			clear_helm = clear_helm and terrain.terrain_height_at(spawn + forward * distance + right * side) < -3.0
	check(clear_helm, "opening helm has an 80m water corridor with 10m clearance on either side")
	for stage in range(3):
		game.voyage.stage = stage
		game.voyage.set_target(game)
		game.boat.position = spawn
		check(game.course_forward().dot((game.target-spawn).normalized()) > 0.999, "stage %d bearing is correct from the relocated departure" % stage)
	# Five cross-sections allow the real hull plus turning clearance on both routes.
	for alternate in [false, true]:
		var pilot := Pilot.new()
		pilot.alternate = alternate
		for stage in range(3):
			var previous := Vector2(spawn.x, spawn.z) if stage == 0 else Vector2(-230,-155) if stage == 1 else Vector2(226,-205)
			var safe := true
			for point: Vector2 in pilot.route(stage):
				var direction := (point - previous).normalized()
				var side := direction.orthogonal()
				for i in range(101):
					for width: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
						var at := previous.lerp(point, i/100.0) + side * width
						safe = safe and terrain.terrain_height_at(Vector3(at.x,0,at.y)) < -2.5
				previous = point
			check(safe, "route %s stage %d retains a 6m wide navigable corridor" % [alternate,stage])
	# Use the actual CharacterBody hull against several exposed terrain faces.
	for route: Vector4 in [Vector4(0,100,0,-70), Vector4(-160,-40,-55,-40), Vector4(140,10,270,10)]:
		var start := Transform3D(Basis.IDENTITY,Vector3(route.x,0,route.y))
		check(game.boat.test_move(start,Vector3(route.z-route.x,0,route.w-route.y)), "real boat hull cannot cross exposed shore from %s" % start.origin)
	var grounded := true
	var sampled := 0
	for z in range(-280, 290, 12):
		for x in range(-310, 320, 12):
			var height: float = terrain.terrain_height_at(Vector3(x,0,z))
			if height < 1.0:
				continue
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,height+6,z),Vector3(x,-4,z),1)
			grounded = grounded and not space.intersect_ray(query).is_empty()
			sampled += 1
	check(grounded and sampled > 150, "%d exposed terrain samples have physical collision" % sampled)
	var dressing = game.archipelago.get_node("IslandDressing")
	var outcrops := 0
	var colliding_outcrops := true
	for child in dressing.get_children(true):
		if child is not StaticBody3D:
			continue
		outcrops += 1
		var visual := child.get_child(0) as MeshInstance3D
		var collision := child.get_child(1) as CollisionShape3D
		colliding_outcrops = colliding_outcrops and collision.shape is ConvexPolygonShape3D and visual.scale.is_equal_approx(collision.scale)
		var center: Vector3 = child.global_position
		var query := PhysicsRayQueryParameters3D.create(center+Vector3.UP*16,center-Vector3.UP*3,1)
		var hit := space.intersect_ray(query)
		colliding_outcrops = colliding_outcrops and not hit.is_empty() and hit.collider == child
	check(outcrops > 0 and colliding_outcrops, "%d exposed rock outcrops have matching convex collision and physical ray hits" % outcrops)
	check(dressing.get_meta("tree_count") < 45 and dressing.get_meta("boulder_count") < 60 and dressing.get_meta("grass_count") < 120, "decoration remains sparse")
	var platform_supported := true
	for i in range(16):
		var at := Vector3(275,0,250) + Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*24
		platform_supported = platform_supported and terrain.terrain_height_at(at) > 16.5
	check(platform_supported, "lighthouse foundation is supported around its full perimeter")
	for patrol: Marker3D in game.archipelago.get_node("PiratePatrols").get_children():
		var at: Vector3 = patrol.get_meta("spawn")
		var safe := true
		for offset: Vector3 in [Vector3.ZERO, Vector3(5,0,0), Vector3(-5,0,0), Vector3(0,0,5), Vector3(0,0,-5)]:
			safe = safe and terrain.terrain_height_at(at+offset) < -3.0
		check(safe, "%s pirate spawn has a submerged hull footprint" % patrol.name)
	print("ISLAND COMPOSITION: %d checks, %d failures" % [checks, failures])
	game.free()
	quit(0 if failures == 0 else 1)

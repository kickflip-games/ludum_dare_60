extends SceneTree
## Real boat sweeps and reachable existing pickups; not a player-balance test.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + label)


func clear_boat(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.4
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3(0,0.4,-0.5))
	query.collision_mask = 1
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func pickup_positions(marker: Marker3D, radius: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for i in 24:
		var angle := i*TAU/24.0
		var at := marker.position+Vector3(sin(angle),0,cos(angle))*radius*0.72
		if game.archipelago.get_node("Terrain").terrain_height_at(at) < -2.5 and clear_boat(at):
			positions.append(at)
	return positions


func hits_prop(start: Vector3, finish: Vector3, expected: String) -> void:
	var collision := KinematicCollision3D.new()
	var hit: bool = game.boat.test_move(Transform3D(Basis.IDENTITY,start),finish-start,collision)
	var name_value := str(collision.get_collider().get_meta("hazard_name","")) if hit else "nothing"
	check(hit and name_value == expected,"real hull sweep stops at %s (hit %s)"%[expected,name_value])
	var escape: bool = not game.boat.test_move(Transform3D(Basis.IDENTITY,start), (start-finish).normalized()*8.0)
	check(escape,"open reverse escape beside %s"%expected)


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in 10:
		await process_frame
	await physics_frame
	game.state = game.State.SAILING
	var story = game.archipelago.story_landmarks
	check(story.get_meta("site_count") == 6,"three destinations and three existing optional sites are dressed")
	check(story.get_meta("batch_count") < 65,"static geometry remains within 65 per-material cluster batches")
	check(story.get_node("LighthouseStonework").is_visible_in_tree() and not game.beacon.visible,"tower silhouette precedes the existing beacon activation")
	check(story.warm_lights.size() <= 6,"only a few local lantern lights are added")
	var local_lights := true
	for light: OmniLight3D in story.warm_lights:
		local_lights = local_lights and light.omni_range <= 25.0 and not light.shadow_enabled
	check(local_lights,"lantern lights have bounded range and no new shadow maps")
	var counts := {"meshes":get_nodes_in_group("story_meshes").size(),"batches":story.get_meta("batch_count"),"lights":story.warm_lights.size()}
	print("LANDMARK BUDGET ",JSON.stringify(counts))
	# The existing route through the peaks retains a broad central corridor.
	var passage := true
	for x: float in [214,220,226,232,238]:
		for z in range(-146,-235,-3):
			passage = passage and clear_boat(Vector3(x,0,z))
	check(passage,"24-metre central passage retains full hull clearance")
	var rocks := get_nodes_in_group("story_rocks")
	check(rocks.size() >= 3,"a few embedded rock accents have dedicated collision")
	for body: StaticBody3D in rocks:
		var collision: CollisionShape3D = body.get_child(0)
		var shape := collision.shape as ConvexPolygonShape3D
		check(collision.transform == Transform3D.IDENTITY and shape.margin <= 0.02,"rock collision is baked in metres without scaled margins")
		var highest := Vector3(0,-INF,0)
		for point: Vector3 in shape.points:
			if point.y > highest.y:
				highest = point
		var world: Vector3 = body.to_global(Vector3(highest.x*0.95,highest.y,highest.z*0.95))
		var query := PhysicsRayQueryParameters3D.create(world+Vector3.UP,world-Vector3.UP*3.0,1)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == body,"exposed top of %s matches its convex collider"%body.get_parent().name)
	for marker: Marker3D in game.archipelago.get_node("NavigationRegions").get_children():
		var positions := pickup_positions(marker,marker.radius)
		check(positions.size() >= 4,"%s has multiple clear water approaches (%d sampled)"%[marker.name,positions.size()])
	for marker: Marker3D in game.archipelago.get_node("OptionalDiscoveries").get_children():
		var positions := pickup_positions(marker,19.0)
		check(positions.size() >= 4,"%s salvage has multiple clear water pickup positions (%d)"%[marker.name,positions.size()])
		if positions.is_empty():
			continue
		game.boat.position = positions[0]
		game.hull = 2
		game.archipelago.update_discoveries()
		check(game.hull == 3 and marker.name in game.archipelago.discoveries,"%s uses the existing hull-repair reward"%marker.name)
		game.hull = 2
		game.archipelago.update_discoveries()
		check(game.hull == 2,"%s reward remains once per voyage"%marker.name)
	hits_prop(Vector3(-230,0,-163),Vector3(-260,0,-163),"a wreck")
	hits_prop(Vector3(-196,0,122),Vector3(-210,0,122),"the moored fishing boat")
	hits_prop(Vector3(-80,0,-239),Vector3(-96,0,-239),"the drifting cargo")
	hits_prop(Vector3(259,0,214),Vector3(247,0,214),"the old jetty")
	# Floating scenery must survive the existing restart filter without duplicates.
	for repeat in 3:
		game.restart()
		await process_frame
		var retained := 0
		for item: Dictionary in game.ocean.floating_visuals:
			if is_instance_valid(item.visual) and item.visual.get_parent().get_meta("landmark",false):
				retained += 1
		check(retained == 7,"restart %d retains wreck, four scraps, skiff and cargo exactly once"%repeat)
		check(game.archipelago.discoveries.is_empty() and not game.beacon.visible,"restart %d resets salvage and beacon effects"%repeat)
	game.state = game.State.SAILING
	game.voyage.stage = 2
	game.voyage.set_target(game)
	game.boat.position = Vector3(350,0,40)
	game.advance_sailing(0.0,0.0)
	check(game.beacon.visible and game.beacon_seen,"existing final-stage distance gate activates the lighthouse")
	game.sea_time = 0.0
	story._process(0.0)
	var rotation_a: float = story.beam_pivot.rotation.y
	game.sea_time = 4.0
	story._process(0.0)
	check(is_equal_approx(story.beam_pivot.rotation.y-rotation_a,0.88),"beam sweeps smoothly at the authored rate")
	var beam: MeshInstance3D = story.beam_pivot.get_node("MainBeam")
	check(beam.mesh.get_faces().size() == 96 and beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"main beam is only 32 unshadowed triangles")
	# Floating visuals follow the same water samples as existing flotsam.
	var float_visual: Node3D = story.get_node("LanternCoveSkiff").get_child(0).get_node("FloatingSkiff")
	var before := float_visual.position.y
	game.ocean.update_surface(Vector3(-196,0,125),7.0,1.0,0.0,0.0)
	check(not is_equal_approx(float_visual.position.y,before),"moored skiff responds to the existing ocean sampler")
	print("LANDMARK CHECK: %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

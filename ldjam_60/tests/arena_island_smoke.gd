extends SceneTree
## Native renderer required: headless dummy MultiMeshes cannot return transforms.
## Baked scenery must match collision, ground its trees and leave combat water open.
const CENTRES := [Vector2(265, 15), Vector2(427, 82), Vector2(423, 421),
	Vector2(125, 431), Vector2(42, 236)]
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
	if DisplayServer.get_name() == "headless":
		push_error("Run arena_island_smoke with the native renderer to inspect MultiMesh transforms.")
		quit(1)
		return
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	var terrain = game.archipelago.get_node("Terrain")
	var dressing = game.archipelago.get_node("IslandDressing")
	var crowns: MultiMeshInstance3D = dressing.get_node("PineCrowns")
	var trees := crowns.multimesh
	var image: Image = load("res://game/world/arena_height.res")
	check(image.get_data().to_float32_array() == terrain.md,
		"arena height image and physical collision agree at every sample")
	var vertices: PackedVector3Array = terrain.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var synchronized := true
	var ring_clear := true
	for vertex in vertices:
		var index := roundi(vertex.z + 128) * 257 + roundi(vertex.x + 128)
		synchronized = synchronized and absf(vertex.y - terrain.md[index]) < 0.001
		var distance := Vector2(vertex.x * 4 - 275, vertex.z * 4 - 250).length()
		# Includes ten metres beyond the boundary for hull/camera clearance.
		if distance > 60 and distance <= 180:
			ring_clear = ring_clear and vertex.y < -10.0
	check(synchronized, "every rendered terrain vertex agrees with collision")
	check(ring_clear, "new shores leave the combat ring and ten-metre outer margin submerged")
	var foam: Image = load("res://game/ocean/arena_coastal_foam_mask.res")
	check(foam.get_meta("terrain_hash") == FileAccess.get_sha256("res://game/world/arena_mesh.res"),
		"shoreline foam was baked from the current arena terrain")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for centre in CENTRES:
		var at := Vector3(centre.x, 0, centre.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 100, at - Vector3.UP * 20, 1))
		check(not hit.is_empty() and hit.collider == terrain and hit.position.y > 10,
			"island %s has physical exposed terrain" % centre)
		var count := 0
		for i in trees.instance_count:
			var origin := trees.get_instance_transform(i).origin
			if Vector2(origin.x, origin.z).distance_to(centre) < 40:
				count += 1
		check(count >= 6, "island %s has a visible grove (%d pines)" % [centre, count])
	var grounded := true
	for i in trees.instance_count:
		var at := trees.get_instance_transform(i).origin
		grounded = grounded and absf(at.y + 0.35 - terrain.terrain_height_at(at)) < 0.01
	check(grounded and trees.instance_count < 90, "all %d pines are grounded and batched within the scenery budget" % trees.instance_count)
	for marker in game.archipelago.arena_layout.get_node("EnemySectors").get_children():
		check(game.archipelago.water_clear(marker.global_position, 12), "%s spawn remains clear" % marker.name)
	var before := trees.buffer.duplicate()
	game.restart()
	await physics_frame
	check(trees.buffer == before and dressing.get_node("PineCrowns") == crowns,
		"retry preserves scenery without duplicating or moving trees")
	game.free()
	await process_frame
	print("ARENA ISLANDS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

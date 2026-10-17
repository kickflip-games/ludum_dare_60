extends SceneTree
## Godot --headless --path ldjam_60 --script res://tests/pirate_kit_smoke.gd

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func bounds_of(node: Node, relative_to: Node3D) -> AABB:
	var result := AABB()
	var found: bool = false
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		pending.append_array(current.get_children())
		if current is MeshInstance3D:
			var transform: Transform3D = relative_to.global_transform.affine_inverse() * current.global_transform
			var box: AABB = transform * current.get_aabb()
			result = result.merge(box) if found else box
			found = true
	return result


func _run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	var ship: Node3D = game.find_child("SailBoatPlayer", true, false)
	var cannon: Node3D = game.find_child("PirateKitStarboardCannon", true, false)
	var rock: Node3D = game.find_child("PirateKitRock", true, false)
	check(ship != null and cannon != null and rock != null, "sailboat, cannon and rock models instantiate in the playable scene")
	var ship_bounds := bounds_of(ship, game.boat)
	check(ship_bounds.size.x > 2.5 and ship_bounds.size.x < 4.0 and ship_bounds.size.z > 5.0 and ship_bounds.size.z < 7.0,
		"ship visual scale and forward axis match the existing boat")
	var cannon_bounds := bounds_of(cannon, game.cannon)
	check(cannon_bounds.size.x > cannon_bounds.size.z and cannon_bounds.end.x > 1.0,
		"cannon model is aligned horizontally toward starboard")
	check(absf(game.cannon.muzzle.position.x - 1.22) < 0.001 and absf(game.cannon.muzzle.position.z) < 0.001,
		"visual replacement preserves the tested muzzle location")
	check(game.obstacles[0].body.collision_layer == 1 and game.obstacles[0].body.get_child(0) is CollisionShape3D,
		"rock visual keeps the original hazard collision")
	print("Imported ship bounds: %s; cannon bounds: %s" % [ship_bounds, cannon_bounds])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

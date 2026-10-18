extends SceneTree
## Exercise real sailing at the map edges, including waves and steering recovery.
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


func stage_at(position: Vector3, heading: float) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = position
	game.heading = heading


func inside_map() -> bool:
	return absf(game.boat.position.x) <= game.SAILING_LIMIT and absf(game.boat.position.z) <= game.SAILING_LIMIT and game.boat.position.y == 0.0


func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	var limit: float = game.SAILING_LIMIT
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
	for hz: int in [30, 60, 120]:
		for direction: Vector2 in directions:
			var outward := direction.normalized()
			var heading := atan2(outward.x, -outward.y)
			stage_at(Vector3(direction.x, 0, direction.y) * (limit - 0.2), heading)
			game.wave_sailing.drift = outward * 3.8
			var contained := true
			for frame in range(hz * 3):
				game.advance_sailing(1.0 / hz, 0.0)
				contained = contained and inside_map()
			check(contained and game.state == game.State.SAILING and game.hull == game.hull_capacity,
				"%s at %d Hz stays in the map without damage or loss" % [direction, hz])
			check(game.wave_sailing.drift.dot(outward) <= 0.0001 and game.boat.velocity.length() < 0.001,
				"%s at %d Hz stops outward momentum and reports stopped motion" % [direction, hz])
			# Use the actual rudder to leave the boundary, including corners.
			for frame in range(hz * 5):
				game.advance_sailing(1.0 / hz, 1.0)
				contained = contained and inside_map()
			check(contained and maxf(absf(game.boat.position.x), absf(game.boat.position.z)) < limit - 1.0,
				"%s at %d Hz can steer back into the map" % [direction, hz])
			await process_frame
	stage_at(Vector3(limit - 0.01, 0, 0), PI / 4.0)
	game.wave_sailing.drift = Vector2(2, 1)
	for frame in range(60):
		game.advance_sailing(1.0 / 60.0, 0.0)
	check(inside_map() and game.boat.position.z < -3.0 and game.wave_sailing.drift.x == 0.0 and game.wave_sailing.drift.y > 0.0,
		"edge preserves along-shore sailing and tangential wave drift")
	check(game.discovery_text.contains("turn back") and game.discovery_left > 0,
		"reaching open sea explains how to return")
	game.discovery_left = 1.0
	game.advance_sailing(1.0 / 60.0, 0.0)
	check(game.discovery_left == 1.0, "remaining at the edge does not restart the notice every tick")
	# Exercise following while sliding along the edge. The chase camera uses its
	# configured arm; the former close helm view's five-metre limit no longer applies.
	for frame in range(60):
		game.advance_sailing(1.0 / 60.0, 0.0)
		game._update_view(1.0 / 60.0)
	var hull_center: Vector3 = game.boat.position + Basis(Vector3.UP, -game.heading) * game.BoatWaveMotion.HULL_CENTER
	check(game._sailing_anchor.distance_to(hull_center) < 1.5,
		"sailing camera anchor follows the ship sliding along the boundary")
	var expected_camera: Transform3D = game._normal_sailing_pose(0.0)
	check(game.camera.position.distance_to(expected_camera.origin) < 0.25 and game.camera.position.is_finite(),
		"sailing camera keeps its configured chase pose with the bounded ship")
	# A visible moving crest pushes the ship into the same boundary.
	stage_at(Vector3(limit - 0.2, 0, 0), PI / 2.0)
	game.ocean.wave_field.add_wave(Vector2(limit - 24, 0), Vector2.RIGHT, 1.85, 4.8, 26, 8, 0, 8)
	var wave_contained := true
	for frame in range(480):
		game.advance_sailing(1.0 / 60.0, 0.0)
		wave_contained = wave_contained and inside_map()
	check(wave_contained and game.state == game.State.SAILING, "a full wave encounter cannot carry the ship off the map")
	stage_at(Vector3(limit - 0.01, 0, limit - 0.01), PI * 0.75)
	game.advance_sailing(2.0, 0.0)
	check(inside_map() and game.state == game.State.SAILING, "a long movement tick cannot skip the corner boundary")
	game.restart()
	check(not game._at_sailing_boundary and game.discovery_left == 0.0 and game.boat.velocity == Vector3.ZERO
		and game.boat.position.is_equal_approx(game.archipelago.get_node("SpawnPoints/Departure").position),
		"retry resets the boundary notice, motion and departure position")
	print("SAILING BOUNDS: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

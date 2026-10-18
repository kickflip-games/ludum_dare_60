extends "res://tests/arcade_controls_smoke.gd"
## Sample rays against real visual triangles, independent of collision/target layers.
func surfaces(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree():
		result.append(node)
	for child in node.get_children():
		surfaces(child, result)

func coverage() -> Vector2:
	var meshes: Array[MeshInstance3D] = []
	surfaces(game.boat_visual, meshes)
	var hits := 0
	var center_hits := 0
	for y in 9:
		for x in 16:
			var pixel := Vector2((x + 0.5) / 16, (y + 0.5) / 9) * root.get_visible_rect().size
			var start: Vector3 = game.camera.project_ray_origin(pixel)
			var finish: Vector3 = start + game.camera.project_ray_normal(pixel) * 30
			var blocked := false
			for instance in meshes:
				if instance.mesh == null:
					continue
				var local_start := instance.to_local(start)
				var local_end := instance.to_local(finish)
				if not instance.get_aabb().intersects_segment(local_start, local_end):
					continue
				var faces := instance.mesh.get_faces()
				for index in range(0, faces.size(), 3):
					if Geometry3D.segment_intersects_triangle(start, finish, instance.to_global(faces[index]), instance.to_global(faces[index + 1]), instance.to_global(faces[index + 2])) != null:
						blocked = true
						break
				if blocked:
					break
			if blocked:
				hits += 1
				if x in range(6, 10) and y in range(3, 5):
					center_hits += 1
	return Vector2(hits / 144.0, center_hits / 8.0)

func camera_check(label: String, close: bool) -> void:
	var at: Vector3 = game.camera.position
	check(game.camera.transform.is_finite() and absf(game.look_yaw) <= 45.001 and at.y >= game.ocean.height_at(Vector2(at.x, at.z)) + 1.19, label + ": finite, bounded and above sea")
	var occupied := coverage()
	check(occupied.x < 0.35 and (not close or occupied.y == 0), label + ": ship coverage %.1f%%, central coverage %.1f%%" % [occupied.x * 100, occupied.y * 100])

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	fresh()
	game.arena_cannon_view = true
	var offset: Vector3 = game.cannon_view_offset
	game.cannon_view_offset = Vector3(0.2, 0.8, -0.8)
	for i in 60: game._update_view(1.0 / 60)
	check(coverage().x > 0.1, "negative control detects obstructing original barrel framing")
	game.cannon_view_offset = offset
	for close in [false, true]:
		for yaw in [-45, 0, 45]:
			fresh()
			game.arena_cannon_view = close
			game.look_target = yaw
			game.look_idle = -10
			for i in 60: game._update_view(1.0 / 60)
			camera_check("%s yaw %d" % ["close" if close else "chase", yaw], close)
	# Stress cosmetic banking beyond the observed wave trim, at both look limits.
	for yaw in [-45, 45]:
		fresh()
		game.arena_cannon_view = true
		game.look_target = yaw
		game.look_idle = -10
		for i in 60: game._update_view(1.0 / 60)
		game.boat_visual.rotation.x = 0.35
		game.boat_visual.rotation.z = -0.4 if yaw < 0 else 0.4
		camera_check("large pitch/roll yaw %d" % yaw, true)
	for code in [KEY_A, KEY_D]:
		fresh()
		game.arena_cannon_view = true
		game.ocean.wave_field.add_wave(Vector2(game.boat.position.x, game.boat.position.z + 8), Vector2(0, -1), 2, 9, 45, 8, game.sea_time)
		key(code, true)
		key(KEY_SPACE, true)
		mouse(120)
		var start: Vector3 = game.boat.position
		step(1.1)
		game.damage_immunity = 0
		game.take_damage(1, "Presentation regression")
		step(0.05)
		camera_check("turn/wave/fire/damage %d" % code, true)
		check(game.boat.position.distance_to(start) > 5 and game.cannon.shots_fired == 1 and game.turn_input != 0 and game.cannon.aim_degrees == 0, "sailing, steering and fixed cannon remain independent")
	fresh()
	var sail: MeshInstance3D = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail")
	var imported = load("res://assets/sail_boat/sail_boat.glb").instantiate()
	var original: MeshInstance3D = imported.get_node("RootNode/Sail")
	check(sail.get_active_material(1) != original.get_active_material(1) and sail.get_active_material(1).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "player canvas is local and opaque")
	imported.free()
	for i in 20:
		key(KEY_E, true)
		key(KEY_E, false)
		step(1.0 / 60)
	check(not game.arena_cannon_view and sail.visible and game.player_pennant.visible, "rapid E toggles retain the full player silhouette")
	game.restart()
	check(not game.arena_cannon_view and game.aim_camera_blend == 0 and sail.visible, "retry restores chase without visibility overrides")
	var count: int = game.get_child_count()
	for i in 3:
		var ship = game.enemy_encounters.ships[i]
		ship.configure_archetype(load("res://game/enemies/%s.tres" % ["skiff", "cutter", "heavy"][i]))
		ship.begin(game.boat.position + Vector3(30 + i * 10, 0, 0))
		var mesh_id: int = ship.pennant.mesh.get_instance_id()
		ship.set_aim_highlight(false)
		var fill: float = ship.sail_material.emission_energy_multiplier
		ship.set_aim_highlight(true)
		check(ship.sail_material.emission_energy_multiplier > fill and ship.pennant.cloth.albedo_color == ship.archetype.pennant_color, "class %d highlight leaves hostile pennant unchanged" % i)
		ship.pennant.flutter(1.0)
		var pose: Transform3D = ship.pennant.transform
		ship.pennant.flutter(1.0)
		check(ship.pennant.transform == pose and ship.pennant.mesh.get_instance_id() == mesh_id and ship.pennant.get_child_count() == 0 and ship.pennant.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "class %d flutter is deterministic with one persistent cosmetic triangle" % i)
		ship.take_hit()
		check(ship.sail_material.emission_energy_multiplier > fill + 0.3, "class %d hit flash remains distinct" % i)
		ship.reset()
		ship.begin()
		check(ship.pennant.mesh.get_instance_id() == mesh_id and ship.pennant.get_parent() == ship.presentation, "class %d pool reuse keeps one pennant under sinking/rocking hierarchy" % i)
	check(game.get_child_count() == count, "presentation lifecycle adds no root nodes")
	game.queue_free()
	await process_frame
	print("SHIP READABILITY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

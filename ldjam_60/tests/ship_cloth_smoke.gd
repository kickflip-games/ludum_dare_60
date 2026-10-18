extends "res://tests/arcade_controls_smoke.gd"
## Real imported meshes, original transforms, visibility/reuse and hull isolation.
const Cloth = preload("res://game/ship_cloth_motion.gd")

func player_canvas() -> void:
	var sail: MeshInstance3D = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail")
	var cloth = sail.get_node("ClothMotion")
	cloth.set_process(false)
	var imported = game.PLAYER_SAIL_BOAT.instantiate()
	var original: MeshInstance3D = imported.get_node("RootNode/Sail")
	check(sail.mesh == original.mesh and sail.get_active_material(0) == original.get_active_material(0), "player retains original mesh and fixed mast/boom surface")
	check(cloth._parts.is_empty() and cloth._canvas == sail.get_active_material(1), "only the player's canvas surface receives sway")
	var pose := sail.transform
	var body_pose: Transform3D = game.boat.transform
	var pennant_pose: Transform3D = game.player_pennant.transform
	var peak := 0.0
	for frame in 300:
		cloth._process(1.0 / 60)
		peak = maxf(peak, absf(cloth._canvas.get_shader_parameter("sway_angle")))
	check(peak > deg_to_rad(1.5) and peak <= deg_to_rad(2.5), "player canvas sways visibly within the subtle angle limit")
	check(sail.transform.is_equal_approx(pose) and game.boat.transform.is_equal_approx(body_pose)
		and game.player_pennant.transform.is_equal_approx(pennant_pose), "canvas motion leaves mast assembly, physics and existing pennant untouched")
	cloth.sail_degrees = 0
	cloth._process(0)
	check(is_zero_approx(cloth._canvas.get_shader_parameter("sway_angle")), "zero amplitude restores the exact original canvas shape")
	cloth.sail_degrees = 2.5
	var material: ShaderMaterial = cloth._canvas
	game.restart()
	check(sail.get_node("ClothMotion") == cloth and sail.get_active_material(1) == material, "retry reuses the player's single sail component and material")
	cloth.set_process(true)
	imported.free()

func exercise(model: Node3D, sails: int, flags: int) -> void:
	var cloth = model.get_node("ClothMotion")
	cloth.set_process(false)
	check(cloth._parts.size() == sails + flags and cloth._flags.count(true) == flags, "%s: imported sail/flag nodes cached" % model.name)
	var model_pose := model.transform
	var hull: Node3D = model.get_child(0)
	var hull_pose := hull.transform
	var resource_mesh: Mesh = cloth._parts[0].mesh
	var resource_material: Material = cloth._parts[0].get_active_material(0)
	var moving := false
	for frame in 360:
		cloth._process(1.0 / 60)
		for i in cloth._parts.size():
			var part: Node3D = cloth._parts[i]
			var rest: Transform3D = cloth._rest[i]
			var angle: float = (rest.basis.inverse() * part.basis).get_euler().y
			moving = moving or absf(angle) > 0.015
			if not part.position.is_equal_approx(rest.origin) or absf(angle) > deg_to_rad(cloth.flag_degrees if cloth._flags[i] else cloth.sail_degrees) + 0.00001:
				check(false, "cloth stays on its mast axis and within amplitude")
	check(moving, "%s: visible movement across a complete sail cycle" % model.name)
	check(model.transform.is_equal_approx(model_pose) and hull.transform.is_equal_approx(hull_pose), "hull/model transforms untouched")
	check(cloth._parts[0].mesh == resource_mesh and cloth._parts[0].get_active_material(0) == resource_material, "original shared mesh and appearance retained")
	# Frame subdivision must not change the pose.
	cloth._time = 0
	for i in 30: cloth._process(1.0 / 30)
	var at_30: Transform3D = cloth._parts[0].transform
	cloth._time = 0
	for i in 120: cloth._process(1.0 / 120)
	check(at_30.is_equal_approx(cloth._parts[0].transform), "30/120 Hz agree")
	model.visible = false
	var hidden_time: float = cloth._time
	cloth._process(2)
	check(cloth._time == hidden_time, "hidden pooled ships skip cloth work")
	model.visible = true
	cloth._process(0.1)
	check(cloth._time > hidden_time, "reused visible ships resume smoothly")
	cloth.sail_degrees = 0
	cloth.flag_degrees = 0
	cloth._process(0)
	var restored := true
	for i in cloth._parts.size():
		restored = restored and cloth._parts[i].transform.is_equal_approx(cloth._rest[i])
	check(restored, "zero amplitude restores every exact imported local transform")
	cloth.sail_degrees = 2.5
	cloth.flag_degrees = 6

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	fresh()
	player_canvas()
	var first = game.enemy_encounters.ships[0]
	var second = game.enemy_encounters.ships[1]
	for ship in [first, second, game.enemy_encounters.boss]:
		ship.begin(game.boat.position + Vector3(28, 0, -12))
		var model: Node3D = ship.flagship_model if ship == game.enemy_encounters.boss else ship.ship_model
		var body_pose: Transform3D = ship.transform
		var collision_pose: Transform3D = ship.collision_shape.transform
		exercise(model, 2 if ship == game.enemy_encounters.boss else 1, 3 if ship == game.enemy_encounters.boss else 2)
		check(ship.transform.is_equal_approx(body_pose) and ship.collision_shape.transform.is_equal_approx(collision_pose), "physics and collision roots untouched")
		ship.heading = 0.7
		ship.rotation.y = -ship.heading
		game.ocean.wave_field.add_wave(Vector2(ship.position.x, ship.position.z), Vector2(0, -1), 2, 9, 45, 8, game.sea_time)
		ship.update_visuals(0.1)
		var cloth = model.get_node("ClothMotion")
		cloth._process(0.1)
		check(model.global_transform.is_finite() and cloth._parts[0].position.is_equal_approx(cloth._rest[0].origin), "turning/wave parent motion retains local attachment")
		ship.reset()
		ship.begin(game.boat.position + Vector3(28, 0, -12))
		check(model.get_node("ClothMotion") == cloth, "reset/relaunch reuses one cloth component")
	var a = first.ship_model.get_node("ClothMotion")
	var b = second.ship_model.get_node("ClothMotion")
	a._time = 0
	b._time = 0
	a._process(0.5)
	b._process(0.5)
	check(not a._parts[0].transform.is_equal_approx(b._parts[0].transform), "simultaneous enemies have independent phases")
	var combined := Node3D.new()
	root.add_child(combined)
	var inert := Cloth.new()
	combined.add_child(inert)
	check(not inert.is_processing() and inert._parts.is_empty(), "unsupported/combined model safely does nothing")
	combined.free()
	print("SHIP CLOTH: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

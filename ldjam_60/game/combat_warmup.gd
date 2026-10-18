extends Node
## Prime combat rendering from the menu, using clipped copies and isolated lights.
## No weapon methods, timers, audio or gameplay random stream are touched.
var complete := false
var elapsed_ms := 0.0

func prepare(game: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		complete = true
		return
	_warm.call_deferred(game)

func _warm(game: Node3D) -> void:
	# Let the existing menu/world present once before compiling combat variants.
	await RenderingServer.frame_post_draw
	var start := Time.get_ticks_usec()
	# Compile against the real viewport's formats/lighting variants. Geometry is
	# completely beyond its clip volume; private culling bounds admit the draw.
	# Lights affect only these copies, never the visible world.
	var camera: Camera3D = game.get_viewport().get_camera_3d()
	var old_mask := camera.cull_mask
	const WARM_LAYER := 1 << 19
	camera.cull_mask |= WARM_LAYER
	var stage := Node3D.new()
	add_child(stage)
	var anchor := camera.global_position - camera.global_basis.z * 10.0
	var clipped := camera.to_global(Vector3(10000,0,-10))
	var flash_light := OmniLight3D.new()
	flash_light.light_energy = 5.0
	flash_light.omni_range = 64.0
	flash_light.light_cull_mask = WARM_LAYER
	stage.add_child(flash_light)
	flash_light.global_position = anchor
	var lantern := OmniLight3D.new()
	lantern.omni_range = 64.0
	lantern.light_energy = game.lantern_energy
	lantern.light_cull_mask = WARM_LAYER
	stage.add_child(lantern)
	lantern.global_position = anchor
	# The muzzle light also selects variants on the player sail, deck and cannon.
	# Use their actual material resources, including surface overrides.
	var pool = game.cannon.projectile_visuals
	var samples: Array[MeshInstance3D] = []
	for material in [pool.friendly, pool.hostile]:
		var ball := MeshInstance3D.new()
		ball.mesh = pool.sphere
		ball.material_override = material
		samples.append(ball)
	var flame := MeshInstance3D.new()
	flame.mesh = game.combat_particles.flame_mesh()
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	samples.append(flame)
	for i in 2:
		var splash := MeshInstance3D.new()
		var source: MeshInstance3D = game.cannon.splash_pool[0][i].node
		splash.mesh = source.mesh
		splash.material_override = source.material_override
		splash.cast_shadow = source.cast_shadow
		samples.append(splash)
	if game.enemy_encounters.boss != null:
		var mine = game.enemy_encounters.boss.mine_pool.front()
		_collect(mine.model, mine.model.transform, samples)
		var ring := MeshInstance3D.new()
		ring.mesh = mine.ring.mesh
		# Private values: inactive mines remain untouched throughout warm-up.
		ring.material_override = mine.material.duplicate()
		ring.material_override.set_shader_parameter("strength",1.0)
		ring.cast_shadow = mine.ring.cast_shadow
		samples.append(ring)
		var warning := MeshInstance3D.new()
		warning.mesh = game.enemy_encounters.boss.warnings[0].mesh
		warning.material_override = game.enemy_encounters.boss.warnings[0].material_override
		warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		samples.append(warning)
	_collect(game.boat_visual, Transform3D.IDENTITY, samples)
	# Ordinary hull/atlas emission and gun materials were absent from the original
	# warm-up. Include their actual opaque overrides without spawning a ship.
	var ordinary = game.enemy_encounters.ships[0]
	_collect(ordinary.ship_model, Transform3D.IDENTITY, samples)
	_collect(ordinary._armament_pool[0].gun, Transform3D.IDENTITY, samples)
	# The first arrival also draws the enemy spray's own MultiMesh variant.
	var arrival := MultiMeshInstance3D.new()
	var arrival_batch := MultiMesh.new()
	arrival_batch.transform_format = MultiMesh.TRANSFORM_3D
	arrival_batch.use_custom_data = true
	arrival_batch.mesh = ordinary.sea_effects.pool.mesh
	arrival_batch.instance_count = 1
	arrival_batch.set_instance_transform(0, Transform3D.IDENTITY)
	arrival_batch.set_instance_custom_data(0, Color(1,1,1,0.7))
	arrival.multimesh = arrival_batch
	arrival.material_override = ordinary.sea_effects.spray.material_override
	arrival.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(arrival)
	arrival.layers = WARM_LAYER
	arrival.global_position = clipped
	arrival_batch.custom_aabb = AABB(arrival.to_local(anchor)-Vector3.ONE,Vector3.ONE*2)

	for i in samples.size():
		var sample := samples[i]
		stage.add_child(sample)
		sample.layers = WARM_LAYER
		sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sample.global_position = clipped
		sample.custom_aabb = AABB(sample.to_local(anchor)-Vector3.ONE,Vector3.ONE*2)
	var particles := MultiMeshInstance3D.new()
	# An empty/zero-sized batch does not exercise a live particle draw reliably.
	# Private instance data prevents touching the real pool or its random stream.
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = game.combat_particles.mesh.mesh
	batch.instance_count = 2
	for i in 2:
		batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(i*2,1,0)))
		batch.set_instance_color(i,Color(1,0.8,0.5,1))
		batch.set_instance_custom_data(i,Color(0,0,0,1 if i == 0 else -1))
	particles.multimesh = batch
	particles.material_override = game.combat_particles.material.duplicate()
	particles.material_override.set_shader_parameter("effect_time",0.1)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(particles)
	particles.layers = WARM_LAYER
	particles.global_position = clipped
	batch.custom_aabb = AABB(particles.to_local(anchor)-Vector3.ONE,Vector3.ONE*2)
	# Distant enemies/shots see zero local lights; the deck sees its lantern
	# and then the muzzle light. Prime all three Compatibility variants.
	flash_light.hide()
	lantern.hide()
	await RenderingServer.frame_post_draw
	lantern.show()
	await RenderingServer.frame_post_draw
	flash_light.show()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	camera.cull_mask = old_mask
	stage.queue_free()
	complete = true
	elapsed_ms = (Time.get_ticks_usec()-start)/1000.0
	print("COMBAT_WARMUP_MS ", elapsed_ms)

func _collect(node: Node3D, pose: Transform3D, samples: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var copy := MeshInstance3D.new()
		copy.mesh = node.mesh
		copy.transform = pose
		for i in node.mesh.get_surface_count():
			copy.set_surface_override_material(i,node.get_active_material(i))
		samples.append(copy)
	for child in node.get_children():
		if child is Node3D: _collect(child, pose*child.transform, samples)

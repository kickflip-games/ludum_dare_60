extends Node
## Render existing combat material paths in a tiny private world, never on screen.
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
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32,32)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = game.world_environment.environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	var flash_light := OmniLight3D.new()
	flash_light.light_energy = 5.0
	flash_light.omni_range = 7.0
	flash_light.position = Vector3(0,2,0)
	viewport.add_child(flash_light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	viewport.add_child(camera)
	camera.position = Vector3(0,12,18)
	camera.look_at(Vector3.ZERO)
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
	for i in samples.size():
		var sample := samples[i]
		viewport.add_child(sample)
		sample.position = Vector3((i%5-2)*4,0,(i/5)*4)
	var particles := MultiMeshInstance3D.new()
	particles.multimesh = game.combat_particles.mesh
	particles.material_override = game.combat_particles.material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(particles)
	# Two real draw opportunities include shader variants and their render passes.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
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

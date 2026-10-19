extends SceneTree
## Native alpha-coverage probe of the real canvas mesh/material, plus health/reset paths.
var game
var checks := 0
var failures := 0
var viewport: SubViewport
var material: ShaderMaterial
var last_pixels: Image

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func coverage() -> int:
	material.set_shader_parameter("damage_stage", game.boat_damage._canvas.get_shader_parameter("damage_stage"))
	for frame in 3: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	var pixels := viewport.get_texture().get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	last_pixels = pixels
	var count := 0
	for y in pixels.get_height():
		for x in pixels.get_width():
			if pixels.get_pixel(x, y).a > 0.5: count += 1
	return count

func tears_reach_edge(healthy: Image, damaged: Image) -> bool:
	# Flood the rendered background. Removed canvas must connect to the outside,
	# rather than form a new enclosed hole, regardless of how the shader cuts it.
	var width := damaged.get_width()
	var size := width * damaged.get_height()
	var before := healthy.get_data()
	var after := damaged.get_data()
	var visited := PackedByteArray()
	visited.resize(size)
	visited.fill(0)
	var queue := PackedInt32Array([0])
	visited[0] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var candidates := [index - width, index + width]
		if index % width > 0: candidates.append(index - 1)
		if index % width < width - 1: candidates.append(index + 1)
		for next: int in candidates:
			if next >= 0 and next < size and visited[next] == 0 and after[next * 4 + 3] < 128:
				visited[next] = 1
				queue.append(next)
	for index in size:
		if before[index * 4 + 3] >= 128 and after[index * 4 + 3] < 128 and visited[index] == 0:
			return false
	return true

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Sail damage coverage needs a native renderer")
		quit(1)
		return
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	var sail: MeshInstance3D = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail")
	var source_mesh: Mesh = sail.mesh
	var wood: Material = sail.get_active_material(0)
	var pose: Transform3D = game.boat.transform
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sail.mesh.surface_get_arrays(1))
	canvas.mesh = mesh
	canvas.scale = Vector3.ONE * 1000
	material = game.boat_damage._canvas.duplicate()
	material.set_shader_parameter("sway_angle", 0.0)
	canvas.material_override = material
	viewport.add_child(canvas)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(10, -0.7, 3.5)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, -0.7, 3.5), Vector3(0, 0, 1))
	camera.current = true
	var healthy: int = await coverage()
	var healthy_pixels := last_pixels
	check(healthy > 10000, "healthy canvas renders solid coverage")
	game.take_damage(1, "sail damage fixture")
	check(game.boat_damage._canvas.get_shader_parameter("damage_stage") == 1, "first hit selects damaged cloth immediately")
	var damaged: int = await coverage()
	check(tears_reach_edge(healthy_pixels, last_pixels), "damaged sail tears open onto an edge without isolated holes")
	check(damaged < healthy * 0.99 and damaged > healthy * 0.75, "damaged sail has real cutouts while retaining most canvas")
	check(not game.take_damage(1, "immune") and await coverage() == damaged, "immune contact cannot deepen tears")
	game.damage_immunity = 0
	game.take_damage(1, "critical sail fixture")
	check(game.boat_damage._canvas.get_shader_parameter("damage_stage") == 2, "second accepted hit selects critical cloth")
	var critical: int = await coverage()
	check(tears_reach_edge(healthy_pixels, last_pixels), "critical sail tears open onto an edge without isolated holes")
	check(critical < damaged * 0.92 and critical > healthy * 0.45, "critical sail has substantially more missing cloth without disappearing")
	game.restore_hull(1)
	check(await coverage() == damaged, "partial repair restores the exact damaged-cloth silhouette")
	game.restore_hull(1)
	check(await coverage() == healthy, "full repair restores the exact healthy-cloth silhouette")
	game.damage_immunity = 0
	game.take_damage(2, "retry fixture")
	game.restart()
	check(await coverage() == healthy, "restart clears all sail tears and fraying")
	check(sail.mesh == source_mesh and sail.get_active_material(0) == wood and game.boat.transform == pose, "canvas damage leaves original mesh, mast/boom and physical boat unchanged")
	print("SAIL COVERAGE: healthy=%d damaged=%d critical=%d" % [healthy, damaged, critical])
	viewport.queue_free()
	var clean := await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	check(clean, "shutdown releases all audio playbacks")
	print("SAIL DAMAGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

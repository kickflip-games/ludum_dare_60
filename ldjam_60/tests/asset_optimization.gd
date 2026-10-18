extends Node
## Frozen, identical native/Web fleet fixture. ?variant=before selects source mines.
var variant := "after"
var output := "/tmp/blackwater-assets"
var frames: Array[float] = []
var cpu: Array[float] = []
var ticks := 0
var last := 0
var game
var camera: Camera3D
var result := {}
var asset_instances := {}
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if OS.has_feature("web"):
		variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('variant') || 'after'")
	seed(60)
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.restart()
	game.state = game.State.SAILING
	game.hud.hide()
	var center: Vector3 = game.arena_center() + Vector3(0, 0, 85)
	game.boat.position = center + Vector3(-18, 0, 12)
	var boss = game.enemy_encounters.boss
	boss.begin(center)
	boss.rotation.y = 0
	for i in 2:
		var ship = game.enemy_encounters.ships[i]
		ship.configure_archetype(load("res://game/enemies/%s.tres" % ["cutter", "skiff"][i]))
		ship.begin(center + Vector3(-18 if i == 0 else 18, 0, -7))
		ship.rotation.y = 0
	for vessel in game.enemy_encounters.combat_ships():
		if vessel.visible:
			vessel.sea_effects.advance_arrival(1)
			vessel.sea_effects.apply_arrival()
	for i in 6:
		var mine = load("res://game/boss_mine.tscn").instantiate()
		mine.game = game
		game.add_child(mine)
		mine.position = center + Vector3((i % 3 - 1) * 14, 0, 20 + (i / 3) * 13)
		mine.model.free()
		var path := "res://assets/boss_mine/spike_mine.glb" if variant == "before" else "res://assets/optimized/spike_mine.glb"
		mine.model = load(path).instantiate()
		mine.model.scale = Vector3.ONE * 16
		mine.add_child(mine.model)
		mine.age = 2
		mine.update_visuals()
		boss.mines.append(mine)
	_count_assets(game)
	print("ASSET_INSTANCES " + JSON.stringify(asset_instances))
	_freeze(game)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = center + Vector3(52, 58, 72)
	camera.look_at(center + Vector3(0, 0, 7))
	camera.fov = 58
	camera.current = true
	last = Time.get_ticks_usec()

func _count_assets(node: Node) -> void:
	if node.is_queued_for_deletion(): return
	if node is Node3D and node.is_visible_in_tree() and node.scene_file_path.ends_with(".glb"):
		asset_instances[node.scene_file_path] = asset_instances.get(node.scene_file_path, 0) + 1
	for child in node.get_children(): _count_assets(child)

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): _freeze(child)

func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * fraction))]

func _process(_delta: float) -> void:
	if camera == null: return
	var now := Time.get_ticks_usec()
	ticks += 1
	if ticks > 180:
		frames.append((now - last) / 1000.0)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	last = now
	if ticks != 480: return
	set_process(false)
	result = {"variant":variant, "asset_instances":asset_instances, "viewport":str(get_viewport().get_visible_rect().size), "renderer":RenderingServer.get_current_rendering_method(), "frames":frames.size(),
		"frame_ms_p50":percentile(frames, 0.5), "frame_ms_p95":percentile(frames, 0.95), "frame_ms_p99":percentile(frames, 0.99),
		"cpu_ms_p50":percentile(cpu, 0.5), "cpu_ms_p95":percentile(cpu, 0.95),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
	print("ASSET_BENCHMARK " + JSON.stringify(result))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.assetBenchmark = " + JSON.stringify(result))
		return
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join(variant + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	await get_tree().process_frame
	RenderingServer.force_draw(true, 0.0)
	get_viewport().get_texture().get_image().save_png(output.path_join(variant + ".png"))
	# Matching close-up from the same direction, then reverse side to inspect normals.
	var mine = game.enemy_encounters.boss.mines[1]
	for side in [-1, 1]:
		camera.position = mine.model.global_position + Vector3(side * 3.5, 2.5, side * 4.5)
		camera.look_at(mine.model.global_position)
		await get_tree().process_frame
		RenderingServer.force_draw(true, 0.0)
		get_viewport().get_texture().get_image().save_png(output.path_join(variant + "-mine-%d.png" % side))
	get_tree().quit()

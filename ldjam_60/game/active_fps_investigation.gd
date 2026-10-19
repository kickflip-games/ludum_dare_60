extends Node
## Opt-in A/B in crossing.tscn, using wall time and the real callbacks/rendering.
## Every case restarts the same seeded wave-two scenario. Temporary interventions
## are restored even on focus loss/cancel; no changes are saved to preferences.
const Metrics = preload("res://game/active_frame_metrics.gd")
const Diagnostics = preload("res://game/live_diagnostics.gd")
const CASES := ["legacy_guide", "legacy_downward_camera", "legacy_frozen_simulation", "baseline", "downward_camera", "frozen_simulation", "clouds_off", "static_sky", "flat_ocean", "ocean_64", "terrain_hidden", "baseline_unprofiled", "baseline_repeat", "paused", "lost", "ready"]
const WARMUP := 3.0
const SECONDS := 6.0
const MAX_CASE_SECONDS := 18.0
const ROW_LIMIT := 1200
var game
var running := false
var case_name := ""
var results: Array = []
var rows: Array = []
var case_index := -1
var started := 0
var measured := 0
var previous := 0
var previous_physics := 0
var previous_draw := 0
var _physics_mode := Node.PROCESS_MODE_INHERIT
var _sky: Material
var _near: Material
var _far: Material
var _cells := 192
var _hidden: Array = []
var _frozen := false
var _output := ""
var label: Label
var _browser_callback: JavaScriptObject
var _guide: MeshInstance3D
var _legacy: MeshInstance3D
var _window_settings: Array = []
var cases: Array = CASES.duplicate()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	var layer := CanvasLayer.new()
	layer.layer = 91
	add_child(layer)
	label = Label.new()
	label.position = Vector2(12, 42)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	layer.add_child(label)
	if OS.has_feature("web"):
		_select_cases(JavaScriptBridge.get_interface("BlackwaterRuntime").investigationCases())
		_browser_callback = JavaScriptBridge.create_callback(func(_args): start())
		JavaScriptBridge.get_interface("BlackwaterRuntime").installInvestigation(_browser_callback)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--active-fps-cases="): _select_cases(arg.get_slice("=", 1))
		if arg.begins_with("--active-fps-output="): _output = arg.get_slice("=", 1)
		if arg == "--active-fps": start.call_deferred()

func _select_cases(value: String) -> void:
	if value.is_empty(): return
	var selected: Array = []
	for entry in value.split(","):
		if entry not in CASES or entry in selected: return
		selected.append(entry)
	if not selected.is_empty(): cases = selected

func start() -> void:
	if running: return
	results.clear()
	case_index = -1
	running = true
	var window := get_window()
	_window_settings = [window.content_scale_size, window.content_scale_mode, window.content_scale_aspect]
	game.diagnostics._apply_web_resolution(1)
	game.diagnostics.close_panel()
	# Starting is an explicit user action. Consume the canvas blur/focus pair
	# caused by clicking the diagnostic button before explicitly resuming.
	game.diagnostics.poll_lifecycle()
	game.diagnostics.set_enabled(true)
	_next_case()

func _restore() -> void:
	Metrics.enabled = false
	Metrics.take()
	if is_instance_valid(_legacy):
		_legacy.visible = false
		_legacy.queue_free()
		game.cannon.cone_visual = _guide
		_legacy = null
	game.process_mode = _physics_mode
	_frozen = false
	if _sky != null:
		game.world_environment.environment.sky.sky_material = _sky
	game.sky_material.set_shader_parameter("diagnostic_clouds_off", false)
	if is_instance_valid(game.ocean):
		game.ocean.near_mesh.material_override = _near if _near != null else game.ocean.material
		game.ocean.distant_mesh.material_override = _far if _far != null else game.ocean.material
		if game.ocean.cells != _cells:
			game.ocean._build_geometry(_cells)
			game.ocean._sync_settings()
	for item in _hidden:
		if is_instance_valid(item[0]): item[0].visible = item[1]
	_hidden.clear()

func cancel(reason: String) -> void:
	if not running: return
	if measured > 0: _finish_case(reason)
	_restore()
	running = false
	case_name = ""
	game.set_paused(true)
	_restore_window()
	label.text = "A/B stopped: " + reason + " · Export Diagnostics retains completed cases"
	_publish()

func _next_case() -> void:
	if case_index >= 0: _restore()
	case_index += 1
	if case_index == cases.size():
		running = false
		case_name = ""
		game.restart(true)
		_restore_window()
		label.text = "A/B complete · F8 → Export Diagnostics"
		_publish()
		return
	case_name = cases[case_index]
	game.set_paused(false, false)
	# Reset through READY, then enter the diagnostic sailing scenario directly;
	# automated cases do not request pointer capture from a sandboxed iframe.
	game.restart(true)
	game.state = game.State.SAILING
	game.transition_elapsed = game.CAST_OFF_SECONDS
	game.enemy_encounters.resume_wave(2)
	# Protection is diagnostic-only, identical in every sailing case. All damage
	# tests, AI, hit queries, collisions, trajectories and waves still execute.
	game.damage_immunity = 1000.0
	_physics_mode = game.process_mode
	_sky = game.world_environment.environment.sky.sky_material
	_near = game.ocean.near_mesh.material_override
	_far = game.ocean.distant_mesh.material_override
	_cells = game.ocean.cells
	if case_name.begins_with("legacy_"):
		_guide = game.cannon.cone_visual
		_guide.visible = false
		_legacy = preload("res://game/diagnostic_firing_cone.gd").new()
		_legacy.cannon = game.cannon
		game.add_child(_legacy)
		game.cannon.cone_visual = _legacy
	if case_name == "clouds_off": game.sky_material.set_shader_parameter("diagnostic_clouds_off", true)
	if case_name == "static_sky":
		var simple := ShaderMaterial.new()
		simple.shader = preload("res://game/diagnostic_night.gdshader")
		game.world_environment.environment.sky.sky_material = simple
	if case_name == "flat_ocean":
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_color = Color("0c244a")
		game.ocean.near_mesh.material_override = flat
		game.ocean.distant_mesh.material_override = flat
	if case_name == "ocean_64":
		game.ocean._build_geometry(64)
		game.ocean._sync_settings()
	if case_name == "terrain_hidden":
		for branch in [game.archipelago.get_node("Terrain"), game.archipelago.get_node("IslandDressing")]:
			for node in branch.find_children("*", "GeometryInstance3D", true, false):
				_hidden.append([node, node.visible])
				node.visible = false
	if case_name == "lost": game.begin_result(false)
	if case_name == "ready": game.restart(true)
	started = Time.get_ticks_usec()
	measured = 0
	previous = 0
	rows.clear()
	Metrics.take()
	Metrics.enabled = case_name != "baseline_unprofiled"
	label.visible = true
	_publish_progress()

func after_view() -> void:
	if not running: return
	if case_name in ["downward_camera", "legacy_downward_camera"]:
		# The loss camera's final pose, without begin_result/stop/reset calls.
		var at: Vector3 = game.boat.position + Basis(Vector3.UP, -game.heading) * Vector3(9, 6, 12)
		var focus: Vector3 = game.boat.position + Vector3.UP * 1.5
		game.camera.transform = Transform3D(Basis.looking_at(focus - at), at)
		game.camera.h_offset = 0.0

func _process(_delta: float) -> void:
	if not running: return
	if not game._window_focused or (game.paused and case_name != "paused"):
		cancel("focus/pause interrupted the comparison")
		return
	var now := Time.get_ticks_usec()
	if measured == 0:
		if now - started < WARMUP * 1000000: return
		measured = now
		previous = now
		previous_physics = Engine.get_physics_frames()
		previous_draw = Engine.get_frames_drawn()
		Metrics.take()
		if case_name in ["frozen_simulation", "legacy_frozen_simulation"]:
			_frozen = true
			game.process_mode = Node.PROCESS_MODE_DISABLED
		if case_name == "paused": game.set_paused(true)
		return
	var physics := Engine.get_physics_frames()
	var draw := Engine.get_frames_drawn()
	var timing := Metrics.take()
	if rows.size() < ROW_LIMIT:
		rows.append({"t_ms": now / 1000.0, "interval_ms": (now - previous) / 1000.0,
			"physics_ticks": physics - previous_physics, "rendered_frames": draw - previous_draw,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"cpu": timing, "state": game.State.keys()[game.state], "paused": game.paused,
			"simulation_s": game.elapsed, "sea_time": game.sea_time,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"nodes": get_tree().get_node_count(), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	previous = now
	previous_physics = physics
	previous_draw = draw
	if now - measured >= SECONDS * 1000000 or now - started >= MAX_CASE_SECONDS * 1000000:
		_finish_case()
		_next_case()

func _finish_case(reason := "") -> void:
	var summary := Diagnostics.summarize(rows.map(func(r): return [r.t_ms, r.interval_ms]))
	if summary.get("duration_s", 0.0) > 0:
		summary["presented_fps"] = rows.reduce(func(n, r): return n + r.rendered_frames, 0) / summary.duration_s
	var cpu := {}
	for row in rows:
		for key in row.cpu.us:
			cpu[key] = cpu.get(key, 0.0) + row.cpu.us[key] / 1000.0
	var browser_summary := {}
	if OS.has_feature("web") and not rows.is_empty():
		var browser = JavaScriptBridge.get_interface("BlackwaterRuntime")
		var offset: float = browser.clockMs() - Time.get_ticks_usec() / 1000.0
		var data: Dictionary = JSON.parse_string(browser.report())
		browser_summary = Diagnostics.summarize(data.raf_frames.filter(func(r): return r[0] >= rows[0].t_ms + offset and r[0] <= rows[-1].t_ms + offset))
	results.append({"case": case_name, "summary": summary, "cpu_inclusive_total_ms": cpu, "browser_raf_summary": browser_summary,
		"rows": rows.duplicate(), "interrupted": reason, "inventory": inventory(),
		"engine_end_ms": Time.get_ticks_msec(),
		"browser_end_ms": JavaScriptBridge.get_interface("BlackwaterRuntime").clockMs() if OS.has_feature("web") else null})
	print("ACTIVE FPS: ", case_name, " ", JSON.stringify(summary), " CPU ", JSON.stringify(cpu))

func inventory() -> Dictionary:
	var meshes := []
	for node in [game.archipelago.get_node("Terrain/MeshInstance3D"), game.ocean.near_mesh, game.ocean.distant_mesh]:
		var vertices := 0
		var triangles := 0
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		meshes.append({"path": str(game.get_path_to(node)), "vertices": vertices, "triangles": triangles,
			"visible": node.is_visible_in_tree(), "world_aabb_position": str(node.global_transform * node.get_aabb().position),
			"aabb_size": str(node.get_aabb().size)})
	return {"meshes": meshes, "terrain_collision_disabled": game.archipelago.get_node("Terrain/CollisionShape3D").disabled,
		"ocean_cells": game.ocean.cells, "physics_hz": Engine.physics_ticks_per_second}

func report() -> Dictionary:
	return {"running": running, "case": case_name, "warmup_s": WARMUP, "measure_s": SECONDS, "results": results,
		"notes": "Real production scene/callbacks. Each case restarts seeded wave 2, with identical damage immunity. Only the named intervention changes. Frozen simulation retains the chase view with no pause overlay. CPU categories are inclusive and overlap. baseline_unprofiled measures timer overhead. Physics ticks include idle engine ticks even while paused; cpu.physics_tick calls count actual gameplay ticks. Presented FPS counts engine renders; child rAF is a browser scheduling proxy, not compositor proof. Null/zero memory may be unavailable."}

func _publish_progress() -> void:
	label.text = "FPS A/B %d/%d · %s · focus loss stops · F8 cancels" % [case_index + 1, cases.size(), case_name]
	if OS.has_feature("web"): JavaScriptBridge.get_interface("BlackwaterRuntime").investigationProgress(label.text)

func _restore_window() -> void:
	if _window_settings.is_empty(): return
	get_window().content_scale_size = _window_settings[0]
	get_window().content_scale_mode = _window_settings[1]
	get_window().content_scale_aspect = _window_settings[2]

func _publish() -> void:
	var result: Dictionary = game.diagnostics.report()
	var data := JSON.stringify(result)
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("BlackwaterRuntime").investigationFinished(data)
	elif not _output.is_empty():
		var file := FileAccess.open(_output, FileAccess.WRITE)
		if file != null: file.store_string(data)

func _exit_tree() -> void:
	Metrics.enabled = false

extends SceneTree
## Real renderer validation, GPU/CPU probes, screenshots, motion frames, and frame-cadence samples.
## Godot --path ldjam_60 --script res://tests/ocean_render_check.gd -- --output=/tmp/last-bearing-ocean

var output_dir: String = "/tmp/last-bearing-ocean"
var failures: int = 0
var game


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	_run.call_deferred()


func capture(name: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	if result != OK:
		failures += 1
	print("CAPTURE: %s (%s)" % [name, result])


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check requires the real renderer, not headless mode.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir.path_join("motion"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	var original = game.ocean_settings
	await gpu_parity()
	game.ocean_settings = original
	game.sea_time = 18.0
	game._update_view(1.0)
	await capture("01-choppy-title")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	game._update_view(1.0)
	await capture("02-choppy-helm")
	game.reading = true
	game.has_reading = true
	game.last_reading = game.heading
	game._update_view(1.0)
	await capture("03-choppy-astrolabe")
	game.reading = false
	for name: String in ["calm", "stormy"]:
		game.ocean_settings = load("res://game/ocean/presets/" + name + ".tres")
		game.boat_motion.reset()
		game._update_view(1.0)
		await capture("04-" + name + "-helm")
	game.ocean_settings = original
	game.boat_motion.reset()
	game.boat.position = game.course_forward() * 160.0 + game.course_right() * 20.0
	game.elapsed = 27.0
	game.sea_creatures.update_creatures()
	game._update_view(1.0)
	await capture("05-choppy-creature")
	game.boat.position = game.course_forward() * 480.0 + game.course_right() * -12.0
	game.elapsed = 78.0
	game.beacon.visible = true
	game.beacon_seen = true
	game.advance_sailing(1.0 / 60.0, 0.0)
	game._update_view(1.0)
	await capture("06-choppy-arrival")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	game.boat.position = game.course_forward() * 35.0
	game.sea_time = 18.0
	game.boat_motion.reset()
	for frame in range(18):
		for step in range(6):
			game._physics_process(1.0 / 60.0)
		await capture("motion/frame-%02d" % frame)
	var benchmarks: Array[Dictionary] = []
	for quality in [0, 1, 2]:
		benchmarks.append(await benchmark(quality))
	var file := FileAccess.open(output_dir.path_join("render-measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
		"description": "Uncapped real-rendered frame cadence, not isolated GPU timings or a sustained benchmark.",
		"samples": benchmarks}, "\t"))
	file.close()
	file = null
	game.queue_free()
	await process_frame
	print("OCEAN RENDER CHECK: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func gpu_parity() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 3)
	viewport.disable_3d = true
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(16, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tests/ocean_gpu_probe.gdshader")
	rect.material = mat
	viewport.add_child(rect)
	var max_error: float = 0.0
	for preset: String in ["calm", "choppy", "stormy"]:
		var settings = load("res://game/ocean/presets/" + preset + ".tres")
		game.ocean_settings = settings
		game.ocean.update_surface(Vector3.ZERO, 12.375, 0.0, 0.0, game.heading)
		settings.apply_waves(mat)
		mat.set_shader_parameter("wave_time", 12.375)
		mat.set_shader_parameter("focus_xz", Vector2.ZERO)
		mat.set_shader_parameter("fade_start", game.ocean.fade_start)
		mat.set_shader_parameter("fade_end", game.ocean.fade_end)
		for region in range(2):
			var origin := Vector2(-20, -10) if region == 0 else Vector2(30, 23)
			var step := Vector2(2.2, 0.4) if region == 0 else Vector2(3.2, 1.8)
			mat.set_shader_parameter("probe_origin", origin)
			mat.set_shader_parameter("probe_step", step)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			for i in range(16):
				var p := origin + step * i
				var sample_value: Vector3 = game.ocean.sample_surface(p, 12.375)
				var normal: Vector3 = game.ocean.normal_at(p, 12.375)
				var expected := Vector3(sample_value.x, normal.x, normal.z)
				for row in range(3):
					var pixel := image.get_pixel(i, row)
					var packed_value: int = roundi(pixel.r * 255.0) * 256 + roundi(pixel.g * 255.0)
					var actual: float = float(packed_value) / 65535.0 * 8.0 - 4.0
					max_error = maxf(max_error, absf(actual - expected[row]))
	viewport.queue_free()
	if max_error > 0.001:
		push_error("GPU/CPU wave parity failed: %.6f" % max_error)
		failures += 1
	print("GPU/CPU PARITY: 288 rendered height/normal components, max error %.6f" % max_error)


func benchmark(quality: int) -> Dictionary:
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.heading = game.TARGET_HEADING
	game.ocean_quality = quality
	game.boat.position = game.course_right() * -14.0
	for frame in range(120):
		game._physics_process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	var frame_ms: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	for frame in range(600):
		game._physics_process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0)
		previous = now
	frame_ms.sort()
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000.0
	var result := {"quality": ["Low", "Standard", "High"][quality], "frames": 600,
		"mean_frame_ms": elapsed / 600.0, "median_frame_ms": frame_ms[300],
		"p95_frame_ms": frame_ms[570], "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	if game.state != game.State.SAILING:
		push_error("Benchmark unexpectedly left the helm view.")
		failures += 1
	print("RENDER CADENCE: " + JSON.stringify(result))
	return result

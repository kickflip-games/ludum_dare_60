extends SceneTree
var game
var failures := 0
var output_dir := "../artifacts/water_review/wave_implementation"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var result := root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
	if result != OK:
		failures += 1
	print("CAPTURE " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU surface parity requires a real renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://game/crossing.tscn").instantiate()
	game.weather_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	await process_frame
	await parity()
	game.restart()
	game.state = game.State.SAILING
	game.boat.position = Vector3(-280, 0, 50)
	game.heading = 0.0
	game.sea_time = 3.0
	game._update_view(1.0)
	await capture("01-calm-helm")
	game.ocean.wave_field.add_wave(Vector2(-280, -2), Vector2.DOWN, 1.0, 4.8, 26, 8, 0, 8)
	game._update_view(1.0)
	await capture("02-frontal-crest")
	for height: float in [0.65, 1.1, 1.85]:
		game.ocean.wave_field.waves[0].height = height
		game._update_view(1.0)
		await capture("height-%.2f" % height)
	game.ocean.wave_field.clear()
	game.ocean.wave_field.add_wave(Vector2(-320, 12), Vector2(1, 0.3), 0.95, 4.8, 26, 8, 0, 8)
	game._update_view(1.0)
	await capture("03-oblique-crest")
	game.camera.position = game.boat.position + Vector3(0, 45, 20)
	game.camera.look_at(game.boat.position + Vector3(0, 0, -14))
	await capture("04-crest-overview")
	game.ocean.wave_field.add_wave(Vector2(-240, 5), Vector2(-1, 0.5), 0.6, 4.4, 24, 8, 0, 8)
	game._update_view(1.0)
	await capture("05-crossing-crests")
	game.ocean.wave_field.clear()
	game.ocean.wave_field.add_wave(Vector2(-280, -2), Vector2.DOWN, 1.0, 4.8, 26, 8, 0, 8)
	for frame in range(16):
		game.sea_time = 3.0 + frame * 0.25
		game._update_view(0.25)
		await capture("motion-%02d" % frame)
	game.ocean.wave_field.advance(9)
	game.sea_time = 9
	game._update_view(1.0)
	await capture("06-calm-after")
	game.queue_free()
	await process_frame
	print("WAVE RENDER: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func parity() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 4)
	viewport.disable_3d = true
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(16, 4)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tests/ocean_gpu_probe.gdshader")
	rect.material = mat
	mat.set_shader_parameter("probe_range", 12.0)
	mat.set_shader_parameter("probe_rows", 4.0)
	viewport.add_child(rect)
	var max_error := 0.0
	var components := 0
	var original = game.ocean_settings
	for preset: String in ["calm", "choppy", "stormy"]:
		game.ocean_settings = load("res://game/ocean/presets/" + preset + ".tres").duplicate(true)
		for count in range(5):
			game.ocean.wave_field.clear()
			for i in range(count):
				game.ocean.wave_field.add_wave(Vector2(-24 + i * 2, -i * 3), Vector2(1, i * 0.22), 0.65 + i * 0.45, 4.0 + i * 0.2, 24, 8, 0, 8)
			for time: float in [-0.02, 0.0, 0.02, 0.79, 0.81, 3.0, 6.5, 7.5, 8.02]:
				for lane in range(3):
					var origin: Vector2 = [Vector2(-15, 0), Vector2(34, 8), Vector2(84, -7)][lane]
					var focus: Vector2 = [Vector2.ZERO, Vector2(0.7, -0.3), Vector2(9.17, -11.34)][lane]
					var step := Vector2(2.7, 0.3)
					game.ocean.update_surface(Vector3(focus.x, 0, focus.y), time, 0, 0, 0)
					game.ocean_settings.apply_waves(mat)
					game.ocean.wave_field.apply_to(mat)
					mat.set_shader_parameter("wave_time", time)
					mat.set_shader_parameter("focus_xz", focus)
					mat.set_shader_parameter("probe_origin", origin)
					mat.set_shader_parameter("probe_step", step)
					for styled: bool in [false, true]:
						mat.set_shader_parameter("probe_styled", styled)
						viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
						await process_frame
						RenderingServer.force_draw(true, 1.0 / 60.0)
						var pixels := viewport.get_texture().get_image()
						for i in range(16):
							var p := origin + step * i
							var sample_value: Vector3 = game.ocean.sample_surface(p, time)
							var normal: Vector3 = game.ocean.normal_at(p, time)
							var expected := Vector4(sample_value.x, normal.x, normal.y, normal.z)
							for row in range(4):
								var pixel := pixels.get_pixel(i, row)
								var packed_value := roundi(pixel.r * 255) * 256 + roundi(pixel.g * 255)
								var actual := float(packed_value) / 65535.0 * 24.0 - 12.0
								max_error = maxf(max_error, absf(actual - expected[row]))
								components += 1
	game.ocean_settings = original
	viewport.queue_free()
	print("EVENT GPU/CPU PARITY: %d components, error %.6f" % [components, max_error])
	if max_error > 0.001:
		failures += 1

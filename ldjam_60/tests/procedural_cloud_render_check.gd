extends "res://tests/night_cloud_previews.gd"
## Actual GL pixels: opacity, fixed stars, continuous drift, reprojection and navigation.
var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)


func pixels() -> Image:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	return root.get_texture().get_image()


func difference(a: Image, b: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			total += absf(a.get_pixel(x, y).r - b.get_pixel(x, y).r)
			samples += 1
	return total / samples


func sky_mask(label: String) -> Image:
	game.sky_material.set_shader_parameter("cloud_debug", 1)
	return await capture(label + "-mask")


func step(seconds: float) -> void:
	for frame in range(roundi(seconds * 60)):
		game._physics_process(1.0 / 60.0)
	game.hud._process(0.0)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Procedural cloud pixel checks require a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.reading = true
	game._update_view(2.0)
	game.hud.hide()
	# Isolate sky pixels from mountains entering the view during the translation
	# diagnostic. The matched gameplay previews retain all production geometry.
	var geometry_mask: int = game.camera.cull_mask
	game.camera.cull_mask = 0
	var material: ShaderMaterial = game.sky_material
	material.set_shader_parameter("cloud_density", 0.0)
	var empty := await sky_mask("zero-coverage")
	var empty_total := 0.0
	for y in range(0, 720, 4):
		for x in range(0, 1280, 4):
			empty_total += empty.get_pixel(x, y).r
	check(empty_total == 0.0, "coverage zero removes every procedural cloud pixel")
	material.set_shader_parameter("cloud_debug", 0)
	material.set_shader_parameter("twinkle_strength", 0.0)
	material.set_shader_parameter("target_focus", 0.0)
	material.set_shader_parameter("visual_time", 0.0)
	var stars_a := await capture("stars-time-000")
	material.set_shader_parameter("visual_time", 240.0)
	var stars_b := await capture("stars-time-240")
	check(stars_a.get_data() == stars_b.get_data(), "fixed celestial stars are pixel-identical across time without twinkle")
	material.set_shader_parameter("cloud_debug", 2)
	var under := await pixels()
	check(stars_b.get_data() == under.get_data(), "zero-coverage composite retains all underlying stars")
	material.set_shader_parameter("cloud_density", game.cloud_density)
	material.set_shader_parameter("visual_time", 60.0)
	var mask_a := await sky_mask("default-coverage")
	material.set_shader_parameter("visual_time", 60.0 + 1.0 / 60.0)
	var next_frame := await pixels()
	material.set_shader_parameter("visual_time", 120.0)
	var later := await sky_mask("drift-120")
	check(difference(mask_a, next_frame) < 0.003, "one-frame drift is continuous without resets")
	check(difference(mask_a, later) > 0.01, "coherent wind visibly moves cloud coverage over one minute")
	report["drift"] = {"one_frame_mean_delta": difference(mask_a, next_frame), "one_minute_mean_delta": difference(mask_a, later)}
	# Translation does not move an infinitely distant sky. Turning must reproject
	# the same cloud field, rather than hold cloud features at screen positions.
	material.set_shader_parameter("visual_time", 60.0)
	game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(60), 0, 0))
	var reference := await sky_mask("world-reference")
	var directions: Array[Vector3] = []
	var values: Array[float] = []
	for y in range(100, 620, 40):
		for x in range(200, 1080, 40):
			directions.append(game.camera.project_ray_normal(Vector2(x, y)))
			values.append(reference.get_pixel(x, y).r)
	game.camera.position += Vector3(70, 0, -40)
	var translated := await pixels()
	check(reference.get_data() == translated.get_data(), "moving the ship/camera leaves the world-direction sky unchanged")
	game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(60), deg_to_rad(-20), 0))
	var turned := await sky_mask("world-yaw-020")
	var error := 0.0
	var count := 0
	for i in directions.size():
		var at: Vector2 = game.camera.unproject_position(game.camera.position + directions[i] * 100)
		if Rect2(Vector2(2, 2), Vector2(1276, 716)).has_point(at):
			error += absf(values[i] - turned.get_pixelv(Vector2i(at)).r)
			count += 1
	check(count > 150 and error / count < 0.015, "yaw reprojects the same fixed cloud field at matching world directions")
	report["reprojection"] = {"samples": count, "mean_alpha_error": error / maxi(count, 1)}
	game._update_view(0.0)
	# Opaque clouds must be identical to the cloud-only image: stars are below them.
	material.set_shader_parameter("cloud_density", 1.0)
	material.set_shader_parameter("storm", 1.0)
	material.set_shader_parameter("cloud_debug", 0)
	var composite := await capture("high-coverage-composite")
	var mask := await sky_mask("high-coverage")
	material.set_shader_parameter("cloud_debug", 3)
	var cloud_only := await capture("cloud-only")
	var opaque := 0
	var max_error := 0.0
	for y in range(0, 720, 2):
		for x in range(0, 1280, 2):
			if mask.get_pixel(x, y).r >= 0.999:
				opaque += 1
				var a := composite.get_pixel(x, y)
				var b := cloud_only.get_pixel(x, y)
				max_error = maxf(max_error, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	check(opaque > 1000 and max_error <= 2.0 / 255.0, "opaque clouds truly occlude stars in the actual renderer")
	report["occlusion"] = {"opaque_pixels_sampled": opaque, "max_rgb_error": max_error}
	# The single active star stays readable through dense weather at every stage.
	for seed in [60, 97]:
		game._cloud_layout.configure_procedural(material, seed)
		for time in [0.0, 60.0, 240.0, 480.0]:
			for stage in 3:
				game.voyage.stage = stage
				game.voyage.set_target(game)
				game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(60), -game.destination_bearing(), 0))
				material.set_shader_parameter("visual_time", time)
				var sample_mask := await sky_mask("seed-%d-time-%03d-stage-%d" % [seed, time, stage])
				var at: Vector2 = game.camera.unproject_position(game.camera.position + game.guiding_star_direction() * 100)
				check(Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(at) and sample_mask.get_pixelv(Vector2i(at)).r < 0.01, "seed %d / time %.0f keeps active destination star %d clear in dense storm" % [seed, time, stage])
	game._cloud_layout.configure_procedural(material, 60)
	game.camera.cull_mask = geometry_mask
	game.hud.show()
	material.set_shader_parameter("cloud_debug", 0)
	for stage in 3:
		game.voyage.stage = stage
		game.voyage.set_target(game)
		Input.action_press("astrolabe")
		step(0.5)
		await capture("stage-%d-search" % stage)
		step(1.3)
		await capture("stage-%d-focus" % stage)
		check(game.hud.instrument.get_child_count() == 0 and game.focus_strength == 1.0 and material.get_shader_parameter("active_star") == stage, "real Space input focuses the existing stage %d star" % stage)
		check(Rect2(Vector2.ZERO, game.hud.size).has_point(game.hud.star_guidance().position), "stage %d focus UI remains aligned and inside the viewport" % stage)
		Input.action_release("astrolabe")
		step(1.0 / 60.0)
		check(game.hud.star_guidance().is_empty() and material.get_shader_parameter("target_focus") == 0.0, "stage %d Space release clears guidance immediately" % stage)
	# Existing weather clock, including its actual lightning pulse.
	game.weather_enabled = true
	game.elapsed = 18.0
	game._update_weather(0.5)
	check(game.phase == 2 and float(material.get_shader_parameter("lightning")) > 0.29, "progression storm still produces the timed lightning pulse")
	await capture("production-lightning")
	game.elapsed = 18.3
	game._update_weather(0.3)
	check(material.get_shader_parameter("lightning") == 0.0, "production lightning fades out")
	var retry := InputEventKey.new()
	retry.physical_keycode = KEY_R
	retry.pressed = true
	game._unhandled_input(retry)
	check(game.state == game.State.CASTING_OFF and game.voyage.stage == 0 and material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()), "R begins the same voyage with the live departure star")
	report["checks"] = checks
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PROCEDURAL CLOUD RENDER CHECK ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

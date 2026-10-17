extends "res://tests/night_cloud_previews.gd"
## Native renderer evidence. Camera angles are staged; focus uses the real controller.
var make_clip := false
var failures := 0
var checks := 0


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		make_clip = make_clip or arg == "--clip"
	if DisplayServer.get_name() == "headless":
		push_error("Sky review requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.phase_banner_left = 0
	game.elapsed = 10
	game.sea_time = 4.5
	game.reading = false
	game._update_view(2.0)
	game.hud._process(0.0)
	await capture("01-sailing-horizon")
	game.hud.hide()
	game.camera.fov = game.stargazing_fov
	for tilt: float in [0, 45, 78, 90]:
		game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(tilt), 0, 0))
		await capture("02-tilt-%02d" % tilt)
		await sky_coverage("tilt-%02d" % tilt)
	# Heading sweep includes the south-facing cloud banks and high sky.
	for heading: float in [90, 180, 270]:
		game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(78), deg_to_rad(-heading), 0))
		await capture("03-heading-%03d" % heading)
		await sky_coverage("heading-%03d" % heading)
	game.reading = true
	game.heading = game.START_HEADING
	game._update_view(2.0)
	game.hud.show()
	for stage in 3:
		game.voyage.stage = stage
		game.voyage.set_target(game)
		game._update_view(0.5)
		game.hud._process(0.0)
		await capture("04-star-%d-search" % stage)
		game._update_view(1.3)
		game.hud._process(0.0)
		await capture("04-star-%d-focus" % stage)
		await sky_coverage("star-%d-focus" % stage)
	game.hud.hide()
	game.camera.basis = Basis.from_euler(Vector3(deg_to_rad(78), 0, 0))
	for seconds: float in [0, 60, 120, 240, 480]:
		game.sky_material.set_shader_parameter("visual_time", seconds)
		await capture("05-drift-%03d" % seconds)
		await sky_coverage("drift-%03d" % seconds)
	game.sky_material.set_shader_parameter("visual_time", 4.5)
	# Warm renderer caches, then measure frame intervals without image readback.
	for i in 60:
		await process_frame
	var timings: Array[float] = []
	var then := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		timings.append((now - then) / 1000.0)
		then = now
	timings.sort()
	report["native_frame_ms"] = {"median": timings[90], "p95": timings[171], "samples": timings.size()}
	if make_clip:
		DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
		for i in 120:
			# Time lapse of eight minutes of slow world-space drift.
			game.sky_material.set_shader_parameter("visual_time", i * 4.0)
			await capture("frames/sky-%04d" % i)
	await rendered_checks()
	await family_review()
	report["checks"] = checks
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("coverage.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PAINTERLY SKY REVIEW: ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)


func sky_coverage(label: String) -> void:
	var was_visible: bool = game.hud.visible
	game.hud.hide()
	game.sky_material.set_shader_parameter("cloud_debug", 1)
	var mask: Image = await capture(label + "-mask")
	var covered := 0
	var samples := 0
	for y in range(0, mask.get_height(), 4):
		for x in range(0, mask.get_width(), 4):
			covered += int(mask.get_pixel(x, y).r > 0.2)
			samples += 1
	var star_masks: Array[float] = []
	for region in game.archipelago.get_node("NavigationRegions").get_children():
		var direction: Vector3 = region.star_direction.normalized()
		var at: Vector2 = game.camera.unproject_position(game.camera.position + direction * 100)
		star_masks.append(mask.get_pixelv(Vector2i(at)).r if Rect2(Vector2.ZERO, Vector2(mask.get_size())).has_point(at) else -1.0)
	report[label] = {"cloud_fraction": float(covered) / samples, "navigation_star_masks": star_masks}
	if label.begins_with("tilt-") and label != "tilt-00":
		check(float(covered) / samples < 0.45, label + " leaves most of the sky clear")
	for i in star_masks.size():
		if star_masks[i] >= 0.0:
			check(star_masks[i] == 0.0, label + " keeps navigation star %d clear" % i)
	game.sky_material.set_shader_parameter("cloud_debug", 0)
	game.hud.visible = was_visible


func family_review() -> void:
	# Same shader and atlas, staged as eight isolated formations for art review.
	var centers := PackedVector4Array()
	var rights := PackedVector4Array()
	var ups := PackedVector4Array()
	for i in 40:
		var at := Vector3((float(i % 4) - 1.5) * 0.92, 1.65 - float(i / 4) * 0.95, -2.4).normalized()
		var right := (Vector3.RIGHT - at * at.x).normalized()
		var up := right.cross(at).normalized()
		var width := deg_to_rad(20)
		var height: float = width * game._cloud_layout.HEIGHT_RATIOS[i % 8]
		centers.append(Vector4(at.x, at.y, at.z, 0.0 if i < 8 else 2.0))
		rights.append(Vector4(right.x / tan(width*.5), right.y / tan(width*.5), right.z / tan(width*.5), i % 8))
		ups.append(Vector4(up.x / tan(height*.5), up.y / tan(height*.5), up.z / tan(height*.5), 0.5))
	game.sky_material.set_shader_parameter("cloud_centers", centers)
	game.sky_material.set_shader_parameter("cloud_rights", rights)
	game.sky_material.set_shader_parameter("cloud_ups", ups)
	game.sky_material.set_shader_parameter("visual_time", 0.0)
	game.camera.look_at(game.camera.position + Vector3(0, 1.175, -2.4))
	game.camera.fov = 66
	await capture("08-eight-cloud-families")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	print(("PASS: " if condition else "FAIL: ") + label)


func rendered_checks() -> void:
	game.hud.hide()
	game.sky_material.set_shader_parameter("target_focus", 0.0)
	game.sky_material.set_shader_parameter("cloud_density", 0.0)
	game.sky_material.set_shader_parameter("twinkle_strength", 0.0)
	game.sky_material.set_shader_parameter("visual_time", 0.0)
	var fixed: Image = await capture("06-fixed-stars-000")
	game.sky_material.set_shader_parameter("visual_time", 120.0)
	var later: Image = await capture("06-fixed-stars-120")
	check(fixed.get_data() == later.get_data(), "star positions and sizes are pixel-identical across time with twinkle disabled")
	game.sky_material.set_shader_parameter("twinkle_strength", game.twinkle_strength)
	game.sky_material.set_shader_parameter("visual_time", 0.0)
	var pulse_a: Image = await capture("06-twinkle-000")
	game.sky_material.set_shader_parameter("visual_time", 120.0)
	var pulse_b: Image = await capture("06-twinkle-120")
	check(pulse_a.get_data() != pulse_b.get_data(), "asynchronous twinkle changes star brightness")
	# All opaque cloud pixels must match the paint-only rendering. This catches
	# stars drawn over clouds or alpha-sorting leaks in the actual renderer.
	game.sky_material.set_shader_parameter("cloud_density", game.cloud_density)
	game.sky_material.set_shader_parameter("visual_time", 4.5)
	var composite: Image = await capture("07-occlusion-composite")
	game.sky_material.set_shader_parameter("cloud_debug", 1)
	var mask: Image = await capture("07-occlusion-mask")
	game.sky_material.set_shader_parameter("cloud_debug", 3)
	var paint: Image = await capture("07-occlusion-paint")
	var opaque := 0
	var max_error := 0.0
	for y in range(0, mask.get_height(), 2):
		for x in range(0, mask.get_width(), 2):
			if mask.get_pixel(x, y).r >= 0.999:
				opaque += 1
				var a := composite.get_pixel(x, y)
				var b := paint.get_pixel(x, y)
				max_error = maxf(max_error, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
	check(opaque > 1000 and max_error <= 2.0 / 255.0, "opaque clouds hide underlying stars without sorting leaks")
	report["occlusion"] = {"opaque_samples": opaque, "max_color_error": max_error}
	game.sky_material.set_shader_parameter("cloud_debug", 0)

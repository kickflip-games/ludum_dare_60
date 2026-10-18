extends SceneTree
## Real Compatibility renderer. Camera/clock/weather are staged for art review.
var game
var output := "/tmp/night-cloud-review"
var report: Dictionary = {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()


func capture(label: String) -> Image:
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(label + ".png")) == OK)
	print("CLOUD CAPTURE: ", label)
	return image


func coverage(label: String) -> void:
	game.hud.hide()
	game.sky_material.set_shader_parameter("cloud_debug", 1)
	var mask: Image = await capture(label + "-mask")
	var covered := 0
	var samples := 0
	for y in range(0, mask.get_height(), 3):
		for x in range(0, mask.get_width(), 3):
			covered += int(mask.get_pixel(x, y).r > 0.2)
			samples += 1
	var star_position: Vector2 = game.camera.unproject_position(game.camera.position + game.guiding_star_direction() * 100)
	var star_mask := -1.0
	if Rect2(Vector2.ZERO, Vector2(mask.get_size())).has_point(star_position):
		star_mask = mask.get_pixelv(Vector2i(star_position)).r
	report[label] = {"visible_cloud_fraction": float(covered) / samples, "guiding_star_mask": star_mask}
	if label == "01-stargazing":
		game.sky_material.set_shader_parameter("cloud_debug", 0)
		await capture("occlusion-composite")
		game.sky_material.set_shader_parameter("cloud_debug", 3)
		await capture("occlusion-paint")
		game.sky_material.set_shader_parameter("cloud_debug", 2)
		await capture("occlusion-underlying-stars")
	game.sky_material.set_shader_parameter("cloud_debug", 0)
	game.hud.show()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Cloud art review requires a real renderer")
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
	game.start_crossing()
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.phase_banner_left = 0
	game.elapsed = 10
	game.sea_time = 4.5
	game.reading = true
	game._update_view(2.0)
	game.hud._process(0.0)
	await capture("01-stargazing")
	await coverage("01-stargazing")
	for heading: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		game.heading = heading
		game._update_view(0.0)
		game.hud._process(0.0)
		await capture("heading-%03d" % rad_to_deg(heading))
		await coverage("heading-%03d" % rad_to_deg(heading))
	game.heading = game.START_HEADING
	for seconds: float in [30.0, 60.0, 120.0]:
		game.sea_time = seconds
		game._update_view(0.0)
		game.hud._process(0.0)
		await capture("drift-%03d" % seconds)
		await coverage("drift-%03d" % seconds)
	game.storm_blend = 1.0
	game.sky_material.set_shader_parameter("storm", 1.0)
	await capture("storm-stargazing")
	await coverage("storm-stargazing")
	game.storm_blend = 0.0
	game.sky_material.set_shader_parameter("storm", 0.0)
	game.sea_time = 4.5
	game.reading = false
	game._update_view(2.0)
	game.hud._process(0.0)
	await capture("02-sailing")
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	game._update_view(2.0)
	game.hud._process(0.0)
	await capture("03-cannon")
	# Close inspection through the actual sky shader, at an existing formation.
	game.hud.hide()
	var centers: PackedVector4Array = game.sky_material.get_shader_parameter("cloud_centers")
	var center := Vector3(centers[5].x, centers[5].y, centers[5].z)
	game.camera.look_at(game.camera.position + center)
	game.camera.fov = 50
	await capture("04-cloud-closeup")
	# Eight-family contact sheet rendered as staged sky cards, not a mockup.
	game.camera.look_at(game.camera.position + Vector3(0.0, 0.8, -2.0))
	game.camera.fov = 74
	var rights := PackedVector4Array()
	var ups := PackedVector4Array()
	for i in 40:
		var at := Vector3((float(i % 4) - 1.5) * 0.85, 1.1 - float(i / 4) * 0.6, -2.0).normalized()
		var right := (Vector3.RIGHT - at * at.x).normalized()
		var up := right.cross(at).normalized()
		centers[i] = Vector4(at.x, at.y, at.z, 0.0 if i < 8 else 2.0)
		rights.append(Vector4(right.x * 6.4, right.y * 6.4, right.z * 6.4, i % 8))
		ups.append(Vector4(up.x * 10.6, up.y * 10.6, up.z * 10.6, float(i % 3) * 0.3))
	game.sky_material.set_shader_parameter("cloud_centers", centers)
	game.sky_material.set_shader_parameter("cloud_rights", rights)
	game.sky_material.set_shader_parameter("cloud_ups", ups)
	game.sky_material.set_shader_parameter("visual_time", 0.0)
	await capture("05-eight-silhouettes")
	var file := FileAccess.open(output.path_join("coverage.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CLOUD COVERAGE: ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit()

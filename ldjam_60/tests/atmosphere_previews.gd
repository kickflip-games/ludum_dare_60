extends "res://tests/sailing_camera_previews.gd"
## Matched production geometry, seeded sky, clocks and cameras for night lighting.
var metrics: Dictionary = {}
var baseline_source := ""

func weather(strength: float) -> void:
	game.storm_blend = strength
	game.weather_enabled = true
	game._update_weather(0.0)
	game.weather_enabled = false
	game.sky_material.set_shader_parameter("lightning", 0.0)
	if game.has_method("_apply_night_illumination"):
		game._apply_night_illumination()
	if not baseline_source.is_empty():
		var environment: Environment = game.world_environment.environment
		environment.ambient_light_color = Color("60838e")
		environment.ambient_light_energy = lerpf(0.78,0.56,strength)
		environment.fog_light_color = Color("243c46")
		game.moon.light_color = Color("a4c6d4")
		game.moon.light_energy = lerpf(0.88,0.68,strength)

func pose(at: Vector3, yaw: float, storm: float = 0.0) -> void:
	place(at, yaw)
	game.wave_encounters.enabled = false
	game.elapsed = 60.0
	game.sea_time = 60.0
	game._update_view(2.0)
	weather(storm)
	game.hud._process(0.0)

func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true, 1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	frames[label] = {"camera":str(game.camera.transform), "clock":game.sea_time,
		"heading":game.heading,"storm":game.storm_blend,"fov":game.camera.fov}
	print("ATMOSPHERE CAPTURE ", label)

func benchmark(label: String) -> void:
	for i in range(60):
		await process_frame
		RenderingServer.force_draw(true,1.0/60)
	var values: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(300):
		await process_frame
		RenderingServer.force_draw(true,1.0/60)
		var now := Time.get_ticks_usec()
		values.append((now-previous)/1000.0)
		previous = now
	values.sort()
	metrics[label] = {"median_ms":values[150],"p95_ms":values[285],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-source="):
			baseline_source = arg.trim_prefix("--baseline-source=")
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	if not baseline_source.is_empty():
		# Replay preserved presentation only, without swapping working files.
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(baseline_source.path_join("sea.gdshader"))
		game.water_material.shader = shader
		game.ocean_settings = load(baseline_source.path_join("calm.tres"))
		for child in game.boat_visual.get_children():
			if child is OmniLight3D:
				child.light_color = Color("ffc178")
				child.light_energy = 2.0
				child.light_specular = 1.0
		game.enemy_encounters.ship.sail_color = Color("a23e32")
		game.enemy_encounters.ship.sail_material.emission_enabled = false
	pose(game.archipelago.get_node("SpawnPoints/Departure").position,game.START_HEADING)
	await shot("01-departure")
	pose(Vector3(-300,0,-330),0)
	await shot("02-open-ocean")
	await benchmark("calm")
	game.ocean.wave_field.add_wave(Vector2(-300,-356),Vector2(0,1),1.4,4.8,26,8,58,9)
	game._update_view(0.0)
	await shot("03-wave")
	pose(Vector3(-175,0,-40),PI/2)
	await shot("04-island")
	pose(Vector3(292,0,105),-2.94)
	game.voyage.stage = 2
	game.voyage.set_target(game)
	game.beacon.visible = true
	await shot("05-lighthouse")
	pose(game.archipelago.get_node("SpawnPoints/Departure").position,game.START_HEADING)
	action("astrolabe",true)
	await advance(1.8)
	weather(0.0)
	await shot("06-focused-star")
	weather(1.0)
	await shot("07-storm-star")
	action("astrolabe",false)
	pose(Vector3(-300,0,-330),0)
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position+Vector3(18,0,-40))
	ship.heading = -0.7
	ship.rotation.y = -ship.heading
	game._update_view(0.0)
	print("ENEMY ",ship.global_position," visible=",ship.is_visible_in_tree()," screen=",game.camera.unproject_position(ship.global_position+Vector3.UP*4))
	await shot("08-enemy-sailing")
	weather(1.0)
	await shot("09-storm-sailing")
	await benchmark("storm")
	ship.position = game.boat.position+game.cannon.starboard_direction()*40
	action("watch_starboard",true)
	# Settle the actual gun-camera transition without advancing the staged enemy.
	for i in range(40):
		game.cannon.update_aim(1.0/60)
		game._update_view(1.0/60)
	assert(game.cannon.aiming)
	weather(0.0)
	game.hud._process(0.0)
	await shot("10-cannon")
	weather(1.0)
	await shot("11-storm-cannon")
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"poses":frames,"performance":metrics,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("ATMOSPHERE METRICS ",JSON.stringify(metrics))
	game.queue_free()
	await process_frame
	await process_frame
	quit()

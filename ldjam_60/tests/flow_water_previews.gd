extends SceneTree
## Native matched water views and a real-input pass through an authored flow.
var game
var output := ""
var final_settings: Resource
var final_shader: Shader
var baseline_settings: Resource
var baseline_shader: Shader
var measures: Array[Dictionary] = []
var benchmark_only := false
var has_baseline := false

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../build/water_flow/rendered")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--benchmark-only": benchmark_only = true
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0)
	await process_frame
	RenderingServer.force_draw(true,1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	measures.append({"frame":label,"speed":game.propulsion_speed(),"actual_speed":game.actual_speed,
		"collected":game.flow_zones.collected.keys(),"camera":str(game.camera.position),
		"clearance":game.camera.position.y-game.ocean.height_at(Vector2(game.camera.position.x,game.camera.position.z)),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	print("WATER CAPTURE: "+label)

func benchmark() -> void:
	# Review process only: avoid 16.7/33.3 ms vsync quantisation in diagnostics.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var runs: Array[Dictionary] = []
	for count in [0,4]:
		for repeat in 3:
			for baseline in ([true,false] if has_baseline else [false]):
				place(Vector2(70,-30),0,baseline,count)
				var timings: Array[float] = []
				for frame in 120:
					await process_frame
					var start := Time.get_ticks_usec()
					game._update_view(1.0/60)
					RenderingServer.force_draw(true,1.0/60)
					if frame >= 30: timings.append((Time.get_ticks_usec()-start)/1000.0)
				timings.sort()
				var row := {"baseline":baseline,"events":count,"repeat":repeat,
					"median_ms":timings[timings.size()/2],"p95_ms":timings[int(timings.size()*0.95)],
					"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
				runs.append(row)
				print("WATER FRAME TIMING: "+JSON.stringify(row))
	var file := FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(runs,"\t"))

func place(offset: Vector2, heading: float, baseline: bool = false, crest_count: int = 0) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.flow_zones.enabled = not baseline
	game.ocean_settings = baseline_settings.duplicate(true) if baseline else final_settings.duplicate(true)
	game.water_material.shader = baseline_shader if baseline else final_shader
	game.ocean._sync_settings()
	game.boat.position = game.arena_center() + Vector3(offset.x,0,offset.y)
	game.heading = heading
	game.boat.rotation.y = -heading
	game.elapsed = 18.0
	game.sea_time = 18.0
	game.ocean.wave_time = 18.0
	var forward := Vector2(sin(heading),-cos(heading))
	var center := Vector2(game.boat.position.x,game.boat.position.z)
	for i in crest_count:
		var direction := forward.rotated(0.8 if i%2==0 else -0.9)
		game.ocean.wave_field.add_wave(center+forward*(8+i*4)-direction*24,direction,0.8+i*0.2,4.8,26,8,15,8)
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	# Settle the existing ride/camera at an identical fixed wave clock.
	for frame in 180: game._update_view(1.0/60)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	final_settings = game.ocean_settings.duplicate(true)
	final_shader = game.water_material.shader
	baseline_shader = Shader.new()
	var baseline_source := ProjectSettings.globalize_path("res://../build/water_flow/source/sea.gdshader")
	has_baseline = FileAccess.file_exists(baseline_source)
	if has_baseline:
		baseline_shader.code = FileAccess.get_file_as_string(baseline_source)
	else:
		baseline_shader = final_shader
		print("No preserved baseline shader; capturing final only, without a before claim.")
	baseline_settings = final_settings.duplicate(true)
	baseline_settings.height_multiplier = 0.095
	baseline_settings.speed_multiplier = 0.5
	baseline_settings.trough_color = Color(0.062745,0.121569,0.231373)
	baseline_settings.main_color = Color(0.094118,0.231373,0.349020)
	baseline_settings.slope_color = Color(0.258824,0.423529,0.513725)
	baseline_settings.crest_color = Color(0.396078,0.556863,0.666667)
	baseline_settings.foam_color = Color(0.6,0.72549,0.8)
	baseline_settings.frequency_1 = 0.18
	baseline_settings.frequency_2 = 0.39
	baseline_settings.frequency_3 = 0.72
	baseline_settings.band_softness = 0.09
	baseline_settings.foam_threshold = 0.68
	baseline_settings.foam_intensity = 0
	if benchmark_only:
		await benchmark()
		game.queue_free()
		await process_frame
		quit()
		return
	for baseline in ([true,false] if has_baseline else [false]):
		var prefix := "before" if baseline else "after"
		place(Vector2(70,-30),0,baseline)
		await capture(prefix+"-rolling-water")
		place(Vector2(104,32),0,baseline)
		await capture(prefix+"-flow-approach")
		place(Vector2(70,-30),0,baseline,4)
		await capture(prefix+"-four-crests")
	place(Vector2(104,32),0)
	game.ocean_quality = 0
	await capture("after-low-flow")
	game.ocean_quality = 1
	game.motion_setting = 1
	for frame in 120: game._update_view(1.0/60)
	await capture("after-reduced-motion")
	game.motion_setting = 0
	place(Vector2(70,-30),0,false,4)
	game.storm_blend = 0.7
	game.sky_material.set_shader_parameter("storm",0.7)
	game._update_view(1.0/60)
	await capture("after-storm-crests")
	place(Vector2(104,32),0)
	Input.action_press("watch_starboard")
	for frame in 36: game._physics_process(1.0/60)
	await capture("after-cannon-water")
	Input.action_release("watch_starboard")
	# One real forward sail through EastFlow; do not assign collection IDs.
	place(Vector2(104,32),0)
	var clock := 0.0
	for frame in 540:
		game._physics_process(1.0/60)
		clock += 1.0/60
		if frame%30 == 0:
			await capture("sequence-%02d" % (frame/30))
		if frame == 220: await capture("after-flow-collected")
		if frame == 530: await capture("after-flow-exit")
	print("REAL FLOW PASS: collected=%s propulsion=%f" % [game.flow_zones.collected.keys(),game.propulsion_speed()])
	# Surface motion strip supplies reproducible animated evidence.
	place(Vector2(70,-30),0)
	for frame in 18:
		for tick in 10:
			game.sea_time += 1.0/60
			game._update_view(1.0/60)
		await capture("rolling-%02d" % frame)
	var file := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(measures,"\t"))
	game.queue_free()
	await process_frame
	quit()

extends SceneTree
## Matched native water review. Fixed simulation time, real movement and one shared surface.
var game
var output := ProjectSettings.globalize_path("res://../artifacts/water_review/dynamic_toon/baseline")
var record_clip := false
var benchmark_only := false
var baseline_source := ""
var baseline_shader: Shader
var baseline_wake_shader: Shader
var frames: Dictionary = {}
var trace: Array[Dictionary] = []
var clip_index := 0
const OPEN := Vector3(-300, 0, -330)
const DT := 1.0 / 60.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--clip":
			record_clip = true
		if arg == "--benchmark-only":
			benchmark_only = true
		if arg.begins_with("--baseline-source="):
			baseline_source = arg.trim_prefix("--baseline-source=")
	_run.call_deferred()

func place(at: Vector3 = OPEN, preset: String = "calm") -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	var preset_path := "res://game/ocean/presets/" + preset + ".tres" if baseline_source.is_empty() else baseline_source.path_join("ldjam_60/game/ocean/presets/"+preset+".tres")
	game.ocean_settings = load(preset_path).duplicate(true)
	game.boat.position = at
	game.heading = 0.0
	game.boat.rotation = Vector3.ZERO
	game.actual_speed = game.SPEED
	game.boat.velocity = Vector3(0, 0, -game.SPEED)
	game.sea_time = 0.0
	game.elapsed = 40.0
	game.phase_banner_left = 0.0
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	for i in range(30):
		game._update_view(DT)
	game.hud._process(DT)

func crest(direction: Vector2, height: float, arrival: float = 3.0, lateral: float = 0.0) -> void:
	var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
	var target := Vector2(center.x, center.z - game.SPEED * arrival)
	var side := Vector2(-direction.y, direction.x)
	game.ocean.wave_field.add_wave(target - direction * 8.0 * arrival + side * lateral,
		direction, height, 4.8, 26.0, 8.0, 0.0, 8.0)

func advance(seconds: float, steering: float = 0.0, clip: bool = false) -> void:
	for frame in range(roundi(seconds / DT)):
		game.advance_sailing(DT, steering)
		game.cannon.advance(DT)
		game._update_view(DT)
		game.hud._process(DT)
		if clip:
			var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
			trace.append({"time":game.sea_time,"water_center":game.ocean.height_at(Vector2(center.x,center.z)),
				"heave":game.boat_motion.heave,"pitch_degrees":rad_to_deg(game.boat_motion.pitch),
				"roll_degrees":rad_to_deg(game.boat_motion.roll),"heading":game.heading,
				"drift":game.wave_sailing.drift.length(),"yaw_rate":game.wave_sailing.yaw_rate,
				"camera_roll":game.camera.rotation.z})
		if frame % 3 == 0:
			await process_frame
			if clip and record_clip:
				RenderingServer.force_draw(true, DT)
				root.get_texture().get_image().save_png(output.path_join("clip/%04d.png" % clip_index))
				clip_index += 1

func capture(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true, DT)
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	frames[label] = {"saved":result == OK,"clock":game.sea_time,"position":str(game.boat.position),
		"camera":str(game.camera.position),"heave":game.boat_motion.heave,
		"pitch_degrees":rad_to_deg(game.boat_motion.pitch),"roll_degrees":rad_to_deg(game.boat_motion.roll),
		"camera_roll_degrees":rad_to_deg(game.camera.rotation.z),"waves":game.ocean.wave_field.waves.size()}
	print("WATER VIEW " + label)

func benchmark() -> Dictionary:
	var results := {}
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for count in [0, 4]:
		place()
		for i in range(count):
			game.ocean.wave_field.add_wave(Vector2(-324+i*8,-330-i*5),Vector2(1,0.3*i),0.65+i*0.4,4.8,26,0.1,0,1000)
		game.sea_time = 3.0
		var intervals: Array[float] = []
		var gpu: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in range(210):
			game._update_view(DT)
			await process_frame
			RenderingServer.force_draw(true, DT)
			var now := Time.get_ticks_usec()
			if frame >= 30:
				intervals.append((now-previous)/1000.0)
				var elapsed: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				if elapsed > 0.0:
					gpu.append(elapsed)
			previous = now
		intervals.sort()
		gpu.sort()
		results[str(count)] = {"whole_frame_median_ms":intervals[intervals.size()/2],
			"whole_frame_p95_ms":intervals[int(intervals.size()*0.95)],
			"gpu_median_ms":gpu[gpu.size()/2] if not gpu.is_empty() else null,
			"samples":intervals.size(),"vertices":game.ocean.near_mesh.mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size(),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	results["note"] = "1280x720 native Compatibility, Standard quality, 30 warmup + 180 fixed-view frames; explicit drawing, no capture/readback while timing. Whole-frame timing includes scripted stepping."
	print("WATER BENCHMARK " + JSON.stringify(results))
	return results

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the native renderer for water appearance and GPU measurements.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	if not baseline_source.is_empty():
		# Reproduce the saved shader in memory. Never swap or overwrite working files.
		var include_source := FileAccess.get_file_as_string(baseline_source.path_join("ldjam_60/game/ocean/waves.gdshaderinc"))
		baseline_shader = Shader.new()
		baseline_shader.code = FileAccess.get_file_as_string(baseline_source.path_join("ldjam_60/game/sea.gdshader")).replace('#include "res://game/ocean/waves.gdshaderinc"',include_source)
		baseline_wake_shader = Shader.new()
		baseline_wake_shader.code = FileAccess.get_file_as_string(baseline_source.path_join("ldjam_60/game/ocean/wake.gdshader")).replace('#include "res://game/ocean/waves.gdshaderinc"',include_source)
		game.ocean.material.shader = baseline_shader
		for mat: ShaderMaterial in game.ocean.wake_root.materials:
			mat.shader = baseline_wake_shader
		game.ocean._sync_settings()
	await physics_frame
	await process_frame
	if not benchmark_only:
		place()
		await advance(2.0)
		await capture("01-calm-night")
		place(OPEN,"choppy")
		await advance(2.0)
		await capture("02-rolling-open-water")
		place()
		crest(Vector2.RIGHT,1.1)
		await advance(1.5)
		await capture("03-port-approach")
		place()
		crest(Vector2.LEFT,1.1)
		await advance(1.5)
		await capture("04-starboard-approach")
		place()
		crest(Vector2.RIGHT,1.85)
		await advance(2.8,0.0,true)
		await capture("05-large-impact")
		await advance(5.7,0.0,true)
		await capture("07-recovery")
		place()
		crest(Vector2.RIGHT,1.1,3.0)
		crest(Vector2.LEFT,0.8,3.2)
		crest(Vector2.DOWN,1.5,3.4)
		crest(Vector2(1,1).normalized(),0.65,3.6)
		await advance(2.6)
		await capture("06-four-crests")
		place(OPEN,"choppy")
		crest(Vector2.RIGHT,1.1)
		game.cannon.set_aim_held(true)
		game.cannon.update_aim(DT)
		await advance(2.0)
		await capture("08-cannon-chop")
		place(Vector3(-156,0,20))
		game.heading = PI/2
		game.boat.rotation.y = -game.heading
		game._sailing_camera_initialized = false
		game.ocean.wave_field.add_wave(Vector2(-146,40),Vector2.RIGHT,1.4,4.8,12,8,0,8)
		await advance(1.5)
		await capture("09-rocky-coast")
		place()
		await advance(1.0)
		game.camera.position = OPEN + Vector3(-8,5,8)
		game.camera.look_at(OPEN + Vector3(5,1,-80))
		await capture("10-night-horizon")
		place()
		crest(Vector2.RIGHT,1.85)
		await advance(2.3)
		game.reading = true
		game._update_view(1.8)
		game.hud._process(DT)
		await capture("11-stargazing-impact")
		place()
		await advance(4.5,0.45)
		game.camera.position = game.boat.position+Vector3(0,28,14)
		game.camera.look_at(game.boat.position+Vector3(0,0,8))
		await capture("12-curved-wake")
	var timings := await benchmark()
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"views":frames,"benchmark":timings,"response":trace},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	await process_frame
	quit()

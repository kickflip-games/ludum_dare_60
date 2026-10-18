extends SceneTree
## Native palette comparison plus real scheduled wave contact under held Shift.
var game
var output := ""
var metrics: Array[Dictionary] = []

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../build/night_shift/rendered")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0)
	await process_frame
	RenderingServer.force_draw(true,1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	metrics.append({"frame":label,"time":game.sea_time,"propulsion":game.propulsion_speed(),
		"actual_speed":game.actual_speed,"boosting":game.boosting,"waves":game.wave_encounters.total_launched,
		"active_crests":game.ocean.wave_field.waves.size(),"drift":game.wave_sailing.drift.length(),
		"yaw":game.wave_sailing.yaw_rate,"combat":game.enemy_encounters.battle_active(),
		"clearance":game.camera.position.y-game.ocean.height_at(Vector2(game.camera.position.x,game.camera.position.z))})
	print("NIGHT CAPTURE: "+label)

func stage() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.flow_zones.enabled = false
	game.boat.position = game.arena_center()+Vector3(70,0,-30)
	game.heading = 0
	game.boat.rotation.y = 0
	game.sea_time = 18
	game.ocean.wave_time = 18
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	for frame in 180: game._update_view(1.0/60)

func _run() -> void:
	if DisplayServer.get_name()=="headless":
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
	await capture("shift-controls")
	stage()
	var final_settings: Resource = game.ocean_settings.duplicate(true)
	game.ocean_settings.trough_color = Color("125d85")
	game.ocean_settings.main_color = Color("177ca5")
	game.ocean_settings.slope_color = Color("309bb8")
	game.ocean_settings.crest_color = Color("72bed3")
	game.ocean_settings.foam_color = Color("d5ebf1")
	game.ocean._sync_settings()
	game._update_view(1.0/60)
	await capture("before-blue-water")
	game.ocean_settings = final_settings
	game.ocean._sync_settings()
	game._update_view(1.0/60)
	await capture("after-dark-night-water")
	stage()
	game.boat.position = game.arena_center()+Vector3(115,0,75)
	game.sea_time = 0
	game.ocean.wave_time = 0
	game.wave_encounters.enabled = true
	game.enemy_encounters.enabled = true
	game.enemy_encounters.next_wave_in = 0
	game.damage_immunity = 1000 # Protected capture, not a successful combat playthrough.
	Input.action_press("boost_sailing")
	var contact_captured := false
	for frame in 780:
		game._physics_process(1.0/60)
		game.cannon.advance(1.0/60)
		if frame%30==0: await process_frame
		if frame==360: await capture("shift-boost-sailing")
		if game.wave_encounters.total_launched>0 and game.wave_sailing.drift.length()>0.25 and not contact_captured:
			contact_captured = true
			await capture("scheduled-wave-push")
		if frame>=480 and frame%15==0: await capture("wave-motion-%02d" % ((frame-480)/15))
	Input.action_release("boost_sailing")
	game._physics_process(1.0/60)
	await capture("shift-released")
	var fire := InputEventKey.new()
	fire.physical_keycode = KEY_SPACE
	fire.pressed = true
	Input.parse_input_event(fire)
	Input.flush_buffered_events()
	for frame in 36: game._physics_process(1.0/60)
	await capture("night-starboard-cone")
	fire.pressed = false
	Input.parse_input_event(fire)
	Input.flush_buffered_events()
	root.size = Vector2i(900,506)
	game.restart()
	game.state = game.State.READY
	game._update_view(0.1)
	await capture("shift-controls-small")
	var file := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	game.queue_free()
	await process_frame
	quit()

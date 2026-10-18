extends "res://tests/dynamic_water_previews.gd"
## Development-only production fixture. No fixture or control ships in release.
var views_only := false
var effects := true

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/water_review/turbulence_camera/after")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--clip": record_clip = true
		if arg == "--views-only": views_only = true
		if arg == "--no-effects": effects = false
	_run.call_deferred()

func action(name: String,pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func advance(seconds: float, steering: float = 0.0, clip: bool = false) -> void:
	for frame in range(roundi(seconds/DT)):
		if steering<0: Input.action_press("steer_port",-steering)
		if steering>0: Input.action_press("steer_starboard",steering)
		game._physics_process(DT)
		game.cannon.advance(DT)
		game.hud._process(DT)
		if clip:
			trace.append({"time":game.sea_time,"heave":game.boat_motion.heave,
				"hull_pitch":game.boat_motion.pitch,"hull_roll":game.boat_motion.roll,
				"camera_pitch":game.camera.rotation.x,"camera_roll":game.camera.rotation.z,
				"camera_y":game.camera.position.y,"clearance":game.camera.position.y-game.ocean.height_at(Vector2(game.camera.position.x,game.camera.position.z)),
				"contact_ids":game.turbulence_effects.last_events.duplicate(),"effects":game.turbulence_effects.active_count})
		if frame%3==0:
			await process_frame
			if clip and record_clip:
				RenderingServer.force_draw(true,DT)
				root.get_texture().get_image().save_png(output.path_join("clip/%04d.png" % clip_index))
				clip_index += 1

func _run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.development_tools = true
	if "development_spray" in game:
		game.development_spray = effects
		game.development_overlays = effects
		game.development_sound = effects
	await physics_frame
	place()
	await capture("01-calm-deck")
	action("watch_starboard",true)
	await advance(0.4)
	await capture("02-cannon-entry")
	action("fire_starboard",true)
	action("fire_starboard",false)
	await advance(0.6)
	await capture("03-real-cannon")
	action("astrolabe",true)
	await advance(2.0)
	await capture("04-sighting")
	action("astrolabe",false)
	action("watch_starboard",false)
	if not views_only:
		for scenario in ["front","port","starboard","oblique","four"]:
			place()
			var directions := {"front":Vector2.DOWN,"port":Vector2.RIGHT,"starboard":Vector2.LEFT,"oblique":Vector2(1,1).normalized()}
			if scenario == "four":
				for direction: Vector2 in directions.values(): crest(direction,1.85,3.0)
			else:
				crest(directions[scenario],1.85,3.0)
			await advance(2.8,0.0,record_clip)
			await capture(scenario+"-impact")
			await advance(5.2,0.0,record_clip)
			await capture(scenario+"-recovery")
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frames,"trace":trace},"\t"))
	game.queue_free()
	await process_frame
	quit()

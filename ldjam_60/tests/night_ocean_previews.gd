extends "res://tests/sailing_camera_previews.gd"
## Matched water/effect views. Low-speed movement is a visual fixture, not new controls.
var record_clip := false
var clip_frame := 0
var tick := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--clip":
			record_clip = true
	_run.call_deferred()

func water_step(seconds: float, speed: float, turn: float = 0.0) -> void:
	for frame in range(roundi(seconds*60)):
		game.heading += turn/60.0
		game.boat.rotation.y = -game.heading
		var previous: Vector3 = game.boat.position
		game.boat.move_and_collide(Vector3(sin(game.heading),0,-cos(game.heading))*speed/60.0)
		game.actual_speed = game.boat.position.distance_to(previous)*60.0
		game.sea_time += 1.0/60
		game.elapsed += 1.0/60
		game.cannon.update_aim(1.0/60)
		game._update_view(1.0/60)
		game.cannon.advance(1.0/60)
		game.hud._process(1.0/60)
		await process_frame
		if record_clip and tick%6 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("clip/%04d.png" % clip_frame))
			clip_frame += 1
		tick += 1

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await process_frame
	place(game.archipelago.get_node("SpawnPoints/Departure").position,game.START_HEADING)
	game.wave_encounters.enabled = false
	await water_step(1.0,0)
	await capture("01-stationary")
	await water_step(3.0,1.4)
	await capture("02-low-speed")
	await water_step(4.5,6.3)
	await capture("03-cruising")
	await water_step(3.0,6.3,0.50)
	await capture("04-turning")
	game.camera.position = game.boat.position+Vector3(2,31,18)
	game.camera.look_at(game.boat.position+game.course_forward()*-8)
	await capture("05-curved-wake-overview")
	place(Vector3(-156,0,20),PI/2)
	await water_step(0.5,0)
	await capture("06-coastal-foam")
	place(Vector3(-184,0,-106),PI/2)
	await water_step(0.5,0)
	await capture("07-rock-foam")
	place(Vector3(-300,0,-330),0)
	await water_step(0.5,6.3)
	action("watch_starboard",true)
	await water_step(0.5,6.3)
	await capture("08-cannon-ocean")
	game.cannon.cooldown = 0
	game.cannon.fire()
	var impact := Vector3.ZERO
	for frame in range(300):
		await water_step(1.0/60,0)
		for effect: Dictionary in game.cannon.effects:
			if effect.get("ring",false):
				impact = effect.node.position
		if impact != Vector3.ZERO:
			break
	await water_step(0.10,0)
	game.camera.position = impact+Vector3(5,4,8)
	game.camera.look_at(impact+Vector3.UP*0.6)
	await capture("09-cannon-water-impact")
	place(Vector3(-280,0,-330),0)
	game.sea_time = 3
	game.ocean.wave_field.add_wave(Vector2(-280,-376),Vector2(0,1),1.4,4.8,26,8,0,9)
	await water_step(0.1,0)
	await capture("10-moonlit-wave")
	record_clip = false
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(180):
		await water_step(1.0/60,6.3)
		var now := Time.get_ticks_usec()
		if frame >= 30:
			intervals.append((now-previous)/1000.0)
		previous = now
	intervals.sort()
	frames["cadence"] = {"median_ms":intervals[intervals.size()/2],"p95_ms":intervals[int(intervals.size()*0.95)],"clip_frames":clip_frame,"note":"Native whole-frame cadence with scripted stepping; not isolated GPU timing."}
	var file := FileAccess.open(output.path_join("water-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(frames,"\t"))
	file.close()
	print("WATER REVIEW "+JSON.stringify(frames["cadence"]))
	game.queue_free()
	await process_frame
	await process_frame
	quit()

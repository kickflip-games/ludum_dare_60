extends "res://tests/dynamic_water_previews.gd"
## Identical real-arena poses for source-snapshot comparisons; no production changes.
var path_trace: Array[Dictionary] = []

func place(at: Vector3 = Vector3(345,0,230), _preset: String = "calm") -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game._sound_enabled = false
	game.boat.position = at
	game.heading = 0.0
	game.boat.rotation = Vector3.ZERO
	game.sea_time = 0.0
	game.elapsed = 0.0
	game.phase_banner_left = 0.0
	game.actual_speed = 0.0
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	game._update_view(DT)

func sail(seconds: float, steering: float = 0.0, moving: bool = true, clip: bool = false) -> void:
	for i in range(roundi(seconds/DT)):
		if moving:
			game.advance_sailing(DT,steering)
		else:
			game.sea_time += DT
			game.actual_speed = 0.0
		game._update_view(DT)
		game.cannon.advance(DT)
		game.hud._process(DT)
		path_trace.append({"t":game.sea_time,"p":str(game.boat.position),"heading":game.heading,
			"speed":game.actual_speed,"drift":str(game.wave_sailing.drift),"yaw":game.wave_sailing.yaw_rate})
		if i%3==0:
			await process_frame
			if clip and record_clip:
				RenderingServer.force_draw(true,DT)
				root.get_texture().get_image().save_png(output.path_join("clip/%04d.png" % clip_index))
				clip_index += 1

func approaching(count: int) -> void:
	var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
	var target := Vector2(center.x,center.z-game.propulsion_speed()*2.6)
	for i in range(count):
		var d := Vector2(1,0.3).rotated(i*PI/2)
		game.ocean.wave_field.add_wave(target-d*8*2.6,d,1.85,4.8,30,8,game.sea_time,9)

func _run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await process_frame
	place()
	await sail(1,0,false)
	await capture("01-stationary")
	game.sailing_speed = 1.4
	await sail(3)
	await capture("02-slow")
	game.sailing_speed = 7.5
	place()
	await sail(4.5)
	await capture("03-cruise")
	place()
	game.boosting = true
	await sail(4.5)
	await capture("04-boost")
	place()
	for zone in game.flow_zones.zones: game.flow_zones.collected[zone.id] = true
	game.boosting = true
	await sail(4.5)
	await capture("05-flow-boost")
	place()
	await sail(2)
	await sail(2,-1)
	await capture("06-port-turn")
	game.camera.position = game.boat.position+Vector3(4,27,22)
	game.camera.look_at(game.boat.position+Vector3(0,0,7))
	await capture("07-wake-overview")
	place()
	await sail(2)
	await sail(2,1)
	await capture("08-starboard-turn")
	place()
	approaching(1)
	await sail(2.7,0,true,true)
	await capture("09-impact")
	await sail(0.25,0,true,true)
	await capture("10-impact-recovery")
	await sail(0.4,0,true,true)
	await capture("15-directional-burst")
	await sail(0.6,0,true,true)
	place()
	approaching(4)
	await sail(2.7)
	await capture("11-four-crests")
	place()
	game.ocean_quality = 0
	game.ocean.set_quality(0)
	await sail(4.5)
	await capture("12-low-quality")
	game.ocean_quality = 1
	game.ocean.set_quality(1)
	place()
	game.arena_cannon_view = true
	await sail(4.5)
	await capture("13-cannon")
	place()
	await sail(0.1,0,false)
	await capture("14-retry")
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frames,"trajectory":path_trace},"\t"))
	game.queue_free()
	await process_frame
	quit()

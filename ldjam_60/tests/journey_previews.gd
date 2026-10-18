extends SceneTree
## Native screenshots and a physically sailed, input-driven complete voyage.
var game
var output := ""
var capture_voyage := false
var failures := 0

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../build/navigation_review/after").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg == "--voyage": capture_voyage = true
	run.call_deferred()

func capture(label: String) -> void:
	game._update_view(0.0)
	game.hud._process(0.0)
	await process_frame
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	print("CAPTURE "+label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280,720)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.heading = game.destination_bearing()
	game._update_view(1.0)
	await capture("01-red-star-sextant")
	game.voyage.leg = 1
	game.voyage.set_target(game)
	game.heading = game.destination_bearing()
	game._update_view(0.5)
	await capture("02-blue-star")
	game.storm_blend = 1.0
	game._update_view(0)
	await capture("03-storm-star")
	# Pixel evidence isolates the actual sky light from the HUD's halo.
	var at: Vector2 = game.hud._star_screen_position()
	game.hud.hide()
	RenderingServer.force_draw(true)
	var bright: Image = root.get_texture().get_image()
	game.sky_material.set_shader_parameter("target_focus",0.0)
	RenderingServer.force_draw(true)
	var ordinary: Image = root.get_texture().get_image()
	var gain := 0.0
	for y in range(int(at.y)-6,int(at.y)+7):
		for x in range(int(at.x)-6,int(at.x)+7):
			if x >= 0 and y >= 0 and x < bright.get_width() and y < bright.get_height():
				var a := bright.get_pixel(x,y)
				var b := ordinary.get_pixel(x,y)
				gain += a.r+a.g+a.b-b.r-b.g-b.b
	print("NATIVE STAR PIXEL GAIN %.4f" % gain)
	if gain < 0.1: failures += 1
	game.hud.show()
	game.update_guiding_star()
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.1)
	game._update_view(0.5)
	await capture("04-cannon-sextant")
	game.cannon.cancel_aim()
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(350,0,-75)
	game.voyage.leg = 8
	game.voyage.set_target(game)
	game.heading = game.destination_bearing()
	for frame in range(240):
		game._physics_process(1.0/60)
		if frame%6 == 0: await process_frame
	await capture("05-aligned-turbulence-wind")
	if capture_voyage:
		game.restart()
		game.state = game.State.SAILING
		game.enemy_encounters.enabled = true
		var previous_leg := -1
		for frame in range(60*240):
			var steer: float = clampf(game.destination_turn()*3.0-game.wave_sailing.yaw_rate*0.7,-1,1)
			Input.action_press("steer_port",maxf(0,-steer))
			Input.action_press("steer_starboard",maxf(0,steer))
			game._physics_process(1.0/60)
			game.cannon.advance(1.0/60)
			if previous_leg != game.voyage.leg:
				previous_leg = game.voyage.leg
				await capture("voyage-leg-%02d" % previous_leg)
			if frame%6 == 0: await process_frame
			if game.state != game.State.SAILING: break
		# Let the real result menu and ending camera finish their entry animation.
		game._update_view(0.8)
		game.hud._process(0.8)
		await capture("06-lighthouse-arrival")
		print("NATIVE VOYAGE state=%d time=%.2f hull=%d zones=%d" % [game.state,game.elapsed,game.hull,game.wave_encounters.star_history.size()])
		if game.state != game.State.ARRIVED: failures += 1
	game.free()
	quit(0 if failures == 0 else 1)

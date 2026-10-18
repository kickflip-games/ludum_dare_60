extends "res://tests/stargazing_previews.gd"
## Real renderer and Space input. Poses/stages are controlled comparison fixtures;
## the separate archipelago_voyage completes the journey without teleporting.
var observations: Array[Dictionary] = []
var pixel_checks := 0
var pixel_failures := 0

func record(label: String) -> void:
	capture(label)
	if game.focus_strength >= 1 and game.hud.star_guidance().get("visible", false):
		await verify_star_pixels(label)
	observations.append({"image": label, "stage": game.voyage.stage,
		"position": str(game.boat.global_position), "heading": game.heading,
		"bearing": game.destination_bearing(), "ray": str(game.guiding_star_direction()),
		"focus": game.focus_strength, "guidance": game.hud.star_guidance()})

func verify_star_pixels(label: String) -> void:
	# Isolate the sky shader from its delicate HUD halo at the same pose/clock.
	await process_frame
	var logical_at: Vector2 = game.hud._star_screen_position()
	game.hud.hide()
	RenderingServer.force_draw(true, 1.0 / 60)
	var focused: Image = root.get_texture().get_image()
	# canvas_items stretches logical HUD/camera coordinates into native pixels.
	var at := Vector2i(logical_at * Vector2(focused.get_size()) / game.hud.size)
	game.sky_material.set_shader_parameter("target_focus", 0.0)
	RenderingServer.force_draw(true, 1.0 / 60)
	var ordinary: Image = root.get_texture().get_image()
	var delta := 0.0
	var peak := 0.0
	for y in range(at.y - 6, at.y + 7):
		for x in range(at.x - 6, at.x + 7):
			if x < 0 or y < 0 or x >= focused.get_width() or y >= focused.get_height():
				continue
			var a := focused.get_pixel(x, y)
			var b := ordinary.get_pixel(x, y)
			var change := (a.r + a.g + a.b - b.r - b.g - b.b) / 3.0
			delta += change
			peak = maxf(peak, change)
	var outside_delta := 0.0
	for y in range(10, focused.get_height(), 24):
		for x in range(10, focused.get_width(), 24):
			if Vector2(x, y).distance_to(Vector2(at)) > 32:
				var a := focused.get_pixel(x, y)
				var b := ordinary.get_pixel(x, y)
				outside_delta = maxf(outside_delta, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
	pixel_checks += 1
	if delta < 0.1 or peak < 0.02 or outside_delta > 0.01:
		pixel_failures += 1
		focused.save_png(output.path_join("failed-" + label + ".png"))
	print("STAR PIXELS %s: local gain=%.4f peak=%.4f unrelated sky delta=%.4f" % [label, delta, peak, outside_delta])
	game.update_guiding_star()
	game.hud.show()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	capture_clip = false
	DirAccess.make_dir_recursive_absolute(output)
	root.size = requested_size
	# Scripted captures must remain reproducible while the user works in another
	# app. Real focus-loss behavior is exercised separately by stargazing_smoke.
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.start_crossing()
	await advance(game.CAST_OFF_SECONDS + 0.5)
	await record("01-normal-sailing")
	Input.action_press("astrolabe")
	await advance(0.5)
	await record("02-before-focus")
	await advance(0.75)
	await record("03-partial-focus")
	await advance(0.55)
	await record("04-focused-gold")
	Input.action_release("astrolabe")
	await advance(1.0 / 60)
	await record("05-release-first-frame")
	await advance(0.4)
	await record("06-return-sailing")
	Input.action_press("astrolabe")
	game.heading = game.destination_bearing() + deg_to_rad(45)
	game.wave_sailing.reset()
	await advance(1.8)
	await record("07-star-port")
	game.heading = game.destination_bearing() - deg_to_rad(45)
	game.wave_sailing.reset()
	await advance(0.1)
	await record("08-star-starboard")
	game.heading = game.destination_bearing() - deg_to_rad(145)
	game.wave_sailing.reset()
	await advance(0.1)
	await record("09-peripheral-starboard")
	game.heading = game.destination_bearing() + deg_to_rad(145)
	game.wave_sailing.reset()
	await advance(0.1)
	await record("10-peripheral-port")
	game.heading = game.destination_bearing() + PI
	game.wave_sailing.reset()
	await advance(0.1)
	await record("11-peripheral-astern")
	# Controlled real region entries establish the appearance of each stage.
	game.boat.position = game.target
	game.voyage.update_progress(game)
	await advance(1.0 / 60)
	await record("12-stage-clears-old-focus")
	Input.action_release("astrolabe")
	game.heading = game.destination_bearing()
	game.wave_sailing.reset()
	await advance(0.4)
	await record("13-wreck-discovery")
	Input.action_press("astrolabe")
	await advance(1.8)
	await record("14-focused-blue")
	game.boat.position = game.target
	game.voyage.update_progress(game)
	Input.action_release("astrolabe")
	game.heading = game.destination_bearing()
	game.wave_sailing.reset()
	await advance(0.4)
	await record("15-peaks-discovery")
	Input.action_press("astrolabe")
	await advance(1.8)
	await record("16-focused-coral")
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 40
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0
	ship.locked_point = game.boat.position
	await advance(0.1)
	await record("17-focus-during-combat")
	Input.action_release("astrolabe")
	await advance(0.4)
	await record("18-return-combat")
	# Open-water wave fixture: sailing, yaw, star ray and camera remain live.
	ship.reset()
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(-380, 0, -350)
	game.heading = game.destination_bearing()
	game.wave_sailing.reset()
	var forward := Vector2(sin(game.heading), -cos(game.heading))
	var d := Vector2(1, -0.5).normalized().rotated(game.heading)
	game.ocean.wave_field.add_wave(Vector2(-380, -350) + forward * 18.9 - d * 24, d, 1.0, 4.0, 26.0, 8.0, game.sea_time, 8.0)
	Input.action_press("astrolabe")
	await advance(3.0)
	await record("19-focused-during-wave")
	Input.action_release("astrolabe")
	await advance(0.4)
	await record("20-return-during-wave")
	# Canonical renderer/projection cases, including wraparound and different
	# positions; these do not route the ship or alter production camera logic.
	game.ocean.wave_field.clear()
	Input.action_press("astrolabe")
	await advance(1.8)
	for example in [[0, 0], [0, -45], [0, 45], [0, 180], [359, 1], [1, 359], [179, -179], [-179, 179]]:
		game.boat.position = Vector3(400, 0, -360)
		game.heading = deg_to_rad(example[0])
		var bearing := deg_to_rad(example[1])
		game.target = game.boat.position + Vector3(sin(bearing), 0, -cos(bearing)) * 300
		game._update_view(0.0)
		game.hud._process(0.0)
		if game.hud.star_guidance().visible:
			await verify_star_pixels("heading-%s-target-%s" % example)
	Input.action_release("astrolabe")
	var file := FileAccess.open(output.path_join("observations.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(observations, "\t"))
	file.close()
	print("STAR PIXEL CHECK: %d checks, %d failures" % [pixel_checks, pixel_failures])
	game.queue_free()
	await process_frame
	quit(0 if pixel_checks >= 5 and pixel_failures == 0 else 1)

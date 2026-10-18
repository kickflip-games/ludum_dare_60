extends SceneTree
## Frozen UI/combat views for native review, separate from a human playthrough.
var game
var output := "res://../build/menu_ui/combat"
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(0.5)
	for frame in 5: await process_frame
	RenderingServer.force_draw(true, 1.0 / 60)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("COMBAT UI CAPTURE: " + path)

func cloth_pixels(pale: bool = false) -> int:
	var pixels := root.get_texture().get_image()
	var count := 0
	for y in range(0, pixels.get_height() / 2, 4):
		for x in range(pixels.get_width() / 3, pixels.get_width(), 4):
			var color := pixels.get_pixel(x, y)
			var is_cloth := color.r > 0.7 and color.g > 0.65 and color.b > 0.35 and color.b < color.r * 0.95 if pale else color.r > 0.15 and color.r > color.g * 1.15 and color.r > color.b * 1.25
			if is_cloth:
				count += 1
	return count

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.start_crossing()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game.heading = 0.0
	game._update_view(1)
	game.enemy_encounters.wave_number = 1
	await capture("early-wave")
	game.enemy_encounters.wave_number = 4
	game.enemy_encounters.announcement_left = 1.0
	await capture("wave-announcement")
	game.enemy_encounters.announcement_left = 0.0
	game.enemy_encounters.wave_number = 5
	await capture("late-wave")
	game.show_discovery("CURRENT CAUGHT · +25%", 2)
	await capture("flow-pickup")
	game.discovery_left = 0
	var enemy = game.enemy_encounters.ship
	enemy.begin(game.boat.position + Vector3(24, 0, -10))
	game.enemy_encounters.enabled = true
	enemy.mode = enemy.Mode.TELEGRAPH
	game.enemy_encounters.announcement_left = 1.0
	await capture("danger-priority")
	game.motion_setting = 1
	await capture("danger-reduced")
	game.enemy_encounters.enabled = false
	enemy.reset()
	game.enemy_encounters.announcement_left = 0
	game.motion_setting = 0
	game.arena_cannon_view = true
	for yaw in [-45, 0, 45]:
		game.look_yaw = yaw
		game.look_target = yaw
		game.look_idle = 0
		game._update_view(0.5)
		await capture("close-player-%d" % yaw)
	# Nearby enemy sails can enter either view without changing target eligibility.
	for close_view in [false, true]:
		game.arena_cannon_view = close_view
		game.look_yaw = 0
		game.look_target = 0
		game._update_view(1)
		enemy.begin(game.boat.position + Vector3(5, 0, 0))
		await capture("nearby-enemy-close" if close_view else "nearby-enemy-chase")
	# Native GPU comparison: a giant near sail clears, a distant sail stays opaque.
	for distance in [5, 24]:
		enemy.position = game.boat.position + Vector3(distance, 0, 0)
		enemy.sail_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
		await capture("cloth-%d-opaque" % distance)
		var opaque := cloth_pixels()
		enemy.sail_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		await capture("cloth-%d-fade" % distance)
		var faded := cloth_pixels()
		var ok := opaque > 10 and (faded < opaque * 0.25 if distance == 5 else faded >= opaque * 0.95)
		if not ok: failures += 1
		print(("PASS" if ok else "FAIL") + ": cloth at %d m: opaque=%d faded=%d" % [distance, opaque, faded])
	# A real finite crest, held rudder and physical shot in each retained camera.
	game.damage_immunity = 1000
	for close_view in [false, true]:
		game.arena_cannon_view = close_view
		game._update_view(1)
		var point := Vector2(game.boat.position.x, game.boat.position.z)
		game.ocean.wave_field.clear()
		game.ocean.wave_field.add_wave(point - Vector2.RIGHT, Vector2.RIGHT, 1.5, 6, 60, 1, game.sea_time - 1)
		for action in ["steer_starboard", "fire_starboard"]:
			var event := InputEventAction.new()
			event.action = action
			event.pressed = true
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		for frame in 20:
			game._physics_process(1.0 / 60)
			game.cannon.advance(1.0 / 60)
		await capture("crest-turn-fire-close" if close_view else "crest-turn-fire-chase")
		if close_view:
			var sail: MeshInstance3D = game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail")
			for surface in sail.mesh.get_surface_count():
				sail.get_active_material(surface).distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
			await capture("crest-player-opaque")
			var opaque := cloth_pixels(true)
			for surface in sail.mesh.get_surface_count():
				sail.get_active_material(surface).distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			await capture("crest-player-fade")
			var faded := cloth_pixels(true)
			var ok := opaque > 100 and faded < opaque * 0.25
			if not ok: failures += 1
			print(("PASS" if ok else "FAIL") + ": player cloth on crest: opaque=%d faded=%d" % [opaque, faded])
		for action in ["steer_starboard", "fire_starboard"]:
			var event := InputEventAction.new()
			event.action = action
			event.pressed = false
			Input.parse_input_event(event)
		Input.flush_buffered_events()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

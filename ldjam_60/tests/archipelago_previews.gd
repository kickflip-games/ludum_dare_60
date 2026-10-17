extends SceneTree
## Native rendered review shots; curated camera positions are separate from voyage testing.
var game
var output := ProjectSettings.globalize_path("res://../artifacts/archipelago/final")
func _initialize() -> void:
	_run.call_deferred()
func capture(label: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var err: int = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("CAPTURE %s %d" % [label, err])
func pose(boat_at: Vector3, at: Vector3, focus: Vector3, stage: int) -> void:
	game.boat.position = boat_at
	game.voyage.stage = stage
	game.voyage.set_target(game)
	game.heading = atan2(focus.x - boat_at.x, -(focus.z - boat_at.z))
	game.reading = false
	game._update_view(1.0)
	game.camera.position = at
	game.camera.look_at(focus)
	game.camera.fov = 74
	game.hud._process(0.1)
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in range(60):
		await process_frame
	game.state = game.State.SAILING
	game.elapsed = 37.2
	game.has_reading = true
	game.archipelago.toggle_debug()
	await capture("01-overview")
	game.archipelago.toggle_debug()
	pose(Vector3(0,0,104), Vector3(0,2.65,104), Vector3(-115,13,-40), 0)
	await capture("02-departure")
	pose(Vector3(-208,0,-128), Vector3(-197,4.8,-119), Vector3(-248,5,-163), 0)
	await capture("03-wreck")
	pose(Vector3(226,0,-140), Vector3(226,4.4,-130), Vector3(226,25,-218), 1)
	await capture("04-twin-peaks")
	pose(Vector3(334,0,-60), Vector3(351,7,-41), Vector3(306,7,-80), 2)
	game.enemy_encounters.ship.begin(Vector3(310,0,-77))
	game.enemy_encounters.ship.heading = -1.9
	game.enemy_encounters.ship.rotation.y = 1.9
	game.enemy_encounters.ship.update_visuals(0.1)
	await capture("05-pirate-territory")
	game.enemy_encounters.ship.reset()
	pose(Vector3(298,0,158), Vector3(305,3.2,152), Vector3(275,30,250), 2)
	game.beacon.visible = true
	await capture("06-lighthouse")
	pose(Vector3(-180,0,30), Vector3(-180,3,30), Vector3(-80,20,-60), 1)
	game.reading = true
	game.read_blend = 1
	game.focus_elapsed = 2
	game._update_view(0)
	game.hud._process(0.1)
	await capture("07-stargazing")
	# Capture a rising instrument frame that includes the island horizon.
	game.read_blend = 0.43
	game._update_view(0)
	game.hud._process(0.1)
	await capture("08-stargazing-horizon")
	print("NATIVE PREVIEWS COMPLETE")
	game.queue_free()
	await process_frame
	quit()

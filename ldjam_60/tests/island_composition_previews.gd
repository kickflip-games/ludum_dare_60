extends "res://tests/archipelago_previews.gd"
## Repeatable views of the actual helm, shore, passage and complete island layout.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in range(60):
		await process_frame
	game.restart()
	game.state = game.State.SAILING
	game.elapsed = 37.2
	game.sea_time = 37.2
	game._update_view(1.0)
	game.hud._process(0.0)
	await capture("01-initial-sailing")
	game.hud.hide()
	pose(Vector3(-158,0,94), Vector3(-158,10,94), Vector3(-12,22,-44), 0)
	await capture("02-central-island")
	pose(Vector3(-150,0,30), Vector3(-150,3.4,30), Vector3(-97,11,-15), 0)
	await capture("03-rocky-coast")
	pose(Vector3(226,0,-140), Vector3(226,4.4,-130), Vector3(226,22,-218), 1)
	await capture("04-twin-peaks-channel")
	pose(Vector3(-40,0,160), Vector3(-40,4,160), Vector3(-25,9,-170), 0)
	await capture("05-distant-silhouettes")
	game.archipelago.toggle_debug()
	game.archipelago.debug_layer.hide()
	await capture("06-top-down")
	game.archipelago.toggle_debug()
	game.hud.hide()
	pose(Vector3(298,0,158), Vector3(305,3.2,152), Vector3(275,30,250), 2)
	game.beacon.visible = true
	await capture("07-lighthouse")
	pose(Vector3(-208,0,-128), Vector3(-197,4.8,-119), Vector3(-248,5,-163), 0)
	await capture("08-wreck")
	var dressing = game.archipelago.get_node("IslandDressing")
	var report := {"spawn":str(game.archipelago.get_node("SpawnPoints/Departure").position),
		"trees":dressing.get_meta("tree_count"), "boulders":dressing.get_meta("boulder_count"),
		"grass":dressing.get_meta("grass_count"), "outcrops":dressing.get_meta("outcrop_count"), "captures":8}
	var file := FileAccess.open(output.path_join("composition.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ISLAND COMPOSITION " + JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit()

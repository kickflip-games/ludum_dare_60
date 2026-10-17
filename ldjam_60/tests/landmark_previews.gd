extends "res://tests/archipelago_previews.gd"
## Matched native views; curated cameras are separate from physical voyage tests.
var report: Dictionary = {}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Landmark review requires the native renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	game.restart()
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.phase_banner_left = 0
	game.elapsed = 37.2
	game.sea_time = 7.0
	game.hud.hide()
	pose(Vector3(-151,0,-66), Vector3(-144,5.5,-60), Vector3(-248,5.5,-163), 0)
	await capture("01-wreck-distant")
	pose(Vector3(-223,0,-141), Vector3(-225,5.7,-139), Vector3(-248,5,-163), 0)
	await capture("02-wreck-close")
	pose(Vector3(226,0,-135), Vector3(226,5.6,-127), Vector3(226,25,-215), 1)
	await capture("03-twin-peaks-approach")
	pose(Vector3(226,0,-210), Vector3(226,6,-203), Vector3(181,27,-211), 1)
	await capture("04-lookout-shoulder")
	pose(Vector3(350,0,-29), Vector3(350,5.5,-29), Vector3(275,36,250), 2)
	game.beacon.visible = true
	await capture("05-lighthouse-distant")
	pose(Vector3(292,0,170), Vector3(300,6,157), Vector3(268,31,250), 2)
	game.beacon.visible = true
	await capture("06-lighthouse-final-approach")
	pose(Vector3(267,0,182), Vector3(269,4.5,183), Vector3(261,7,214), 2)
	game.beacon.visible = true
	await capture("07-arrival-harbour")
	pose(Vector3(-186,0,137), Vector3(-183,4.4,139), Vector3(-206,5,120), 0)
	await capture("08-lantern-cove")
	pose(Vector3(-69,0,-233), Vector3(-66,4.7,-230), Vector3(-90,2,-239), 1)
	await capture("09-drifters-cache")
	pose(Vector3(94,0,190), Vector3(98,5,187), Vector3(57,13,212), 2)
	await capture("10-watchmans-rest")
	# Existing terrain is sampled only for placement review, never regenerated.
	var terrain = game.archipelago.get_node("Terrain")
	for xz: Vector2 in [Vector2(177,-217),Vector2(185,-193),Vector2(194,-182),Vector2(284,-217),Vector2(272,-181),Vector2(252,205),Vector2(252,215),Vector2(252,225),Vector2(-208,118),Vector2(-217,120),Vector2(56,212),Vector2(68,210)]:
		report[str(xz)] = terrain.terrain_height_at(Vector3(xz.x,0,xz.y))
	# Frame cadence at the complete lighthouse, without screenshot readback.
	pose(Vector3(292,0,170), Vector3(300,6,157), Vector3(268,31,250), 2)
	game.beacon.visible = true
	for i in 60:
		await process_frame
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 180:
		game.sea_time += 1.0 / 60.0
		game._update_view(0.0)
		game.camera.position = Vector3(300,6,157)
		game.camera.look_at(Vector3(268,31,250))
		game.camera.fov = 74
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now-previous)/1000.0)
		previous = now
	intervals.sort()
	report["frame_ms"] = {"median":intervals[90],"p95":intervals[171],"samples":180}
	# Close construction views without the player model covering the foreground.
	game.boat_visual.hide()
	pose(Vector3(-223,0,-141),Vector3(-236,6.5,-152),Vector3(-248,5.7,-163),0)
	await capture("11-wreck-detail")
	pose(Vector3(267,0,182),Vector3(265,3,205),Vector3(252,1.7,216),2)
	game.beacon.show()
	await capture("12-jetty-detail")
	pose(Vector3(94,0,190),Vector3(78,16,200),Vector3(56,20,212),2)
	await capture("13-watchtower-detail")
	if "--clip" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
		for i in 80:
			game.sea_time = i*0.1
			pose(Vector3(292,0,170),Vector3(300,6,157),Vector3(268,31,250),2)
			game.beacon.show()
			await capture("frames/beam-%04d"%i)
	# Silhouette inspection removes colour, emission, lighting and atmospheric fog.
	# These diagnostic shots are not substituted for the nighttime art captures.
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	blacken(game.archipelago,black)
	for obstacle: Dictionary in game.obstacles:
		blacken(obstacle.body,black)
	game.beacon.hide()
	game.ocean.hide()
	# A flat neutral sea hides the black seabed in this diagnostic. Hiding the
	# ocean alone merges every hull into the exposed seabed silhouette.
	var neutral := StandardMaterial3D.new()
	neutral.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neutral.albedo_color = Color("9ba6b4")
	var sea := PlaneMesh.new()
	sea.size = Vector2(2200,2200)
	game._mesh(game,sea,Vector3(0,game.ocean.settings.sea_level,0),neutral)
	game.world_environment.environment.background_mode = Environment.BG_COLOR
	game.world_environment.environment.background_color = Color("9ba6b4")
	game.world_environment.environment.fog_enabled = false
	pose(Vector3(-223,0,-141),Vector3(-236,6.5,-152),Vector3(-248,5.7,-163),0)
	await capture("14-wreck-silhouette")
	pose(Vector3(226,0,-135),Vector3(226,5.6,-127),Vector3(226,25,-215),1)
	await capture("15-peaks-silhouette")
	pose(Vector3(292,0,170),Vector3(300,6,157),Vector3(268,31,250),2)
	await capture("16-lighthouse-silhouette")
	if game.archipelago.get("story_landmarks") != null:
		report["batches"] = game.archipelago.story_landmarks.get_meta("batch_count")
		report["local_lights"] = game.archipelago.story_landmarks.warm_lights.size()
	var file := FileAccess.open(output.path_join("landmarks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("LANDMARK REVIEW ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit()


func blacken(node: Node, material: Material) -> void:
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		node.material_override = material
	for child in node.get_children(true):
		blacken(child,material)

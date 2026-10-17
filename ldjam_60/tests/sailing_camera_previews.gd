extends SceneTree
## Native, input-driven before/after views of the single sailing camera.
var game
var output := "/tmp/sailing-camera-review"
var frames: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func advance(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		game._physics_process(1.0/60)
		game.cannon.advance(1.0/60)
		game.hud._process(1.0/60)
		await process_frame

func place(at: Vector3, yaw: float) -> void:
	game.restart()
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game.state = game.State.SAILING
	game.boat.position = at
	game.heading = yaw
	game.elapsed = 37.2
	game.sea_time = 37.2
	game.phase_banner_left = 0
	game._update_view(0.0)

func ship_bounds(node: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MeshInstance3D and node.visible:
		for i in range(8):
			points.append(node.global_transform * node.get_aabb().get_endpoint(i))
	for child in node.get_children():
		points.append_array(ship_bounds(child))
	return points

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var err: int = root.get_texture().get_image().save_png(output.path_join(label+".png"))
	var projected := Rect2()
	var first := true
	var points := ship_bounds(game.boat_visual)
	var local_bounds := AABB(game.boat.to_local(points[0]),Vector3.ZERO)
	for point: Vector3 in points:
		local_bounds = local_bounds.expand(game.boat.to_local(point))
		if game.camera.is_position_behind(point):
			continue
		var screen: Vector2 = game.camera.unproject_position(point)
		if first:
			projected = Rect2(screen,Vector2.ZERO)
			first = false
		else:
			projected = projected.expand(screen)
	frames[label] = {"boat_screen_height":projected.size.y/root.size.y,
		"boat_screen_bounds":str(projected),"camera":str(game.camera.position),
		"heading":game.heading,"camera_mode":game.camera_mode,"fov":game.camera.fov,
		"model_bounds_metres":str(local_bounds.size)}
	print("CAMERA CAPTURE %s: %d %s" % [label,err,JSON.stringify(frames[label])])

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await process_frame
	place(game.archipelago.get_node("SpawnPoints/Departure").position,game.START_HEADING)
	await advance(0.6)
	await capture("01-straight")
	action("steer_port",true)
	await advance(1.0)
	await capture("02-turn-port")
	action("steer_port",false)
	action("steer_starboard",true)
	await advance(1.6)
	await capture("03-turn-starboard")
	action("steer_starboard",false)
	place(Vector3(-175,0,-40),PI/2)
	await advance(0.5)
	await capture("04-island-approach")
	place(Vector3(226,0,-150),0)
	game.voyage.stage = 1
	game.voyage.set_target(game)
	await advance(0.6)
	await capture("05-channel")
	action("fire_starboard",true)
	action("fire_starboard",false)
	await advance(0.5)
	await capture("06-cannon-view")
	action("astrolabe",true)
	await advance(1.8)
	await capture("07-stargazing")
	action("astrolabe",false)
	await advance(0.6)
	await capture("08-return-from-stargazing")
	place(Vector3(-151,0,-40),-PI/2)
	await advance(0.1)
	await capture("09-shore-clearance")
	var file := FileAccess.open(output.path_join("framing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(frames,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	await process_frame
	quit()

extends SceneTree
## Native rendered review; overlay circles/labels exist only in this fixture.
var game
var output := "/tmp/latitude-arena-revision/after"
var overlays: Array[Node] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true,1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	print("ARENA CAPTURE: "+label)

func ring(radius: float, color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	for i in 128:
		for angle in [i*TAU/128.0,(i+1)*TAU/128.0]:
			tool.add_vertex(game.arena_center()+Vector3(sin(angle)*radius,1,cos(angle)*radius))
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=color
	var mesh: MeshInstance3D = game._mesh(game,tool.commit(),Vector3.ZERO,mat)
	overlays.append(mesh)

func label_at(text_value: String, world: Vector3) -> void:
	var label := Label.new()
	label.text=text_value
	label.position=game.camera.unproject_position(world)+Vector2(8,-18)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("ffdfa5"))
	label.add_theme_color_override("font_outline_color",Color("11212c"))
	label.add_theme_constant_override("outline_size",5)
	root.add_child(label)
	overlays.append(label)

func helm(at: Vector2, focus: Vector2) -> void:
	game.boat.position=game.arena_center()+Vector3(at.x,0,at.y)
	var direction := focus-at
	game.heading=atan2(direction.x,-direction.y)
	game.boat.rotation.y=-game.heading
	game._sailing_camera_initialized=false
	game.sea_time=18.0
	game.ocean.wave_time=18.0
	game._update_view(1.0)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=74
	game.hud._process(0)

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("sequence"))
	root.size=Vector2i(1280,720)
	game=load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.enemy_encounters.enabled=false
	game.wave_encounters.enabled=false
	await physics_frame
	game.hud._process(0)
	await capture("01-menu")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game._update_view(1.0)
	game.hud._process(0)
	await capture("02-spawn")
	game.hud.hide()
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=390
	game.camera.position=game.arena_center()+Vector3(0,420,0.1)
	game.camera.look_at(game.arena_center(),Vector3.FORWARD)
	# Top-down fog would obscure the chart from 420 m; gameplay fog is restored
	# immediately after this overview. Rings are review annotations, not barriers.
	game.world_environment.environment.fog_enabled=false
	ring(170,Color("e7c893"))
	ring(132,Color("679cba"))
	label_at("170 m STORM LINE · 132 m WARNING\nReview overlay; player movement is unrestricted",game.arena_center()+Vector3(-168,0,172))
	label_at("LIGHTHOUSE",game.arena_center()+Vector3(0,0,5))
	label_at("JAGGED REEF",game.arena_center()+Vector3(-119,0,-44))
	label_at("BROKEN WRECK",game.arena_center()+Vector3(88,0,62))
	label_at("LOW ISLETS",game.arena_center()+Vector3(26,0,-100))
	label_at("PLAYER · 75 m",game.archipelago.get_node("SpawnPoints/ArenaSpawn").global_position)
	for marker in game.archipelago.arena_layout.get_node("EnemySectors").get_children():
		label_at(marker.name+" spawn",marker.global_position)
	await capture("03-overhead")
	for overlay in overlays:
		overlay.queue_free()
	await process_frame
	game.world_environment.environment.fog_enabled=true
	game.hud.show()
	helm(Vector2(-65,-37),Vector2(-103,-18))
	await capture("04-reef-helm")
	helm(Vector2(63,16),Vector2(85,45))
	await capture("05-wreck-helm")
	helm(Vector2(18,-62),Vector2(48,-94))
	await capture("06-islets-helm")
	# Identical lens and elevated distance for cluster silhouettes and both routes.
	game.hud.hide()
	for entry in [["07-reef-routes",Vector3(-99,0,-15)],["08-wreck-routes",Vector3(85,0,45)],["09-islet-routes",Vector3(43,0,-91)]]:
		var focus: Vector3 = game.arena_center()+entry[1]
		game.camera.position=focus+Vector3(34,32,45)
		game.camera.look_at(focus)
		await capture(entry[0])
	game.hud.show()
	helm(Vector2(136,0),Vector2(170,0))
	game.arena_return.reset()
	game.wave_sailing.reset()
	for frame in 720:
		game._physics_process(1.0/60)
		if frame%60==0:
			await capture("sequence/storm-%02d"%(frame/60))
	# One visible cutter from a normal sector, still targeting only the player.
	game.restart()
	await physics_frame
	game.state=game.State.SAILING
	game.enemy_encounters.enabled=true
	game.enemy_encounters.next_wave_in=0
	game.enemy_encounters.update_encounters(1.0/60)
	game._update_view(1)
	game.hud._process(0)
	await capture("10-first-wave")
	game.queue_free()
	await process_frame
	quit()

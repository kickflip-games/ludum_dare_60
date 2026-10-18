extends SceneTree
## Surface attachment, fixed gameplay bodies, cleanup and optional native frames.
var checks := 0
var failures := 0
var game
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.restart()
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	var at: Vector3 = game.arena_center() + Vector3(55, 0, 80)
	game.boat.position = at + Vector3(0, 0, 18)
	game._add_hazard(at, 2.0, "debris")
	var timber: Node3D = game.obstacles.back().body
	game._add_hazard(at + Vector3(7, 0, 0), 2.0, "barrels")
	var barrels: Node3D = game.obstacles.back().body
	var mine = load("res://game/boss_mine.tscn").instantiate()
	mine.game = game
	game.add_child(mine)
	mine.position = at + Vector3(-7, 3.2, 0)
	mine.set_process(false)
	var mine_position: Vector3 = mine.position
	var timber_position: Vector3 = timber.position
	var barrel_position: Vector3 = barrels.position
	var min_height := INF
	var max_height := -INF
	for hz in [30, 60, 120]:
		for tick in hz * 3:
			game.sea_time = float(tick) / hz
			game.ocean.update_surface(game.boat.position, game.sea_time, 1.0 / hz, 0, 0)
			mine._process(1.0 / hz)
			for body in [timber, barrels]:
				var visual: Node3D = body.get_node("HazardVisual")
				var height: float = game.ocean.height_at(Vector2(body.position.x, body.position.z))
				check(absf(visual.global_position.y - height + game.ocean.settings.sea_level) < 0.001, "debris follows full surface at %d Hz" % hz)
			var water: float = game.ocean.height_at(Vector2(mine.position.x, mine.position.z))
			check(absf(mine.model.global_position.y - water - 0.65) < 0.001, "elevated mine spawn cannot offset its waterline")
			min_height = minf(min_height, mine.model.global_position.y)
			max_height = maxf(max_height, mine.model.global_position.y)
	check(max_height - min_height > 0.2, "mine visibly bobs over time")
	check(mine.position == mine_position and timber.position == timber_position and barrels.position == barrel_position, "flotation never moves gameplay bodies")
	check(mine.age == 0 and not mine.armed(), "visual updates cannot arm or age a mine")
	# A finite crest must lift props immediately, even on a zero-delta refresh.
	game.ocean.wave_field.add_wave(Vector2(at.x - 2, at.z), Vector2.RIGHT, 1.5, 9, 30, 2, 0)
	game.ocean.update_surface(game.boat.position, 1.0, 0, 0, 0)
	check(absf(timber.get_node("HazardVisual").global_position.y - game.ocean.height_at(Vector2(at.x, at.z)) + game.ocean.settings.sea_level) < 0.001, "travelling crest and zero-delta refresh follow the surface")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1280, 720)
		game.hud.visible = false
		for time in [1.0, 3.0]:
			game.sea_time = time
			game._update_view(1.0 / 60)
			mine.update_visuals()
			game.camera.position = at + Vector3(17, 12, 24)
			game.camera.look_at(at)
			game.camera.fov = 58
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60)
			check(root.get_texture().get_image().save_png(output.path_join("float-%.0f.png" % time)) == OK, "native frame saved")
	# Destruction must not leave an invalid flotation entry.
	var temporary := Node3D.new()
	game.add_child(temporary)
	game.ocean.register_float_visual(temporary)
	temporary.queue_free()
	await process_frame
	game.ocean._update_floating_visuals(0)
	check(game.ocean.floating_visuals.all(func(item): return is_instance_valid(item.visual)), "destroyed debris is removed from flotation")
	mine.expire()
	game.restart()
	await process_frame
	game.ocean._update_floating_visuals(0)
	check(game.ocean.floating_visuals.size() == 3, "retry restores arena floating props exactly once")
	game.queue_free()
	await process_frame
	print("FLOATING HAZARDS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

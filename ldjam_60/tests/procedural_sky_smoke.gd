extends SceneTree
## Production state/input/weather regressions. Pixel/cloud shape checks need the native fixture.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)


func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	var material: ShaderMaterial = game.sky_material
	var offset: Vector3 = material.get_shader_parameter("cloud_offset")
	var field = game.ocean.wave_field
	check(game.procedural_clouds and material.get_shader_parameter("procedural_clouds"), "real game uses the procedural cloud layer")
	game.cloud_scale = 1.3
	game.cloud_wind = Vector2(-1, 0.5)
	game.cloud_density = 0.0
	game.cloud_speed = 0.0
	game._update_view(0.0)
	check(material.get_shader_parameter("cloud_scale") == game.cloud_scale and material.get_shader_parameter("cloud_wind") == game.cloud_wind, "scale and wind Inspector settings reach the existing sky material")
	check(material.get_shader_parameter("cloud_density") == 0.0 and material.get_shader_parameter("cloud_speed") == 0.0, "zero coverage and drift are passed through exactly")
	game.cloud_density = 1.0
	game.cloud_speed = 0.7
	game.cloud_seed = 97
	game._update_view(0.0)
	check(offset != material.get_shader_parameter("cloud_offset"), "game seed changes cloud field")
	game.cloud_seed = 60
	game._update_view(0.0)
	check(offset == material.get_shader_parameter("cloud_offset"), "restoring seed gives the same cloud field")
	var start: Vector3 = game.boat.position
	Input.action_press("astrolabe")
	for frame in range(114):
		game._physics_process(1.0 / 60.0)
	game.hud._process(0.0)
	check(game.focus_strength == 1.0 and not game.hud.star_guidance().is_empty(), "actual Space hold focuses with high coverage")
	check(game.boat.position.distance_to(start) > 10 and game.ocean.wave_field == field, "sailing continues using the original authoritative wave field")
	Input.action_release("astrolabe")
	game._physics_process(1.0 / 60.0)
	game.hud._process(0.0)
	check(game.focus_strength == 0.0 and material.get_shader_parameter("target_focus") == 0.0 and game.hud.star_guidance().is_empty(), "Space release clears guidance without changing cloud seed")
	check(material.get_shader_parameter("cloud_offset") == offset and material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()), "focus and sailing never move cloud seed; the star follows the live destination")
	game.voyage.stage = 2
	game.voyage.set_target(game)
	game.boat.position = game.archipelago.get_node("SpawnPoints/Departure").position
	game.elapsed = 18.0
	game._update_weather(0.5)
	check(game.phase == 2 and game.storm_blend > 0.1 and material.get_shader_parameter("storm") > 0.1, "voyage progress still activates storm weather")
	check(is_equal_approx(float(material.get_shader_parameter("lightning")), 0.3), "storm phase still triggers lightning")
	game.elapsed = 18.3
	game._update_weather(0.3)
	check(material.get_shader_parameter("lightning") == 0.0, "lightning fades using the existing weather clock")
	for state in [game.State.SAILING, game.State.LOST, game.State.ARRIVED]:
		game.state = state
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		event.pressed = true
		if state == game.State.SAILING:
			Input.action_press("restart_crossing")
			game._physics_process(game.RESTART_HOLD_SECONDS)
			Input.action_release("restart_crossing")
		else:
			game._unhandled_input(event)
		check(game.state == game.State.CASTING_OFF and game.voyage.stage == 0 and game.hull == game.hull_capacity, "R retry preserves gameplay reset from state %d" % state)
		check(material.get_shader_parameter("cloud_offset") == offset and material.get_shader_parameter("guiding_star").is_equal_approx(game.guiding_star_direction()) and material.get_shader_parameter("target_focus") == 0.0, "retry keeps the same procedural world and clears focus from state %d" % state)
		check(material.get_shader_parameter("lightning") == 0.0 and material.get_shader_parameter("storm") == 0.0, "retry clears storm and lightning from state %d" % state)
		event.pressed = false
		game._unhandled_input(event)
	print("PROCEDURAL SKY CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

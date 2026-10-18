extends SceneTree
## Lighting lifecycle and the boundary between cosmetic weather and shared waves.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = Vector3(-300,0,-330)
	game.sea_time = 60.0
	game._update_view(0.0)
	var field = game.ocean.wave_field
	field.add_wave(Vector2(-300,-350),Vector2(0,1),1.4,4.8,26,8,58,9)
	game._update_view(0.0)
	var height: float = game.ocean.height_at(Vector2(-300,-330))
	var environment: Environment = game.world_environment.environment
	var calm: float = environment.ambient_light_energy
	var moon: float = game.moon.light_energy
	for storm in [0.0,0.25,0.45,1.0]:
		game.storm_blend = storm
		game._update_view(0.0)
		check(game.ocean.wave_field == field and game.ocean.height_at(Vector2(-300,-330)) == height,
			"weather %.2f leaves the authoritative wave object, clock and height unchanged" % storm)
		check(is_equal_approx(float(game.water_material.get_shader_parameter("storm_shading")),storm),
			"weather %.2f reaches the visible water" % storm)
	check(environment.ambient_light_energy < calm and environment.ambient_light_energy > calm*0.6,
		"full storm dims ambient while retaining a shadow-detail floor")
	check(game.moon.light_energy < moon and game.moon.light_energy > moon*0.6,
		"full storm dims directional light without removing it")
	Input.action_press("astrolabe")
	for i in range(114):
		game._physics_process(1.0/60)
	check(game.focus_strength == 1.0 and game.camera_mode == game.CameraMode.STARGAZING,
		"real Space hold still focuses in full storm")
	var ray: Vector3 = game.sky_material.get_shader_parameter("guiding_star")
	check(ray.is_equal_approx(game.guiding_star_direction()),"storm focus retains the live world-direction star")
	Input.action_release("astrolabe")
	game._physics_process(1.0/60)
	check(game.focus_strength == 0.0,"release removes focus in storm")
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position+Vector3(18,0,-40))
	var healthy: Color = ship.sail_material.emission
	ship.take_hit()
	check(ship.hull == ship.hull_capacity-1 and ship.sail_material.emission != healthy,
		"actual cannon damage still darkens the red cloth, including its restrained fill")
	ship.reset()
	ship.begin(game.boat.position+Vector3(18,0,-40))
	check(ship.sail_material.emission == healthy and ship.hull == ship.hull_capacity,
		"new encounter restores the undamaged cloth and hull")
	game.weather_enabled = true
	game.voyage.stage = 2
	game.voyage.set_target(game)
	game.storm_blend = 0.0
	game.elapsed = 18.0
	game._update_view(1.0/60)
	check(game.storm_blend > 0.0 and game.storm_blend < 0.01 and environment.ambient_light_energy < calm,
		"normal weather progression changes light continuously on its first frame")
	check(is_equal_approx(float(game.sky_material.get_shader_parameter("lightning")),0.3),
		"original brief storm lightning still triggers")
	game.elapsed = 18.3
	game._update_view(0.3)
	check(game.sky_material.get_shader_parameter("lightning") == 0.0,"lightning still expires")
	for state in [game.State.SAILING,game.State.LOST,game.State.ARRIVED]:
		game.state = state
		var event := InputEventAction.new()
		event.action = "restart_crossing"
		event.pressed = true
		if state == game.State.SAILING:
			Input.action_press("restart_crossing")
			game._physics_process(game.RESTART_HOLD_SECONDS)
			Input.action_release("restart_crossing")
		else:
			game._unhandled_input(event)
		check(game.state == game.State.CASTING_OFF and game.storm_blend == 0.0 and game.hull == game.hull_capacity,
			"retry restores calm and healthy voyage from state %d" % state)
		check(is_equal_approx(environment.ambient_light_energy,calm) and game.water_material.get_shader_parameter("storm_shading") == 0.0,
			"retry immediately restores calm surface and environment from state %d" % state)
		event.pressed = false
		game._unhandled_input(event)
	print("ATMOSPHERE CHECK: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

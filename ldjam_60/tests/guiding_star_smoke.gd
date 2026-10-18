extends SceneTree
## Continuous guidance replaces the former Space/focus camera contract.
var game
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ")+label)
func run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	for hz in [30,60,120]:
		game.restart()
		game.state = game.State.SAILING
		game.wave_encounters.enabled = false
		game.enemy_encounters.enabled = false
		game.boat.position = Vector3(400,0,320)
		game.heading = 0
		game.target = Vector3(400,0,0)
		for frame in range(hz): game._physics_process(1.0/hz)
		var ordinary_pitch: float = game.camera.rotation.x
		Input.action_press("astrolabe")
		for frame in range(hz): game._physics_process(1.0/hz)
		check(game.camera_mode == game.CameraMode.SAILING and game.camera.rotation.x < 0 and absf(game.camera.rotation.x-ordinary_pitch) < 0.03,"%d Hz retired Space action never raises the deck camera" % hz)
		check(game.sky_material.get_shader_parameter("target_focus") == 1 and game.hud.star_guidance().get("visible",false),"%d Hz bright star is continuously visible without focus waiting" % hz)
		Input.action_release("astrolabe")
		game._physics_process(1.0/hz)
		game.hud._process(0.0)
		check(game.hud.instrument.visible and not game.hud.star_guidance().is_empty(),"%d Hz release cannot hide sextant or star" % hz)
		for motion in [0,1]:
			game.motion_setting = motion
			for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(900,600),Vector2i(1920,800)]:
				root.size = dimensions
				await process_frame
				game._update_view(0.1)
				game.hud._process(0)
				check(game.hud.star_guidance().get("visible",false) and game.hud.get_viewport_rect().encloses(game.hud.instrument.get_global_rect()),"motion=%d viewport=%s retains forward star and corner instrument" % [motion,dimensions])
		game.cannon.set_aim_held(true)
		game.cannon.update_aim(0.1)
		game._update_view(0.4)
		game.hud._process(0)
		check(game.camera_mode == game.CameraMode.CANNON and game.hud.instrument.visible,"gun view keeps permanent sextant without another input priority")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not game.cannon.aiming and game.voyage.alignment_elapsed == 0,"focus loss clears aim and incomplete alignment hold")
	game.free()
	print("GUIDING STAR CHECKS %d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

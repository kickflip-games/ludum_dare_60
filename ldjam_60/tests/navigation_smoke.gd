extends SceneTree
## Independent vector checks and production input/state transitions; no route-solving HUD.
const Bearings = preload("res://game/navigation_bearings.gd")
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)


func step(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		game._physics_process(1.0 / 60.0)
	game.hud._process(0.0)


func _run() -> void:
	# Expected results are compass conventions, independent of implementation.
	for cardinal in [[Vector3(0, 50, -100), 0], [Vector3(100, -20, 0), 90], [Vector3(0, 20, 100), 180], [Vector3(-100, 0, 0), 270]]:
		check(Bearings.compass_degrees(Bearings.bearing_to(Vector3.ZERO, cardinal[0])) == cardinal[1], "world cardinal %s is %03d° regardless of height" % cardinal)
	for example in [[350, 10, 20], [10, 350, -20], [330, 10, 40], [10, 330, -40], [0, 180, -180], [180, 0, -180], [1070, -710, 20], [-710, 1070, -20]]:
		var correction := rad_to_deg(Bearings.signed_turn(deg_to_rad(example[0]), deg_to_rad(example[1])))
		check(is_equal_approx(correction, float(example[2])) and absf(correction) <= 180.0, "%s° to %s° gives signed turn %+d°" % example)
	for example in [[-720, 0], [-320, 40], [-40, 320], [359.4, 359], [359.9, 0], [360, 0], [720, 0]]:
		check(Bearings.compass_degrees(deg_to_rad(example[0])) == example[1], "absolute %s° displays %03d°" % example)
	for example in [[2.4, 0], [2.6, 5], [357.4, 355], [357.6, 0]]:
		check(Bearings.compass_degrees(deg_to_rad(example[0]), 5) == example[1], "approximate reading %s° rounds to %03d°" % example)
	check(Bearings.bearing_to(Vector3(2, 0, 3), Vector3(2, 30, 3), 0.73) == 0.73, "coincident planar destination retains the heading")
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.state = game.State.SAILING
	game.weather_enabled = false
	game.wave_encounters.enabled = false
	game.ocean.wave_field.clear()
	game.enemy_encounters.enabled = false
	var original_bearing: float = game.destination_bearing()
	game.position = Vector3(23,0,-17)
	game.voyage.set_target(game)
	check(absf(angle_difference(original_bearing,game.destination_bearing())) < 0.00001,"translated boat and targets share global coordinates")
	game.position = Vector3.ZERO
	for leg in range(game.voyage.POINTS.size()):
		game.voyage.leg = leg
		game.voyage.set_target(game)
		for at: Vector3 in [Vector3(24,0,148),Vector3(-221,0,-109),Vector3(356,0,74)]:
			game.boat.position = at
			var toward: Vector3 = (game.target-at).normalized()
			var ray: Vector3 = game.guiding_star_direction()
			check(Vector3(ray.x,0,ray.z).normalized().dot(toward) > 0.9999,"leg %d star azimuth follows its physical destination" % leg)
			check(is_equal_approx(ray.y,sin(deg_to_rad(12))),"low twelve-degree star elevation")
			game.heading = game.destination_bearing()
			game._update_view(0.0)
			check(game.sky_material.get_shader_parameter("guiding_star").is_equal_approx(ray),"shader and sextant share the live ray")
	game.boat.position = Vector3(400,0,-360)
	for example in [[0,0,0],[0,-35,-1],[0,35,1],[359,1,1],[1,359,-1],[0,180,-1]]:
		game.heading = deg_to_rad(example[0])
		var bearing := deg_to_rad(example[1])
		game.target = game.boat.position+Vector3(sin(bearing),0,-cos(bearing))*300
		game._update_view(0.0)
		var guidance: Dictionary = game.hud.star_guidance()
		var x: float = guidance.position.x-game.hud.size.x*0.5
		check(absf(x) < 0.1 if example[2] == 0 else signf(x) == example[2],"projected or offscreen star has correct side across north and astern")
		var old_heading: float = game.heading
		game.hud._process(0.1)
		check(game.heading == old_heading,"HUD never steers the boat")
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.heading = game.destination_bearing()+PI
	var before: float = game.boat.position.distance_to(game.target)
	step(2)
	check(game.boat.position.distance_to(game.target) > before+15 and game.voyage.leg == 0,"wrong-direction travel loses ground and cannot advance")
	Input.action_press("astrolabe")
	step(0.1)
	Input.action_release("astrolabe")
	step(0.1)
	check(game.sky_material.get_shader_parameter("target_focus") == 1 and not game.hud.star_guidance().is_empty(),"Space press/release cannot hide or delay guidance")
	game.restart()
	game.state = game.State.SAILING
	for leg in range(game.voyage.POINTS.size()):
		var previous_ray: Vector3 = game.guiding_star_direction()
		game.boat.position = game.target
		game.voyage.update_progress(game)
		game._update_view(0.0)
		check(game.voyage.leg == leg+1,"physical destination hands off leg %d exactly once" % leg)
		if leg < game.voyage.POINTS.size()-1:
			check(game.sky_material.get_shader_parameter("target_focus") == 1 and not game.hud.star_guidance().is_empty(),"next star appears immediately without a fresh focus search")
		else:
			check(game.state == game.State.ARRIVED and game.hud.star_guidance().is_empty(),"final physical harbour entry ends guidance")
	print("NAVIGATION CHECK: %d checks, %d failures" % [checks,failures])
	game.free()
	quit(0 if failures == 0 else 1)

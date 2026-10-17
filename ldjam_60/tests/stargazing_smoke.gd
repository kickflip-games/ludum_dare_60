extends SceneTree
## Focus timing, memory, fixed-world projection and active threats; no pilot skill claims.
var failures := 0
var checks := 0
var game


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
	game.hud._process(0.1)


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.elapsed = 8
	game.phase_banner_left = 0
	var hud = game.hud
	var start: Vector3 = game.boat.position
	Input.action_press("astrolabe")
	Input.action_press("watch_starboard")
	step(0.6)
	check(game.focus_strength == 0 and game.focus_elapsed > 0.5, "searching has no target assistance before delay")
	check(hud.bearing_label.text.is_empty() and hud.alignment_label.text.is_empty(), "initial hold withholds star name and solution")
	check(game.boat.position.distance_to(start) > 3, "sailing continues while the instrument is raised")
	check(game.look_blend == 0 and game.camera.rotation.x > 1.3, "sky mode takes precedence over held combat glance")
	step(0.6)
	check(game.focus_strength > 0.05 and game.focus_strength < 0.8, "focus ramps gradually after the short search")
	check(hud.alignment_label.text.is_empty(), "mid-focus still withholds exact bearing")
	step(0.6)
	check(game.focus_strength == 1 and hud.bearing_label.text == "North Star", "short continued hold reliably identifies the star")
	check(hud.alignment_label.text == hud._navigation_text(), "focused cue measures the active regional bearing")
	check(not hud.alignment_label.text.contains("Adjust"), "default assistance avoids solving the course correction")
	game.extended_text = 1
	step(1)
	check(hud.alignment_label.text == hud._course_hint(), "optional extended hold exposes the existing coarse course correction")
	var last: float = game.last_reading
	Input.action_release("astrolabe")
	step(1.0 / 60)
	check(game.focus_strength == 0 and game.focus_elapsed == 0, "release immediately erases focus, including its sky glow")
	check(hud.bearing_label.text.is_empty() and hud.alignment_label.text.is_empty() and not hud.release_label.visible, "release immediately clears all sighting text")
	check(game.last_reading == last, "lowered instrument cannot update the remembered sighting")
	step(0.3)
	check(not hud.instrument.visible and game.look_blend == 1 and game.camera.rotation.x < 0, "release smoothly returns to the still-held combat glance")
	Input.action_release("watch_starboard")
	for i in range(3):
		Input.action_press("astrolabe")
		step(0.35)
		check(game.focus_strength == 0, "quick check %d starts with a fresh search" % (i + 1))
		Input.action_release("astrolabe")
		step(0.1)
	Input.action_press("astrolabe")
	step(1.8)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1440, 900)]:
		root.size = dimensions
		await process_frame
		for degrees in [0, 90, 180, -90]:
			game.heading = deg_to_rad(degrees)
			game._update_view(0.0)
			hud._process(0.0)
			var at: Vector2 = hud._star_screen_position()
			check(Rect2(Vector2.ZERO, hud.size).has_point(at), "world-north star is in view at %d degrees / %s" % [degrees, dimensions])
		check(Rect2(Vector2.ZERO, hud.size).encloses(hud.alignment_label.get_rect()), "focused text stays in view at %s" % dimensions)
	game.boat.position = Vector3(400, 0, -370)
	game.heading = 0
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.position = game.boat.position + game.cannon.starboard_direction() * 40
	ship.territory = ship.position
	ship.heading = game.heading
	ship.mode = ship.Mode.TELEGRAPH
	ship.timer = 0
	ship.locked_point = game.boat.position
	game.hud._process(0.1)
	check(hud.threat_label.visible and not game.cannon.fire(), "incoming threat stays visible while the raised instrument gates cannon fire")
	var ship_at: Vector3 = ship.position
	step(2.0)
	check(ship.shots_fired > 0 and ship.position.distance_to(ship_at) > 1, "enemy movement and real cannon fire continue during focus")
	check(game.focus_strength == 1 and game.look_blend == 0, "enemy fire cannot take over the focused sky camera")
	game.damage_immunity = 0
	var hull_before: int = game.hull
	game.take_damage(1, "Sighting vulnerability check")
	check(game.hull == hull_before - 1 and game.reading, "the player remains vulnerable while stargazing")
	game.focused_text = 0
	game.extended_text = 0
	game.search_text = 0
	hud._process(0.1)
	check(hud.bearing_label.text.is_empty() and hud.alignment_label.text.is_empty() and not hud.release_label.visible, "text amount can be tuned independently down to none")
	Input.action_release("astrolabe")
	game.restart()
	check(game.focus_elapsed == 0 and game.focus_strength == 0 and not game.reading, "retry clears assistance and hold history")
	print("STARGAZING CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

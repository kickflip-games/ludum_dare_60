extends SceneTree
## UI behavior and real Control geometry; underlying sailing/combat have separate suites.
var failures: int = 0
var checks: int = 0
var game


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func settle() -> void:
	await process_frame
	await process_frame
	game.hud._process(0.2)


func check_inside(control: Control, label: String) -> void:
	var viewport: Rect2 = game.hud.get_viewport_rect()
	check(viewport.grow(0.5).encloses(control.get_global_rect()), label)


func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await settle()
	var hud = game.hud
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.action_button.has_focus(), "title has keyboard focus and hides sailing instruments")
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(960, 540)]:
		root.size = dimensions
		await settle()
		check_inside(hud.menu, "menu stays inside %s" % dimensions)
		check_inside(hud.action_button, "Play button stays inside %s" % dimensions)
		check_inside(hud.menu_footer, "controls footer stays inside %s" % dimensions)
		check_inside(hud.hull_gauge, "hull stays inside %s" % dimensions)
		check_inside(hud.compass, "compass stays inside %s" % dimensions)
		check_inside(hud.cannon_gauge, "cannon stays inside %s" % dimensions)
	check(hud.action_button.pressed.get_connections().size() == 1, "one menu action connection after repeated resizing")
	hud.action_button.pressed.emit()
	await settle()
	check(game.state == game.State.CASTING_OFF and not hud.menu.visible and not hud.gameplay_hud.visible, "Play retains the cast-off transition and hides menus")
	game._physics_process(game.CAST_OFF_SECONDS)
	await settle()
	check(hud.gameplay_hud.visible and not hud.menu.visible, "normal sailing shows anchored instruments")
	check(hud.gameplay_hud.get_node_or_null("Destination") == null and hud.gameplay_hud.get_node_or_null("RouteHint") == null and not hud.notice.visible, "departure leaves navigation to the player without route instructions")
	game.wave_encounters.begin_region(0, Vector2(0, -1), game.sea_time)
	hud._process(0.1)
	check(hud.gameplay_hud.get_node_or_null("WaveWarning") == null and not hud.notice.text.contains("Wave"), "wave sets add no counters or routine sea-state banners")
	game.wave_encounters.stop(game.ocean.wave_field)
	check(hud.hull_gauge.status.text == "Hull" and hud.cannon_gauge.status.text == "F · Enter Gun View", "healthy hull and loaded cannon use compact status text")
	var old_heading: float = hud.compass.heading
	game.heading += 0.6
	hud._process(0.1)
	check(absf(angle_difference(old_heading, hud.compass.heading)) > 0.01 and absf(angle_difference(game.heading, hud.compass.heading)) > 0.01, "compass turns smoothly toward the actual bow heading")
	game.heading = deg_to_rad(-40)
	hud._process(0.1)
	check(hud.compass.status.text == "Heading 320°", "compass shows the numeric heading needed to match a star reading")
	var before_destination: float = hud.compass.heading
	game.target += Vector3(200, 0, -200)
	hud._process(0.0)
	check(hud.compass.heading == before_destination, "changing lighthouse position cannot move the compass")
	game.voyage.set_target(game)
	game.cannon.fire()
	hud._process(0.1)
	check(hud.cannon_gauge.status.text == "Reloading" and hud.cannon_gauge.pulse == 0, "shot displays real reload state without a false ready flash")
	game.cannon.advance(game.cannon.RELOAD_SECONDS)
	hud._process(0.1)
	check(hud.cannon_gauge.status.text == "F · Enter Gun View" and hud.cannon_gauge.pulse > 0, "reload completion gives a brief ready pulse")
	game.take_damage(1, "UI regression hit")
	hud._process(0.1)
	check(hud.hull_gauge.pulse > 0 and hud.hull_gauge.status.text.contains("%d/%d" % [game.hull, game.hull_capacity]), "actual damage animates hull icons and reports accurate capacity")
	game.damage_immunity = 0.0
	game.take_damage(1, "UI regression hit")
	Input.action_press("astrolabe")
	game._physics_process(0.3)
	Input.action_release("astrolabe")
	hud._process(0.2)
	check(hud.instrument.visible and hud.bearing_label.text.is_empty() and hud.alignment_label.text.is_empty(), "early sighting shows the instrument without giving away a bearing")
	Input.action_press("astrolabe")
	game._physics_process(game.focus_delay + game.focus_duration)
	Input.action_release("astrolabe")
	hud._process(0.2)
	check(hud.bearing_label.text == "North Star" and hud.alignment_label.text == hud._navigation_text(), "continued hold reveals the actual live bearing")
	check(hud.alignment_label.text.begins_with("Bearing ~") and not hud.alignment_label.text.contains("Wreck"), "focused reading labels its approximate absolute bearing without repeating the objective")
	check_inside(hud.alignment_label, "full navigation explanation fits the small window")
	check(hud.compass.modulate.a < 0.01 and hud.cannon_gauge.modulate.a < 0.1 and hud.hull_gauge.modulate.a == 1, "sighting dims combat UI while critical hull remains readable")
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.mode = ship.Mode.TELEGRAPH
	hud._process(0.2)
	check(hud.threat_label.visible and hud.threat_label.text.contains("Incoming"), "incoming broadside remains readable during a sighting")
	check_inside(hud.threat_label, "incoming threat text stays within the small window")
	ship.reset()
	hud._process(0.1)
	check(not hud.threat_label.visible, "threat cue disappears when the threat clears")
	game.damage_immunity = 0.0
	game.take_damage(1, "UI regression hit")
	await settle()
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.menu_title.text == "Lost at sea.", "sinking replaces every gameplay element with the defeat menu")
	hud.action_button.pressed.emit()
	await settle()
	game._physics_process(game.CAST_OFF_SECONDS)
	await settle()
	check(game.hull == game.hull_capacity and hud.hull_gauge.status.text == "Hull" and hud.hull_gauge.pulse == 0.0 and hud.cannon_gauge.pulse == 0.0, "retry restores gameplay and clears damage/reload animation memory")
	game.boat.position = game.target
	game.voyage.update_progress(game)
	hud._process(0.1)
	check(game.voyage.stage == game.voyage.Stage.TWIN_PEAKS and hud.notice.text == "The Wreck found" and hud.alignment_label.text.is_empty(), "finding the wreck acknowledges discovery without revealing or directing the next stop")
	game.elapsed = 102.0
	game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
	game.voyage.set_target(game)
	game.boat.position = game.target + Vector3(0,0,-5)
	game.advance_sailing(0.001, 0.0)
	await settle()
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.menu_details.text.contains("01:42") and hud.menu_details.text.contains("3 / 3"), "arrival menu shows the real voyage time and remaining hull")
	check_inside(hud.menu_body, "result text stays inside the small window")
	print("HUD CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

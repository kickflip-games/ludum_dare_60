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
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await settle()
	var hud = game.hud
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.action_button.has_focus(), "title has keyboard focus and hides sailing instruments")
	var controls: Array[String] = []
	for label: Label in hud.menu_controls.get_children():
		controls.append(label.text)
	check(controls == ["A / D", "Steer", "Hold Space", "Find the guiding star", "Hold Shift", "Speed +50%", "Hold E", "Aim cannon", "F", "Fire"], "opening menu lists the current controls including held Shift boost")
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(960, 540), Vector2i(900, 506)]:
		root.size = dimensions
		await settle()
		check_inside(hud.menu, "menu stays inside %s" % dimensions)
		check_inside(hud.action_button, "Play button stays inside %s" % dimensions)
		check_inside(hud.menu_footer, "controls footer stays inside %s" % dimensions)
		check(hud.gameplay_hud.get_node_or_null("Hull") == null, "no hull HUD at %s" % dimensions)
		check_inside(hud.cannon_gauge, "cannon stays inside %s" % dimensions)
	check(hud.action_button.pressed.get_connections().size() == 1, "one menu action connection after repeated resizing")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = hud.action_button.get_global_rect().get_center()
	mouse.pressed = true
	root.push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse, true)
	await settle()
	check(game.state == game.State.CASTING_OFF and not hud.menu.visible and not hud.gameplay_hud.visible, "Play retains the cast-off transition and hides menus")
	game._physics_process(game.CAST_OFF_SECONDS)
	await settle()
	check(hud.gameplay_hud.visible and not hud.menu.visible, "normal sailing keeps the existing context UI available")
	check(hud.gameplay_hud.get_node_or_null("Destination") == null and hud.gameplay_hud.get_node_or_null("RouteHint") == null and not hud.notice.visible, "departure leaves navigation to the player without route instructions")
	game.wave_encounters.begin_region(0, Vector2(0, -1), game.sea_time)
	hud._process(0.1)
	check(hud.gameplay_hud.get_node_or_null("WaveWarning") == null and not hud.notice.text.contains("Wave"), "wave sets add no counters or routine sea-state banners")
	game.wave_encounters.stop(game.ocean.wave_field)
	check(hud.gameplay_hud.get_node_or_null("Hull") == null and not hud.cannon_gauge.visible and hud.get_node_or_null("SailingHUD/HeadingCompass") == null, "no-input sailing has no hull icons, compass or cannon prompt")
	var before_heading: float = game.heading
	game.heading += 0.6
	hud._process(0.1)
	check(game.heading == before_heading + 0.6 and hud.star_horizon_line().is_empty(), "UI preserves authoritative heading without drawing sailing guidance")
	game.target += Vector3(200, 0, -200)
	hud._process(0.0)
	check(not hud.instrument.visible and hud.star_guidance().is_empty(), "destination changes cannot produce a sailing guide")
	game.voyage.set_target(game)
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	hud._process(0.0)
	check(hud.cannon_gauge.status.text == "F · Fire" and hud.cannon_gauge.tooltip_text.contains("Hold E to aim") and not hud.cannon_gauge.tooltip_text.contains("again"), "aim status and tooltip teach hold E / F without obsolete double press")
	game.cannon.fire()
	hud._process(0.1)
	check(hud.cannon_gauge.visible and hud.cannon_gauge.status.text == "Reloading" and hud.cannon_gauge.pulse == 0, "shot displays real reload state without a false ready flash")
	game.cannon.set_aim_held(false)
	game.cannon.advance(game.cannon.RELOAD_SECONDS)
	hud._process(0.1)
	check(hud.cannon_gauge.status.text == "Ready" and hud.cannon_gauge.pulse > 0, "reload completion gives a brief ready pulse")
	hud._process(0.6)
	check(not hud.cannon_gauge.visible, "ready feedback expires after reload without a permanent popup")
	game.take_damage(1, "UI regression hit")
	hud._process(0.1)
	check(game.boat_damage.flash_strength > 0 and game.boat_damage.light_marks.visible and game.hull == 2, "actual damage flashes and scratches the boat without adding HUD health")
	game.damage_immunity = 0.0
	game.take_damage(1, "UI regression hit")
	Input.action_press("astrolabe")
	game._physics_process(0.3)
	Input.action_release("astrolabe")
	hud._process(0.2)
	check(hud.instrument.visible and hud.instrument.get_child_count() == 0, "early sighting shows the instrument without giving away a bearing")
	Input.action_press("astrolabe")
	game._physics_process(game.focus_delay + game.focus_duration)
	Input.action_release("astrolabe")
	hud._process(0.2)
	check(game.focus_strength == 1 and not hud.star_guidance().is_empty(), "continued hold reveals the live star")
	check(hud.instrument.get_child_count() == 0, "focused instrument contains no text or number labels")
	check_inside(hud.instrument, "text-free instrument fits the small window")
	check(not hud.cannon_gauge.visible and hud.gameplay_hud.get_node_or_null("Hull") == null, "sighting keeps the instrument and threat UI without health indicators")
	var ship = game.enemy_encounters.ship
	ship.begin()
	ship.mode = ship.Mode.TELEGRAPH
	hud._process(0.2)
	check(hud.threat_label.visible and hud.threat_label.text.contains("Incoming"), "incoming broadside remains readable during a sighting")
	check_inside(hud.threat_label, "incoming threat text stays within the small window")
	ship.reset()
	hud._process(0.1)
	check(not hud.threat_label.visible, "threat cue disappears when the threat clears")
	game.reading = false
	hud._process(0.0)
	check(not hud.instrument.visible and hud.star_horizon_line().is_empty(), "release hides the whole instrument immediately, despite residual camera blend")
	game.damage_immunity = 0.0
	game.take_damage(1, "UI regression hit")
	await settle()
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.menu_title.text == "Lost at sea.", "sinking replaces every gameplay element with the defeat menu")
	var retry := InputEventAction.new()
	retry.action = "restart_crossing"
	retry.pressed = true
	game._unhandled_input(retry)
	await settle()
	game._physics_process(game.CAST_OFF_SECONDS)
	await settle()
	check(game.hull == game.hull_capacity and game.boat_damage.severity == 0 and game.boat_damage.flash_strength == 0.0 and hud.cannon_gauge.pulse == 0.0, "retry restores gameplay and clears damage/reload animation memory")
	game.boat.position = game.target
	game.voyage.update_progress(game)
	hud._process(0.1)
	check(game.voyage.stage == game.voyage.Stage.TWIN_PEAKS and hud.notice.text == "The Wreck found" and hud.star_guidance().is_empty(), "finding the wreck acknowledges discovery without revealing or directing the next stop")
	game.elapsed = 102.0
	game.voyage.stage = game.voyage.Stage.LIGHTHOUSE
	game.voyage.set_target(game)
	game.boat.position = game.target + Vector3(0,0,-5)
	game.advance_sailing(0.001, 0.0)
	await settle()
	check(hud.menu.visible and not hud.gameplay_hud.visible and hud.menu_details.text.contains("01:42") and not hud.menu_details.text.contains("Hull"), "arrival menu shows real voyage time without numeric hull health")
	check_inside(hud.menu_body, "result text stays inside the small window")
	var mute := InputEventAction.new()
	mute.action = "mute_sea"
	mute.pressed = true
	var sound_before: bool = game._sound_enabled
	game._unhandled_input(mute)
	check(game._sound_enabled != sound_before, "M mute action remains functional")
	var chart := InputEventKey.new()
	chart.keycode = KEY_F2
	chart.pressed = true
	game._unhandled_input(chart)
	check(not game.archipelago.debug_layer.visible, "F2 development chart stays hidden by default")
	game.development_tools = true
	game._unhandled_input(chart)
	check(game.archipelago.debug_layer.visible, "F2 remains available when development tools are enabled")
	game._unhandled_input(chart)
	check(not game.archipelago.debug_layer.visible, "F2 closes the chart again")
	game.state = game.State.READY
	hud._process(0.0)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await settle()
	check(game.state == game.State.CASTING_OFF, "Enter activates the keyboard-focused Play button")
	print("HUD CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

extends SceneTree
## Real director records and lethal/nonlethal hits drive presentation only.
var game
var enemies
var hud
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func create_game() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	hud = game.hud
	enemies = game.enemy_encounters

func begin() -> void:
	game.restart()
	hud._process(0)
	game._physics_process(game.CAST_OFF_SECONDS)
	enemies._update_arena(0)
	hud._process(0)

func icons() -> int:
	return hud.fleet_icons.get_children().filter(func(icon): return icon.visible).size()

func settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	create_game()
	await physics_frame
	hud._process(0)
	check(not hud.fleet_status.visible, "title has no fleet tracker")
	begin()
	hud._process(0.3)
	check(enemies.wave_number == 1 and hud.wave_label.text == "I / V", "first actual fleet launch uses compact Roman number")
	check(hud.wave_announcement.visible and hud.wave_announcement.text == "FLEET I" and hud.wave_announcement.modulate.a == 1, "large first-fleet announcement appears")
	check(icons() == 2 and enemies.spawn_queue.size() == 1, "icons include the queued second ship before arrival")
	var first = enemies.living_ships()[0]
	first.take_hit()
	hud._process(0)
	check(first.hull == 1 and icons() == 2, "nonlethal hit leaves the ship icon intact")
	first.take_hit()
	hud._process(0)
	check(first.mode == first.Mode.SINKING and icons() == 1, "lethal hit removes exactly one icon during sinking")
	enemies.on_ship_sunk(first)
	hud._process(0)
	check(icons() == 1, "duplicate defeat notification cannot remove another icon")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	hud._process(0)
	check(icons() == 1 and enemies.spawn_queue.is_empty(), "queued arrival keeps the outstanding count unchanged")
	var second = enemies.living_ships()[0]
	while second.hull > 0: second.take_hit()
	enemies._update_arena(0)
	hud._process(0)
	check(icons() == 0 and not hud.fleet_divider.visible and not hud.wave_announcement.visible, "all-clear removes all icons, divider and launch banner")
	check(hud.wave_countdown.text.begins_with("FLEET CLEARED"), "intermission uses fleet wording")
	# Fresh timed overlap: two survivors plus all three new arrivals are outstanding.
	begin()
	enemies.wave_remaining = 0
	enemies._update_arena(0)
	hud._process(0.3)
	check(enemies.wave_number == 2 and icons() == 5 and hud.wave_label.text == "II / V", "next fleet retains old survivors and adds its full queue")
	check(hud.wave_announcement.text == "FLEET II" and hud.wave_announcement.visible, "overlapping second fleet gets its own launch announcement")
	hud._process(3.1)
	check(not hud.wave_announcement.visible and hud.fleet_status.visible and icons() == 5, "large announcement expires while compact tracker stays")
	for fleet in 3:
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0.3)
		check(hud.wave_label.text == ["III / V", "IV / V", "V / V"][fleet], "fleet %d uses Roman progress" % (fleet + 3))
	check(enemies.wave_number == 5 and icons() == 20 and hud.wave_label.text == "V / V", "worst-case final fleet counts all twenty undefeated ships")
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(900,506)]:
		root.size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO, hud.size).grow(1)
		check(bounds.encloses(hud.fleet_status.get_child(0).get_global_rect()) and bounds.encloses(hud.wave_announcement.get_global_rect()), "twenty icons and launch announcement fit %s" % dimensions)
	game.motion_setting = 1
	hud._process(0)
	check(hud.wave_announcement.modulate.a == 1, "Reduced motion keeps a steady readable launch announcement")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		game.state = ending
		hud._process(0)
		check(not hud.fleet_status.visible and icons() == 0 and not hud.wave_announcement.visible, "ending %d clears icons and banner" % ending)
	game.restart(true)
	hud._process(0)
	check(enemies.records.is_empty() and hud._announced_fleet == 0 and icons() == 0, "menu reset clears fleet presentation and records")
	begin()
	hud._process(0.3)
	check(icons() == 2 and hud.wave_announcement.text == "FLEET I", "retry rebuilds first fleet without stale icons")
	game.walkthrough.active = true
	hud._process(0)
	check(not hud.fleet_status.visible and icons() == 0, "walkthrough hides and clears the combat tracker")
	print("FLEET HUD: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

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

func dots() -> int:
	return hud.fleet_icons.get_children().filter(func(icon): return icon.visible and icon.get_theme_stylebox("panel").bg_color.a > 0).size()

func empty_circles() -> int:
	return hud.fleet_icons.get_children().filter(func(icon): return icon.visible and icon.get_theme_stylebox("panel").bg_color.a == 0 and icon.get_theme_stylebox("panel").border_width_left == 1).size()

func settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	create_game()
	await physics_frame
	hud._process(0)
	check(not hud.fleet_status.visible, "title has no fleet tracker")
	begin()
	hud._process(0.3)
	check(enemies.wave_number == 1 and hud.wave_label.text == "WAVE 1 / 5", "first actual fleet launch uses explicit wave label and regular numbers")
	check(hud.wave_announcement.visible and hud.wave_announcement.text == "WAVE 1" and hud.wave_announcement.modulate.a == 1, "large first-fleet announcement appears")
	check(dots() == 2 and enemies.spawn_queue.size() == 1, "dots include the queued second ship before arrival")
	var dot = hud.fleet_icons.get_child(0)
	check(dot is Panel and dot.custom_minimum_size == Vector2(12, 12) and dot.get_theme_stylebox("panel").corner_radius_top_left == 6, "remaining ships use small circular dots without boat textures")
	var first = enemies.living_ships()[0]
	first.take_hit()
	hud._process(0)
	check(first.hull == 1 and dots() == 2, "nonlethal hit leaves the ship dot intact")
	first.take_hit()
	hud._process(0)
	check(first.mode == first.Mode.SINKING and dots() == 1, "lethal hit removes exactly one filled dot during sinking")
	enemies.on_ship_sunk(first)
	hud._process(0)
	check(dots() == 1 and empty_circles() == 1, "duplicate defeat notification keeps one filled dot and one empty circle")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 1 and enemies.spawn_queue.is_empty(), "queued arrival keeps the outstanding count unchanged")
	var second = enemies.living_ships()[0]
	while second.hull > 0: second.take_hit()
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 0 and empty_circles() == 2 and hud.fleet_divider.visible and not hud.wave_announcement.visible, "all-clear retains two empty circles and hides launch banner")
	check(hud.wave_countdown.text.begins_with("WAVE CLEARED"), "intermission uses wave wording")
	enemies.next_wave_in = 0
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 3 and empty_circles() == 0, "next wave clears all previous destroyed-ship circles")
	# A timed launch also drops old empty circles while retaining survivors.
	begin()
	var survivor = enemies.living_ships()[0]
	while survivor.hull > 0: survivor.take_hit()
	enemies.wave_remaining = 0
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 4 and empty_circles() == 0, "timed next wave removes old empty circle and retains the queued survivor")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	var old_ship = enemies.living_ships()[0]
	while old_ship.hull > 0: old_ship.take_hit()
	hud._process(0)
	check(dots() == 3 and empty_circles() == 0, "defeating a previous-wave survivor leaves no old empty circle")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	var current_ship = enemies.living_ships()[0]
	while current_ship.hull > 0: current_ship.take_hit()
	hud._process(0)
	check(dots() == 2 and empty_circles() == 1, "defeating a current-wave ship still creates an empty circle")
	# Fresh timed overlap: two survivors plus all three new arrivals are outstanding.
	begin()
	enemies.wave_remaining = 0
	enemies._update_arena(0)
	hud._process(0.3)
	check(enemies.wave_number == 2 and dots() == 5 and hud.wave_label.text == "WAVE 2 / 5", "next fleet retains old survivors and adds its full queue")
	check(hud.wave_announcement.text == "WAVE 2" and hud.wave_announcement.visible, "overlapping second fleet gets its own launch announcement")
	hud._process(3.1)
	check(not hud.wave_announcement.visible and hud.fleet_status.visible and dots() == 5, "large announcement expires while compact tracker stays")
	for fleet in 3:
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0.3)
		check(hud.wave_label.text == ["WAVE 3 / 5", "WAVE 4 / 5", "WAVE 5 / 5"][fleet], "fleet %d uses regular numbers" % (fleet + 3))
	check(enemies.wave_number == 5 and dots() == 17 and hud.wave_label.text == "WAVE 5 / 5", "final fleet counts all sixteen ordinary enemies plus the flagship")
	check(hud.boss_health.visible and hud.boss_health.value == enemies.boss.hull, "flagship health remains visible beside the integrated fleet display")
	enemies.boss.take_hit()
	hud._process(0)
	check(dots() == 17 and hud.boss_health.value == enemies.boss.hull, "nonlethal flagship damage updates its health without removing its ship dot")
	check(hud.boss_label.offset_top >= hud.fleet_status.offset_bottom and hud.wave_announcement.offset_top > hud.boss_health.offset_bottom, "flagship health and fleet launch announcement do not overlap")
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(900,506)]:
		root.size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO, hud.size).grow(1)
		check(bounds.encloses(hud.fleet_status.get_child(0).get_global_rect()) and bounds.encloses(hud.wave_announcement.get_global_rect()) and bounds.encloses(hud.boss_health.get_global_rect()), "remaining dots, flagship health and launch announcement fit %s" % dimensions)
	game.motion_setting = 1
	hud._process(0)
	check(hud.wave_announcement.modulate.a == 1, "Reduced motion keeps a steady readable launch announcement")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		game.state = ending
		hud._process(0)
		check(not hud.fleet_status.visible and dots() == 0 and empty_circles() == 0 and not hud.wave_announcement.visible, "ending %d clears dots and banner" % ending)
	game.restart(true)
	hud._process(0)
	check(enemies.records.is_empty() and hud._announced_fleet == 0 and dots() == 0, "menu reset clears fleet presentation and records")
	begin()
	hud._process(0.3)
	check(dots() == 2 and empty_circles() == 0 and hud.wave_announcement.text == "WAVE 1", "retry rebuilds first fleet without stale empty circles")
	game.walkthrough.active = true
	hud._process(0)
	check(not hud.fleet_status.visible and dots() == 0 and empty_circles() == 0, "walkthrough hides and clears the combat tracker")
	print("FLEET HUD: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

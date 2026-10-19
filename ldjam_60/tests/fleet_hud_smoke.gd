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
	return hud.fleet_circles.remaining

func empty_circles() -> int:
	return hud.fleet_circles.total - dots()

func settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	create_game()
	await physics_frame
	hud._process(0)
	check(not hud.fleet_status.visible, "title has no fleet tracker")
	begin()
	check(enemies.wave_number == 1 and hud.wave_announcement.text == "WAVE 1 / 5", "authoritative first wave launches numbered announcement")
	check(hud.wave_announcement.visible and hud.wave_announcement.modulate.a == 1, "ribbon appears immediately")
	check(hud.gameplay_hud.find_child("SurvivalWave", true, false) == null, "no permanent wave-number control remains")
	var ribbon: TextureRect = hud.wave_announcement.get_node("AdventureRibbon")
	check(ribbon.texture.get_size() == Vector2(512, 128) and ribbon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "real Kenney ribbon is loaded with preserved proportions")
	check(dots() == 2 and enemies.spawn_queue.size() == 1, "circles include the queued second ship before arrival")
	check(hud.fleet_circles.custom_minimum_size == Vector2(32, 12) and hud.fleet_circles.get_child_count() == 0, "12px primitive circles have 8px gaps and no icon textures")
	for tick in 120: hud._process(1.0 / 60)
	check(hud.wave_announcement.visible and is_equal_approx(hud.wave_announcement.modulate.a, 1), "announcement stays opaque for two seconds across repeated updates")
	hud._process(0.2)
	check(is_equal_approx(hud.wave_announcement.modulate.a, 0.5), "last 0.4 seconds fade smoothly")
	hud._process(0.21)
	check(not hud.wave_announcement.visible and hud.fleet_status.visible, "banner fully disappears at 2.4 seconds, leaving only circles")
	# Real no-input sailing/AI observation, with protection only to isolate HUD expiry.
	game.damage_immunity = 30
	for tick in 180:
		game.advance_sailing(1.0 / 60, 0)
		hud._process(1.0 / 60)
	check(not hud.wave_announcement.visible and enemies.wave_number == 1 and dots() == 2, "no-input sailing cannot replay a launch or count arrivals twice")
	begin()
	var first = enemies.living_ships()[0]
	first.take_hit()
	hud._process(0)
	check(first.hull == 1 and dots() == 2 and empty_circles() == 0, "nonlethal hit leaves the ship circle intact")
	first.take_hit()
	hud._process(0)
	check(first.mode == first.Mode.SINKING and dots() == 1 and empty_circles() == 1, "lethal hit turns exactly one filled circle hollow during sinking")
	enemies.on_ship_sunk(first)
	hud._process(0)
	check(dots() == 1 and empty_circles() == 1, "duplicate defeat notification cannot decrement twice")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 1 and enemies.spawn_queue.is_empty(), "queued arrival keeps the outstanding count unchanged")
	var second = enemies.living_ships()[0]
	while second.hull > 0: second.take_hit()
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 0 and empty_circles() == 2 and hud.fleet_status.visible and not hud.wave_announcement.visible, "all-clear briefly shows the completed row and hides announcement")
	check(not hud.wave_countdown.visible and hud.wave_countdown.text.is_empty(), "intermission has no countdown")
	hud._process(1.01)
	check(not hud.fleet_status.visible, "completed row hides after one second")
	for tick in 20: hud._process(0.01)
	check(not hud.fleet_status.visible, "repeated all-clear updates cannot replay the completed row")
	enemies.next_wave_in = 0
	enemies._update_arena(0)
	hud._process(0)
	check(dots() == 3 and empty_circles() == 0 and hud.wave_announcement.text == "WAVE 2 / 5", "early-clear transition rebuilds group and announces once")
	# A timed launch drops old hollows while retaining all survivors, including the queue.
	begin()
	var survivor = enemies.living_ships()[0]
	while survivor.hull > 0: survivor.take_hit()
	enemies.wave_remaining = 0.01
	enemies._update_arena(0.02)
	hud._process(0)
	check(dots() == 4 and empty_circles() == 0, "deadline transition removes old hollow and retains queued survivor")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	var old_ship = enemies.living_ships()[0]
	while old_ship.hull > 0: old_ship.take_hit()
	hud._process(0)
	check(dots() == 3 and empty_circles() == 1, "defeated carried survivor leaves a hollow in the displayed group")
	enemies.on_ship_sunk(old_ship)
	hud._process(0)
	check(dots() == 3 and empty_circles() == 1, "duplicate callback for earlier-wave survivor is ignored")
	enemies.spawn_remaining = 0
	enemies._update_arena(0)
	var current_ship = enemies.living_ships()[0]
	while current_ship.hull > 0: current_ship.take_hit()
	hud._process(0)
	check(dots() == 2 and empty_circles() == 2, "current-wave destruction preserves the same group size")
	# Maximum backlog: two survivors plus all later arrivals, including one flagship.
	begin()
	for wave in range(2, 6):
		enemies.wave_remaining = 0
		enemies._update_arena(0)
		hud._process(0)
		check(hud.wave_announcement.text == ["WAVE 2 / 5", "WAVE 3 / 5", "WAVE 4 / 5", "FLAGSHIP"][wave - 2], "wave %d announces its own title" % wave)
		if wave == 2:
			check(dots() == 5 and empty_circles() == 0, "overlapping second wave includes both earlier survivors and all three arrivals")
	check(enemies.wave_number == 5 and dots() == 17, "maximum final backlog counts sixteen ordinary ships and flagship exactly once")
	# A delayed boss spawn remains outstanding, then activation must not add a circle.
	enemies.boss.reset()
	enemies.boss_spawn_pending = true
	hud._process(0)
	check(dots() == 17 and not hud.boss_health.visible, "pending flagship is counted without a premature health bar")
	enemies._spawn_boss()
	hud._process(0)
	check(dots() == 17 and not hud.fleet_status.visible and hud.boss_health.visible and hud.boss_health.value == enemies.boss.hull, "active flagship replaces all dots with its health display without changing counts")
	var cloth_time: float = hud._ribbon_time
	hud._process(0.1)
	check(is_equal_approx(hud._ribbon_time, cloth_time + 0.1) and is_equal_approx(float(ribbon.material.get_shader_parameter("cloth_time")), hud._ribbon_time), "visible cloth advances with presentation time")
	check(hud.wave_announcement.material.get_shader_parameter("cloth_time") == ribbon.material.get_shader_parameter("cloth_time") and hud.wave_announcement.material.get_shader_parameter("ribbon_size") == hud.wave_announcement.size, "lettering shares the cloth clock and banner coordinates")
	var normal_fill: Color = hud.boss_health.get_theme_stylebox("fill").bg_color
	check(hud._boss_hit_left == 0 and hud.boss_health.offset_left == -120, "first flagship appearance does not flash or shake")
	enemies.living_ships()[0].take_hit()
	hud._process(0.1)
	check(hud._boss_hit_left == 0, "ordinary enemy damage does not trigger flagship feedback")
	enemies.boss.take_hit()
	hud._process(0)
	check(hud._boss_hit_left > 0 and hud.boss_health.get_theme_stylebox("fill").bg_color != normal_fill, "actual flagship damage immediately flashes its HP fill")
	hud._process(0.025)
	check(absf(hud.boss_health.offset_left + 120) > 0 and absf(hud.boss_health.offset_left + 120) <= 2.5 and absf(hud.boss_health.offset_top - 84) <= 1.5, "HP shake is visible and stays within 2.5 by 1.5 pixels")
	var frozen_left: float = hud.boss_health.offset_left
	var frozen_timer: float = hud._boss_hit_left
	var frozen_cloth: float = hud._ribbon_time
	game.set_paused(true)
	hud._process(1)
	check(hud._boss_hit_left == frozen_timer and hud.boss_health.offset_left == frozen_left and hud._ribbon_time == frozen_cloth, "pause freezes HP feedback and cloth animation")
	game.set_paused(false)
	enemies.boss.take_hit()
	hud._process(0)
	check(is_equal_approx(hud._boss_hit_left, hud.BOSS_HIT_SECONDS), "another damaging hit restarts the brief feedback")
	for hz in [30, 60, 120]:
		enemies.boss.take_hit()
		hud._process(0)
		for tick in ceili(0.35 * hz): hud._process(1.0 / hz)
		check(hud._boss_hit_left == 0 and hud.boss_health.offset_left == -120 and hud.boss_health.offset_top == 84 and hud.boss_health.get_theme_stylebox("fill").bg_color == normal_fill, "%d Hz restores the exact resting bar and colour" % hz)
	check(dots() == 17 and hud.boss_health.value == enemies.boss.hull, "damage feedback preserves enemy counts and authoritative HP")
	check(hud.wave_announcement.offset_bottom < hud.boss_health.offset_top, "Flagship ribbon sits above HP without overlap")
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(960,540), Vector2i(900,506)]:
		root.size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO, hud.size).grow(1)
		check(bounds.encloses(hud.wave_announcement.get_global_rect()) and bounds.encloses(hud.boss_health.get_global_rect()), "boss health and Flagship ribbon fit %s" % dimensions)
		check(not hud.fleet_status.visible and absf(hud.boss_health.get_global_rect().get_center().x - hud.size.x / 2) < 1, "boss bar stays centred with dots hidden at %s" % dimensions)
	game.motion_setting = 1
	enemies.boss.take_hit()
	hud._process(0)
	hud._process(0.025)
	check(float(ribbon.material.get_shader_parameter("motion_amount")) == 0.0 and float(hud.wave_announcement.material.get_shader_parameter("motion_amount")) == 0.0, "legacy Reduced Motion keeps cloth and lettering still")
	check(hud._boss_hit_left > 0 and hud.boss_health.get_theme_stylebox("fill").bg_color != normal_fill and hud.boss_health.offset_left == -120 and hud.boss_health.offset_top == 84, "legacy Reduced Motion retains the damage cue without movement")
	hud._process(0.35)
	hud._fleet_banner_left = 0.1
	var banner_y: float = hud.wave_announcement.offset_top
	hud._process(0)
	check(hud.wave_announcement.modulate.a == 1 and hud.wave_announcement.offset_top == banner_y, "Reduced Motion holds stationary opaque ribbon")
	hud._process(0.11)
	check(hud.wave_announcement.visible and hud.wave_announcement.text == "FLAGSHIP", "Flagship ribbon remains with its HP bar")
	for tick in 60: hud._process(1.0 / 60)
	check(hud.wave_announcement.visible and hud.wave_announcement.text == "FLAGSHIP" and hud.wave_announcement.modulate.a == 1 and dots() == 17 and not hud.fleet_status.visible, "persistent Flagship identity does not restore dots or alter counts")
	while enemies.boss.hull > 0: enemies.boss.take_hit()
	hud._process(0)
	check(hud._boss_hit_left == 0 and hud._boss_last_hull == -1 and hud.boss_health.offset_left == -120, "victory clears all HP feedback state")
	check(game.state == game.State.ARRIVED and not hud.fleet_status.visible and not hud.boss_health.visible and dots() == 0 and not hud.wave_announcement.visible, "actual flagship victory clears circles, health and ribbon even with surviving escorts")
	begin()
	game.hull = 1
	game.take_damage(1, "HUD defeat fixture")
	hud._process(0)
	check(game.state == game.State.LOST and not hud.fleet_status.visible and dots() == 0 and empty_circles() == 0 and not hud.wave_announcement.visible, "actual defeat clears circles and ribbon")
	game.restart(true)
	hud._process(0)
	check(enemies.records.is_empty() and hud._announced_fleet == 0 and dots() == 0, "menu reset clears fleet presentation and records")
	begin()
	check(dots() == 2 and empty_circles() == 0 and hud.fleet_status.visible and hud._ribbon_time == 0 and hud._boss_hit_left == 0 and hud._boss_last_hull == -1 and hud.wave_announcement.text == "WAVE 1 / 5", "retry restores dots without stale hollows or HP feedback")
	game.walkthrough.active = true
	hud._process(0)
	check(not hud.fleet_status.visible and dots() == 0 and empty_circles() == 0, "walkthrough hides and clears combat tracker")
	print("FLEET HUD: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

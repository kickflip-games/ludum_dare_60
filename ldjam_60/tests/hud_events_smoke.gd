extends SceneTree
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await process_frame
	game.start_crossing()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	var hud = game.hud
	var waves = game.enemy_encounters
	waves.wave_number = 4
	waves.announcement_left = 1
	waves.next_wave_in = 20
	hud._process(0)
	check(hud.gameplay_hud.find_child("SurvivalWave", true, false) == null and not hud.wave_countdown.visible, "quiet progress has no permanent wave number or countdown")
	check(hud.wave_announcement.text == "WAVE IV", "launch announcement reads the fourth fleet")
	waves.next_wave_in = 12
	hud._process(0)
	check(hud.wave_countdown.visible and hud.wave_countdown.text.contains("00:12"), "countdown retains actual final 15 seconds")
	game.boat.position = game.arena_center() + Vector3(180, 0, 0)
	hud._process(0)
	check(hud.storm_warning.visible and hud.storm_warning.offset_top > maxf(hud.wave_countdown.offset_bottom, hud.wave_announcement.offset_bottom), "storm warning clears simultaneous ribbon and countdown")
	hud._process(3.1)
	hud.reset_storm_notice()
	var zone: Dictionary = game.flow_zones.zones[0]
	game.boat.position = Vector3(zone.center.x, 0, zone.center.y)
	game.advance_sailing(0.001, 0)
	hud._process(0)
	check(game.flow_zones.collected.size() == 1 and is_equal_approx(game.flow_zones.multiplier(), 1.25), "real pickup keeps permanent compound reward")
	check(hud.notice.text == "SPEED +25%" and not hud.notice.text.contains("m/s"), "pickup feedback is momentary and contains no technical speed")
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game._update_view(1)
	var ship = waves.ship
	ship.begin(game.boat.position + Vector3(24, 0, -10))
	ship.mode = ship.Mode.TELEGRAPH
	waves.enabled = true
	waves.announcement_left = 1
	waves.wave_number = 5
	hud._process(0)
	check(hud.threat_icon.visible and hud.wave_announcement.visible, "new fleet announcement remains visible alongside lateral danger warning")
	for side in [-1, 1]:
		ship.position = game.boat.position + game.cannon.starboard_direction() * 24 * side
		hud._process(0)
		check(hud.threat_icon.visible and ((hud.threat_icon.position.x > hud.size.x * 0.5) == (side == 1)), "warning icon follows threat side %d" % side)
		var peak: float = hud.threat_icon.modulate.a
		hud._process(0.45)
		check(hud.threat_icon.modulate.a < peak - 0.2 and hud.threat_icon.modulate.a >= 0.69, "warning pulses gently without disappearing")
		hud._process(0.45)
		check(is_equal_approx(hud.threat_icon.modulate.a, peak), "pulse returns smoothly after one cycle")
	var pulse: float = hud.threat_icon.modulate.a
	var clock: float = hud._threat_pulse
	game.set_paused(true)
	hud._process(1)
	check(hud._threat_pulse == clock and hud.threat_icon.modulate.a == pulse, "pause freezes warning animation")
	game.set_paused(false)
	for dimensions in [Vector2i(1280,720), Vector2i(900,506)]:
		root.size = dimensions
		for frame in 6: await process_frame
		hud._process(0)
		check(Rect2(Vector2.ZERO, hud.size).encloses(hud.threat_icon.get_global_rect()), "warning icon fits %s" % dimensions)
	ship.mode = ship.Mode.REPOSITION
	ship.locked_point = game.boat.position
	ship._launch_ball(ship.position)
	hud._process(0)
	check(hud.threat_icon.visible, "a real in-flight projectile retains the warning after telegraph")
	ship.reset()
	hud._process(0)
	check(not hud.threat_icon.visible and hud._threat_pulse == 0, "cleared threat hides the icon and resets its pulse")
	ship.begin(game.boat.position + Vector3(24,0,-10))
	ship.mode = ship.Mode.TELEGRAPH
	game.boat.position = game.arena_center() + Vector3(180, 0, 0)
	hud._process(0)
	check(hud.storm_warning.visible and not hud.notice.visible and hud.storm_warning.offset_top > hud.wave_announcement.offset_bottom, "storm message stays below the fleet announcement")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		game.state = ending
		hud._process(0)
		check(hud.notice.text.is_empty() and hud.wave_announcement.text.is_empty() and hud.wave_countdown.text.is_empty() and not hud.threat_icon.visible, "ending %d clears transient text" % ending)
	game.restart(true)
	hud._process(0)
	check(game.discovery_left == 0 and not hud.notice.visible and not hud.gameplay_hud.visible and game.flow_zones.collected.is_empty(), "Main Menu reset clears pickup and all gameplay messages")
	print("HUD EVENTS: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

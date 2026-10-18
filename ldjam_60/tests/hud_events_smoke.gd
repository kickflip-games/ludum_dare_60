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
	check(hud.wave_label.text == "FLEETS 4 / V" and not hud.wave_countdown.visible, "quiet progress has requested fleet label and no permanent countdown")
	check(hud.wave_announcement.text == "WAVE IV" and hud.wave_announcement_detail.text == "FIVE SHIPS APPROACH", "announcement reads actual fourth-wave count")
	waves.next_wave_in = 12
	hud._process(0)
	check(hud.wave_countdown.visible and hud.wave_countdown.text.contains("00:12"), "countdown retains actual final 15 seconds")
	waves.announcement_left = 0
	var zone: Dictionary = game.flow_zones.zones[0]
	game.boat.position = Vector3(zone.center.x, 0, zone.center.y)
	game.advance_sailing(0.001, 0)
	hud._process(0)
	check(game.flow_zones.collected.size() == 1 and is_equal_approx(game.flow_zones.multiplier(), 1.25), "real pickup keeps permanent compound reward")
	check(hud.notice.text == "CURRENT CAUGHT · +25%" and not hud.notice.text.contains("m/s"), "pickup feedback is momentary and contains no technical speed")
	game.boat.position = game.arena_center() + Vector3(0, 0, 100)
	game._update_view(1)
	var ship = waves.ship
	ship.begin(game.boat.position + Vector3(24, 0, -10))
	ship.mode = ship.Mode.TELEGRAPH
	waves.enabled = true
	waves.announcement_left = 1
	hud._process(0)
	check(hud.threat_label.visible and not hud.wave_announcement.visible and not hud.wave_announcement_detail.visible, "incoming danger takes precedence over wave decoration")
	game.boat.position = game.arena_center() + Vector3(180, 0, 0)
	hud._process(0)
	check(hud.storm_warning.visible and not hud.notice.visible and not hud.wave_announcement.visible, "storm message has a clear centre")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		game.state = ending
		hud._process(0)
		check(hud.notice.text.is_empty() and hud.wave_announcement.text.is_empty() and hud.wave_countdown.text.is_empty() and hud.threat_label.text.is_empty(), "ending %d clears transient text" % ending)
	game.restart(true)
	hud._process(0)
	check(game.discovery_left == 0 and not hud.notice.visible and not hud.gameplay_hud.visible and game.flow_zones.collected.is_empty(), "Main Menu reset clears pickup and all gameplay messages")
	print("HUD EVENTS: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

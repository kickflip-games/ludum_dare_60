extends "res://tests/arcade_controls_smoke.gd"
var thunder_count := 0

func ready_weather() -> void:
	game.weather_enabled = true
	game.storm_lightning_enabled = true
	game.motion_setting = 0
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	thunder_count = 0

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var lightning = game.storm_lightning
	lightning.thundered.connect(func(): thunder_count += 1)
	var timings: Array[float] = []
	for hz in [30, 60, 120]:
		ready_weather()
		check(lightning.next_strike_in >= 14 and lightning.next_strike_in <= 28, "%d Hz: no immediate startup flash" % hz)
		var first := -1.0
		var strikes := 0
		var peak := 0.0
		for frame in 65 * hz:
			game._update_weather(1.0 / hz)
			if lightning.flash_age == 0.0:
				strikes += 1
				if first < 0: first = float(frame + 1) / hz
				check(lightning.pending_thunder >= 0.9 and thunder_count == strikes - 1, "%d Hz: thunder follows each flash instead of coinciding" % hz)
			peak = maxf(peak, lightning.strength)
		check(strikes >= 2 and strikes <= 4 and thunder_count >= strikes - 1, "%d Hz: occasional bounded strikes and delayed thunder" % hz)
		check(peak > 0.35 and peak <= 0.42, "%d Hz: brief bounded flash envelope" % hz)
		timings.append(first)
	check(timings.max() - timings.min() <= 1.0 / 30.0 + 0.001, "first strike timing agrees across frame rates")
	ready_weather()
	var start: float = lightning.next_strike_in
	game.restart()
	check(lightning.next_strike_in == start, "retry reseeds only the cosmetic weather schedule")
	game.state = game.State.SAILING
	lightning.next_strike_in = 0
	game._update_view(0)
	game._update_view(0.05)
	check(float(game.sky_material.get_shader_parameter("lightning")) > 0.4, "scheduled flash reaches the real sky")
	check(game.moon.light_energy > game.calm_moon_energy, "flash briefly illuminates actual ships and water")
	check(thunder_count == 0 and lightning.pending_thunder > 0.5, "thunder remains pending while flash is visible")
	game._update_view(0.5)
	check(game.sky_material.get_shader_parameter("lightning") == 0.0, "sky flash expires without lingering light")
	var wave_height: float = game.ocean.height_at(Vector2(game.boat.position.x, game.boat.position.z))
	game._update_view(3)
	check(thunder_count == 1 and lightning.pending_thunder < 0, "one delayed rumble per flash")
	check(game.ocean.height_at(Vector2(game.boat.position.x, game.boat.position.z)) == wave_height and game.hull == game.hull_capacity, "lightning leaves physical waves and hull unchanged")
	game.motion_setting = 1
	lightning.next_strike_in = 0
	game._update_view(0.05)
	game._update_view(0.05)
	check(lightning.strength == 0 and game.sky_material.get_shader_parameter("lightning") == 0.0, "Reduced motion suppresses visual flashes")
	game._update_view(3)
	check(thunder_count == 2, "Reduced motion retains thunder")
	for ending in [game.State.LOST, game.State.ARRIVED, game.State.READY]:
		ready_weather()
		lightning.next_strike_in = 0
		game._update_view(0.05)
		game.state = ending
		game._update_view(0.05)
		check(lightning.strength == 0 and lightning.pending_thunder < 0, "ending %d cancels flash and pending thunder" % ending)
		game.restart()
		check(lightning.strength == 0 and lightning.pending_thunder < 0 and lightning.next_strike_in >= 14, "ending %d retry starts with clean weather timers" % ending)
	ready_weather()
	lightning.next_strike_in = 0
	game._update_view(0.05)
	game.weather_enabled = false
	game._update_view(4)
	check(lightning.strength == 0 and lightning.pending_thunder < 0 and thunder_count == 0, "weather opt-out cancels pending events")
	ready_weather()
	lightning.next_strike_in = 0
	game._update_view(0.05)
	game.storm_lightning_enabled = false
	game._update_view(4)
	check(lightning.pending_thunder < 0 and thunder_count == 0, "independent lightning opt-out cancels delayed thunder")
	ready_weather()
	lightning.next_strike_in = 0
	game._update_view(0.05)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._update_view(0.05)
	check(lightning.strength == 0 and lightning.pending_thunder < 0, "focus loss cancels flash and pending thunder")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	ready_weather()
	game._update_weather(100)
	check(lightning.next_strike_in >= 14 and thunder_count == 0 and lightning.pending_thunder >= 0.9, "long frame schedules one event without catch-up thunder bursts")
	var stream = lightning.make_thunder()
	check(stream.data.size() == 158760 and stream.mix_rate == 22050, "bounded 3.6-second mono thunder sample")
	check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "thunder sample has silent click-free ends")
	game.queue_free()
	await process_frame
	print("STORM LIGHTNING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

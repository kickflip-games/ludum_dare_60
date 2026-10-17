extends RefCounted
## Small authored encounter library. Seed mirrors/offsets it; there is no endless generator.

var encounters: Array[Dictionary] = []
var current: float = 0.0
var gust_push: float = 0.0
var gust_warning: float = 0.0
var gust_direction: float = 1.0
var next_gust: float = 9.0
var gust_left: float = 0.0
var wind_phase: int = 0
var rng := RandomNumberGenerator.new()
var notice: String = ""
var notice_left: float = 0.0


func reset(seed_value: int) -> void:
	rng.seed = seed_value
	current = 0.0
	gust_push = 0.0
	gust_warning = 0.0
	gust_left = 0.0
	next_gust = 9.0
	wind_phase = 0
	notice = ""
	notice_left = 0.0
	encounters.clear()
	var mirror: float = 1.0 if rng.randf() > 0.5 else -1.0
	var shift: float = rng.randf_range(-2.0, 2.0)
	# [course, lane, radius, kind]. Gaps include the boat's 1.25 m collision radius.
	_add(158, "ROCK GATE", [[0, -1, 6, "rock"], [0, 27, 6, "rock"],
		[0, -19, 7, "rock"], [0, 46, 7, "rock"], [0, -39, 8, "rock"]], mirror, shift)
	_add(220, "WRECKAGE FIELD", [[-14, 16, 5, "debris"], [9, -9, 7, "wreck"],
		[32, 17, 5, "rock"], [36, -29, 5, "debris"]], mirror, shift)
	_add(304, "SPLIT REEF", [[0, 0, 13, "wreck"], [-4, -51, 9, "rock"],
		[8, 51, 9, "rock"], [27, 4, 7, "rock"]], mirror, shift)
	_add(386, "THE NARROWS", [[-10, -28, 8, "rock"], [-10, 2, 8, "rock"],
		[17, -28, 8, "rock"], [17, 2, 8, "rock"], [5, 35, 12, "wreck"],
		[0, -53, 9, "rock"]], mirror, shift)
	_add(469, "BROKEN MASTS", [[-11, -12, 7, "wreck"], [13, 14, 6, "rock"],
		[36, -4, 5, "debris"], [4, 43, 8, "rock"]], -mirror, shift)
	_add(574, "HARBOUR REEF", [[0, -16, 8, "rock"], [0, 17, 8, "rock"],
		[-8, -42, 8, "rock"], [4, 44, 9, "rock"]], -mirror, shift)


func _add(at: float, label: String, layout: Array, mirror: float, shift: float) -> void:
	var hazards: Array[Array] = []
	for item: Array in layout:
		hazards.append([at + item[0], item[1] * mirror + shift, item[2], item[3]])
	encounters.append({"distance": at, "label": label, "hazards": hazards, "spawned": false})


func spawn_ahead(game: Node3D) -> void:
	var distance: float = game.journey_distance()
	for encounter: Dictionary in encounters:
		if encounter.spawned or encounter.distance - distance > 180.0:
			continue
		encounter.spawned = true
		for item: Array in encounter.hazards:
			# Also safe when a debug/test teleports the boat; never materialise on the bow.
			if item[0] - distance < 55.0:
				continue
			game._add_hazard(game.course_forward() * item[0] + game.course_right() * item[1], item[2], item[3])


func danger_at(progress: float) -> float:
	return 0.35 if progress < 0.2 else 0.85 if progress < 0.5 else 1.35 if progress < 0.85 else 0.55


func update_forces(game: Node3D, delta: float) -> void:
	var progress: float = game.journey_progress()
	var danger: float = danger_at(progress)
	var cycle: int = int(game.elapsed / 8.0)
	var direction: float = 1.0 if (cycle + game.encounter_seed) % 2 == 0 else -1.0
	var target_current: float = direction * game.current_strength * danger * (0.8 + 0.2 * sin(game.elapsed * 0.36))
	if progress > 0.54 and progress < 0.63:
		target_current *= 1.25
	current = lerpf(current, target_current, 1.0 - exp(-game.current_response * delta))
	notice_left = maxf(0.0, notice_left - delta)
	gust_push = 0.0
	if gust_warning > 0.0:
		gust_warning = maxf(0.0, gust_warning - delta)
		if gust_warning == 0.0:
			gust_left = game.gust_duration
			game.cue_sound("gust")
	elif gust_left > 0.0:
		gust_left = maxf(0.0, gust_left - delta)
		gust_push = gust_direction * game.gust_strength * danger * sin(PI * gust_left / game.gust_duration)
	elif game.elapsed >= next_gust:
		gust_direction = 1.0 if rng.randf() > 0.5 else -1.0
		gust_warning = game.gust_warning_seconds
		next_gust = game.elapsed + game.gust_interval + rng.randf_range(-1.5, 1.5)
		game.cue_sound("warning")
	wind_phase = cycle


func force_warning() -> String:
	if gust_warning > 0.0:
		return "GUST FROM %s  ·  %.1fs" % ["PORT" if gust_direction > 0.0 else "STARBOARD", gust_warning]
	if gust_left > 0.0:
		return "GUST  ·  COUNTERSTEER"
	if absf(current) > 0.8:
		return "CROSS-CURRENT  " + ("→" if current > 0.0 else "←")
	return ""

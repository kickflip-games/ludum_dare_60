extends RefCounted
## Three sequential regional discoveries, plus the existing current/gust model.
enum Stage { WRECK, TWIN_PEAKS, LIGHTHOUSE, COMPLETE }
var stage: Stage = Stage.WRECK
var current: float = 0.0
var gust_push: float = 0.0
var gust_warning: float = 0.0
var gust_direction: float = 1.0
var next_gust: float = 9.0
var gust_left: float = 0.0
var rng := RandomNumberGenerator.new()

func reset(seed_value: int) -> void:
	rng.seed = seed_value
	stage = Stage.WRECK
	current = 0.0
	gust_push = 0.0
	gust_warning = 0.0
	gust_left = 0.0
	next_gust = 9.0

func region(game: Node3D) -> Marker3D:
	return game.archipelago.get_node("NavigationRegions").get_child(mini(stage, Stage.LIGHTHOUSE))

func set_target(game: Node3D) -> void:
	game.target = region(game).global_position
	game.focus_elapsed = 0.0
	game.focus_strength = 0.0
	game.has_reading = false

func update_progress(game: Node3D) -> void:
	if stage == Stage.COMPLETE or game.state != game.State.SAILING:
		return
	var destination := region(game)
	if game.boat.global_position.distance_to(destination.global_position) > destination.radius:
		return
	game.show_discovery(destination.display_name + " Found")
	game.cue_sound("victory")
	stage = (stage + 1) as Stage
	if stage == Stage.COMPLETE:
		game.state = game.State.ARRIVED
	else:
		set_target(game)

func danger_at(progress: float) -> float:
	return 0.35 if progress < 0.2 else 0.85 if progress < 0.5 else 1.1 if progress < 0.85 else 0.55

func update_forces(game: Node3D, delta: float) -> void:
	var danger: float = danger_at(game.journey_progress())
	var cycle: int = int(game.elapsed / 8.0)
	var direction: float = 1.0 if (cycle + game.encounter_seed) % 2 == 0 else -1.0
	var target_current: float = direction * game.current_strength * danger * (0.8 + 0.2 * sin(game.elapsed * 0.36))
	# Twin Peaks has stronger cross-flow; the broad northern bypass avoids it.
	if Vector2(game.boat.position.x - 226, game.boat.position.z + 210).length() < 60:
		target_current *= 1.4
	current = lerpf(current, target_current, 1.0 - exp(-game.current_response * delta))
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

func force_warning() -> String:
	if gust_warning > 0.0:
		return "GUST FROM %s" % ("PORT" if gust_direction > 0.0 else "STARBOARD")
	return "CROSS-CURRENT" if absf(current) > 0.8 else ""

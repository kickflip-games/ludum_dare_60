extends SceneTree
## Interactive, test-only open-water duel. R restages the existing enemy; Esc quits.
var game
var staged := false
var trial := 0
var last_mode := false
var last_shots := 0
var last_hits := 0
var wall_seconds := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.enemy_encounters.visited.assign(["WreckPatrol", "EasternPatrol"])
	game.start_crossing()


func _process(delta: float) -> bool:
	wall_seconds += delta
	if wall_seconds > 240:
		quit()
	if not is_instance_valid(game):
		return false
	if game.state != game.State.SAILING:
		staged = false
		return false
	if not staged:
		staged = true
		trial += 1
		game.boat.position = Vector3(400, 0, 360)
		game.current_strength = 0.35 * ((trial - 1) % 3)
		game.gust_strength = 0.04 * ((trial - 1) % 3)
		game.phase_banner_left = 0
		var ship = game.enemy_encounters.ship
		ship.begin(game.boat.position + game.cannon.starboard_direction() * 34)
		ship.heading = game.heading
		ship.rotation.y = -ship.heading
		print("INTERACTIVE DUEL %d staged: current=%.2f gust=%.2f" % [trial, game.current_strength, game.gust_strength])
		last_shots = 0
		last_hits = 0
	if game.cannon.aiming != last_mode or game.cannon.shots_fired != last_shots or game.cannon.targets_hit != last_hits:
		print("LIVE INPUT: trial=%d cannon=%s shots=%d hits=%d hull=%d enemy_hull=%d heading=%.2f turn=%.2f" % [trial, game.cannon.aiming, game.cannon.shots_fired, game.cannon.targets_hit, game.hull, game.enemy_encounters.ship.hull, game.heading, game.turn_input])
		last_mode = game.cannon.aiming
		last_shots = game.cannon.shots_fired
		last_hits = game.cannon.targets_hit
	return false

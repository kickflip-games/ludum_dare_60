extends RefCounted
## Compatibility entry point for external test scripts; never used by the game.
const Pilot = preload("res://tests/archipelago_pilot.gd")
static func steering(game: Node3D, branch: float = 1.0, _combat: bool = false) -> float:
	if not game.has_meta("test_pilot") or game.elapsed < game.get_meta("test_pilot_time", 0.0):
		game.set_meta("test_pilot", Pilot.new())
	game.set_meta("test_pilot_time", game.elapsed)
	var pilot = game.get_meta("test_pilot")
	pilot.alternate = branch < 0.0
	return pilot.steering(game)

extends "res://game/boss_ship.gd"
## Measurement-only subclass; production movement, planning and shots are inherited.
var sample_time := 0.0
var completed: Array[float] = []
var volleys_completed := 0
var attempts := 0
var failed_preparations := 0
var aborted := 0
var lane_queries := 0
var planned_rounds := 0
var sequence_shots := 0
var blocked_seconds := {}

func _prepare_volley(seconds: float) -> bool:
	attempts += 1
	if salvo == 0:
		planned_rounds = 0
		sequence_shots = shots_fired
	var ok := super._prepare_volley(seconds)
	if ok: planned_rounds += volley.size()
	else: failed_preparations += 1
	return ok

func _volley_lane_clear(from: Vector3, to: Vector3) -> bool:
	lane_queries += 1
	return super._volley_lane_clear(from, to)

func _finish_pattern() -> void:
	if not volley.is_empty() and planned_rounds > 0 and shots_fired - sequence_shots == planned_rounds and volley.all(func(s): return s.fired):
		completed.append(sample_time)
		volleys_completed += 2 if pattern == Pattern.DOUBLE else 1
	else: aborted += 1
	super._finish_pattern()

func _update_weapon(delta: float) -> void:
	if weapon_state == Weapon.READY:
		var distance := position.distance_to(game.boat.position)
		var reason := "eligible"
		if cooldown > 0: reason = "cooldown"
		elif safety_priority >= 3: reason = "safety"
		elif distance < minimum_attack_distance or distance > firing_range: reason = "range"
		elif game.enemy_encounters.director.clock < game.enemy_encounters.director.next_warning: reason = "scheduler"
		blocked_seconds[reason] = blocked_seconds.get(reason, 0.0) + delta
	super._update_weapon(delta)

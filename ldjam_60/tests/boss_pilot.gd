extends "res://tests/combat_arena_pilot.gd"
## Same sailing/fire input controller, with short-horizon mine and shell evasion.
var dodge_left := 0.0
var dodge_helm := 0.0
func update(game, delta: float) -> void:
	super.update(game, delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	# Terrain and hull avoidance selected by the navigation pilot has priority.
	if avoid_left > 0.0:
		dodge_left = 0.0
		return
	var danger := clearance(game, 0.0)
	if danger < 1.5 and dodge_left <= 0:
		var left := clearance(game, -1.0)
		var right := clearance(game, 1.0)
		dodge_helm = -1.0 if left > right else 1.0
		dodge_left = 0.5
	if dodge_left > 0:
		var course: float = game.heading + dodge_helm * 0.5
		if lane_clear(game, course, 18): helm(dodge_helm)

func clearance(game, steering: float) -> float:
	var score := 1000.0
	var position: Vector3 = game.boat.position
	var heading: float = game.heading
	var hazards: Array = game.enemy_encounters.boss.mines.duplicate()
	for ship in game.enemy_encounters.ships:
		if ship.mine_layer != null: hazards.append_array(ship.mine_layer.mines)
	for i in 12:
		heading += steering * 0.72 * 0.2
		position += Vector3(sin(heading), 0, -cos(heading)) * game.propulsion_speed() * 0.2
		var time := (i + 1) * 0.2
		for mine in hazards:
			if is_instance_valid(mine) and not mine.spent and mine.age + time >= mine.arming_delay:
				var offset: Vector3 = position - mine.position
				offset.y = 0
				score = minf(score, offset.length() - mine.trigger_radius - 2.0)
		for ship in game.enemy_encounters.combat_ships():
			for shot in ship.projectiles:
				var projected: Vector3 = shot.position + shot.velocity * time
				if time < shot.ttl:
					var offset: Vector3 = position - projected
					offset.y = 0
					score = minf(score, offset.length() - 3.0)
	return score

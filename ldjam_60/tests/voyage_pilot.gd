extends RefCounted
## Test-only authored route follower. Never loaded by the shipped game or HUD.


static func lane_at(game: Node3D, distance: float, branch: float = 1.0) -> float:
	var gate: Array = game.voyage.encounters[0].hazards
	var mirror: float = signf(gate[1][1] - gate[0][1])
	var shift: float = (gate[0][1] + gate[1][1]) * 0.5 - 13.0 * mirror
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(80, 0), Vector2(130, 13),
		Vector2(175, 13), Vector2(200, -7), Vector2(212, -7), Vector2(235, 7),
		Vector2(264, 7), Vector2(290, 28 * branch), Vector2(340, 28 * branch),
		Vector2(368, -13), Vector2(420, -13), Vector2(452, -7), Vector2(468, -7),
		Vector2(485, 0), Vector2(516, -10), Vector2(558, 0), Vector2(660, 0)]
	for i in range(1, points.size()):
		if distance <= points[i].x:
			var u: float = clampf(inverse_lerp(points[i - 1].x, points[i].x, distance), 0.0, 1.0)
			return lerpf(points[i - 1].y, points[i].y, u) * mirror + shift
	return shift


static func steering(game: Node3D, branch: float = 1.0) -> float:
	var distance: float = game.journey_distance()
	var lane: float = game.boat.position.dot(game.course_right())
	var look: float = 12.0
	var desired: float = game.TARGET_HEADING + atan2(lane_at(game, distance + look, branch) - lane, look)
	desired -= asin(clampf(game.voyage.current / game.SPEED, -0.4, 0.4))
	return clampf(wrapf(desired - game.heading, -PI, PI) * 3.5, -1.0, 1.0)

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


static func steering(game: Node3D, branch: float = 1.0, combat: bool = false) -> float:
	var distance: float = game.journey_distance()
	var lane: float = game.boat.position.dot(game.course_right())
	var look: float = 12.0
	var desired: float = game.TARGET_HEADING + atan2(lane_at(game, distance + look, branch) - lane, look)
	desired -= asin(clampf(game.voyage.current / game.SPEED, -0.4, 0.4))
	var ship = game.enemy_encounters.ship
	if combat and ship.mode in [ship.Mode.POSITION, ship.Mode.TELEGRAPH, ship.Mode.REPOSITION] and ship.age < 16.0:
		var offset: Vector3 = ship.global_position + ship.velocity * 0.6 - game.cannon.shot_origin()
		var gun_heading: float = wrapf(atan2(offset.x, -offset.z) - PI / 2.0, -PI, PI)
		if _clearance(game, gun_heading) > 4.0 and absf(wrapf(gun_heading - game.TARGET_HEADING, -PI, PI)) < 1.0:
			desired = gun_heading
	if ship.mode == ship.Mode.TELEGRAPH or not ship.projectiles.is_empty():
		for offset in [-0.4, 0.4]:
			if _clearance(game, desired + offset) > 3.0:
				desired += offset
				break
	return clampf(wrapf(desired - game.heading, -PI, PI) * 3.5, -1.0, 1.0)


static func _clearance(game: Node3D, angle: float) -> float:
	var closest: float = INF
	for i in range(1, 13):
		var at: Vector3 = game.boat.position + (Vector3(sin(angle), 0, -cos(angle)) * game.SPEED + game.course_right() * game.voyage.current) * i * 0.25
		for obstacle: Dictionary in game.obstacles:
			if not obstacle.body.get_meta("destroyed", false):
				closest = minf(closest, at.distance_to(obstacle.position) - obstacle.radius - 1.25)
	return closest

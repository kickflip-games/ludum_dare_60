extends RefCounted
## Test-only route waypoints. Normal gameplay never loads these or draws a route.
const WEST_START := [Vector2(-130, 58), Vector2(-185, -26), Vector2(-221, -109), Vector2(-230, -155)]
const WRECK_SHORTCUT := [Vector2(-125, 60), Vector2(-160, 15), Vector2(-170, -55), Vector2(-189, -82), Vector2(-199, -135), Vector2(-230, -155)]
const NORTH_ROUTE := [Vector2(-202, -140), Vector2(-156, -175), Vector2(-145, -205), Vector2(15, -205), Vector2(115, -195), Vector2(138, -150), Vector2(226, -153), Vector2(226, -205)]
const SOUTH_ROUTE := [Vector2(-190, -90), Vector2(-167, 71), Vector2(-60, 115), Vector2(95, 108), Vector2(140, 70), Vector2(142, -93), Vector2(226, -151), Vector2(226, -205)]
const EAST_ROUTE := [Vector2(226, -143), Vector2(332, -117), Vector2(350, -55), Vector2(356, 74), Vector2(344, 151), Vector2(260, 183)]
const INNER_ROUTE := [Vector2(226, -143), Vector2(140, -95), Vector2(130, 28), Vector2(139, 82), Vector2(201, 144), Vector2(260, 183)]
var point: int = 0
var previous_stage: int = -1
var alternate: bool = false

func route(stage: int) -> Array:
	return (WRECK_SHORTCUT if alternate else WEST_START) if stage == 0 else (SOUTH_ROUTE if alternate else NORTH_ROUTE) if stage == 1 else (INNER_ROUTE if alternate else EAST_ROUTE)

func steering(game: Node3D) -> float:
	if game.voyage.stage != previous_stage:
		previous_stage = game.voyage.stage
		point = 0
	var points := route(mini(game.voyage.stage, 2))
	var boat := Vector2(game.boat.position.x, game.boat.position.z)
	while point < points.size() - 1 and boat.distance_to(points[point]) < 14.0:
		point += 1
	var offset: Vector2 = points[point] - boat
	var desired := atan2(offset.x, -offset.y)
	return clampf(wrapf(desired - game.heading, -PI, PI) * 2.8, -1.0, 1.0)

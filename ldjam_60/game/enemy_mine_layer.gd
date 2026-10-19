extends RefCounted
## Bounded stern hazards for ordinary ships, using the existing mine and ring.
const MINE = preload("res://game/boss_mine.tscn")
const INTERVAL := 4.0
const MAXIMUM := 3
const RADIUS := 5.0
var ship: CharacterBody3D
var enabled := false
var clock := 0.0
var mines: Array[Node3D] = []
var pool: Array[Node3D] = []

func prepare() -> void:
	if not pool.is_empty(): return
	for i in MAXIMUM:
		var mine: Node3D = MINE.instantiate()
		mine.game = ship.game
		mine.pooled = true
		mine.trigger_radius = RADIUS
		mine.arming_delay = 1.2
		ship.game.enemy_encounters.add_child(mine)
		pool.append(mine)

func dispose() -> void:
	for mine in pool:
		if is_instance_valid(mine): mine.queue_free()
	pool.clear()
	mines.clear()

func reset() -> void:
	for mine in mines:
		if is_instance_valid(mine): mine.expire()
	mines.clear()
	clock = 0.0

func update(delta: float) -> void:
	for i in range(mines.size() - 1, -1, -1):
		var mine = mines[i]
		if not is_instance_valid(mine) or mine.spent:
			mines.remove_at(i)
		else:
			mine.update_mine(delta)
			# Fatal damage can clear this entire trail during the callback.
			if ship.game.state != ship.game.State.SAILING: return
	if not enabled or ship.hull <= 0 or ship.get_meta("destroyed", true) or not ship.game.arena_mode or ship.game.state != ship.game.State.SAILING:
		return
	clock = minf(INTERVAL, clock + delta)
	var pursuit: Vector3 = ship.game.boat.position - ship.position
	# Lay a trail for a pursuer, never surprise-drop underneath the player.
	if clock >= INTERVAL and pursuit.length() < 100.0 and pursuit.normalized().dot(ship.forward()) < -0.25 and ship.velocity.length() > 3.0:
		if deploy(): clock = 0.0

func deploy() -> bool:
	if not enabled or ship.hull <= 0 or ship.get_meta("destroyed", true) or not ship.game.arena_mode or ship.game.state != ship.game.State.SAILING:
		return false
	var game = ship.game
	var at: Vector3 = ship.position - ship.forward() * 9.0
	if at.distance_to(game.boat.position) < RADIUS + 18.0:
		return false
	if at.distance_to(game.arena_center()) > game.arena_radius - RADIUS - 10.0 or not game.archipelago.water_clear(at, RADIUS + 2.0):
		return false
	# Keep gaps between all ordinary trails and the flagship's mines.
	for vessel in game.enemy_encounters.combat_ships():
		var hazards: Array = vessel.mine_layer.mines if vessel.mine_layer != null else vessel.mines
		for mine in hazards:
			if is_instance_valid(mine) and not mine.spent and at.distance_to(mine.position) < RADIUS + mine.trigger_radius + 3.0:
				return false
	mines = mines.filter(func(mine): return is_instance_valid(mine) and not mine.spent)
	if mines.size() >= MAXIMUM:
		return false
	var mine: Node3D = null
	for candidate in pool:
		if candidate.spent:
			mine = candidate
			break
	assert(mine != null, "Prepared heavy mine pool must cover trail maximum")
	mine.activate(at)
	game.note_event("mine_deployment", {"side": "enemy", "position": [at.x, at.z]})
	mines.append(mine)
	return true

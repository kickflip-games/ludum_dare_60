extends Node3D
## Two authored open-water territories; one active cutter, bounded pursuit.
const SHIP = preload("res://game/enemy_ship.tscn")
var game: Node3D
var ship: CharacterBody3D
var encounter_index: int = 0
var ships_sunk: int = 0
var enabled: bool = true
var visited: Array[String] = []

func _ready() -> void:
	ship = SHIP.instantiate()
	ship.game = game
	add_child(ship)

func update_encounters(delta: float) -> void:
	if not enabled:
		return
	ship.update_ship(delta)
	if ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED]:
		return
	if game.wave_encounters.busy() or not game.ocean.wave_field.waves.is_empty():
		return
	for patrol: Marker3D in game.archipelago.get_node("PiratePatrols").get_children():
		if patrol.name in visited or game.voyage.stage != patrol.get_meta("stage"):
			continue
		if game.elapsed < patrol.get_meta("min_elapsed", 0.0):
			continue
		var spawn: Vector3 = patrol.get_meta("spawn")
		var distance: float = game.boat.position.distance_to(patrol.position)
		var spawn_distance: float = game.boat.position.distance_to(spawn)
		if distance < patrol.get_meta("radius") and spawn_distance > patrol.get_meta("min_distance", 55.0) and spawn_distance < patrol.get_meta("max_distance", 110.0):
			ship.begin(spawn)
			ship.territory = patrol.position
			visited.append(patrol.name)
			encounter_index += 1
			break

func reset() -> void:
	ship.reset()
	encounter_index = 0
	ships_sunk = 0
	visited.clear()

func stop() -> void:
	ship.reset()

func battle_active() -> bool:
	# A defeated or escaped cutter's last shot can still hit the player.
	return enabled and (ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED, ship.Mode.SINKING] or not ship.projectiles.is_empty())

func approach_warning() -> String:
	return ship.warning() if enabled else ""

func update_visuals(delta: float) -> void:
	ship.update_visuals(delta)

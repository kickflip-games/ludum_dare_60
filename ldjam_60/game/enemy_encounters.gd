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
	# Do not reset/reuse the cutter while a previous broadside is still in flight.
	if not ship.projectiles.is_empty():
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
			ship.begin(_engagement_spawn(spawn))
			ship.territory = patrol.position
			visited.append(patrol.name)
			encounter_index += 1
			break

func _engagement_spawn(authored: Vector3) -> Vector3:
	# Patrol markers still own activation. Prefer a noticeable starboard approach
	# relative to the actual helm course, with the authored point as a fallback.
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	var right := Vector3(cos(game.heading), 0, sin(game.heading))
	var terrain = game.archipelago.get_node("Terrain")
	for lateral in [60.0, 50.0, 70.0]:
		for ahead in [16.0, 32.0, 0.0]:
			var candidate: Vector3 = game.boat.position + right * lateral + forward * ahead
			var clear := true
			for offset in [Vector3.ZERO, right * 8.0, -right * 8.0, forward * 16.0]:
				if terrain.terrain_height_at(candidate + offset) > -4.0:
					clear = false
			var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 8, candidate - Vector3.UP * 2, 1)
			if clear and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return candidate
	return authored

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

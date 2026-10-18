extends Node3D
## Five player-targeted arena waves, retaining the original voyage patrols.
const SHIP = preload("res://game/enemy_ship.tscn")
var game: Node3D
var ship: CharacterBody3D
var encounter_index: int = 0
var ships_sunk: int = 0
var enabled: bool = true
var visited: Array[String] = []
const ARENA_WAVES := 5
@export var first_wave_delay := 5.0
@export var intermission_seconds := 10.0
@export var minimum_spawn_distance := 65.0
var wave_number := 0
var cleared_waves := 0
var next_wave_in := 5.0
var sector_index := 0
var wave_in_progress := false


func _ready() -> void:
	ship = SHIP.instantiate()
	ship.game = game
	add_child(ship)
	next_wave_in = first_wave_delay

func update_encounters(delta: float) -> void:
	if not enabled:
		return
	ship.update_ship(delta)
	if game.arena_mode:
		_update_arena(delta)
		return
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
	wave_number = 0
	cleared_waves = 0
	next_wave_in = first_wave_delay
	sector_index = 0
	wave_in_progress = false

func debug_cutter() -> void:
	if not game.development_tools or not game.arena_mode or not enabled:
		return
	if ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED] or not ship.projectiles.is_empty():
		return
	var candidate := _engagement_spawn(game.arena_center() + Vector3(90, 0, 0))
	if candidate.distance_to(game.arena_center()) > game.arena_radius - 12.0:
		candidate = game.arena_center() + Vector3(90, 0, 0)
	ship.begin(candidate)
	ship.territory = game.arena_center()

func stop() -> void:
	ship.reset()

func battle_active() -> bool:
	# A defeated or escaped cutter's last shot can still hit the player.
	return enabled and (ship.mode not in [ship.Mode.DORMANT, ship.Mode.ESCAPED, ship.Mode.SINKING] or not ship.projectiles.is_empty())

func approach_warning() -> String:
	return ship.warning() if enabled else ""

func update_visuals(delta: float) -> void:
	ship.update_visuals(delta)


func _update_arena(delta: float) -> void:
	if game.state != game.State.SAILING:
		return
	if wave_in_progress:
		# A clock or retreat never clears a wave. Resolve the last incoming shot
		# and sinking animation before intermission or the fifth-wave ending.
		if ship.mode != ship.Mode.ESCAPED or ship.hull > 0 or not ship.projectiles.is_empty():
			return
		cleared_waves += 1
		wave_in_progress = false
		if cleared_waves == ARENA_WAVES:
			game.state = game.State.ARRIVED
			game.cue_sound("victory")
			return
		next_wave_in = intermission_seconds
		game.show_discovery("Wave %d cleared · catch your breath" % cleared_waves, 3.0)
		return
	next_wave_in = maxf(0.0, next_wave_in - delta)
	if next_wave_in > 0.0:
		return
	var spawn := arena_spawn()
	if not spawn.is_finite():
		return # Wait for clear water rather than falling back onto a rock/player.
	ship.begin(spawn)
	ship.territory = game.arena_center()
	var toward: Vector3 = game.boat.global_position - spawn
	ship.heading = atan2(toward.x, -toward.z)
	ship.rotation.y = -ship.heading
	wave_number += 1
	encounter_index += 1
	wave_in_progress = true
	game.show_discovery("Wave %d / %d · hostile cutter" % [wave_number, ARENA_WAVES], 3.0)


func arena_spawn() -> Vector3:
	var sectors: Array[Node] = game.archipelago.arena_layout.get_node("EnemySectors").get_children()
	for attempt in range(sectors.size()):
		var index: int = (sector_index + attempt) % sectors.size()
		var marker: Marker3D = sectors[index]
		var offset: Vector3 = marker.global_position - game.arena_center()
		var spread: float = deg_to_rad(marker.get_meta("spread_degrees", 16.0))
		for angle: float in [0.0, -spread, spread]:
			var candidate: Vector3 = game.arena_center() + offset.rotated(Vector3.UP, angle)
			if candidate.distance_to(game.boat.global_position) < minimum_spawn_distance:
				continue
			if not game.archipelago.water_clear(candidate, 12.0):
				continue
			sector_index = (index + 1) % sectors.size()
			return candidate
	return Vector3.INF

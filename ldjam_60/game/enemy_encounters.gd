extends Node3D
## Two distance-triggered interceptions, with one reusable hostile at a time.

const SHIP = preload("res://game/enemy_ship.tscn")
var game: Node3D
var ship: CharacterBody3D
var encounter_index: int = 0
var ships_sunk: int = 0
var enabled: bool = true
var triggers := [178.0, 438.0]


func _ready() -> void:
	ship = SHIP.instantiate()
	ship.game = game
	add_child(ship)


func update_encounters(delta: float) -> void:
	if not enabled:
		return
	ship.update_ship(delta)
	if encounter_index < triggers.size() and ship.mode in [ship.Mode.DORMANT, ship.Mode.ESCAPED]:
		if game.journey_distance() >= triggers[encounter_index]:
			ship.begin()
			encounter_index += 1


func reset() -> void:
	ship.reset()
	encounter_index = 0
	ships_sunk = 0


func stop() -> void:
	ship.reset()


func approach_warning() -> String:
	return ship.warning() if enabled else ""


func update_visuals(delta: float) -> void:
	ship.update_visuals(delta)

extends Resource

@export var display_name := "Cutter"
@export var hull := 2
@export var speed := 13.0
@export var turn_speed := 0.65
@export var turn_acceleration := 0.95
@export var acceleration := 2.0
@export var broadside_separation := 34.0
@export var approach_lead := 28.0
@export var approach_angle := -0.45
@export var reposition_angle := 0.72
@export var attack_run_seconds := 9.0
@export var return_seconds := 3.5
@export var telegraph_seconds := 0.5
@export var reload_seconds := 2.5
@export var firing_range := 78.0

@export_group("Armament")
@export_range(1, 3, 1) var broadside_guns := 2
@export var both_sides := true
@export var bow_gun := false
@export var lays_mines := false

extends Resource
## Exactly five waves; the shared ship scene reads the selected profile at spawn.
const ARCHETYPES := {
	"cutter": preload("res://game/enemies/cutter.tres"),
	"skiff": preload("res://game/enemies/skiff.tres"),
	"heavy": preload("res://game/enemies/heavy.tres")
}
@export var wave_rosters: Array[PackedStringArray] = [
	PackedStringArray(["cutter", "skiff"]),
	PackedStringArray(["cutter", "skiff", "heavy"]),
	PackedStringArray(["cutter", "skiff", "heavy", "skiff"]),
	PackedStringArray(["skiff", "cutter", "heavy", "skiff", "cutter"]),
	PackedStringArray(["skiff", "cutter"])
]
var enemy_counts: PackedInt32Array:
	get:
		var counts := PackedInt32Array()
		for roster in wave_rosters:
			counts.append(roster.size())
		return counts
@export var deadlines := PackedFloat32Array([40.0, 50.0, 65.0, 80.0, 0.0])
@export_range(0.05, 15.0, 0.05) var spawn_interval := 2.5
@export_range(1, 6, 1) var maximum_living := 6
@export var attack_slots := PackedInt32Array([1, 1, 2, 2, 2])
@export_range(0.6, 3.0, 0.1) var warning_interval := 0.7
@export_range(0.0, 3.0, 0.1) var holding_entry_seconds := 0.75
@export_range(0.0, 5.0, 0.1) var early_clear_pause := 3.0
@export_range(0.0, 10.0, 0.1) var first_wave_delay := 0.0
@export_range(50.0, 100.0, 1.0) var player_spawn_separation := 65.0
@export_range(16.0, 40.0, 1.0) var ship_spawn_separation := 25.0

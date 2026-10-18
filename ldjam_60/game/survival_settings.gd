extends Resource
## Exactly five waves; arena scale/art and the existing cutter remain shared.
@export var enemy_counts := PackedInt32Array([1, 2, 4, 6, 8])
@export var deadlines := PackedFloat32Array([40.0, 50.0, 65.0, 80.0, 0.0])
@export_range(0.05, 15.0, 0.05) var spawn_interval := 8.0
@export_range(1, 3, 1) var maximum_living := 3
@export_range(0.0, 5.0, 0.1) var early_clear_pause := 3.0
@export_range(0.0, 10.0, 0.1) var first_wave_delay := 0.0
@export_range(50.0, 100.0, 1.0) var player_spawn_separation := 65.0
@export_range(16.0, 40.0, 1.0) var ship_spawn_separation := 25.0

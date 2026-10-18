extends Node3D
## One preallocated opaque cube batch for all ships. Only emission touches instances;
## the vertex shader animates them. A busy frame replaces oldest cosmetic particles.
const CAPACITY := 192
const MAX_LIFETIME := 1.25
const SHADER = preload("res://game/combat_particles.gdshader")
var batch: MultiMeshInstance3D
var mesh: MultiMesh
var material: ShaderMaterial
var clock := 0.0
var expires_at := 0.0
var cursor := 0
var emitted := 0
var enabled := true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6018
	mesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.use_custom_data = true
	mesh.mesh = BoxMesh.new()
	mesh.instance_count = CAPACITY
	# Shader motion is world-space and cannot update the automatic mesh bounds.
	mesh.custom_aabb = AABB(Vector3(-700, -30, -700), Vector3(1400, 100, 1400))
	material = ShaderMaterial.new()
	material.shader = SHADER
	batch = MultiMeshInstance3D.new()
	batch.name = "CombatCubes"
	batch.multimesh = mesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	reset()


func reset() -> void:
	clock = 0.0
	expires_at = 0.0
	cursor = 0
	emitted = 0
	_rng.seed = 6018
	for index in CAPACITY:
		mesh.set_instance_color(index, Color(0, 0, 0, 0))
	material.set_shader_parameter("effect_time", clock)
	batch.visible = false
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	clock += delta
	material.set_shader_parameter("effect_time", clock)
	if clock >= expires_at:
		batch.visible = false
		set_process(false)


func _emit(at: Vector3, velocity: Vector3, size: Vector3, tint: Color, life: float, smoke := false) -> void:
	if not enabled:
		return
	life = clampf(life, 0.01, MAX_LIFETIME)
	var basis := Basis.from_euler(Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())).scaled(size)
	mesh.set_instance_transform(cursor, Transform3D(basis, at))
	mesh.set_instance_custom_data(cursor, Color(velocity.x, velocity.y, velocity.z, -(clock + 1.0) if smoke else clock + 1.0))
	# Keep colours in [0, 1]; signed custom birth time selects rising smoke.
	tint.a = life / MAX_LIFETIME
	mesh.set_instance_color(cursor, tint)
	cursor = (cursor + 1) % CAPACITY
	emitted += 1
	expires_at = maxf(expires_at, clock + life)
	batch.visible = true
	set_process(true)


func muzzle(at: Vector3, direction: Vector3, hostile := false) -> void:
	for i in 7:
		var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1))
		_emit(at, direction * (5.0 + i * 1.2) + spread * 2.0, Vector3.ONE * (0.23 + i * 0.025),
			Color("ffab61") if hostile else Color("ffe4a4"), 0.18 + i * 0.025)
	for i in 5:
		_emit(at + direction * i * 0.24, direction * (1.6 + i * 0.4) + Vector3.UP * 1.5,
			Vector3.ONE * (0.4 + i * 0.1), Color("8c969e"), 0.65 + i * 0.07, true)


func impact(at: Vector3, timber := true, heavy := false) -> void:
	for i in (24 if heavy else 14):
		var angle := i * 2.39996
		var radial := Vector3(sin(angle), 0, cos(angle))
		var velocity := radial * _rng.randf_range(2.0, 6.5) + Vector3.UP * _rng.randf_range(2.0, 5.5)
		var size := Vector3(0.16, 0.22, _rng.randf_range(0.5, 0.95)) if timber else Vector3.ONE * 0.22
		_emit(at + radial * 0.35, velocity, size,
			Color("e5b87c") if timber and i % 3 == 0 else Color("a87a48") if timber else Color("b2d5d9"),
			_rng.randf_range(0.55, 1.1))
	for i in (5 if heavy else 3):
		_emit(at + Vector3.UP * i * 0.3, Vector3(_rng.randf_range(-1, 1), 1.6 + i * 0.3, 0),
			Vector3.ONE * (0.55 + i * 0.15), Color("858b90"), 0.8 + i * 0.1, true)


func damage(at: Vector3, lethal := false) -> void:
	impact(at, true, lethal)
	# Short pale foam flecks distinguish our hull hit from an enemy muzzle burst.
	for i in 8:
		var angle := i * TAU / 8.0
		_emit(at + Vector3(sin(angle), -0.4, cos(angle)), Vector3(sin(angle) * 4, 3.5, cos(angle) * 4),
			Vector3(0.18, 0.38, 0.18), Color("bce5e7"), 0.55)


func trail(at: Vector3, hostile := false) -> void:
	_emit(at, Vector3.ZERO, Vector3.ONE * (0.18 if hostile else 0.12),
		Color("ffb46e") if hostile else Color("f3dcb0"), 0.22)


func smoke(at: Vector3) -> void:
	# Reuse the bounded rising-smoke cubes for a damaged flagship's small plume.
	for i in 3:
		_emit(at + Vector3.UP * i * 0.25, Vector3(0.25, 1.2 + i * 0.2, 0.15),
			Vector3.ONE * (0.5 + i * 0.15), Color("707b85"), 0.9 + i * 0.1, true)

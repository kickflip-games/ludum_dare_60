extends Node3D
const CombatMetrics = preload("res://game/combat_event_metrics.gd")
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


func _emit(at: Vector3, velocity: Vector3, size: Vector3, tint: Color, life: float, smoke := false, delay := 0.0) -> void:
	if not enabled:
		return
	life = clampf(life, 0.01, MAX_LIFETIME)
	var basis := Basis.from_euler(Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())).scaled(size)
	mesh.set_instance_transform(cursor, Transform3D(basis, at))
	mesh.set_instance_custom_data(cursor, Color(velocity.x, velocity.y, velocity.z, -(clock + delay + 1.0) if smoke else clock + delay + 1.0))
	# Keep colours in [0, 1]; signed custom birth time selects rising smoke.
	tint.a = life / MAX_LIFETIME
	mesh.set_instance_color(cursor, tint)
	cursor = (cursor + 1) % CAPACITY
	emitted += 1
	expires_at = maxf(expires_at, clock + delay + life)
	batch.visible = true
	set_process(true)


func muzzle(at: Vector3, direction: Vector3, hostile := false) -> void:
	for i in 8:
		var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1))
		var size := Vector3(0.14, 0.14, _rng.randf_range(0.35, 0.7)) if i < 3 else Vector3.ONE * _rng.randf_range(0.18, 0.32)
		_emit(at, direction * _rng.randf_range(6, 14) + spread * 3.0, size,
			Color("ffb66e") if hostile else Color("ffe9b5"), _rng.randf_range(0.12, 0.26))
	for i in 4:
		_emit(at + direction * i * 0.25, direction * (1.4 + i * 0.35) + Vector3.UP * 1.4,
			Vector3.ONE * (0.6 + i * 0.13), Color("77818b"), 0.56 + i * 0.045, true, 0.06 + i * 0.025)


func impact(at: Vector3, timber := true, heavy := false) -> void:
	var _profile_started := CombatMetrics.start()
	# A compact contact glint precedes chips; destruction gets a larger warm core.
	_emit(at, Vector3.UP * 0.4, Vector3.ONE * (1.25 if heavy else 0.65), Color("ffdfac") if timber else Color("b2c4ca"), 0.09)
	for i in (26 if heavy else 13 if timber else 7):
		var angle := i * 2.39996
		var radial := Vector3(sin(angle), 0, cos(angle))
		var velocity := radial * _rng.randf_range(2.0, 7.5 if heavy else 5.5) + Vector3.UP * _rng.randf_range(2.0, 6.5 if heavy else 4.5)
		var size := Vector3(_rng.randf_range(0.08, 0.2), _rng.randf_range(0.1, 0.24), _rng.randf_range(0.45, 1.25)) if timber else Vector3.ONE * 0.18
		_emit(at + radial * 0.2, velocity, size,
			Color("e5b87c") if timber and i % 3 == 0 else Color("94623e") if timber else Color("adb9bb"),
			_rng.randf_range(0.55, 1.2) if timber else 0.32)
	for i in (5 if heavy else 3 if timber else 1):
		_emit(at + Vector3.UP * i * 0.3, Vector3(_rng.randf_range(-1, 1), 1.6 + i * 0.3, 0),
			Vector3.ONE * ((0.85 if heavy else 0.45) + i * 0.15), Color("444d59") if heavy else Color("858b90"), 0.75 + i * 0.1, true)
	CombatMetrics.finish("combat_particles.gd:impact", _profile_started)


func damage(at: Vector3, lethal := false) -> void:
	var _profile_started := CombatMetrics.start()
	impact(at, true, lethal)
	# Short pale foam flecks distinguish our hull hit from an enemy muzzle burst.
	for i in 8:
		var angle := i * TAU / 8.0
		_emit(at + Vector3(sin(angle), -0.4, cos(angle)), Vector3(sin(angle) * 4, 3.5, cos(angle) * 4),
			Vector3(0.18, 0.38, 0.18), Color("bce5e7"), 0.55)
	CombatMetrics.finish("combat_particles.gd:damage", _profile_started)


func trail(at: Vector3, hostile := false) -> void:
	_emit(at, Vector3.ZERO, Vector3.ONE * (0.18 if hostile else 0.12),
		Color("ffb46e") if hostile else Color("f3dcb0"), 0.22)


static var _flame: ArrayMesh

static func flame_mesh() -> ArrayMesh:
	if _flame != null:
		return _flame
	_flame = ArrayMesh.new()
	# Two nested six-point flames in one cached mesh; no transparency or bloom.
	for layer in 2:
		var radius := 0.48 if layer == 0 else 0.23
		var length := 1.5 if layer == 0 else 1.95
		var vertices := PackedVector3Array()
		for side in 6:
			var a := Vector3(0.22, sin(side * TAU / 6.0) * radius, cos(side * TAU / 6.0) * radius)
			var b := Vector3(0.22, sin((side + 1) * TAU / 6.0) * radius, cos((side + 1) * TAU / 6.0) * radius)
			vertices.append_array(PackedVector3Array([Vector3(length, 0, 0), a, b, Vector3(-0.12, 0, 0), b, a]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		_flame.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color("ffad52") if layer == 0 else Color("fff1c9")
		_flame.surface_set_material(layer, mat)
	return _flame


func smoke(at: Vector3) -> void:
	# Reuse the bounded rising-smoke cubes for a damaged flagship's small plume.
	for i in 3:
		_emit(at + Vector3.UP * i * 0.25, Vector3(0.25, 1.2 + i * 0.2, 0.15),
			Vector3.ONE * (0.5 + i * 0.15), Color("707b85"), 0.9 + i * 0.1, true)

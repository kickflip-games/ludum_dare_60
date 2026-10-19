extends RefCounted
const CombatMetrics = preload("res://game/combat_event_metrics.gd")
const SMOKE_SHADER = preload("res://game/combat_particles.gdshader")
const SMOKE_CAPACITY := 16
const SMOKE_ORIGIN := Vector3(-0.9, 1.15, 0.25)
## Cosmetic hull/sail warning; health and hit timing belong to crossing.
var light_marks: MeshInstance3D
var heavy_marks: MeshInstance3D
var wood: Array[StandardMaterial3D] = []
var _wood_colors: Array[Color] = []
var _canvas: ShaderMaterial
var _canvas_color: Color
var red_strength := 0.0
var _last_strength := -1.0
var _last_severity := -1
var severity := 0
var flash_strength := 0.0
var smoke: MultiMeshInstance3D
var smoke_material: ShaderMaterial
var smoke_clock := 0.0
var smoke_emitted := 0
var _smoke_stage := 0
var _smoke_elapsed := 0.0
var _smoke_cursor := 0
var _pivot: Node3D
var _rng := RandomNumberGenerator.new()


func configure(pivot: Node3D, ship: Node3D) -> void:
	_pivot = pivot
	_build_smoke()
	# Duplicate only the player's wood materials; the imported mesh stays shared.
	var hull := ship.get_node("RootNode/Boat") as MeshInstance3D
	for surface in [0, 1]:
		var material := hull.get_active_material(surface).duplicate() as StandardMaterial3D
		# The helm now sees the inside of the existing open hull while banking.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.emission_enabled = true
		material.emission = Color("ff1810")
		material.emission_energy_multiplier = 0.0
		hull.set_surface_override_material(surface, material)
		wood.append(material)
		_wood_colors.append(material.albedo_color)
	_canvas = (ship.get_node("RootNode/Sail") as MeshInstance3D).get_active_material(1) as ShaderMaterial
	_canvas_color = _canvas.get_shader_parameter("canvas_color")
	# Two small splintered cuts on the transom, visible from the normal helm.
	light_marks = _marks(pivot, "HullScratches", [
		PackedVector3Array([Vector3(-0.82, 0.94, 0.94), Vector3(-0.57, 0.83, 0.94), Vector3(-0.67, 0.76, 0.94), Vector3(-0.39, 0.60, 0.94)]),
		PackedVector3Array([Vector3(0.23, 0.94, 0.94), Vector3(0.46, 0.85, 0.94), Vector3(0.37, 0.77, 0.94), Vector3(0.69, 0.62, 0.94)]),
		# Inboard gunwale cuts stay visible from the deck eye as well as outside.
		PackedVector3Array([Vector3(-1.08,0.92,-1.2),Vector3(-1.08,0.83,-1.4),Vector3(-1.08,0.87,-1.55),Vector3(-1.08,0.73,-1.75)]),
	], Vector3.BACK)
	# More splintering across the top of both gunwales at critical health.
	heavy_marks = _marks(pivot, "HeavyHullScratches", [
		PackedVector3Array([Vector3(-1.27, 0.978, -0.65), Vector3(-1.10, 0.978, -0.52), Vector3(-1.23, 0.978, -0.39), Vector3(-1.04, 0.978, -0.22)]),
		PackedVector3Array([Vector3(1.20, 0.978, -0.12), Vector3(1.02, 0.978, 0.02), Vector3(1.14, 0.978, 0.15), Vector3(0.94, 0.978, 0.34)]),
	], Vector3.UP)
	update(1, 1, 0.0)


func update(hull: int, capacity: int, hit_flash: float, delta: float = 0.0, sailing: bool = true) -> void:
	var _profile_started := CombatMetrics.start()
	var fraction := clampf(float(hull) / maxf(1.0, capacity), 0.0, 1.0)
	# Exact thirds put the default three-point hull into three distinct conditions.
	severity = 0 if fraction > 2.0 / 3.0 else 1 if fraction > 1.0 / 3.0 else 2
	_update_smoke(severity if hull > 0 and sailing else 0, delta)
	if severity != _last_severity:
		light_marks.visible = severity >= 1
		heavy_marks.visible = severity == 2
	# Keep impact red brief; smoke and muted scorch own the persistent condition.
	flash_strength = clampf((hit_flash - 0.62) / 0.18, 0.0, 1.0)
	red_strength = flash_strength
	if red_strength == _last_strength and severity == _last_severity:
		CombatMetrics.finish("boat_damage.gd:update", _profile_started)
		return
	_last_strength = red_strength
	_last_severity = severity
	var glow := red_strength * 0.65
	var scorch := 0.0 if severity == 0 else 0.08 if severity == 1 else 0.20
	for i in wood.size():
		wood[i].albedo_color = _wood_colors[i].lerp(Color("292b2c"), scorch).lerp(Color("ff1810"), red_strength)
		wood[i].emission_energy_multiplier = glow
	_canvas.set_shader_parameter("canvas_color", _canvas_color.lerp(Color("555659"), scorch * 0.4).lerp(Color("ff1810"), red_strength))
	_canvas.set_shader_parameter("damage_glow", glow)
	_canvas.set_shader_parameter("damage_stage", severity)
	CombatMetrics.finish("boat_damage.gd:update", _profile_started)


func _build_smoke() -> void:
	# Dedicated tiny pool lets repair clear only hull smoke, leaving combat VFX intact.
	smoke = MultiMeshInstance3D.new()
	smoke.name = "HullSmoke"
	smoke.multimesh = MultiMesh.new()
	smoke.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	smoke.multimesh.use_colors = true
	smoke.multimesh.use_custom_data = true
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 3
	smoke.multimesh.mesh = puff
	smoke.multimesh.instance_count = SMOKE_CAPACITY
	smoke_material = ShaderMaterial.new()
	smoke_material.shader = SMOKE_SHADER
	smoke.material_override = smoke_material
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(smoke)
	smoke.top_level = true
	smoke.global_transform = Transform3D.IDENTITY
	_clear_smoke()


func _clear_smoke() -> void:
	smoke.visible = false
	smoke_clock = 0.0
	smoke_emitted = 0
	_smoke_cursor = 0
	_smoke_elapsed = 0.0
	_rng.seed = 6019
	for index in SMOKE_CAPACITY:
		smoke.multimesh.set_instance_color(index, Color(0, 0, 0, 0))
	smoke_material.set_shader_parameter("effect_time", 0.0)


func _update_smoke(stage: int, delta: float) -> void:
	var interval := 0.15 if stage == 1 else 0.08
	if stage != _smoke_stage:
		_clear_smoke()
		_smoke_stage = stage
		_smoke_elapsed = interval # The new condition is visible on its first frame.
	if stage == 0: return
	smoke_clock += maxf(0.0, delta)
	smoke_material.set_shader_parameter("effect_time", smoke_clock)
	# Skip long-frame backlog; the visual pool and work per update stay bounded.
	_smoke_elapsed = minf(_smoke_elapsed + maxf(0.0, delta), interval * 2.0)
	while _smoke_elapsed >= interval:
		_smoke_elapsed -= interval
		var at := _pivot.to_global(SMOKE_ORIGIN)
		var velocity: Vector3 = (_pivot.get_parent() as CharacterBody3D).velocity * 0.8 + Vector3(0.2, 2.8 if stage == 1 else 3.4, 0.15)
		var scale := (0.9 if stage == 1 else 1.35) * _rng.randf_range(0.85, 1.15)
		var basis := Basis.from_euler(Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())).scaled(Vector3.ONE * scale)
		var tint := Color("b5bfc5") if stage == 1 else Color("46515c").lerp(Color("84919c"), _rng.randf() * 0.55)
		tint.a = (1.05 if stage == 1 else 1.2) / 1.25
		smoke.multimesh.set_instance_transform(_smoke_cursor, Transform3D(basis, at))
		smoke.multimesh.set_instance_custom_data(_smoke_cursor, Color(velocity.x, velocity.y, velocity.z, -(smoke_clock + 1.0)))
		smoke.multimesh.set_instance_color(_smoke_cursor, tint)
		_smoke_cursor = (_smoke_cursor + 1) % SMOKE_CAPACITY
		smoke_emitted += 1
		# Shader motion leaves mesh bounds; track a small region around this ship.
		smoke.multimesh.custom_aabb = AABB(at - Vector3.ONE * 18.0, Vector3.ONE * 36.0)
	smoke.visible = true


func _marks(parent: Node3D, node_name: String, cuts: Array, normal: Vector3) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	# Muted fresh-timber edges make the dark cuts readable against dark wood at night.
	for layer in range(2):
		var vertices := PackedVector3Array()
		for cut: PackedVector3Array in cuts:
			for i in range(cut.size() - 1):
				var side := (cut[i + 1] - cut[i]).cross(normal).normalized() * (0.048 if layer == 0 else 0.032)
				var lift := normal * (0.002 * layer)
				var a := cut[i] + lift
				var b := cut[i + 1] + lift
				vertices.append_array(PackedVector3Array([a - side, a + side, b + side, a - side, b + side, b - side]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color("987556") if layer == 0 else Color("211c1b")
		mesh.surface_set_material(layer, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

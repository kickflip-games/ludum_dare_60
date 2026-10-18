extends Node3D
## Shared surface for rendering, flotation, projectiles and directional wave forces.

const WaveSettings = preload("res://game/ocean/wave_settings.gd")
const WaveField = preload("res://game/ocean/wave_field.gd")
var wave_field := WaveField.new()
const WATER_SHADER = preload("res://game/sea.gdshader")
const WAKE_SHADER = preload("res://game/ocean/wake.gdshader")
const WAKE_TRAIL = preload("res://game/ocean/wake_trail.gd")
const PATCH_SIZE: float = 120.0
var settings: WaveSettings
var quality: int = 1
var wave_time: float = 0.0
var focus_xz := Vector2.ZERO
var fade_start: float = 32.0
var fade_end: float = 92.0
var material: ShaderMaterial
var wake_material: ShaderMaterial
var near_mesh: MeshInstance3D
var distant_mesh: MeshInstance3D
var wake_root: Node3D
var wake_strength: float = 0.0
var wake_yaw: float = 0.0
var floating_visuals: Array[Dictionary] = []
var cells: int = 192
var turbulence_center := Vector2.ZERO
var turbulence_radius := 80.0
var turbulence_intensity := 0.0
var _turbulence_active := false
var _turbulence_region := -1


func initialize(value: WaveSettings, quality_value: int = 1) -> void:
	settings = value
	quality = quality_value
	material = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("coastal_foam_mask",ImageTexture.create_from_image(load("res://game/ocean/coastal_foam_mask.res")))
	wake_material = ShaderMaterial.new()
	wake_material.shader = WAKE_SHADER
	near_mesh = _instance("DetailedOcean", material)
	distant_mesh = _instance("HorizonSkirt", material)
	_build_geometry()
	_build_wake()
	settings.changed.connect(_sync_settings)
	_sync_settings()


func configure(value: WaveSettings) -> void:
	if settings != null and settings.changed.is_connected(_sync_settings):
		settings.changed.disconnect(_sync_settings)
	settings = value
	settings.changed.connect(_sync_settings)
	_sync_settings()


func _instance(node_name: String, mat: ShaderMaterial) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mesh)
	return mesh


func _build_geometry() -> void:
	cells = [160, 192, 256][clampi(quality, 0, 2)]
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * PATCH_SIZE
	plane.subdivide_width = cells - 1
	plane.subdivide_depth = cells - 1
	near_mesh.mesh = plane
	# Every inner skirt vertex exactly matches the PlaneMesh edge (including corners).
	# Only eight perimeter rows extend to the horizon; no dense 3,200 m grid.
	var radii := PackedFloat32Array([60, 64, 72, 84, 100, 160, 400, 1600])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for radius in radii:
		for side in range(4):
			for i in range(cells + 1):
				var t := float(i) / cells
				var point := Vector3.ZERO
				match side:
					0: point = Vector3(lerpf(-radius, radius, t), 0, -radius)
					1: point = Vector3(radius, 0, lerpf(-radius, radius, t))
					2: point = Vector3(lerpf(radius, -radius, t), 0, radius)
					3: point = Vector3(-radius, 0, lerpf(radius, -radius, t))
				vertices.append(point)
				normals.append(Vector3.UP)
	var row_size: int = 4 * (cells + 1)
	for row in range(radii.size() - 1):
		for side in range(4):
			for i in range(cells):
				var a: int = row * row_size + side * (cells + 1) + i
				var b: int = a + 1
				var c: int = a + row_size
				var d: int = c + 1
				indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var skirt := ArrayMesh.new()
	skirt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	distant_mesh.mesh = skirt


func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	_build_geometry()
	_sync_settings()


func _sync_settings() -> void:
	if not is_instance_valid(material) or settings == null:
		return
	settings.apply_waves(material)
	settings.apply_palette(material)
	for mat: ShaderMaterial in wake_root.materials:
		settings.apply_waves(mat)
	for mat: ShaderMaterial in [material]+wake_root.materials:
		mat.set_shader_parameter("fade_start", fade_start)
		mat.set_shader_parameter("fade_end", fade_end)
	var margin: float = settings.maximum_displacement() + absf(settings.sea_level) + wave_field.MAX_WAVES * wave_field.MAX_HEIGHT + 0.6
	near_mesh.custom_aabb = AABB(Vector3(-60, -margin, -60), Vector3(120, margin * 2.0, 120))
	distant_mesh.custom_aabb = AABB(Vector3(-1600, -margin, -1600), Vector3(3200, margin * 2.0, 3200))
	near_mesh.extra_cull_margin = 0.5
	distant_mesh.extra_cull_margin = 0.5
	# The cubic sharpener has a third harmonic. Flag settings beyond grid Nyquist.
	var limit := PI / (3.0 * PATCH_SIZE / cells)
	if maxf(settings.frequency_1, maxf(settings.frequency_2, settings.frequency_3)) > limit:
		push_warning("Ocean wave frequency exceeds this quality's grid resolution; lower frequency or choose High quality.")


func update_surface(boat_position: Vector3, time: float, delta: float, speed_factor: float, heading: float) -> void:
	wave_time = time
	focus_xz = Vector2(boat_position.x, boat_position.z)
	# Only X/Z recenter. Phase and LOD focus use continuous world coordinates.
	var grid_step := PATCH_SIZE / cells
	global_position = Vector3(snappedf(boat_position.x, grid_step), 0.0, snappedf(boat_position.z, grid_step))
	material.set_shader_parameter("wave_time", wave_time)
	material.set_shader_parameter("focus_xz", focus_xz)
	wave_field.apply_to(material)
	for mat: ShaderMaterial in wake_root.materials:
		mat.set_shader_parameter("wave_time",wave_time)
		mat.set_shader_parameter("focus_xz",focus_xz)
		wave_field.apply_to(mat)
	_update_floating_visuals(delta)
	var actual_factor: float = wake_root.advance_path(boat_position,time,delta,speed_factor,heading)
	wake_strength = lerpf(wake_strength, actual_factor, 1.0 - exp(-4.0 * delta))
	wake_yaw = lerp_angle(wake_yaw, -heading, 1.0 - exp(-5.0 * delta))
	wake_material.set_shader_parameter("strength", wake_strength)


func sample_surface(p: Vector2, time: float = -1.0) -> Vector3:
	var value: Vector3 = settings.sample_wave(p, wave_time if time < 0.0 else time)
	var offset := p - focus_xz
	var distance_value := offset.length()
	var u := clampf((distance_value - fade_start) / (fade_end - fade_start), 0.0, 1.0)
	var envelope := 1.0 - u * u * (3.0 - 2.0 * u)
	var derivative := -6.0 * u * (1.0 - u) / (fade_end - fade_start)
	var envelope_gradient := offset / maxf(distance_value, 0.0001) * derivative
	return wave_field.sample(p, wave_time if time < 0.0 else time) + Vector3(value.x * envelope + settings.sea_level,
		value.y * envelope + value.x * envelope_gradient.x,
		value.z * envelope + value.x * envelope_gradient.y)


func height_at(p: Vector2, time: float = -1.0) -> float:
	return sample_surface(p, time).x


func clear_turbulence() -> void:
	turbulence_intensity = 0.0
	_turbulence_active = false
	_turbulence_region = -1
	material.set_shader_parameter("turbulence_area",Vector4.ZERO)


func update_turbulence(encounters: RefCounted, delta: float) -> void:
	# A fixed region footprint; neither its position nor its phase follows the mesh.
	var target := 0.0
	if encounters.busy():
		if _turbulence_region != encounters.region_id:
			for r: Vector4 in encounters.REGIONS:
				if int(r.w)==encounters.region_id:
					turbulence_center = Vector2(r.x,r.y)
					turbulence_radius = r.z+45.0
					_turbulence_region = encounters.region_id
		_turbulence_active = true
		target = 0.85 if encounters.phase==encounters.Phase.WARNING else 1.0
	elif encounters.phase==encounters.Phase.RECOVERY:
		target = smoothstep(15.0,20.0,encounters.phase_until-wave_time)
	elif not wave_field.waves.is_empty():
		if not _turbulence_active:
			var wave: Dictionary = wave_field.waves[0]
			turbulence_center = wave.origin+wave.direction*wave.speed*3.0
			turbulence_radius = 70.0
			_turbulence_active = true
		target = 0.7
	else:
		_turbulence_active = false
		_turbulence_region = -1
	turbulence_intensity = lerpf(turbulence_intensity,target,1.0-exp(-1.5*clampf(delta,0.0,1.0)))
	material.set_shader_parameter("turbulence_area",Vector4(turbulence_center.x,turbulence_center.y,turbulence_radius,turbulence_intensity))


func water_hit(from: Vector3, to: Vector3, delta: float) -> Dictionary:
	# Subdivide fast shots, then refine the first surface crossing in space AND time.
	var steps := clampi(ceili(from.distance_to(to) / 0.4), 1, 128)
	for i in range(steps + 1):
		var t := float(i) / steps
		var p := from.lerp(to, t)
		var at_time := maxf(0.0, wave_time - delta * (1.0 - t))
		if p.y > height_at(Vector2(p.x, p.z), at_time):
			continue
		var low := maxf(0.0, float(i - 1) / steps)
		var high := t
		for refine in range(8):
			var middle := (low + high) * 0.5
			var q := from.lerp(to, middle)
			if q.y > height_at(Vector2(q.x, q.z), maxf(0.0, wave_time - delta * (1.0 - middle))):
				low = middle
			else:
				high = middle
		return {"position": from.lerp(to, high)}
	return {}


func normal_at(p: Vector2, time: float = -1.0) -> Vector3:
	var sample_value := sample_surface(p, time)
	return Vector3(-sample_value.y, 1.0, -sample_value.z).normalized()


func register_float_visual(visual: Node3D) -> void:
	floating_visuals.append({"visual": visual, "base_y": visual.position.y})


func _update_floating_visuals(delta: float) -> void:
	var amount := 1.0 - exp(-7.0 * delta)
	for item: Dictionary in floating_visuals:
		var visual: Node3D = item.visual
		if not visual.is_visible_in_tree():
			continue
		var world: Vector3 = visual.get_parent().global_position
		var height: float = height_at(Vector2(world.x, world.z)) - settings.sea_level
		visual.position.y = lerpf(visual.position.y, item.base_y + height * 0.85, amount)


func _build_wake() -> void:
	wake_root = WAKE_TRAIL.new()
	wake_root.name = "SailingWake"
	add_child(wake_root)
	wake_root.setup(wake_material)


func reset_wake(heading: float) -> void:
	wake_strength = 0.0
	wake_yaw = -heading
	wake_root.clear_path()


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(_sync_settings):
		settings.changed.disconnect(_sync_settings)

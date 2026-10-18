extends Node
## Visual-only sail/flag motion. Add beneath an instantiated ship model.
## Sails include their yards: turn around the local vertical mast axis, never
## pitch around the mesh centre. Flag origins likewise lie on their pole axes.
@export_range(0.0, 5.0, 0.1) var sail_degrees := 2.5
@export_range(1.0, 10.0, 0.1) var sail_period := 4.2
@export_range(0.0, 12.0, 0.1) var flag_degrees := 6.0
@export_range(0.3, 3.0, 0.05) var flag_period := 1.15

var _parts: Array[Node3D] = []
var _rest: Array[Transform3D] = []
var _flags: Array[bool] = []
var _time := 0.0
var _phase := 0.0
var _model: Node3D
var _canvas: ShaderMaterial

func configure_canvas(sail: MeshInstance3D, surface: int) -> void:
	# The player's canvas shares a mesh with its fixed mast/boom, but has its own
	# surface. Deform only that surface; keep the imported mesh and wood intact.
	var original := sail.get_active_material(surface) as StandardMaterial3D
	_canvas = ShaderMaterial.new()
	_canvas.shader = preload("res://game/player_sail.gdshader")
	_canvas.set_shader_parameter("canvas_color", original.albedo_color)
	_canvas.set_shader_parameter("roughness", original.roughness)
	_canvas.set_shader_parameter("specular", original.metallic_specular)
	var vertices: PackedVector3Array = sail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(vertex)
	# This import's mast runs along mesh-local Z; the canvas spans local Y.
	_canvas.set_shader_parameter("foot_height", bounds.position.z + bounds.size.z * 0.01)
	_canvas.set_shader_parameter("foot_blend", bounds.size.z * 0.4)
	_canvas.set_shader_parameter("mast_radius", sail.get_aabb().size.x * 0.5)
	sail.set_surface_override_material(surface, _canvas)

func _ready() -> void:
	name = "ClothMotion"
	_model = get_parent() as Node3D
	# Do not consume gameplay's random stream. Each instance starts differently.
	_phase = fmod(float(get_instance_id() % 997) * 2.399963, TAU)
	_collect(_model)
	set_process(not _parts.is_empty() or _canvas != null)

func _collect(node: Node) -> void:
	if node is MeshInstance3D and (node.name.begins_with("sail-") or node.name.begins_with("flag-")):
		_parts.append(node)
		_rest.append(node.transform)
		_flags.append(node.name.begins_with("flag-"))
	for child in node.get_children():
		_collect(child)

func _process(delta: float) -> void:
	if not _model.is_visible_in_tree():
		return
	_time += delta
	if _canvas != null:
		var phase := _time * TAU / maxf(0.01, sail_period) + _phase
		_canvas.set_shader_parameter("sway_angle", deg_to_rad(sail_degrees) * _sway(phase, 0))
	for i in _parts.size():
		var period := flag_period if _flags[i] else sail_period
		var amplitude := flag_degrees if _flags[i] else sail_degrees
		var phase := _time * TAU / maxf(0.01, period) * (1.0 + i * 0.025) + _phase + i * 1.73
		# A restrained second frequency breaks up perfectly mechanical repetition.
		var sway := _sway(phase, i)
		var pose := _rest[i]
		pose.basis = pose.basis * Basis(Vector3.UP, deg_to_rad(amplitude) * sway)
		_parts[i].transform = pose

func _sway(phase: float, index: int) -> float:
	return (sin(phase) + 0.22 * sin(phase * 2.3 + index)) / 1.22

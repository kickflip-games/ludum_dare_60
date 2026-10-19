extends MeshInstance3D
const ActiveMetrics = preload("res://game/active_frame_metrics.gd")
## Persistent local geometry; the shared ocean shader supplies displacement.
const ANGLE_STEPS := 20
const RANGE_STEPS := 48
var cannon: Node3D
var surface := ImmediateMesh.new()
var material := ShaderMaterial.new()
var geometry_builds := 0
var _range := -1.0
var _angle := -1.0

func _ready() -> void:
	mesh = surface
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = preload("res://game/firing_cone.gdshader")
	material_override = material
	cannon.game.ocean.register_surface_material(material)
	visible = false

func water_point(angle: float, distance: float) -> Vector3:
	# CPU authority for tests/tools; never called by the presentation loop.
	var point: Vector3 = cannon.cone_point(angle, distance)
	point.y = cannon.game.ocean.height_at(Vector2(point.x, point.z)) + 0.16
	return point

func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.surface_set_color(color)
	for point in [a, b, c]:
		surface.surface_add_vertex(point)

func update_surface() -> void:
	var started := ActiveMetrics.start()
	if _range != cannon.cone_range or _angle != cannon.cone_half_angle:
		_build_geometry()
	var direction: Vector3 = cannon.starboard_direction()
	var origin: Vector3 = cannon.cone_origin()
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-direction.z, direction.x)), Vector3(origin.x, 0, origin.z))
	ActiveMetrics.finish("firing_guide", started)


func _build_geometry() -> void:
	_range = cannon.cone_range
	_angle = cannon.cone_half_angle
	geometry_builds += 1
	surface.clear_surfaces()
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint := Color(0.72, 0.83, 0.72, 0.12)
	var points: Array[PackedVector3Array] = []
	for ring in RANGE_STEPS + 1:
		var row := PackedVector3Array()
		for sector in ANGLE_STEPS + 1:
			var angle := deg_to_rad(lerpf(-_angle, _angle, float(sector) / ANGLE_STEPS))
			row.append(Vector3.RIGHT.rotated(Vector3.UP, angle) * _range * ring / RANGE_STEPS)
		points.append(row)
	for ring in RANGE_STEPS:
		for sector in ANGLE_STEPS:
			var a := points[ring][sector]
			var b := points[ring][sector + 1]
			var c := points[ring + 1][sector + 1]
			var d := points[ring + 1][sector]
			triangle(a, b, c, tint)
			triangle(a, c, d, tint)
	# Two narrow ribbons follow the water, with a faint fill marking maximum range.
	for side in [-1, 1]:
		var angle: float = side * cannon.cone_half_angle
		var direction := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(angle))
		var width := direction.cross(Vector3.UP) * 0.07
		for ring in RANGE_STEPS:
			var edge_index: int = 0 if side < 0 else ANGLE_STEPS
			var a := points[ring][edge_index] + Vector3.UP * 0.01
			var b := points[ring + 1][edge_index] + Vector3.UP * 0.01
			triangle(a - width, a + width, b + width, Color(0.8, 0.88, 0.77, 0.4))
			triangle(a - width, b + width, b - width, Color(0.8, 0.88, 0.77, 0.4))
	surface.surface_end()
	# Keep the displaced guide inside its culling bounds at every finite crest.
	var ocean = cannon.game.ocean
	extra_cull_margin = ocean.settings.maximum_displacement() + ocean.wave_field.MAX_WAVES * ocean.wave_field.MAX_HEIGHT + 0.2

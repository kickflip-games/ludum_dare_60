extends MeshInstance3D
## Lightweight, depth-tested water overlay. Geometry shares the targeting limits.
const ANGLE_STEPS := 20
const RANGE_STEPS := 48
var cannon: Node3D
var surface := ImmediateMesh.new()

func _ready() -> void:
	mesh = surface
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material_override = material
	visible = false

func water_point(angle: float, distance: float) -> Vector3:
	var point: Vector3 = cannon.cone_point(angle, distance)
	point.y = cannon.game.ocean.height_at(Vector2(point.x, point.z)) + 0.16
	return point

func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.surface_set_color(color)
	for point in [a, b, c]:
		surface.surface_add_vertex(point)

func update_surface() -> void:
	surface.clear_surfaces()
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint := Color(0.72, 0.83, 0.72, 0.12)
	var points: Array[PackedVector3Array] = []
	for ring in RANGE_STEPS + 1:
		var row := PackedVector3Array()
		for sector in ANGLE_STEPS + 1:
			row.append(water_point(lerpf(-cannon.cone_half_angle, cannon.cone_half_angle, float(sector) / ANGLE_STEPS), cannon.cone_range * ring / RANGE_STEPS))
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
		var direction: Vector3 = cannon.starboard_direction().rotated(Vector3.UP, deg_to_rad(angle))
		var width := direction.cross(Vector3.UP) * 0.07
		for ring in RANGE_STEPS:
			var edge_index: int = 0 if side < 0 else ANGLE_STEPS
			var a := points[ring][edge_index] + Vector3.UP * 0.01
			var b := points[ring + 1][edge_index] + Vector3.UP * 0.01
			triangle(a - width, a + width, b + width, Color(0.8, 0.88, 0.77, 0.4))
			triangle(a - width, b + width, b - width, Color(0.8, 0.88, 0.77, 0.4))
	surface.surface_end()

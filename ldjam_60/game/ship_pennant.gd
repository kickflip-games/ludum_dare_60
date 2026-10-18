extends MeshInstance3D
## One opaque, two-sided triangle. Built once; flutter only changes its transform.
var cloth := StandardMaterial3D.new()
var rest_yaw := PI / 4.0

func _init() -> void:
	name = "MastPennant"
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1, -0.42, 0.08), Vector3(0, -1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 1.0
	cloth.emission_enabled = true
	cloth.emission_energy_multiplier = 0.28
	material_override = cloth
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func configure(color: Color, dimensions: Vector2) -> void:
	cloth.albedo_color = color
	cloth.emission = color
	scale = Vector3(dimensions.x, dimensions.y, 1.0)

func flutter(time: float) -> void:
	rotation = Vector3(0.0, rest_yaw + sin(time * 4.5) * 0.16, sin(time * 6.3) * 0.045)

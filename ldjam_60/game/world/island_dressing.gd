@tool
extends Node3D
## Deterministic visual dressing on dry land. Never changes the sea, routes or collision.
const STONE = preload("res://game/world/moonlit_terrain.tres")
const FOLIAGE = preload("res://game/world/island_foliage.gdshader")
const GROVES := [
	Vector4(-32, 25, 24, 12), Vector4(-60, -50, 28, 10),
	Vector4(30, -50, 24, 8), Vector4(-70, -102, 22, 6),
	Vector4(-234, 87, 21, 8), Vector4(-269, -213, 19, 4),
	Vector4(239, 14, 24, 12), Vector4(38, 210, 16, 4),
]
@export var dressing_seed: int = 417
@export_range(0.0, 1.5, 0.1) var density: float = 1.0
var _terrain: StaticBody3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_terrain = get_parent().get_node("Terrain")
	_build()

func _build() -> void:
	_rng.seed = dressing_seed
	var trees: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	for grove: Vector4 in GROVES:
		var placed := 0
		for attempt in range(roundi(grove.w * density) * 6):
			if placed >= roundi(grove.w * density):
				break
			var angle := _rng.randf() * TAU
			var radius := sqrt(_rng.randf()) * grove.z
			var xz := Vector2(grove.x, grove.y) + Vector2.from_angle(angle) * radius
			var height := _height(xz)
			if height < 7.0 or _slope(xz) < 0.68:
				continue
			var size := _rng.randf_range(0.75, 1.35)
			trees.append(_pose(Vector3(xz.x, height - 0.35, xz.y), Vector3(size * 0.9, size, size * 0.9)))
			placed += 1
	# Sparse terrain-only scatter. Footprints are checked on all four sides so
	# boulders and grass cannot disguise a navigable channel or the shoreline.
	for z in range(-282, 290, 11):
		for x in range(-310, 321, 11):
			var xz := Vector2(x, z) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
			var height := _height(xz)
			if height < 4.5 or _near_landmark(xz):
				continue
			var slope := _slope(xz)
			if _rng.randf() < 0.30 * density and slope > 0.46 and _dry_footprint(xz):
				var scale_value := Vector3(_rng.randf_range(1.5, 3.0), _rng.randf_range(1.2, 2.5), _rng.randf_range(1.4, 2.8))
				stones.append(_pose(Vector3(xz.x, height - 0.6, xz.y), scale_value))
			if _rng.randf() < 0.60 * density and slope > 0.73 and height < 42.0:
				for blade in range(3):
					var at := xz + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2))
					var scale_value := _rng.randf_range(0.6, 1.2)
					grasses.append(_pose(Vector3(at.x, _height(at) - 0.12, at.y), Vector3.ONE * scale_value))
	var needles := ShaderMaterial.new()
	needles.shader = FOLIAGE
	var grass := needles.duplicate() as ShaderMaterial
	grass.set_shader_parameter("shadow_color", Color("475649"))
	grass.set_shader_parameter("tip_color", Color("98a18a"))
	grass.set_shader_parameter("plant_height", 1.5)
	grass.set_shader_parameter("wind_strength", 0.16)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("4e4743")
	bark.roughness = 1.0
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.22
	trunk.top_radius = 0.14
	trunk.height = 4.4
	trunk.radial_segments = 5
	# Combined mesh uses local Y=0 as the tree's ground anchor.
	var trunk_tool := SurfaceTool.new()
	trunk_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	trunk_tool.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3.UP * 2.2))
	_instances("PineTrunks", trunk_tool.commit(), bark, trees)
	_instances("PineCrowns", _pine_mesh(), needles, trees)
	_instances("CoastalBoulders", _boulder_mesh(), STONE, stones)
	_instances("DryGrass", _grass_mesh(), grass, grasses)
	set_meta("tree_count", trees.size())
	set_meta("boulder_count", stones.size())
	set_meta("grass_count", grasses.size())

func _height(at: Vector2) -> float:
	return _terrain.terrain_height_at(Vector3(at.x, 0, at.y))

func _slope(at: Vector2) -> float:
	var dx := (_height(at + Vector2(2, 0)) - _height(at - Vector2(2, 0))) * 0.25
	var dz := (_height(at + Vector2(0, 2)) - _height(at - Vector2(0, 2))) * 0.25
	return Vector3(-dx, 1, -dz).normalized().y

func _dry_footprint(at: Vector2) -> bool:
	for offset: Vector2 in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		if _height(at + offset) < 3.5:
			return false
	return true

func _near_landmark(at: Vector2) -> bool:
	return at.distance_to(Vector2(275, 250)) < 20 or at.distance_to(Vector2(45, 209)) < 12

func _pose(at: Vector3, scale_value: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(scale_value)
	return Transform3D(basis, at)

func _instances(label: String, mesh: Mesh, material: Material, poses: Array[Transform3D]) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for i in range(poses.size()):
		batch.set_instance_transform(i, poses[i])
		var tint := _rng.randf_range(0.88, 1.12)
		batch.set_instance_color(i, Color(tint, tint, tint, 1))
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	add_child(instance, false, Node.INTERNAL_MODE_BACK)

func _pine_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(3):
		var cone := CylinderMesh.new()
		cone.bottom_radius = 1.9 - tier * 0.38
		cone.top_radius = 0.0
		cone.height = 3.3 - tier * 0.20
		cone.radial_segments = 5
		var offset := Vector3(0.10 * tier, 2.9 + tier * 1.25, 0)
		tool.append_from(cone, 0, Transform3D(Basis(Vector3.UP, tier * 0.65), offset))
	return tool.commit()

func _boulder_mesh() -> ArrayMesh:
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 3
	var arrays := rock.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0:
			normal = -normal
		tool.set_normal(normal)
		for vertex: Vector3 in [a, b, c]:
			tool.add_vertex(vertex)
	return tool.commit()


func _grass_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(5):
		var angle := i * 2.4
		var center := Vector3(sin(angle) * 0.32, 0, cos(angle) * 0.32)
		var width := Vector3(cos(angle), 0, -sin(angle)) * 0.22
		tool.set_normal(Vector3.UP)
		tool.add_vertex(center - width)
		tool.add_vertex(center + width)
		tool.add_vertex(center + Vector3(0.20 * sin(angle), 0.9 + (i % 3) * 0.25, 0.10 * cos(angle)))
	return tool.commit()

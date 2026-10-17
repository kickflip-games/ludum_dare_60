@tool
extends Node3D
## Sparse deterministic groves and shore rocks; exposed outcrops have matching collision.
const STONE = preload("res://game/world/moonlit_terrain.tres")
const FOLIAGE = preload("res://game/world/island_foliage.gdshader")
const GROVES := [
	Vector4(-32, 25, 22, 8), Vector4(-60, -50, 25, 5),
	Vector4(30, -50, 21, 4), Vector4(-70, -102, 20, 3),
	Vector4(-234, 87, 18, 4), Vector4(-269, -213, 17, 2),
	Vector4(239, 14, 24, 6), Vector4(38, 210, 16, 2),
	Vector4(64, -95, 7, 1), Vector4(-101, -57, 7, 1),
]
# A few embedded angular buttresses, sized in metres. No new offshore barriers.
const OUTCROPS := [Vector4(-112, 8, 5, 7), Vector4(-76, 38, 6, 5),
	Vector4(31, 53, 6, 6), Vector4(69, -54, 6, 10), Vector4(-28, -143, 7, 9),
	Vector4(222, 60, 5, 6), Vector4(264, 49, 6, 8), Vector4(171, -194, 4, 10),
	Vector4(300, -219, 4, 11), Vector4(-251, 104, 4, 6), Vector4(291, 271, 4, 5)]
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
			var crowded := false
			for tree: Transform3D in trees:
				if Vector2(tree.origin.x, tree.origin.z).distance_to(xz) < 5.0:
					crowded = true
			if crowded:
				continue
			var size := _rng.randf_range(0.65, 1.45)
			trees.append(_pose(Vector3(xz.x, height - 0.35, xz.y), Vector3(size * _rng.randf_range(0.75, 1.1), size, size * 0.85)))
			placed += 1
	# Sparse terrain-only scatter. Footprints are checked on all four sides so
	# boulders and grass cannot disguise a navigable channel or the shoreline.
	for z in range(-282, 290, 16):
		for x in range(-310, 321, 16):
			var xz := Vector2(x, z) + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-7, 7))
			var height := _height(xz)
			if height < 4.5 or _near_landmark(xz):
				continue
			var slope := _slope(xz)
			if _rng.randf() < 0.18 * density and slope > 0.46 and _dry_footprint(xz):
				var scale_value := Vector3(_rng.randf_range(1.5, 3.0), _rng.randf_range(1.2, 2.5), _rng.randf_range(1.4, 2.8))
				stones.append(_pose(Vector3(xz.x, height - 0.6, xz.y), scale_value))
			if _rng.randf() < 0.24 * density and slope > 0.73 and height < 42.0:
				for blade in range(2):
					var at := xz + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2))
					var scale_value := _rng.randf_range(0.6, 1.2)
					grasses.append(_pose(Vector3(at.x, _height(at) - 0.12, at.y), Vector3.ONE * scale_value))
	var needles := ShaderMaterial.new()
	needles.shader = FOLIAGE
	needles.set_shader_parameter("tip_color", Color("304d43"))
	var grass := needles.duplicate() as ShaderMaterial
	grass.set_shader_parameter("shadow_color", Color("273c36"))
	grass.set_shader_parameter("tip_color", Color("526458"))
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
	_build_outcrops()
	set_meta("tree_count", trees.size())
	set_meta("boulder_count", stones.size())
	set_meta("grass_count", grasses.size())

func _build_outcrops() -> void:
	var count := 0
	var mesh := _boulder_mesh()
	for rock: Vector4 in OUTCROPS:
		var at := Vector2(rock.x, rock.y)
		if _height(at) < 1.5 or _near_landmark(at):
			continue
		var body := StaticBody3D.new()
		body.name = "ShoreOutcrop%d" % count
		body.set_meta("hazard_name", "the rocky outcrop")
		body.position = Vector3(at.x, _height(at) - 1.8, at.y)
		body.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
		body.collision_layer = 1
		body.collision_mask = 0
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = STONE
		visual.scale = Vector3(rock.z, rock.w, rock.z * 0.65)
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_convex_shape()
		collision.scale = visual.scale
		body.add_child(collision)
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		count += 1
	set_meta("outcrop_count", count)

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
	for i in range(vertices.size()):
		var v := vertices[i]
		# Sheared, uneven planes give these a broken stone silhouette.
		v.x += v.y * 0.20
		v.z += v.y * 0.12
		v.y *= 0.88 + 0.16 * sin(v.x * 2.8 + v.z * 3.1)
		vertices[i] = v
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

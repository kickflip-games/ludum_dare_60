extends SceneTree
## Offline waterline rasterization. Runtime uses one small static mask lookup.
const RESOLUTION := 1025
const RADIUS := 2.6
var mask := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_R8)
var segments := 0

func _initialize() -> void:
	mask.fill(Color.BLACK)
	var arena := "--arena" in OS.get_cmdline_user_args()
	var mesh_path := "res://game/world/arena_mesh.res" if arena else "res://game/world/archipelago_mesh.res"
	var mesh: ArrayMesh = load(mesh_path)
	var settings = load("res://game/ocean/presets/calm.tres")
	_raster_mesh(mesh,Transform3D(Basis.from_scale(Vector3(4,1,4)),Vector3.ZERO),settings.sea_level)
	var islands = load("res://game/world/archipelago.tscn").instantiate()
	for marker: Marker3D in islands.get_node("Hazards").get_children():
		if arena:
			continue
		if marker.get_meta("kind","rock") != "rock":
			continue
		var rock: Node3D = load("res://assets/pirate_kit/rock.glb").instantiate()
		var radius: float = marker.get_meta("radius",5.0)
		var pose := Transform3D(Basis(Vector3.UP,marker.position.x).scaled(Vector3.ONE*radius*2.65),marker.position)
		_rock_meshes(rock,pose,settings.sea_level)
		rock.free()
	islands.free()
	mask.set_meta("terrain_hash",FileAccess.get_sha256(mesh_path))
	mask.set_meta("layout_hash",FileAccess.get_sha256("res://game/world/archipelago.tscn"))
	mask.set_meta("sea_level",settings.sea_level)
	mask.set_meta("radius_m",RADIUS)
	mask.set_meta("segments",segments)
	var output_path := "res://game/ocean/arena_coastal_foam_mask.res" if arena else "res://game/ocean/coastal_foam_mask.res"
	assert(ResourceSaver.save(mask,output_path,ResourceSaver.FLAG_COMPRESS)==OK)
	print("COASTAL FOAM: %d exact waterline segments, %dx%d R8, %.1fm band" % [segments,RESOLUTION,RESOLUTION,RADIUS])
	quit()

func _rock_meshes(node: Node3D, parent_pose: Transform3D, level: float) -> void:
	var pose := parent_pose*node.transform
	if node is MeshInstance3D:
		_raster_mesh(node.mesh,pose,level)
	for child in node.get_children():
		if child is Node3D:
			_rock_meshes(child,pose,level)

func _raster_mesh(mesh: Mesh, pose: Transform3D, level: float) -> void:
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count,3):
			var points: Array[Vector3] = []
			for j in range(3):
				points.append(pose*vertices[indices[i+j] if not indices.is_empty() else i+j])
			if minf(points[0].y,minf(points[1].y,points[2].y))>=level or maxf(points[0].y,maxf(points[1].y,points[2].y))<=level:
				continue
			var crossings: Array[Vector2] = []
			for j in range(3):
				var a := points[j]
				var b := points[(j+1)%3]
				if (a.y<level)==(b.y<level):
					continue
				var p := a.lerp(b,(level-a.y)/(b.y-a.y))
				crossings.append(Vector2(p.x,p.z))
			if crossings.size()==2:
				_segment(crossings[0],crossings[1])

func _segment(a: Vector2, b: Vector2) -> void:
	segments += 1
	var low := (a.min(b)-Vector2.ONE*RADIUS+Vector2.ONE*512).floor()
	var high := (a.max(b)+Vector2.ONE*RADIUS+Vector2.ONE*512).ceil()
	var edge := b-a
	for z in range(maxi(0,int(low.y)),mini(RESOLUTION,int(high.y)+1)):
		for x in range(maxi(0,int(low.x)),mini(RESOLUTION,int(high.x)+1)):
			var p := Vector2(x-512,z-512)
			var nearest := a+edge*clampf((p-a).dot(edge)/maxf(edge.length_squared(),0.0001),0,1)
			var value := 1.0-smoothstep(0.15,RADIUS,p.distance_to(nearest))
			if value>mask.get_pixel(x,z).r:
				mask.set_pixel(x,z,Color(value,0,0,1))

extends Node3D
## Fixed-capacity movement history; two reusable meshes, no spawned wake nodes.
const CAPACITY := 96
const LIFETIME := 5.0
var materials: Array[ShaderMaterial] = []
var points := PackedVector3Array()
var directions := PackedVector2Array()
var times := PackedFloat32Array()
var speeds := PackedFloat32Array()
var count := 0
var cursor := -1
var previous := Vector3.ZERO
var initialized := false
var sample_clock := 0.0
var draw_clock := 0.0
var last_time := 0.0
var meshes: Array[ArrayMesh] = []
var buffers: Array[Array] = []

func setup(material: ShaderMaterial) -> void:
	points.resize(CAPACITY)
	directions.resize(CAPACITY)
	times.resize(CAPACITY)
	speeds.resize(CAPACITY)
	materials.assign([material,material.duplicate()])
	for kind in range(2):
		materials[kind].set_shader_parameter("wake_kind",kind)
		var mesh := ArrayMesh.new()
		meshes.append(mesh)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var size := CAPACITY*2*(2 if kind==0 else 1)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var colors := PackedColorArray()
		vertices.resize(size)
		normals.resize(size)
		normals.fill(Vector3.UP)
		uv.resize(size)
		colors.resize(size)
		var indices := PackedInt32Array()
		for wing in range(2 if kind==0 else 1):
			for i in range(CAPACITY-1):
				var a := (wing*CAPACITY+i)*2
				indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		buffers.append(arrays)
		var node := MeshInstance3D.new()
		node.name = "VWake" if kind==0 else "SternTurbulence"
		node.mesh = mesh
		node.material_override = materials[kind]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 9.0
		add_child(node)
	_rebuild(0)

func clear_path() -> void:
	count = 0
	cursor = -1
	initialized = false
	sample_clock = 0
	draw_clock = 0
	_rebuild(last_time)

func advance_path(at: Vector3, time: float, delta: float, speed_factor: float, heading: float) -> float:
	# Vertices are in world coordinates. Recentring the ocean must never drag foam.
	global_transform = Transform3D.IDENTITY
	var motion := Vector2(at.x-previous.x,at.z-previous.z)
	if not initialized or motion.length()>24.0 or time<last_time:
		count = 0
		cursor = -1
		previous = at
		initialized = true
		motion = Vector2.ZERO
	last_time = time
	var factor := minf(clampf(speed_factor,0,1),motion.length()/maxf(delta*6.3,0.001))
	previous = at
	sample_clock += delta
	draw_clock += delta
	if sample_clock>=1.0/15.0 and motion.length()>0.001 and factor>0.025:
		sample_clock = 0
		cursor = (cursor+1)%CAPACITY
		count = mini(CAPACITY,count+1)
		points[cursor] = at-Vector3(sin(heading),0,-cos(heading))*0.65
		directions[cursor] = motion.normalized()
		times[cursor] = time
		speeds[cursor] = factor
	if draw_clock>=1.0/30.0:
		draw_clock = 0
		_rebuild(time)
	return factor

func _rebuild(time: float) -> void:
	for kind in range(meshes.size()):
		var arrays := buffers[kind]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for wing in range(2 if kind==0 else 1):
			for i in range(CAPACITY):
				var slot := posmod(cursor-mini(i,maxi(0,count-1)),CAPACITY)
				var age := maxf(0,time-times[slot])
				var life := LIFETIME if kind==0 else 1.35
				var fade := pow(maxf(0,1.0-age/life),1.45)*speeds[slot]
				if count<2 or i>=count:
					fade = 0
				var tangent := directions[slot]
				var side := Vector3(-tangent.y,0,tangent.x)
				var center := points[slot]
				var width := 0.20+age*0.045 if kind==0 else 0.26+age*0.18
				# Deposit-time variation breaks ruler-straight arms without new geometry
				# or moving the fixed world-space history as the ship turns.
				width *= 0.78+0.22*sin(times[slot]*3.3+wing*2.1)
				center += side*0.10*sin(times[slot]*5.1+wing*2.4)
				if kind==0:
					center += side*(-1 if wing==0 else 1)*(0.8+age*1.12*speeds[slot])
				for edge in range(2):
					var index := (wing*CAPACITY+i)*2+edge
					vertices[index] = center+side*width*(-1 if edge==0 else 1)
					uv[index] = Vector2(edge,times[slot])
					colors[index] = Color(1,1,1,fade)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = colors
		buffers[kind] = arrays
		meshes[kind].clear_surfaces()
		meshes[kind].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

extends Node3D
## Authored scenery at existing markers. Terrain and progression stay authoritative.
const SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const ROCK = preload("res://assets/pirate_kit/rock.glb")
const STONE = preload("res://game/world/moonlit_terrain.tres")
const CLOTH = preload("res://game/world/landmark_cloth.gdshader")
const BEAM = preload("res://game/world/lighthouse_beam.gdshader")
var game: Node3D
var map: Node3D
var materials: Dictionary = {}
var cloth: ShaderMaterial
var beam_pivot: Node3D
var warm_lights: Array[OmniLight3D] = []
var batch_count := 0


func configure(value: Node3D, world: Node3D, wreck_body: StaticBody3D) -> void:
	game = value
	map = world
	for entry in [["wood","55483c"],["cut_wood","95806a"],["iron","293a40"],
		["masonry","52646c"],["tower","89958f"],["stripe","354b56"],
		["roof","533e3c"],["rope","746f5c"],["cargo","6b6850"]]:
		materials[entry[0]] = game._material(Color(entry[1]))
	materials["amber"] = game._material(Color("ffc77a"), 1.5)
	materials["window"] = game._material(Color("d39b53"), 0.65)
	cloth = ShaderMaterial.new()
	cloth.shader = CLOTH
	_build_wreck(wreck_body)
	_build_peaks()
	_build_tower()
	_build_harbour()
	_build_discoveries()
	set_meta("site_count", 6)
	set_meta("batch_count", batch_count)


func _process(_delta: float) -> void:
	if not is_instance_valid(game):
		return
	cloth.set_shader_parameter("visual_time", game.sea_time)
	if is_instance_valid(beam_pivot):
		beam_pivot.rotation.y = game.sea_time * 0.22 + 0.4
	for i in warm_lights.size():
		# Tiny asynchronous lantern flicker; local lights never cast shadows.
		warm_lights[i].light_energy = warm_lights[i].get_meta("base_energy") * (1.0 + 0.035 * sin(game.sea_time * 1.3 + i * 2.4))


func _group(label: String, parent: Node3D, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node


func _box(parent: Node3D, size_value: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	return game._box(parent, size_value, at, mat)


func _cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	return game._cylinder(parent, bottom, top, height, at, mat)


func _spar(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = _cylinder(parent, radius, radius * 0.83, a.distance_to(b), (a+b)*0.5, mat)
	mesh.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return mesh


func _rope(parent: Node3D, a: Vector3, b: Vector3, sag: float) -> void:
	var previous := a
	for i in range(1,6):
		var t := i / 5.0
		var next := a.lerp(b,t) + Vector3.DOWN * sin(t*PI) * sag
		_spar(parent,previous,next,0.035,materials.rope)
		previous = next


func _lantern(parent: Node3D, at: Vector3, energy: float = 1.2, reach: float = 10.0) -> void:
	_cylinder(parent,0.32,0.26,0.12,at+Vector3.UP*0.46,materials.iron)
	_box(parent,Vector3(0.37,0.65,0.37),at,materials.amber)
	_cylinder(parent,0.28,0.28,0.12,at-Vector3.UP*0.39,materials.iron)
	for x: float in [-0.23,0.23]:
		_spar(parent,at+Vector3(x,-0.35,0),at+Vector3(x,0.4,0),0.035,materials.iron)
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("ffc27a")
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	light.set_meta("base_energy",energy)
	parent.add_child(light)
	warm_lights.append(light)


func _cloth(parent: Node3D, vertices: Array[Vector3], uvs: Array[Vector2], triangles: Array[int]) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in triangles:
		tool.set_uv(uvs[i])
		tool.add_vertex(vertices[i])
	tool.generate_normals()
	game._mesh(parent,tool.commit(),Vector3.ZERO,cloth)


func _build_wreck(body: StaticBody3D) -> void:
	body.rotation.y = -0.5
	var visual: Node3D = body.get_node("HazardVisual")
	for child in visual.get_children():
		child.free()
	var bow := _group("BrokenBow",visual,Vector3(0,-0.25,-0.3))
	bow.rotation.z = -0.12
	_hull_section(bow,[-6.2,-4.5,-2.7,-1.0],[0.2,1.9,2.8,2.7],[2.0,1.7,1.45,1.15])
	var stern := _group("BrokenStern",visual,Vector3(0.55,-0.35,0.7))
	stern.rotation = Vector3(0.16,0.10,0.19)
	_hull_section(stern,[0.9,2.7,4.7],[2.7,2.6,2.1],[1.3,1.55,1.9])
	_box(stern,Vector3(4.2,1.5,0.22),Vector3(0,0.8,4.7),materials.wood)
	for i in 5:
		if i != 2:
			_box(stern,Vector3(0.72,0.18,2.7),Vector3(-1.6+i*0.8,1.3,3.2),materials.cut_wood)
	var mast := _group("SnappedMast",visual,Vector3(0.1,0.9,-1.0))
	mast.rotation_degrees = Vector3(11,60,21)
	_spar(mast,Vector3.ZERO,Vector3(0,12.6,0),0.28,materials.wood)
	_spar(mast,Vector3(-4.3,9.0,0),Vector3(3.8,9.0,0),0.16,materials.cut_wood)
	_spar(mast,Vector3(0,12.6,0),Vector3(-0.16,13.1,0.1),0.12,materials.cut_wood)
	_cloth(mast,[Vector3(-4.1,8.9,0),Vector3(3.5,8.9,0),Vector3(2.5,7.0,0.2),Vector3(1.2,7.65,0.2),Vector3(0.3,4.9,0.4),Vector3(-1.0,6.1,0.3),Vector3(-2.6,5.6,0.25)],
		[Vector2(0,0),Vector2(1,0),Vector2(0.85,0.5),Vector2(0.7,0.3),Vector2(0.58,1),Vector2(0.4,0.8),Vector2(0.15,0.9)],
		[0,1,3,1,2,3,0,3,5,3,4,5,0,5,6])
	_rope(visual,visual.to_local(mast.to_global(Vector3(0,11.5,0))),Vector3(-2.5,1.3,4.8),0.65)
	_rope(mast,Vector3(-4.2,9.0,0),Vector3(0,12.3,0),0.3)
	_rope(mast,Vector3(3.7,9.0,0),Vector3(0,12.3,0),0.4)
	_spar(visual,Vector3(-2.6,1.6,1.1),Vector3(-3.1,3.2,1.3),0.13,materials.cut_wood)
	_spar(visual,Vector3(2.5,1.4,-0.2),Vector3(2.8,2.7,-0.6),0.12,materials.cut_wood)
	_lantern(visual,Vector3(-1.5,2.25,3.8),1.8,13.0)
	_box(visual,Vector3(1.2,0.9,1.1),Vector3(1.1,1.9,3.1),materials.cargo).rotation.y = 0.3
	_batch(visual)
	# Low scraps bob with the existing ocean sampler; these are small enough to
	# sail over, and do not add hidden walls around the objective's pickup circle.
	for i in 4:
		var debris := _group("WreckDrift%d"%i,self,body.position+Vector3(-8.0+i*1.4,0,5.5+i*1.6))
		debris.set_meta("landmark",true)
		var scraps := _group("FloatingTimber",debris)
		_box(scraps,Vector3(0.4,0.15,2.6-i*0.25),Vector3.ZERO,materials.cut_wood).rotation.y = i*1.15
		game.ocean.register_float_visual(scraps)
		_batch(scraps)
	_embedded_rock("WreckShoreRock",Vector2(-261,-185),Vector3(3.0,4.0,2.4))


func _hull_section(parent: Node3D, stations: Array, widths: Array, rims: Array) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(stations.size()-1):
		for side in [-1.0,1.0]:
			for band in 3:
				var t0 := band/3.0
				var t1 := (band+1)/3.0
				var points: Array[Vector3] = []
				for pair in [[i,t0],[i+1,t0],[i+1,t1],[i,t1]]:
					var station: int = pair[0]
					var t: float = pair[1]
					points.append(Vector3(side*widths[station]*lerpf(0.32,1.0,t),lerpf(-0.9,rims[station],t),stations[station]))
				for j in [0,1,2,0,2,3]:
					tool.add_vertex(points[j])
	tool.generate_normals()
	var mat: StandardMaterial3D = materials.wood.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	game._mesh(parent,tool.commit(),Vector3.ZERO,mat)
	for i in stations.size():
		for side in [-1.0,1.0]:
			_spar(parent,Vector3(side*widths[i],rims[i]+0.1,stations[i]),Vector3(side*widths[i]*0.32,-0.8,stations[i]),0.12,materials.cut_wood)
	for side in [-1.0,1.0]:
		for i in range(stations.size()-1):
			_spar(parent,Vector3(side*widths[i],rims[i],stations[i]),Vector3(side*widths[i+1],rims[i+1],stations[i+1]),0.1,materials.cut_wood)


func _build_peaks() -> void:
	var west := _group("PeaksLookout",self,_ground(Vector2(185,-193)))
	_cylinder(west,3.2,2.9,7.0,Vector3(0,-3.0,0),materials.masonry)
	_ruin(west,2.7,4.8,false)
	_spar(west,Vector3(1.6,3.5,0.5),Vector3(1.2,7.1,0.5),0.12,materials.wood)
	_cloth(west,[Vector3(1.2,7,0.5),Vector3(3.7,6.8,0.5),Vector3(2.8,5.8,0.5),Vector3(1.4,6.0,0.5)],
		[Vector2.ZERO,Vector2(1,0),Vector2(1,1),Vector2(0,1)],[0,1,2,0,2,3])
	_batch(west)
	_embedded_rock("WestPeakCrown",Vector2(177,-217),Vector3(2.2,7.0,2.7))
	_embedded_rock("EastPeakBlade",Vector2(284,-217),Vector3(2.2,10.0,3.2))
	_embedded_rock("WestEntranceButtress",Vector2(189,-183),Vector3(3.0,4.5,2.4))
	_embedded_rock("EastEntranceButtress",Vector2(279,-188),Vector3(3.0,6.0,2.5))


func _ground(xz: Vector2) -> Vector3:
	return Vector3(xz.x,map.get_node("Terrain").terrain_height_at(Vector3(xz.x,0,xz.y)),xz.y)


func _embedded_rock(label: String, xz: Vector2, size_value: Vector3) -> void:
	# Embedded only in existing dry land. Never move a shoreline or narrow water.
	for offset: Vector2 in [Vector2.ZERO,Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]:
		if _ground(xz+offset).y < 1.0:
			return
	var parent := _group(label,self,_ground(xz)-Vector3.UP)
	var rock: Node3D = ROCK.instantiate()
	parent.add_child(rock)
	rock.scale = size_value * 1.5
	_tint(rock,STONE)
	# Exact transformed convex meshes match the added rock, including any edge
	# visible above the heightmap. No broad invisible collision sphere.
	var meshes: Array[MeshInstance3D] = []
	_gather(rock,meshes)
	for mesh in meshes:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("hazard_name","the weathered rock")
		parent.add_child(body)
		body.add_to_group("story_rocks")
		var collision := CollisionShape3D.new()
		var points := mesh.mesh.get_faces()
		var local_pose := parent.global_transform.affine_inverse()*mesh.global_transform
		for i in points.size():
			points[i] = local_pose*points[i]
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		shape.margin = 0.02
		collision.shape = shape
		body.add_child(collision)
	_batch(parent)


func _build_tower() -> void:
	var tower := _group("LighthouseStonework",self,map.get_node("Landmarks/Lighthouse").position)
	_cylinder(tower,7.8,6.4,2.4,Vector3(0,1.0,0),materials.masonry)
	_cylinder(tower,4.2,2.85,28.0,Vector3(0,15.2,0),materials.tower)
	_cylinder(tower,3.78,3.66,2.6,Vector3(0,13.0,0),materials.stripe)
	_cylinder(tower,3.27,3.18,2.0,Vector3(0,23.5,0),materials.stripe)
	_cylinder(tower,4.65,4.65,0.65,Vector3(0,29.6,0),materials.masonry)
	_cylinder(tower,4.7,4.3,0.3,Vector3(0,30.0,0),materials.iron)
	for i in 8:
		var angle := i * TAU / 8.0
		var at := Vector3(sin(angle),0,cos(angle))
		_spar(tower,at*3.0+Vector3.UP*30.1,at*3.0+Vector3.UP*33.3,0.13,materials.iron)
		_spar(tower,at*4.25+Vector3.UP*30.0,at*4.25+Vector3.UP*31.2,0.07,materials.iron)
	for y: float in [30.6,31.2]:
		_ring(tower,4.25,y,0.055,materials.iron)
	_cylinder(tower,4.5,0.6,3.0,Vector3(0,34.5,0),materials.roof)
	_spar(tower,Vector3(0,36.0,0),Vector3(0,38.1,0),0.10,materials.iron)
	_box(tower,Vector3(1.65,3.1,0.18),Vector3(0,3.0,-4.02),materials.iron)
	for i in 3:
		var y := 8.0+i*6.8
		var z := -lerpf(3.88,3.08,i/2.0)
		_box(tower,Vector3(1.13,1.9,0.20),Vector3(0,y,z),materials.masonry)
	_batch(tower)


func build_lighthouse_effects(beacon: Node3D) -> MeshInstance3D:
	# The stone silhouette can be seen earlier. Only the existing late-voyage
	# beacon node owns warm windows, lantern and beam; its activation is unchanged.
	for i in 3:
		_box(beacon,Vector3(0.68,1.35,0.08),Vector3(0,8.0+i*6.8,-lerpf(4.0,3.2,i/2.0)),materials.window)
	var lamp: MeshInstance3D = _cylinder(beacon,0.7,0.7,2.3,Vector3(0,31.7,0),materials.amber)
	lamp.set_meta("keep_instance",true)
	_lantern(beacon,Vector3(0,31.7,0),3.2,25.0)
	for y: float in [30.9,32.5]:
		_cylinder(beacon,1.25,1.25,0.18,Vector3(0,y,0),materials.window)
	beam_pivot = _group("SweepingLantern",beacon,Vector3(0,31.7,0))
	var material := ShaderMaterial.new()
	material.shader = BEAM
	material.set_shader_parameter("strength",0.14)
	var beam: MeshInstance3D = game._mesh(beam_pivot,_beam_mesh(185,13),Vector3.ZERO,material)
	beam.name = "MainBeam"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.set_meta("keep_instance",true)
	var return_mat: ShaderMaterial = material.duplicate()
	return_mat.set_shader_parameter("strength",0.065)
	var counter: MeshInstance3D = game._mesh(beam_pivot,_beam_mesh(100,8),Vector3.ZERO,return_mat)
	counter.name = "CounterBeam"
	counter.rotation.y = PI
	counter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	counter.set_meta("keep_instance",true)
	_batch(beacon)
	set_meta("batch_count",batch_count)
	return lamp


func _beam_mesh(length_value: float, radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a := i*TAU/16.0
		var b := (i+1)*TAU/16.0
		var points := [Vector3(cos(a)*0.5,sin(a)*0.5,0),Vector3(cos(b)*0.5,sin(b)*0.5,0),
			Vector3(cos(b)*radius,sin(b)*radius,-length_value),Vector3(cos(a)*radius,sin(a)*radius,-length_value)]
		for index in [0,1,2,0,2,3]:
			tool.set_uv(Vector2(float(index%2),0.0 if index<2 else 1.0))
			tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()


func _ring(parent: Node3D, radius: float, y: float, thickness: float, material: Material) -> void:
	for i in 8:
		var a := i*TAU/8.0
		var b := (i+1)*TAU/8.0
		_spar(parent,Vector3(sin(a)*radius,y,cos(a)*radius),Vector3(sin(b)*radius,y,cos(b)*radius),thickness,material)


func _build_harbour() -> void:
	var tower_at: Vector3 = map.get_node("Landmarks/Lighthouse").position
	var dock := _group("ArrivalJetty",self,Vector3(tower_at.x-23,0,tower_at.z-34))
	_dock(dock,11.0,3.1)
	_lantern(dock,Vector3(-1.55,2.6,-4.8),1.2,12.0)
	_spar(dock,Vector3(-1.55,0,-4.8),Vector3(-1.55,3.2,-4.8),0.12,materials.wood)
	_rope(dock,Vector3(-1.55,2.1,-4.5),Vector3(-1.55,2.0,3.0),0.45)
	for i in 4:
		_box(dock,Vector3(2.6,0.28,0.8),Vector3(0,1.5+i*0.55,5.0+i*0.85),materials.cut_wood)
	_batch(dock)


func _dock(parent: Node3D, length_value: float, width: float) -> void:
	var body := StaticBody3D.new()
	body.name = "JettyCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("hazard_name","the old jetty")
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,0.35,length_value)
	collision.shape = shape
	collision.position.y = 1.15
	body.add_child(collision)
	for i in 12:
		var z := (i/11.0-0.5)*length_value
		var plank: MeshInstance3D = _box(parent,Vector3(width if i!=0 else width*0.62,0.20,length_value/13.0),Vector3(0,1.15,z),materials.cut_wood if i%3==0 else materials.wood)
		plank.rotation.y = 0.035*sin(i*2.7)
	for z: float in [-length_value*0.43,length_value*0.33]:
		for side in [-1.0,1.0]:
			_spar(parent,Vector3(side*width*0.5,-2,z),Vector3(side*width*0.5,1.9,z),0.17,materials.wood)


func _build_discoveries() -> void:
	var markers: Node3D = map.get_node("OptionalDiscoveries")
	var cove: Vector3 = markers.get_node("HiddenCove").position
	var salvage: Vector3 = markers.get_node("Salvage").position
	var outpost: Vector3 = markers.get_node("Outpost").position
	var skiff := _group("LanternCoveSkiff",self,cove+Vector3(-8,0,-3))
	var skiff_body := _solid(skiff,Vector3(3.6,1.1,2.5),Vector3(0,0.4,0),"the moored fishing boat")
	skiff_body.set_meta("landmark",true)
	var float_visual := _group("FloatingSkiff",skiff_body,Vector3(0,-0.55,0))
	var hull: Node3D = SHIP.instantiate()
	float_visual.add_child(hull)
	hull.scale = Vector3(0.72,0.65,0.72)
	hull.rotation.z = -0.10
	_tint(hull,materials.wood)
	_spar(float_visual,Vector3(0,0.8,0),Vector3(-0.55,4.6,0),0.10,materials.cut_wood)
	_spar(float_visual,Vector3(-1.2,3.7,0),Vector3(1.1,4.0,0),0.075,materials.wood)
	_rope(float_visual,Vector3(-0.5,4.4,0),Vector3(1.8,1.0,0),0.2)
	_lantern(float_visual,Vector3(-1.1,1.65,0.45),0.85,8.0)
	game.ocean.register_float_visual(float_visual)
	_batch(float_visual)
	var mooring := _group("CoveMooring",self,cove+Vector3(-22,0,-2))
	_solid(mooring,Vector3(0.45,3.5,0.45),Vector3(0,0.65,0),"the mooring post")
	_spar(mooring,Vector3(0,-1,0),Vector3(-0.15,2.4,0),0.19,materials.wood)
	_rope(mooring,Vector3(0,1.9,0),Vector3(12,0.7,-1),0.8)
	_box(mooring,Vector3(1.3,0.12,2.2),Vector3(-0.7,0.45,0),materials.cut_wood).rotation.y = -0.2
	_batch(mooring)
	var cache := _group("DriftersCargo",self,salvage+Vector3(-5,0,3))
	var raft_body := _solid(cache,Vector3(4.9,2.5,3.5),Vector3(0,1.0,0),"the drifting cargo")
	raft_body.set_meta("landmark",true)
	var raft := _group("FloatingCargo",raft_body,Vector3(0,-0.9,0))
	for i in 6:
		_box(raft,Vector3(0.6,0.25,3.4),Vector3(-2+i*0.8,0,0),materials.wood)
	for i in 3:
		var crate := _group("LashedCrate%d"%i,raft,Vector3(-1.2+i*1.15,0.8,0.2 if i%2 else -0.45))
		crate.rotation.y = i*0.3-0.2
		_box(crate,Vector3(1.05,1.2,1.1),Vector3.ZERO,materials.cargo)
		for y: float in [-0.45,0.45]:
			_box(crate,Vector3(1.12,0.12,1.18),Vector3(0,y,0),materials.cut_wood)
		_box(crate,Vector3(0.12,1.3,1.18),Vector3.ZERO,materials.cut_wood)
	_lantern(raft,Vector3(1.2,2.0,0.1),0.85,8.0)
	_rope(raft,Vector3(-2.1,0.4,-1.5),Vector3(2.1,1.55,1.2),0.15)
	game.ocean.register_float_visual(raft)
	_batch(raft)
	var watch := _group("WatchmansRest",self,_ground(Vector2(outpost.x-20,outpost.z+9)))
	watch.rotation.y = deg_to_rad(120)
	_ruin(watch,3.3,6.4,true)
	_lantern(watch,Vector3(0,1.8,3.3),0.9,9.0)
	_box(watch,Vector3(0.95,1.5,0.18),Vector3(0,2.7,-2.85),materials.iron)
	_box(watch,Vector3(0.55,1.05,0.12),Vector3(0,2.7,-2.72),materials.window)
	_box(watch,Vector3(1.7,0.2,0.55),Vector3(0,0.4,3.7),materials.wood).rotation.y = 0.4
	_batch(watch)


func _solid(parent: Node3D, size_value: Vector3, at: Vector3, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.set_meta("hazard_name",label)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	return body


func _ruin(parent: Node3D, radius: float, height: float, roof_fragment: bool) -> void:
	_cylinder(parent,radius+0.5,radius+0.25,0.65,Vector3(0,0.2,0),materials.masonry)
	# Deliberate east-facing opening, asymmetric broken wall heights, no interior.
	for i in range(2,9):
		var angle := i*TAU/10.0
		var h: float = height * [0.62,0.9,1.0,0.85,0.68,0.48,0.37][i-2]
		var block: MeshInstance3D = _box(parent,Vector3(radius*0.64,h,0.65),Vector3(sin(angle)*radius,h*0.5,cos(angle)*radius),materials.masonry)
		block.rotation.y = angle
		if i%2==0:
			_box(parent,Vector3(0.55,0.8,0.7),Vector3(sin(angle)*radius,h+0.2,cos(angle)*radius),materials.tower).rotation.y = angle+0.12
	if roof_fragment:
		_spar(parent,Vector3(-2,height*0.7,-1),Vector3(1.5,height*0.9,1.5),0.16,materials.wood)
		_box(parent,Vector3(2.5,0.18,1.5),Vector3(-1.2,height*0.8,0),materials.roof).rotation.z = 0.22


func _tint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_tint(child,material)


func _gather(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and not node.get_meta("keep_instance",false):
		meshes.append(node)
	for child in node.get_children():
		_gather(child,meshes)


func _batch(parent: Node3D) -> void:
	# One baked-at-load mesh per material and cluster. Moving wreck/skiff/raft
	# clusters keep their own local frame; collision and lights retain their nodes.
	var meshes: Array[MeshInstance3D] = []
	_gather(parent,meshes)
	var groups: Dictionary = {}
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			var key := material.get_instance_id()
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":material}
			groups[key].tool.append_from(mesh.mesh,surface,parent.global_transform.affine_inverse()*mesh.global_transform)
	for key in groups:
		var batch: MeshInstance3D = game._mesh(parent,groups[key].tool.commit(),Vector3.ZERO,groups[key].material)
		batch.name = "PaintedBatch%d"%batch_count
		batch.add_to_group("story_meshes")
		batch_count += 1
	for mesh in meshes:
		mesh.free()

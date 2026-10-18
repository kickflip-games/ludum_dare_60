extends SceneTree
func _initialize() -> void: run.call_deferred()
func collect(node: Node3D, pose: Transform3D, data: Dictionary) -> void:
	pose = pose * node.transform
	if node is MeshInstance3D:
		data.objects += 1
		for surface in node.mesh.get_surface_count():
			data.surfaces += 1
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var mat: StandardMaterial3D = node.get_active_material(surface)
			for i in range(0, indices.size(), 3):
				var triangle := {"v":[], "n":[], "color":mat.albedo_color}
				for j in 3:
					var k := indices[i+j]
					triangle.v.append(pose * vertices[k])
					triangle.n.append((pose.basis.inverse().transposed() * normals[k]).normalized())
				data.triangles.append(triangle)
	for child in node.get_children():
		if child is Node3D: collect(child, pose, data)
func first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D: return node.mesh
	for child in node.get_children():
		var found := first_mesh(child)
		if found != null: return found
	return null
func run() -> void:
	var records: Array[Dictionary] = []
	for path in ["res://assets/boss_mine/spike_mine.glb", "res://assets/optimized/spike_mine.glb"]:
		var instance = load(path).instantiate()
		var data := {"objects":0,"surfaces":0,"triangles":[]}
		collect(instance, Transform3D.IDENTITY, data)
		records.append(data)
		instance.free()
	var unmatched: Array = records[1].triangles.duplicate()
	var max_position_error := 0.0
	var max_normal_error := 0.0
	for triangle in records[0].triangles:
		var best := INF
		var best_index := -1
		var normal_error := INF
		for i in unmatched.size():
			var other: Dictionary = unmatched[i]
			if other.color != triangle.color: continue
			for rotation in 3:
				var error := 0.0
				var normals_error := 0.0
				for j in 3:
					error = maxf(error, triangle.v[j].distance_to(other.v[(j+rotation)%3]))
					normals_error = maxf(normals_error, triangle.n[j].distance_to(other.n[(j+rotation)%3]))
				if error < best:
					best = error
					best_index = i
					normal_error = normals_error
		if best_index >= 0: unmatched.remove_at(best_index)
		max_position_error = maxf(max_position_error, best)
		max_normal_error = maxf(max_normal_error, normal_error)
	var passed: bool = unmatched.is_empty() and max_position_error < 0.00002 and max_normal_error < 0.002 and records[1].objects == 1 and records[1].surfaces == 2
	var source = load("res://assets/optimized/spike_mine.glb")
	var one = source.instantiate()
	var two = source.instantiate()
	passed = passed and first_mesh(one) == first_mesh(two)
	one.free()
	two.free()
	print("ASSET CHECK shared mesh confirmed; passed=%s; max position error=%s (x16 in game); max normal error=%s; meshes %d -> %d; surfaces %d -> %d" % [passed,max_position_error,max_normal_error,records[0].objects,records[1].objects,records[0].surfaces,records[1].surfaces])
	if not passed: push_error("Mine geometry/winding/material/normal regression")
	quit(0 if passed else 1)

extends SceneTree
## Offline only: keep the existing islands, discard their invisible deep seabed.
## Collision/height data and every retained position/normal/colour/UV stay exact.
const VISUAL_FLOOR := -12.0

static func trim(source: ArrayMesh) -> ArrayMesh:
	if source.get_meta("visual_floor_m", -INF) == VISUAL_FLOOR: return source
	var result := ArrayMesh.new()
	var original_triangles := 0
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var out_vertices := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_uvs := PackedVector2Array()
		var out_colors := PackedColorArray()
		var out_indices := PackedInt32Array()
		var remap := {}
		original_triangles += indices.size() / 3
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			if maxf(vertices[a].y, maxf(vertices[b].y, vertices[c].y)) <= VISUAL_FLOOR:
				continue
			for index in [a, b, c]:
				if not remap.has(index):
					remap[index] = out_vertices.size()
					out_vertices.append(vertices[index])
					out_normals.append(normals[index])
					out_uvs.append(uvs[index])
					out_colors.append(colors[index])
				out_indices.append(remap[index])
		if out_indices.is_empty(): continue
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = out_vertices
		out[Mesh.ARRAY_NORMAL] = out_normals
		out[Mesh.ARRAY_TEX_UV] = out_uvs
		out[Mesh.ARRAY_COLOR] = out_colors
		out[Mesh.ARRAY_INDEX] = out_indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface))
	result.set_meta("visual_floor_m", VISUAL_FLOOR)
	result.set_meta("full_triangle_count", source.get_meta("full_triangle_count", original_triangles))
	return result

func _initialize() -> void:
	var path := "res://game/world/arena_mesh.res"
	var source: ArrayMesh = load(path)
	var result := trim(source)
	if result == source:
		print("ARENA TRIM: already compact; resources unchanged")
		quit()
		return
	assert(ResourceSaver.save(result, path, ResourceSaver.FLAG_COMPRESS) == OK)
	print("ARENA TRIM: %d -> %d triangles, %d vertices; collision untouched" % [
		result.get_meta("full_triangle_count"), result.surface_get_array_index_len(0) / 3,
		result.surface_get_array_len(0)])
	quit()

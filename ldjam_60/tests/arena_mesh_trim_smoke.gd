extends SceneTree
## The visual trim must preserve every retained triangle and all physical data.
const Terrain = preload("res://addons/lite_terrain/map.gd")
const Trim = preload("res://tools/trim_arena_mesh.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var shape: HeightMapShape3D = load("res://game/world/arena_collision.res")
	var image: Image = load("res://game/world/arena_height.res")
	check(shape.map_data == image.get_data().to_float32_array(), "height image and collision still agree at every sample")
	var terrain := Terrain.new()
	terrain._ensure_children()
	terrain.surface_material = load("res://game/world/moonlit_terrain.tres")
	terrain.set_heightmap(shape.map_data, shape.map_width, shape.map_depth)
	terrain._rebuild_editor_full()
	var source: Array = terrain.mesh_instance.mesh.surface_get_arrays(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--before="):
			var previous: ArrayMesh = load(arg.trim_prefix("--before=").path_join("arena_mesh.res"))
			source = previous.surface_get_arrays(0)
	var mesh: ArrayMesh = load("res://game/world/arena_mesh.res")
	check(Trim.trim(mesh) == mesh, "repeating the trim preserves the existing mesh without re-encoding")
	var actual: Array = mesh.surface_get_arrays(0)
	var old_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = actual[Mesh.ARRAY_INDEX]
	var offset := 0
	var matches := true
	var max_errors := {Mesh.ARRAY_VERTEX: 0.0, Mesh.ARRAY_NORMAL: 0.0, Mesh.ARRAY_TEX_UV: 0.0, Mesh.ARRAY_COLOR: 0.0}
	for triangle in range(0, old_indices.size(), 3):
		var max_height := -INF
		for vertex in 3: max_height = maxf(max_height, source[Mesh.ARRAY_VERTEX][old_indices[triangle + vertex]].y)
		if max_height <= Trim.VISUAL_FLOOR: continue
		for vertex in 3:
			var a := old_indices[triangle + vertex]
			if offset >= indices.size():
				matches = false
				break
			var b := indices[offset]
			for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
				var difference = source[attribute][a] - actual[attribute][b]
				var error: float = maxf(maxf(absf(difference.r), absf(difference.g)), maxf(absf(difference.b), absf(difference.a))) if attribute == Mesh.ARRAY_COLOR else difference.length()
				max_errors[attribute] = maxf(max_errors[attribute], error)
				matches = matches and error < (0.0001 if attribute == Mesh.ARRAY_NORMAL else 0.00001)
			offset += 1
	check(matches and offset == indices.size(), "coastal geometry/UVs/colours/winding match; normals stay within serialization tolerance")
	print("ATTRIBUTE ERRORS: ", max_errors)
	check(indices.size() < old_indices.size() / 10, "deep seabed removal saves more than 90 percent of terrain triangles")
	var used := {}
	for index in indices: used[index] = true
	check(used.size() == actual[Mesh.ARRAY_VERTEX].size(), "unused vertices are removed from the GPU buffer")
	check(mesh.get_aabb().size.x * 4.0 < 550 and mesh.get_aabb().size.z * 4.0 < 550, "rendered terrain fits a compact area around the arena")
	var foam: Image = load("res://game/ocean/arena_coastal_foam_mask.res")
	check(foam.get_meta("terrain_hash") == FileAccess.get_sha256("res://game/world/arena_mesh.res"), "foam provenance follows the trimmed mesh")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--before="): continue
		var before := arg.trim_prefix("--before=")
		for resource in ["arena_height.res", "arena_collision.res"]:
			check(FileAccess.get_sha256(before.path_join(resource)) == FileAccess.get_sha256("res://game/world/" + resource), resource + " is byte-identical to the previous map")
		var old_foam: Image = load(before.path_join("arena_coastal_foam_mask.res"))
		check(old_foam.get_data() == foam.get_data(), "every shoreline foam pixel is unchanged")
	print("TERRAIN GEOMETRY: ", JSON.stringify({"before_triangles": old_indices.size() / 3,
		"after_triangles": indices.size() / 3, "before_vertices": source[Mesh.ARRAY_VERTEX].size(),
		"after_vertices": actual[Mesh.ARRAY_VERTEX].size(), "world_size": str(mesh.get_aabb().size * Vector3(4, 1, 4))}))
	terrain.free()
	await process_frame
	print("ARENA MESH TRIM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

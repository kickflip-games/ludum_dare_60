extends SceneTree
## Offline authoring recipe. Changes only game/world resources; never addon defaults.
const Terrain = preload("res://addons/lite_terrain/map.gd")
const SIZE := 257
const SPACING := 4.0
const ArenaMeshTrim = preload("res://tools/trim_arena_mesh.gd")
# Centre x/z, existing footprint radii x/z, summit height, coastline phase,
# inset summit x/z (relative to radius), ridge angle. The map topology is retained.
const ISLANDS := [
	[0, -25, 90, 103, 45, 0.3, -0.24, -0.24, -0.65],
	[-84, -42, 66, 61, 29, 2.4, -0.13, -0.28, 0.45],
	[0, -115, 108, 49, 33, 1.7, 0.24, -0.12, 0.18],
	[-269, -213, 54, 44, 20, 0.8, -0.24, 0.08, -0.45],
	[181, -211, 27, 43, 54, 2.0, -0.22, -0.16, -0.35],
	[286, -212, 29, 41, 64, 4.2, 0.18, -0.28, 0.40],
	[239, 14, 56, 79, 36, 3.1, 0.20, -0.26, 0.72],
	[275, 250, 46, 39, 20, 0.4, 0.0, 0.0, 0.30],
	[-234, 87, 49, 43, 23, 1.6, -0.28, -0.16, -0.60],
	[38, 210, 47, 34, 20, 2.8, 0.25, 0.02, 0.15],
	[-142, -262, 16, 20, 17, 3.3, -0.20, -0.16, -0.25],
	[139, 126, 13, 17, 11, 0.8, 0.12, -0.24, 0.35],
]
# Shallow coastal indentations, not cuts through an island or new channels.
const COVES := [Vector4(48, 43, 23, 13), Vector4(-119, -23, 17, 11),
	Vector4(211, 61, 18, 11), Vector4(-211, 109, 14, 9)]
# Nearby scenery beyond the 170 m arena: varied silhouettes with open sea gaps.
# Keep every shelf outside the combat ring and inside the baked map edges.
const ARENA_ISLANDS := [
	ISLANDS[7],
	[265, 15, 50, 35, 28, 1.2, -0.20, -0.12, -0.40],
	[427, 82, 42, 34, 32, 2.5, 0.10, -0.18, 0.55],
	[423, 421, 40, 36, 25, 0.7, -0.18, 0.08, -0.30],
	[125, 431, 46, 37, 32, 3.2, 0.16, -0.14, 0.40],
	[42, 236, 43, 58, 38, 1.8, -0.16, -0.20, -0.65],
]

func island_height(p: Vector2, island: Array) -> float:
	var q := (p - Vector2(island[0], island[1])) / Vector2(island[2], island[3])
	var a := q.angle()
	var phase: float = island[5]
	var outline := 0.95 + 0.07 * sin(a * 3.0 + phase) + 0.045 * sin(a * 5.0 + phase) + 0.035 * cos(a * 9.0 - phase)
	var r := q.length() / outline
	if r >= 1.15:
		return -14.0
	var height := lerpf(-14.0, 1.8, smoothstep(1.15, 0.87, r))
	# Low shelves at the navigable edge; steeper rock is set back inland.
	var cliff_side := smoothstep(-0.1, 0.6, -q.y + q.x * 0.35)
	height += island[4] * (0.035 + 0.12 * cliff_side) * smoothstep(0.99, 0.70, r)
	var ridge := (q - Vector2(island[6], island[7])).rotated(island[8])
	var main := maxf(0.0, 1.0 - absf(ridge.x) * 1.28 - absf(ridge.y) * 0.76)
	var spur := (q - Vector2(-island[6] * 0.8, 0.12)).rotated(island[8] - 0.8)
	var secondary := maxf(0.0, 1.0 - absf(spur.x) * 1.65 - absf(spur.y) * 1.2) * 0.53
	height += island[4] * maxf(main, secondary) * smoothstep(1.02, 0.45, r)
	# Metre-scale ledges, with broad facets rather than high-frequency noise.
	height += smoothstep(0.92, 0.35, r) * (sin(p.x * 0.075 + p.y * 0.045 + phase) * 1.3 + cos(p.y * 0.09 - phase) * 0.8)
	return height

func _initialize() -> void:
	var arena := "--arena" in OS.get_cmdline_user_args()
	var resource_prefix := "arena" if arena else "archipelago"
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	for z in range(SIZE):
		for x in range(SIZE):
			var p := Vector2(x - (SIZE - 1) * 0.5, z - (SIZE - 1) * 0.5) * SPACING
			var h := -14.0
			for island in (ARENA_ISLANDS if arena else ISLANDS):
				h = maxf(h, island_height(p, island))
			for cove: Vector4 in ([] if arena else COVES):
				h -= smoothstep(cove.z, 0.0, p.distance_to(Vector2(cove.x, cove.y))) * cove.w
			# Keep the established lighthouse foundation at its authored elevation.
			h = lerpf(h, 19.0, 1.0 - smoothstep(24.0, 37.0, p.distance_to(Vector2(275, 250))))
			h = maxf(-14.0, h)
			heights[z * SIZE + x] = h
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, heights.to_byte_array())
	assert(ResourceSaver.save(image, "res://game/world/%s_height.res" % resource_prefix, ResourceSaver.FLAG_COMPRESS) == OK)
	var shape := HeightMapShape3D.new()
	shape.map_width = SIZE
	shape.map_depth = SIZE
	shape.map_data = heights
	assert(ResourceSaver.save(shape, "res://game/world/%s_collision.res" % resource_prefix, ResourceSaver.FLAG_COMPRESS) == OK)
	var terrain := Terrain.new()
	terrain._ensure_children()
	terrain.surface_material = load("res://game/world/moonlit_terrain.tres")
	terrain.set_heightmap(heights, SIZE, SIZE)
	terrain._rebuild_editor_full()
	var visual_mesh: ArrayMesh = terrain.mesh_instance.mesh
	if arena: visual_mesh = ArenaMeshTrim.trim(visual_mesh)
	assert(ResourceSaver.save(visual_mesh, "res://game/world/%s_mesh.res" % resource_prefix, ResourceSaver.FLAG_COMPRESS) == OK)
	terrain.free()
	print("BAKED: %s, 257x257 R32F + full collision + %d visual triangles" % [resource_prefix, visual_mesh.surface_get_array_index_len(0) / 3])
	quit()

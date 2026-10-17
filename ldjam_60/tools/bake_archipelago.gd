extends SceneTree
## Offline authoring recipe. Changes only game/world resources; never addon defaults.
const Terrain = preload("res://addons/lite_terrain/map.gd")
const SIZE := 257
const SPACING := 4.0
# centre x/z, coastline radii x/z, summit height, silhouette phase.
const ISLANDS := [
	[0, -25, 90, 103, 43, 0.3], [-84, -42, 66, 61, 30, 2.4],
	[0, -115, 108, 49, 31, 1.7], [-269, -213, 54, 44, 17, 0.8],
	[181, -211, 27, 43, 57, 2.0], [286, -212, 29, 41, 65, 4.2],
	[239, 14, 56, 79, 35, 3.1], [275, 250, 46, 39, 19, 0.4],
	[-234, 87, 49, 43, 24, 1.6], [38, 210, 47, 34, 20, 2.8],
	[-142, -262, 16, 20, 19, 3.3], [139, 126, 13, 17, 13, 0.8],
]

func _initialize() -> void:
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	for z in range(SIZE):
		for x in range(SIZE):
			var p := Vector2(x - (SIZE - 1) * 0.5, z - (SIZE - 1) * 0.5) * SPACING
			var h := -14.0
			for island in ISLANDS:
				var q := (p - Vector2(island[0], island[1])) / Vector2(island[2], island[3])
				var a := q.angle()
				var r := q.length() / (1.0 + 0.09 * sin(a * 5.0 + island[5]) + 0.045 * cos(a * 9.0 - island[5]))
				var profile := -14.0
				if r < 1.15:
					profile = lerpf(-14.0, 3.0, smoothstep(1.15, 0.85, r))
					profile += island[4] * (0.28 * smoothstep(0.98, 0.78, r) + 0.72 * pow(maxf(0.0, 1.0 - r / 0.92), 0.66))
					profile += maxf(0.0, 1.0 - r) * (sin(p.x * 0.13 + p.y * 0.07) * 2.8 + cos(p.y * 0.16) * 1.9)
				h = maxf(h, profile)
			heights[z * SIZE + x] = h
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, heights.to_byte_array())
	assert(ResourceSaver.save(image, "res://game/world/archipelago_height.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var shape := HeightMapShape3D.new()
	shape.map_width = SIZE
	shape.map_depth = SIZE
	shape.map_data = heights
	assert(ResourceSaver.save(shape, "res://game/world/archipelago_collision.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var terrain := Terrain.new()
	terrain._ensure_children()
	terrain.surface_material = load("res://game/world/moonlit_terrain.tres")
	terrain.set_heightmap(heights, SIZE, SIZE)
	terrain._rebuild_editor_full()
	assert(ResourceSaver.save(terrain.mesh_instance.mesh, "res://game/world/archipelago_mesh.res", ResourceSaver.FLAG_COMPRESS) == OK)
	terrain.free()
	print("BAKED: 1024m archipelago, 257x257 R32F + full collision + LiteTerrain preview mesh")
	quit()

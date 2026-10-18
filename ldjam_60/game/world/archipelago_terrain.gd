@tool
extends "res://addons/lite_terrain/map.gd"
## Compact-map adapter: use LiteTerrain's baked full mesh and full collision.
## Avoids streamed coarse/fine seams on these small, steep coastal silhouettes.
func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	_ensure_children()
	if get_parent().arena_mode:
		collision.shape = load("res://game/world/arena_collision.res")
		mesh_instance.mesh = load("res://game/world/arena_mesh.res")
		heightmap_path = "res://game/world/arena_height.res"
	var height_shape := collision.shape as HeightMapShape3D
	w = height_shape.map_width
	d = height_shape.map_depth
	md = height_shape.map_data
	mesh_instance.visible = true
	collision.disabled = false
	set_process(false)

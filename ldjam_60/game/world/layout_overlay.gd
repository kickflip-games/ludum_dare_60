extends Control
## Development only; F2/--layout-debug explicitly enables it. No normal-game GPS.
var map: Node3D
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(map) or not is_instance_valid(map.game):
		return
	var camera: Camera3D = map.debug_camera
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 30), "DEVELOPMENT CHART · F2 close · F3/F4/F5 stage starts", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f1dab0"))
	for group in ["NavigationRegions", "OptionalDiscoveries", "PiratePatrols", "SpawnPoints", "Hazards"]:
		for marker: Marker3D in map.get_node(group).get_children():
			var at := camera.unproject_position(marker.global_position)
			var color := Color("f3cc85") if group == "NavigationRegions" else Color("ea8a80") if group == "PiratePatrols" or group == "Hazards" else Color("a4ded9")
			var radius: float = marker.get("radius") if group == "NavigationRegions" else marker.get_meta("radius", 12.0)
			var edge := camera.unproject_position(marker.global_position + Vector3.RIGHT * radius)
			draw_arc(at, at.distance_to(edge), 0, TAU, 48, color, 1.5, true)
			draw_string(font, at + Vector2(8, -9), marker.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	var boat := camera.unproject_position(map.game.boat.global_position)
	draw_circle(boat, 5, Color.WHITE)

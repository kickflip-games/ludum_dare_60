extends Node3D
## One authored map. Marker positions/radii are editable in archipelago.tscn.
@export var coastal_shadows: bool = true
var game: Node3D
var discoveries: Array[String] = []
var debug_view: bool = false
var debug_camera: Camera3D
var debug_layer: CanvasLayer
var wave_test_index := 9

func configure(value: Node3D) -> void:
	game = value
	# Short shadow range grounds cliff details and groves without lighting the sea.
	game.moon.shadow_enabled = coastal_shadows
	game.moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	game.moon.directional_shadow_max_distance = 180.0
	game.moon.directional_shadow_blend_splits = true
	game.moon.shadow_normal_bias = 2.5
	game.moon.shadow_bias = 0.15
	var wreck: Marker3D = $Landmarks/Wreck
	game._add_hazard(wreck.position, 7.0, "wreck")
	game.obstacles.back().body.set_meta("landmark", true)
	_lantern(wreck.position + Vector3(0, 6, 0), $Landmarks)
	for marker: Marker3D in $OptionalDiscoveries.get_children():
		_lantern(marker.position + Vector3.UP * 2.5, $IslandProps)
		game._box($IslandProps, Vector3(3, 0.5, 2), marker.position + Vector3.UP * 0.6, game._material(Color("78604a")))
	# Stone lintel: a separate mesh above the traversable heightmap passage.
	var passage := StaticBody3D.new()
	passage.name = "PassageLintel"
	passage.position = Vector3(234, 37, -224)
	passage.rotation.z = -0.08
	$IslandProps.add_child(passage)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 5, 12)
	collision.shape = shape
	passage.add_child(collision)
	game._box(passage, shape.size, Vector3.ZERO, preload("res://game/world/moonlit_terrain.tres"))
	for i in range(3):
		game._cylinder($IslandProps, 1.2, 1.0, 8 + i * 2, Vector3(45 + i * 6, 15, 209), game._material(Color("647477")))
	debug_camera = Camera3D.new()
	debug_camera.name = "DevelopmentOverview"
	debug_camera.position = Vector3(0, 850, 0)
	debug_camera.rotation_degrees.x = -90
	debug_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	debug_camera.size = 850
	debug_camera.far = 1600
	add_child(debug_camera)
	debug_layer = CanvasLayer.new()
	debug_layer.layer = 8
	add_child(debug_layer)
	var overlay := Control.new()
	overlay.set_script(load("res://game/world/layout_overlay.gd"))
	overlay.set("map", self)
	debug_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_layer.hide()

func _lantern(at: Vector3, parent: Node3D) -> void:
	game._box(parent, Vector3(0.6, 1.1, 0.6), at, game._material(Color("ffcd80"), 1.3))
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("ffc680")
	light.light_energy = 2.2
	light.omni_range = 17
	parent.add_child(light)

func rebuild_hazards() -> void:
	for marker: Marker3D in $Hazards.get_children():
		game._add_hazard(marker.position, marker.get_meta("radius", 5.0), marker.get_meta("kind", "rock"))

func update_discoveries() -> void:
	if game.state != game.State.SAILING:
		return
	for marker: Marker3D in $OptionalDiscoveries.get_children():
		if marker.name not in discoveries and game.boat.position.distance_to(marker.position) < 19:
			discoveries.append(marker.name)
			game.hull = mini(game.hull_capacity, game.hull + 1)
			game.show_discovery("%s · salvage recovered" % marker.get_meta("label"))
			game.cue_sound("victory")

func reset() -> void:
	discoveries.clear()

func toggle_debug() -> void:
	debug_view = not debug_view
	debug_layer.visible = debug_view
	game.hud.visible = not debug_view
	game.world_environment.environment.fog_enabled = not debug_view
	if debug_view:
		debug_camera.make_current()
	else:
		game.camera.make_current()

func debug_spawn(stage: int) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.voyage.stage = stage
	game.voyage.set_target(game)
	game.boat.position = $SpawnPoints.get_child(stage + 1).position
	game.heading = game.destination_bearing()
	game._update_view(1.0)

func debug_wave_zone() -> void:
	# F6 starts with the spacious northwest test area, then cycles all independent zones.
	wave_test_index = (wave_test_index + 1) % game.wave_encounters.REGIONS.size()
	game.restart()
	var region: Vector4 = game.wave_encounters.REGIONS[wave_test_index]
	game.state = game.State.SAILING
	game.boat.position = Vector3(region.x, 0, region.y)
	game.heading = _clear_water_heading(game.boat.position)
	game.boat.rotation.y = -game.heading
	var forward := Vector2(sin(game.heading), -cos(game.heading))
	game.wave_encounters.begin_region(int(region.w), forward, game.sea_time)
	game.show_discovery("Wave test · " + game.wave_encounters.REGION_NAMES[wave_test_index])
	if debug_view:
		toggle_debug()
	game._update_view(1.0)

func _clear_water_heading(origin: Vector3) -> float:
	var best_heading := 0.0
	var best_clearance := -1.0
	for i in range(24):
		var angle := i * TAU / 24.0
		var forward := Vector3(sin(angle), 0, -cos(angle))
		var right := Vector3(cos(angle), 0, sin(angle))
		var clearance := 160.0
		for side: float in [-4.0, 0.0, 4.0]:
			var start := origin + right * side + Vector3.UP * 0.5
			var query := PhysicsRayQueryParameters3D.create(start, start + forward * 160.0, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				clearance = minf(clearance, start.distance_to(hit.position) - 8.0)
			for distance in range(6, 161, 6):
				var point := origin + right * side + forward * distance
				if $Terrain.terrain_height_at(point) > -3.0:
					clearance = minf(clearance, distance - 6.0)
					break
		if clearance > best_clearance:
			best_clearance = clearance
			best_heading = angle
	return best_heading

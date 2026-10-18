extends Node3D
## One authored map. Marker positions/radii are editable in archipelago.tscn.
const STORY = preload("res://game/world/landmark_dressing.gd")
@export var coastal_shadows: bool = true
@export var arena_mode: bool = false
const ARENA_LAYOUT = preload("res://game/world/arena_layout.tscn")
var arena_layout: Node3D
var game: Node3D
var story_landmarks: Node3D
var discoveries: Array[String] = []
var debug_view: bool = false
var debug_camera: Camera3D
var debug_layer: CanvasLayer
var wave_test_index := 9

func configure(value: Node3D) -> void:
	game = value
	if arena_mode:
		arena_layout = ARENA_LAYOUT.instantiate()
		add_child(arena_layout)
	# Short shadow range grounds cliff details and groves without lighting the sea.
	game.moon.shadow_enabled = coastal_shadows
	game.moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	game.moon.directional_shadow_max_distance = 180.0
	game.moon.directional_shadow_blend_splits = true
	game.moon.shadow_normal_bias = 2.5
	game.moon.shadow_bias = 0.15
	var wreck_body: StaticBody3D
	if not arena_mode:
		var wreck: Marker3D = $Landmarks/Wreck
		game._add_hazard(wreck.position, 7.0, "wreck")
		wreck_body = game.obstacles.back().body
		wreck_body.set_meta("landmark", true)
	story_landmarks = STORY.new()
	story_landmarks.name = "LandmarkDressing"
	add_child(story_landmarks)
	story_landmarks.configure(game, self, wreck_body)
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

func rebuild_hazards() -> void:
	if arena_mode:
		for cluster in arena_layout.get_node("Obstacles").get_children():
			for marker: Marker3D in cluster.get_children():
				_build_arena_obstacle(marker)
		return
	for marker: Marker3D in $Hazards.get_children():
		game._add_hazard(marker.position, marker.get_meta("radius", 5.0), marker.get_meta("kind", "rock"))
		if marker.get_meta("kind", "rock") == "rock":
			_paint_coastal_rock(game.obstacles.back().body)

func _paint_coastal_rock(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = preload("res://game/world/moonlit_terrain.tres")
	for child in node.get_children():
		_paint_coastal_rock(child)

func update_discoveries() -> void:
	if arena_mode or game.state != game.State.SAILING:
		return
	for marker: Marker3D in $OptionalDiscoveries.get_children():
		if marker.name not in discoveries and game.boat.position.distance_to(marker.position) < 19:
			discoveries.append(marker.name)
			game.restore_hull(1)
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
	if arena_mode:
		return
	game.restart()
	game.state = game.State.SAILING
	game.voyage.stage = stage
	game.voyage.set_target(game)
	game.boat.position = $SpawnPoints.get_child(stage + 1).position
	game.heading = game.destination_bearing()
	game._update_view(1.0)

func debug_wave_zone() -> void:
	if arena_mode:
		return
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


func _build_arena_obstacle(marker: Marker3D) -> void:
	var kind: String = marker.get_meta("kind")
	var radius: float = marker.get_meta("radius")
	game._add_hazard(marker.global_position, radius, kind)
	var body: StaticBody3D = game.obstacles.back().body
	body.name = marker.name
	body.set_meta("arena_marker", str(marker.name))
	body.rotation = marker.global_rotation
	var visual: Node3D = body.get_node("HazardVisual")
	if kind == "rock":
		if marker.get_meta("height_scale", 1.0) > 0.8:
			# Reuse the established sheared stone mesh for sharp, uneven reef crowns.
			var crown: MeshInstance3D = game._mesh(visual, $IslandDressing._boulder_mesh(), Vector3(0, radius * 0.5, 0), preload("res://game/world/moonlit_terrain.tres"))
			crown.scale = Vector3(radius * 0.6, radius * 1.3, radius * 0.65)
			crown.rotation = Vector3(0.18, 0.7, -0.22)
		# Normalize the licensed mesh to the marker's explicit horizontal footprint.
		var bounds := _visual_bounds(visual)
		var factor := radius * 2.0 / maxf(bounds.size.x, bounds.size.z)
		visual.scale = Vector3(factor, factor * marker.get_meta("height_scale", 1.0), factor)
		_paint_coastal_rock(visual)
	elif kind == "wreck":
		for child in visual.get_children():
			child.free()
		var bow := Node3D.new()
		visual.add_child(bow)
		bow.rotation.z = -0.16
		story_landmarks._hull_section(bow, [-7.2, -5.0, -2.5, -0.8], [0.1, 1.8, 3.0, 2.8], [2.0, 1.7, 1.4, 1.1])
		var stern := Node3D.new()
		visual.add_child(stern)
		stern.position = Vector3(0.9, -0.6, 1.0)
		stern.rotation.z = 0.24
		story_landmarks._hull_section(stern, [1.0, 3.5, 5.0], [2.8, 2.6, 2.2], [1.0, 1.5, 1.9])
		game._box(stern, Vector3(4.2, 1.4, 0.3), Vector3(0, 0.8, 5.0), story_landmarks.materials.wood)
		story_landmarks._spar(visual, Vector3(0, 0, -2), Vector3(2.5, 8, -1), 0.25, story_landmarks.materials.cut_wood)
		story_landmarks._spar(visual, Vector3(-2, 6.3, -1), Vector3(4.5, 6.3, -1), 0.14, story_landmarks.materials.wood)
		story_landmarks._lantern(visual, Vector3(-1.2, 1.5, 4), 0.9, 9)
	# No spherical proxy wall: every physical face comes from visible geometry.
	# Float transforms stay cosmetic as in existing debris; submerged faces let
	# both the planar hull and cannonballs contact the visible waterline footprint.
	for child in body.get_children():
		if child is CollisionShape3D:
			child.free()
	_add_mesh_collision(body, visual)


func _visual_bounds(node: Node3D) -> AABB:
	var result := AABB()
	for child in node.get_children():
		if child is MeshInstance3D:
			result = result.merge(child.transform * child.get_aabb())
		elif child is Node3D:
			result = result.merge(child.transform * _visual_bounds(child))
	return result


func _add_mesh_collision(body: StaticBody3D, node: Node3D) -> void:
	if node is MeshInstance3D and node.mesh:
		# Imported meshes have very small source units and large node scales.
		# Bake the complete transform into metre-sized faces; physics shapes must
		# not rely on those non-uniform imported scales.
		var faces: PackedVector3Array = node.mesh.get_faces()
		var local: Transform3D = body.global_transform.affine_inverse() * node.global_transform
		for i in faces.size():
			faces[i] = local * faces[i]
		var surface := ConcavePolygonShape3D.new()
		surface.set_faces(faces)
		surface.backface_collision = true
		var shape := CollisionShape3D.new()
		shape.shape = surface
		body.add_child(shape)
	for child in node.get_children():
		if child is Node3D:
			_add_mesh_collision(body, child)


func water_clear(at: Vector3, clearance: float) -> bool:
	if at.distance_to(game.arena_center()) + clearance > game.arena_radius:
		return false
	# A heightmap is a surface: a query entirely below a tall island can miss it.
	# Depth samples reject land independently before checking obstacle meshes.
	for offset in [Vector3.ZERO, Vector3.RIGHT * clearance, Vector3.LEFT * clearance,
			Vector3.FORWARD * clearance, Vector3.BACK * clearance]:
		if $Terrain.terrain_height_at(at + offset) > -4.0:
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = clearance
	query.shape = shape
	query.transform.origin = at + Vector3.UP
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func sailing_lane_clear(at: Vector3, direction: Vector3, length_value: float, half_width: float = 3.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 1.5
	shape.radius = half_width
	query.shape = shape
	query.transform.origin = at + Vector3.UP * 0.5
	query.motion = direction * length_value
	query.collision_mask = 1
	var state := get_world_3d().direct_space_state
	return state.intersect_shape(query, 1).is_empty() and state.cast_motion(query)[0] > 0.999


func safe_return_rudder(steering: float) -> float:
	var forward := Vector3(sin(game.heading), 0, -cos(game.heading))
	var lookahead: float = maxf(32.0, game.propulsion_speed() * 3.2)
	if sailing_lane_clear(game.boat.global_position, forward, lookahead):
		return steering
	# Only the boundary assistant calls this. Pick a visible-water escape on
	# either side, allowing a full turn before contact; normal inner helm is free.
	for angle in [0.55, 0.95, 1.4, 1.9, 2.5]:
		for side in [game.arena_return.turn_side, -game.arena_return.turn_side]:
			var bearing: float = game.heading + angle * side
			var direction := Vector3(sin(bearing), 0, -cos(bearing))
			var end: Vector3 = game.boat.global_position + direction * lookahead
			if end.distance_to(game.arena_center()) < game.arena_radius - 3.0 and sailing_lane_clear(game.boat.global_position, direction, lookahead):
				return clampf(angle * side * 2.4, -1.0, 1.0)
	return steering

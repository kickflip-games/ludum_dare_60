extends CharacterBody3D
## One arcade cutter. Movement, telegraph and non-homing shots share the voyage clock.

const Motion = preload("res://game/ocean/boat_wave_motion.gd")
const SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const CANNON = preload("res://assets/pirate_kit/cannon.glb")
enum Mode { DORMANT, APPROACH, POSITION, TELEGRAPH, FIRE, REPOSITION, SINKING, ESCAPED, DISENGAGING }

@export var sailing_speed: float = 7.0
@export var turning_speed: float = 0.42
@export var turn_acceleration: float = 0.65
@export var broadside_separation: float = 34.0
@export var attack_run_seconds: float = 6.0
@export var return_seconds: float = 8.5
@export var hull_capacity: int = 2
@export var firing_range: float = 62.0
@export var reload_seconds: float = 3.8
@export var telegraph_seconds: float = 1.65
@export var projectile_speed: float = 24.0
@export var encounter_seconds: float = 55.0
@export var escape_distance: float = 135.0
@export var cleanup_distance: float = 180.0
## Every other pass aims slightly long; the locked warning still shows the true shot.
@export var forgiving_aim_offset: float = 4.5
@export_group("Night presentation")
@export var sail_color := Color("e69b79")
@export_range(0.0, 0.3, 0.01) var sail_fill: float = 0.22

var territory := Vector3.ZERO
var game: Node3D
var mode: Mode = Mode.DORMANT
var heading: float = 0.0
var hull: int = 2
var age: float = 0.0
var timer: float = 0.0
var cooldown: float = 0.0
var locked_point := Vector3.ZERO
var hit_reaction: float = 0.0
var shots_fired: int = 0
var shots_hit: int = 0
var visual: Node3D
var sail_material: StandardMaterial3D
var flash: MeshInstance3D
var tell_line: MeshInstance3D
var tell_mesh: BoxMesh
var motion := Motion.new()
var projectiles: Array[Dictionary] = []
var run_heading: float = 0.0
var run_speed: float = 6.3
var lane_separation: float = 34.0
var run_elapsed: float = 0.0
var passes: int = 0
var turn_rate: float = 0.0
var _speed: float = 0.0
var _escape_elapsed: float = 0.0
var _avoid_left: float = 0.0
var _avoid_heading: float = 0.0
var _avoid_side: float = 1.0
var _blocked_elapsed: float = 0.0
var _departure_heading: float = 0.0
var _pass_fired: bool = false
var _course_age: float = 0.0
var archetype: Resource
var presentation: Node3D
var collision_shape: CollisionShape3D
var sail_bands: Array[MeshInstance3D] = []
var aim_highlight := false
var acceleration := 1.2
var approach_lead := 28.0
var approach_angle := -0.45
var reposition_angle := 0.72
var _route_point := Vector3.INF
var _route_check_left := 0.0


func _ready() -> void:
	set_meta("hazard_name", "the hostile cutter")
	set_meta("target_kind", "ship")
	set_meta("target_radius", 4.2)
	set_meta("destroyed", true)
	add_to_group("cannon_targets")
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.6
	collision.shape = sphere
	collision.position = Vector3(0, 1.0, -1.8)
	add_child(collision)
	collision_shape = collision
	visual = Node3D.new()
	add_child(visual)
	presentation = Node3D.new()
	visual.add_child(presentation)
	var model: Node3D = SHIP.instantiate()
	model.rotation.y = -PI / 2.0
	model.scale = Vector3(1.30, 0.9, 0.95)
	model.position = Vector3(0, -0.1, -1.8)
	presentation.add_child(model)
	var timber = game._material(Color("3b2423"))
	game._box(presentation, Vector3(0.18, 6.0, 0.18), Vector3(0, 3.1, -1.8), timber)
	sail_material = game._material(sail_color)
	# A restrained cloth fill keeps the red identity on the moon's shadow side.
	sail_material.emission_enabled = true
	sail_material.emission = sail_color
	sail_material.emission_energy_multiplier = sail_fill
	var canvas := Node3D.new()
	presentation.add_child(canvas)
	canvas.position = Vector3(0, 4.3, -1.8)
	canvas.rotation.y = PI / 4.0
	for panel_index in 2:
		var side := -1.0 if panel_index == 0 else 1.0
		var panel = game._box(canvas, Vector3(2.5, 3.4, 0.09), Vector3(side * 1.02, 0, 0.72), sail_material)
		panel.rotation.y = side * deg_to_rad(35.0)
		for band_index in 2:
			var band = game._box(panel, Vector3(2.5, 0.28, 0.11), Vector3(0, -0.6 + band_index * 1.1, 0), timber)
			band.visible = false
			sail_bands.append(band)
		game._box(panel, Vector3(2.6, 0.14, 0.14), Vector3(0, 1.8, 0), timber)
	game._box(presentation, Vector3(1.6, 0.8, 0.06), Vector3(0.7, 7.0, -1.8), game._material(Color("151e23")))
	var gun: Node3D = CANNON.instantiate()
	gun.position = Vector3(-1.1, 0.55, -1.8)
	gun.rotation.y = -PI / 2.0
	gun.scale = Vector3.ONE * 1.1
	presentation.add_child(gun)
	var spark := SphereMesh.new()
	spark.radius = 0.4
	spark.height = 0.8
	flash = game._mesh(presentation, spark, Vector3(-2.4, 1.3, -1.8), game._material(Color("ffbe67"), 2.0))
	tell_mesh = BoxMesh.new()
	tell_line = game._mesh(game, tell_mesh, Vector3.ZERO, game._material(Color("ed9e5c"), 1.0))
	tell_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reset()


func reset() -> void:
	if has_meta("wave_id"):
		remove_meta("wave_id")
	for shot: Dictionary in projectiles:
		shot.node.queue_free()
	projectiles.clear()
	mode = Mode.DORMANT
	visible = false
	collision_layer = 0
	set_meta("destroyed", true)
	tell_line.visible = false
	flash.visible = false
	shots_fired = 0
	shots_hit = 0
	velocity = Vector3.ZERO
	hull = hull_capacity
	age = 0.0
	timer = 0.0
	cooldown = 0.0
	hit_reaction = 0.0
	locked_point = Vector3.ZERO
	heading = 0.0
	rotation = Vector3.ZERO
	visual.transform = Transform3D.IDENTITY
	sail_material.albedo_color = sail_color
	sail_material.emission = sail_color
	motion.reset()
	run_heading = 0.0
	run_speed = game.SPEED
	lane_separation = broadside_separation
	run_elapsed = 0.0
	passes = 0
	turn_rate = 0.0
	_speed = 0.0
	_escape_elapsed = 0.0
	_avoid_left = 0.0
	_avoid_heading = 0.0
	_avoid_side = 1.0
	_blocked_elapsed = 0.0
	_departure_heading = 0.0
	_pass_fired = false
	_course_age = 0.0
	_route_point = Vector3.INF
	_route_check_left = 0.0
	set_aim_highlight(false)
	_update_cloth()


func configure_archetype(profile: Resource, lane_offset: float = 0.0) -> void:
	archetype = profile
	sailing_speed = profile.speed
	turning_speed = profile.turn_speed
	turn_acceleration = profile.turn_acceleration
	acceleration = profile.acceleration
	hull_capacity = profile.hull
	sail_color = profile.sail_color
	sail_fill = profile.sail_fill
	broadside_separation = profile.broadside_separation + lane_offset
	approach_lead = profile.approach_lead
	approach_angle = profile.approach_angle
	reposition_angle = profile.reposition_angle
	attack_run_seconds = profile.attack_run_seconds
	return_seconds = profile.return_seconds
	telegraph_seconds = profile.telegraph_seconds
	reload_seconds = profile.reload_seconds
	presentation.scale = Vector3.ONE * profile.size
	collision_shape.shape.radius = 3.6 * profile.size
	collision_shape.position = Vector3(0, 1.0, -1.8) * profile.size
	set_meta("target_radius", 4.2 * profile.size)
	set_meta("hazard_name", "the hostile " + profile.display_name.to_lower())
	for band_index in sail_bands.size():
		sail_bands[band_index].visible = band_index % 2 < profile.sail_bands
	_update_cloth()


func display_name() -> String:
	return archetype.display_name if archetype != null else "Cutter"


func set_aim_highlight(enabled: bool) -> void:
	aim_highlight = enabled and visible and not get_meta("destroyed", true)
	_update_cloth()


func _update_cloth() -> void:
	var damage := 0.16 * (1.0 - float(maxi(0, hull)) / maxi(1, hull_capacity))
	var color := sail_color.darkened(damage)
	var impact := clampf((hit_reaction - 0.45) / 0.20, 0.0, 1.0)
	sail_material.albedo_color = color.lerp(Color("fff0c4"), impact * 0.8)
	sail_material.emission = color.lerp(Color("fff0c4"), impact)
	sail_material.emission_energy_multiplier = sail_fill + (0.20 if aim_highlight else 0.0) + impact * 0.65


func begin(at: Vector3 = Vector3.INF) -> void:
	reset()
	_capture_course()
	position = at if at.is_finite() else game.boat.position + _run_forward() * 16.0 + _run_right() * 60.0
	territory = position
	heading = run_heading + approach_angle
	rotation.y = -heading
	_speed = sailing_speed
	velocity = forward() * _speed
	mode = Mode.APPROACH
	visible = true
	collision_layer = 4
	set_meta("destroyed", false)
	sail_material.albedo_color = sail_color
	sail_material.emission = sail_color
	_update_cloth()
	game.cue_sound("enemy")


func forward() -> Vector3:
	return Vector3(sin(heading), 0, -cos(heading))


func port_direction() -> Vector3:
	return Vector3(-cos(heading), 0, -sin(heading))


func muzzle_position() -> Vector3:
	return global_position + forward() * 1.8 + port_direction() * 2.4 + Vector3.UP * 1.3


func _turn_toward(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.01:
		var desired: float = atan2(direction.x, -direction.z)
		var error := wrapf(desired - heading, -PI, PI)
		var desired_rate := clampf(error * 2.0, -turning_speed, turning_speed)
		turn_rate = move_toward(turn_rate, desired_rate, turn_acceleration * delta)
		heading = wrapf(heading + turn_rate * delta, -PI, PI)
	rotation.y = -heading


func update_ship(delta: float) -> void:
	_advance_shots(delta)
	if game.arena_mode and game.state != game.State.SAILING:
		return
	if mode in [Mode.DORMANT, Mode.ESCAPED]:
		return
	timer += delta
	hit_reaction = maxf(0, hit_reaction - delta)
	_update_cloth()
	if mode == Mode.SINKING:
		visual.position.y -= delta * 2.5
		visual.rotation.z += delta * 0.18
		if timer >= 3.5:
			mode = Mode.ESCAPED
			visible = false
		return
	age += delta
	cooldown = maxf(0.0, cooldown - delta)
	var to_player: Vector3 = game.boat.position - global_position
	_escape_elapsed = _escape_elapsed + delta if to_player.length() > escape_distance else 0.0
	if not game.arena_mode and mode != Mode.DISENGAGING and (age >= encounter_seconds or (age > 8.0 and _escape_elapsed > 4.0)):
		disengage()
	var desired := _run_forward()
	var target_speed := run_speed
	match mode:
		Mode.APPROACH:
			_course_age += delta
			# Re-evaluate a changed helm course at deliberate intervals, never each frame.
			if _course_age >= 5.0 and absf(wrapf(game.heading - run_heading, -PI, PI)) > 0.35:
				_capture_course()
			# Follow a lane ahead of the hull, never the player or a changing landmark bearing.
			# The captured course stays fixed for this manoeuvre; only along-course progress moves.
			var relative: Vector3 = global_position - game.boat.position
			var along := relative.dot(_run_forward())
			var lateral := relative.dot(_run_right())
			if lateral > 26.0 and lateral < 50.0 and not _path_clear(_run_forward(), 45.0):
				lane_separation = minf(lane_separation, 26.0)
			var goal_ahead := clampf(along + approach_lead, -12.0, approach_lead) if game.arena_mode else along + approach_lead
			var goal: Vector3 = game.boat.position + _run_forward() * goal_ahead + _run_right() * lane_separation
			desired = _arena_approach(goal, delta) if game.arena_mode else (goal - global_position).normalized()
			target_speed = clampf(run_speed + (8.0 - along) * 0.12, sailing_speed * 0.74, sailing_speed * 1.12)
			if timer > 2.0 and absf(lateral - lane_separation) < 10.0 and absf(along) < 18.0 and forward().dot(_run_forward()) > 0.94 and _avoid_left <= 0.0 and _path_clear(_run_forward(), 32.0 if game.arena_mode else 45.0):
				run_elapsed = 0.0
				_pass_fired = false
				passes += 1
				_change(Mode.POSITION)
		Mode.POSITION, Mode.TELEGRAPH, Mode.FIRE:
			# Fire states are substates of one predictable, parallel six-second pass.
			run_elapsed += delta
			target_speed = run_speed + 0.15
			if mode == Mode.POSITION:
				var distance := to_player.length()
				if not _pass_fired and cooldown <= 0.0 and distance > 24.0 and distance < firing_range and port_direction().dot(to_player.normalized()) > 0.90:
					_lock_shot()
					_change(Mode.TELEGRAPH)
					game.cue_sound("warning")
			elif mode == Mode.TELEGRAPH and timer >= telegraph_seconds:
				_fire()
				_pass_fired = true
				_change(Mode.FIRE)
			elif mode == Mode.FIRE and timer >= 0.18:
				_change(Mode.POSITION)
			if run_elapsed >= attack_run_seconds and mode == Mode.POSITION:
				_change(Mode.REPOSITION)
		Mode.REPOSITION:
			# Continue ahead, arc out, then return into the lane. Fixed leg headings
			# make a wide dogleg without reversing or orbiting the moving player.
			var return_angle := -0.55 if archetype == null else -reposition_angle * 0.76
			var offset := 0.0 if timer < 1.2 else reposition_angle if timer < 4.2 else return_angle
			desired = _direction(run_heading + offset)
			target_speed = sailing_speed
			if timer >= return_seconds:
				_capture_course()
				_change(Mode.APPROACH)
		Mode.DISENGAGING:
			desired = _direction(_departure_heading)
			target_speed = sailing_speed
			# Removal is permitted only once the retreat has actually opened a safe gap.
			var offscreen: bool = not game.camera.is_position_in_frustum(global_position + Vector3.UP * 3.0)
			if timer > 4.0 and to_player.length() > cleanup_distance and (offscreen or to_player.length() > cleanup_distance + 60.0):
				_finish_escape()
				return
	# Resolve safety first, then apply exactly one bounded, acceleration-limited turn.
	desired = _safe_direction(desired, to_player, delta)
	_turn_toward(desired, delta)
	if archetype != null:
		target_speed = minf(target_speed, sailing_speed * 1.12)
	_speed = move_toward(_speed, target_speed, delta * acceleration)
	var before := position
	velocity = forward() * _speed
	var travel := velocity * delta
	if game.arena_mode:
		travel = game.arena_return.bounded_motion(global_position - game.arena_center(), travel, game.arena_radius - 5.0)
	var collision := move_and_collide(travel)
	if collision:
		var normal := Vector3(collision.get_normal().x, 0, collision.get_normal().z).normalized()
		move_and_collide(collision.get_remainder().slide(normal))
		_hold_avoidance((normal + forward() * 0.35).normalized(), 2.5)
	position.y = 0.0
	velocity = (position - before) / maxf(delta, 0.0001)
	_blocked_elapsed = _blocked_elapsed + delta if velocity.length() < _speed * 0.3 else 0.0
	if _blocked_elapsed > 1.0:
		# Physical contact can defeat a forward feeler: commit to a clear escape course.
		_hold_avoidance(_clear_course(), 3.0)
		_blocked_elapsed = 0.0
	_update_tell()


func _direction(value: float) -> Vector3:
	return Vector3(sin(value), 0.0, -cos(value))


func _water_lane_clear(from: Vector3, to: Vector3) -> bool:
	var offset := to - from
	var side: Vector3 = Vector3(-offset.z, 0, offset.x).normalized() * (collision_shape.shape.radius + 1.0)
	var samples := maxi(1, ceili(offset.length() / 10.0))
	var terrain = game.archipelago.get_node("Terrain")
	for sample_index in range(1, samples + 1):
		var point := from.lerp(to, float(sample_index) / samples)
		for margin in [Vector3.ZERO, side, -side]:
			if terrain.terrain_height_at(point + margin) > -3.0:
				return false
	for margin in [Vector3.ZERO, side, -side]:
		var ray := PhysicsRayQueryParameters3D.create(from + margin + Vector3.UP * 0.5, to + margin + Vector3.UP * 0.5, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true


func _arena_approach(goal: Vector3, delta: float) -> Vector3:
	_route_check_left = maxf(0.0, _route_check_left - delta)
	var reached := _route_point.is_finite() and global_position.distance_to(_route_point) < 14.0
	if _route_check_left <= 0.0 or reached:
		_route_check_left = 1.0
		if _water_lane_clear(global_position, goal):
			_route_point = Vector3.INF
		elif not _route_point.is_finite() or reached:
			var center: Vector3 = game.arena_center()
			var radial := global_position - center
			var target := goal - center
			var angle := atan2(radial.x, -radial.z)
			var difference := wrapf(atan2(target.x, -target.z) - angle, -PI, PI)
			var preferred := 1.0 if difference >= 0.0 else -1.0
			for side in [preferred, -preferred]:
				var candidate: Vector3 = center + _direction(angle + side * PI / 4.0) * (game.arena_radius - 25.0)
				if _water_lane_clear(global_position, candidate):
					_route_point = candidate
					var direction: Vector3 = candidate - global_position
					_avoid_side = signf(wrapf(atan2(direction.x, -direction.z) - heading, -PI, PI))
					break
	var point := _route_point if _route_point.is_finite() else goal
	return (point - global_position).normalized()


func _run_forward() -> Vector3:
	return _direction(run_heading)


func _run_right() -> Vector3:
	return Vector3(cos(run_heading), 0.0, sin(run_heading))


func _capture_course() -> void:
	run_heading = game.heading
	run_speed = clampf(game.boat.velocity.length(), game.SPEED * 0.85, game.SPEED * 1.05)
	if archetype != null:
		run_speed = minf(run_speed, sailing_speed * 0.96)
	_course_age = 0.0
	lane_separation = broadside_separation


func _path_clear(direction: Vector3, distance: float = 30.0) -> bool:
	var terrain = game.archipelago.get_node("Terrain")
	var side := Vector3(-direction.z, 0, direction.x) * 4.5
	for step in [0.35, 0.7, 1.0]:
		var at: Vector3 = global_position + direction * distance * step
		for offset in [Vector3.ZERO, side, -side]:
			if game.arena_mode and (at + offset).distance_to(game.arena_center()) > game.arena_radius - 9.0:
				return false
			if terrain.terrain_height_at(at + offset) > -3.0:
				return false
	if not game.arena_mode:
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + direction * distance + Vector3.UP, 1)
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	for offset in [Vector3.ZERO, side, -side]:
		var origin: Vector3 = global_position + offset + Vector3.UP * 0.5
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 5, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _clear_course() -> Vector3:
	# Keep the preferred side on ties rather than reselecting left/right every tick.
	for angle in [0.65, 1.15, 1.75, 2.4, PI]:
		for side in [_avoid_side, -_avoid_side]:
			var candidate := _direction(heading + angle * side)
			if _path_clear(candidate) and (global_position + candidate * 20.0).distance_to(game.boat.position) > 18.0:
				_avoid_side = side
				return candidate
	return -forward()


func _hold_avoidance(direction: Vector3, seconds: float) -> void:
	_avoid_heading = atan2(direction.x, -direction.z)
	_avoid_left = seconds
	# Cancel a wind-up if safe sailing no longer supports the advertised shot.
	if mode in [Mode.POSITION, Mode.TELEGRAPH, Mode.FIRE]:
		_change(Mode.REPOSITION)


func _safe_direction(desired: Vector3, to_player: Vector3, delta: float) -> Vector3:
	_avoid_left = maxf(0.0, _avoid_left - delta)
	if game.arena_mode:
		for other in game.enemy_encounters.living_ships():
			if other == self:
				continue
			var relative: Vector3 = global_position-other.global_position
			var motion_delta: Vector3 = forward()*_speed-other.velocity
			var closest := clampf(-relative.dot(motion_delta)/maxf(0.01,motion_delta.length_squared()),0,3)
			if relative.length()<16 or (relative.length()<34 and (relative+motion_delta*closest).length()<12):
				var away := (relative.normalized()+_run_forward()*0.4).normalized()
				_hold_avoidance(away if _path_clear(away) else _clear_course(),1.5)
				break
	if _avoid_left > 0.0:
		return _direction(_avoid_heading)
	if not _path_clear(forward()) or not _path_clear(desired):
		_hold_avoidance(_clear_course(), 2.5)
	else:
		var relative := -to_player
		var motion_delta: Vector3 = forward() * _speed - game.boat.velocity
		var closest_time := clampf(-relative.dot(motion_delta) / maxf(0.01, motion_delta.length_squared()), 0.0, 3.0)
		if to_player.length() < 20.0 or (to_player.length() < 42.0 and (relative + motion_delta * closest_time).length() < 15.0):
			var away := (-to_player.normalized() + _run_forward() * 0.7).normalized()
			_hold_avoidance(away if _path_clear(away) else _clear_course(), 2.0)
	return _direction(_avoid_heading) if _avoid_left > 0.0 else desired


func _change(value: Mode) -> void:
	mode = value
	timer = 0.0


func _lock_shot() -> void:
	# Predict once, then show this fixed world point throughout the warning. No homing.
	# The cutter is settling onto its pass, so predict the committed parallel
	# course rather than extrapolating the last inward approach velocity.
	var future_origin: Vector3 = muzzle_position() + _run_forward() * (run_speed + 0.15) * telegraph_seconds
	var player_at: Vector3 = game.boat.position + game.boat.velocity * telegraph_seconds
	var r: Vector3 = player_at - future_origin
	r.y = 0.0
	var v: Vector3 = game.boat.velocity
	var a: float = v.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * r.dot(v)
	var discriminant: float = maxf(0.0, b * b - 4.0 * a * r.length_squared())
	var flight: float = clampf((-b - sqrt(discriminant)) / (2.0 * a), 0.4, 3.0)
	locked_point = player_at + v * flight
	if passes % 2 == 0:
		locked_point += _run_forward() * forgiving_aim_offset
	locked_point.y = 0.8


func _update_tell() -> void:
	tell_line.visible = mode == Mode.TELEGRAPH
	flash.visible = mode == Mode.FIRE or (mode == Mode.TELEGRAPH and fmod(timer, 0.3) < 0.15)
	if not tell_line.visible:
		return
	var from := muzzle_position()
	var end := locked_point
	end.y = from.y
	var offset := end - from
	tell_mesh.size = Vector3(0.18, 0.08, offset.length())
	tell_line.global_position = (from + end) * 0.5
	tell_line.global_basis = Basis.looking_at(offset)


func _fire() -> void:
	var from := muzzle_position()
	var offset := locked_point - from
	var flat := Vector3(offset.x, 0, offset.z)
	var flight: float = maxf(0.2, flat.length() / projectile_speed)
	var launch := flat.normalized() * projectile_speed
	launch.y = (locked_point.y - from.y + 2.5 * flight * flight) / flight
	var shape := SphereMesh.new()
	shape.radius = 0.4
	shape.height = 0.8
	shape.radial_segments = 8
	shape.rings = 4
	var ball = game._mesh(game, shape, from, game._material(Color("ffad66"), 1.5))
	projectiles.append({"node": ball, "position": from, "velocity": launch, "ttl": 4.0})
	shots_fired += 1
	cooldown = reload_seconds
	game.cue_sound("enemy_shot")


func _advance_shots(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var from: Vector3 = shot.position
		var to: Vector3 = from + shot.velocity * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, 3)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var water: Dictionary = game.ocean.water_hit(from, to, delta)
		if not water.is_empty() and not hit.is_empty() and from.distance_squared_to(water.position) < from.distance_squared_to(hit.position):
			hit = {}
		shot.velocity.y -= 5.0 * delta
		shot.ttl -= delta
		if not hit.is_empty() or not water.is_empty() or shot.ttl <= 0.0:
			if not hit.is_empty() and hit.collider == game.boat:
				if game.take_damage(1, "Enemy broadside hit"):
					shots_hit += 1
			elif not hit.is_empty() and hit.collider.get_meta("destructible", false):
				game.cannon._impact(hit.collider, hit.position)
			if hit.is_empty() or not hit.collider.get_meta("destructible", false):
				game.cannon.water_splash(hit.position if not hit.is_empty() else water.position if not water.is_empty() else to)
			shot.node.queue_free()
			projectiles.remove_at(i)
		else:
			shot.position = to
			shot.node.global_position = to


func take_hit() -> void:
	if mode in [Mode.SINKING, Mode.ESCAPED, Mode.DORMANT]:
		return
	hull -= 1
	hit_reaction = 0.65
	if hull <= 0:
		set_meta("destroyed", true)
		collision_layer = 0
		tell_line.visible = false
		flash.visible = false
		_change(Mode.SINKING)
		set_aim_highlight(false)
		game.enemy_encounters.on_ship_sunk(self)
		game.cue_sound("victory")
	_update_cloth()


func update_visuals(delta: float) -> void:
	if not visible or mode == Mode.SINKING:
		return
	motion.update_motion(game.ocean, self, visual, delta)
	visual.rotation.z += sin(hit_reaction * 20.0) * hit_reaction * 0.16
	_update_tell()


func disengage() -> void:
	if mode in [Mode.DORMANT, Mode.ESCAPED, Mode.SINKING, Mode.DISENGAGING]:
		return
	var away: Vector3 = global_position - game.boat.position
	_departure_heading = atan2(away.x, -away.z)
	_change(Mode.DISENGAGING)
	tell_line.visible = false
	flash.visible = false


func _finish_escape() -> void:
	mode = Mode.ESCAPED
	visible = false
	collision_layer = 0
	set_meta("destroyed", true)
	velocity = Vector3.ZERO
	tell_line.visible = false
	flash.visible = false


func warning() -> String:
	if mode == Mode.TELEGRAPH:
		return "ENEMY BROADSIDE  ·  TURN OFF THE AMBER LINE  ·  %.1fs" % maxf(0, telegraph_seconds - timer)
	if mode in [Mode.APPROACH, Mode.POSITION] and age < 7.0:
		return "HOSTILE %s  ·  SHOOT OR SAIL CLEAR" % display_name().to_upper()
	return ""

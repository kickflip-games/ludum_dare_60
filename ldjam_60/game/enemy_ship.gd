extends CharacterBody3D
## Planar navigation and committed cannon fire use independent state machines.

const Motion = preload("res://game/ocean/boat_wave_motion.gd")
const SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const CANNON = preload("res://assets/pirate_kit/cannon.glb")
enum Mode { DORMANT, APPROACH, POSITION, TELEGRAPH, FIRE, REPOSITION, SINKING, ESCAPED, DISENGAGING }
enum Navigation { DORMANT, APPROACH, ATTACK_RUN, TURN_AWAY, REPOSITION, HOLDING, RETREAT, SINKING, ESCAPED }
enum Weapon { READY, TELEGRAPH, FIRE, RELOAD }

@export var sailing_speed: float = 7.0
@export var turning_speed: float = 0.42
@export var turn_acceleration: float = 0.65
@export var broadside_separation: float = 34.0
@export var attack_run_seconds: float = 6.0
@export var return_seconds: float = 8.5
@export var approach_timeout: float = 40.0
@export var turn_away_seconds: float = 4.0
@export var turn_away_angle: float = 1.05
@export var player_separation: float = 19.0
@export var ship_separation: float = 16.0
@export var steering_commitment: float = 1.5
@export var speed_variation: float = 0.35
@export var holding_speed: float = 7.0
@export var holding_arc: float = 0.42
@export var holding_leg_seconds: float = 9.0
@export var recovery_seconds: float = 5.0
@export var emergency_speed: float = 2.5
@export var terrain_margin: float = 7.0
@export var braking_acceleration: float = 5.0
@export var hull_capacity: int = 2
@export var firing_range: float = 62.0
@export var reload_seconds: float = 3.8
@export var telegraph_seconds: float = 1.65
@export var projectile_speed: float = 24.0
@export var encounter_seconds: float = 55.0
@export var escape_distance: float = 135.0
@export var cleanup_distance: float = 180.0
## Every other pass aims slightly long; aim stays fixed during the muzzle warning.
@export var forgiving_aim_offset: float = 4.5
@export_group("Night presentation")
@export var sail_color := Color("c57565")
@export_range(0.0, 0.3, 0.01) var sail_fill: float = 0.22

var territory := Vector3.ZERO
var game: Node3D
var navigation_state: Navigation = Navigation.DORMANT
var weapon_state: Weapon = Weapon.READY
var navigation_time := 0.0
var weapon_time := 0.0
var mode: Mode:
	get:
		if navigation_state == Navigation.SINKING: return Mode.SINKING
		if navigation_state == Navigation.DORMANT: return Mode.DORMANT
		if navigation_state == Navigation.ESCAPED: return Mode.ESCAPED
		if navigation_state == Navigation.RETREAT: return Mode.DISENGAGING
		if weapon_state == Weapon.TELEGRAPH: return Mode.TELEGRAPH
		if weapon_state == Weapon.FIRE: return Mode.FIRE
		if navigation_state == Navigation.ATTACK_RUN: return Mode.POSITION
		if navigation_state in [Navigation.TURN_AWAY, Navigation.REPOSITION, Navigation.HOLDING]: return Mode.REPOSITION
		return Mode.APPROACH
	set(value):
		match value:
			Mode.TELEGRAPH: weapon_state = Weapon.TELEGRAPH
			Mode.FIRE: weapon_state = Weapon.FIRE
			Mode.POSITION: navigation_state = Navigation.ATTACK_RUN
			Mode.APPROACH: navigation_state = Navigation.APPROACH
			Mode.REPOSITION: navigation_state = Navigation.REPOSITION
			Mode.DISENGAGING: navigation_state = Navigation.RETREAT
			Mode.SINKING: navigation_state = Navigation.SINKING
			Mode.ESCAPED: navigation_state = Navigation.ESCAPED
			Mode.DORMANT: navigation_state = Navigation.DORMANT
var heading: float = 0.0
var hull: int = 2
var age: float = 0.0
var timer: float:
	get: return weapon_time if weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE] else navigation_time
	set(value):
		if weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE]: weapon_time = value
		else: navigation_time = value
var cooldown: float = 0.0
var locked_point := Vector3.ZERO
var hit_reaction: float = 0.0
var shots_fired: int = 0
var shots_hit: int = 0
var visual: Node3D
var pennant: MeshInstance3D
var trim_material: StandardMaterial3D
var sail_material: StandardMaterial3D
var flash: MeshInstance3D
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
var _intercept_origin := Vector3.ZERO
var _intercept_velocity := Vector3.ZERO
var _intercept_point := Vector3.ZERO
var _joined_lane := false
var _staging_point := Vector3.ZERO
var _avoid_priority := 0
var safety_priority := 0
var collisions := 0
var contact_frames := 0
var recoveries := 0
var cancelled_shots := 0
var last_abort := ""
var director: RefCounted
var managed_by_director := false
var holding_radius := 130.0
var holding_direction := 1.0
var _holding_point := Vector3.INF
var _holding_time := 0.0
var _recovery_left := 0.0
var _recovery_heading := 0.0
var _contacting := false


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
	trim_material = game._material(Color("38282d"))
	var timber = trim_material
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
	pennant = preload("res://game/ship_pennant.gd").new()
	presentation.add_child(pennant)
	pennant.position = Vector3(0, 7.45, -1.8)
	pennant.configure(Color("d94b51"), Vector2(1.7, 0.85))
	var gun: Node3D = CANNON.instantiate()
	gun.position = Vector3(-1.1, 0.55, -1.8)
	gun.rotation.y = -PI / 2.0
	gun.scale = Vector3.ONE * 1.1
	presentation.add_child(gun)
	flash = game._mesh(presentation, game.combat_particles.flame_mesh(), Vector3(-2.4, 1.3, -1.8), null)
	flash.rotation.y = PI
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reset()


func reset() -> void:
	if has_meta("wave_id"):
		remove_meta("wave_id")
	if director != null:
		director.release(self)
	set_meta("defeat_recorded", false)
	managed_by_director = false
	_holding_point = Vector3.INF
	_holding_time = 0.0
	for shot: Dictionary in projectiles:
		shot.node.queue_free()
	projectiles.clear()
	navigation_state = Navigation.DORMANT
	weapon_state = Weapon.READY
	navigation_time = 0.0
	weapon_time = 0.0
	visible = false
	collision_layer = 0
	set_meta("destroyed", true)
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
	pennant.flutter(0.0)
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
	_intercept_origin = Vector3.ZERO
	_intercept_velocity = Vector3.ZERO
	_intercept_point = Vector3.ZERO
	_joined_lane = false
	_staging_point = Vector3.ZERO
	_avoid_priority = 0
	safety_priority = 0
	collisions = 0
	contact_frames = 0
	recoveries = 0
	cancelled_shots = 0
	last_abort = ""
	_recovery_left = 0.0
	_recovery_heading = 0.0
	_contacting = false
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
	trim_material.albedo_color = profile.trim_color
	pennant.configure(profile.pennant_color, profile.pennant_size)
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
	var highlighted: bool = enabled and visible and not get_meta("destroyed", true)
	if highlighted == aim_highlight:
		return
	aim_highlight = highlighted
	_update_cloth()


func _update_cloth() -> void:
	var damage := 0.16 * (1.0 - float(maxi(0, hull)) / maxi(1, hull_capacity))
	var color := sail_color.darkened(damage)
	var impact := clampf((hit_reaction - 0.45) / 0.20, 0.0, 1.0)
	sail_material.albedo_color = color.lerp(Color("fff0c4"), impact * 0.8)
	sail_material.emission = color.lerp(Color("fff0c4"), impact)
	sail_material.emission_energy_multiplier = sail_fill + (0.20 if aim_highlight else 0.0) + impact * 0.65


func begin(at: Vector3 = Vector3.INF, coordinated: bool = false) -> void:
	reset()
	managed_by_director = coordinated
	run_heading = game.heading
	position = at if at.is_finite() else game.boat.position + _run_forward() * 16.0 + _run_right() * 60.0
	_capture_course()
	territory = position
	heading = run_heading + approach_angle
	rotation.y = -heading
	_speed = sailing_speed
	velocity = forward() * _speed
	_change_navigation(Navigation.HOLDING if coordinated else Navigation.APPROACH)
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
	if navigation_state in [Navigation.DORMANT, Navigation.ESCAPED]:
		return
	navigation_time += delta
	hit_reaction = maxf(0, hit_reaction - delta)
	_update_cloth()
	pennant.flutter(game.sea_time)
	if navigation_state == Navigation.SINKING:
		visual.position.y -= delta * 2.5
		visual.rotation.z += delta * 0.18
		if navigation_time >= 3.5:
			navigation_state = Navigation.ESCAPED
			visible = false
		return
	age += delta
	cooldown = maxf(0.0, cooldown - delta)
	var to_player: Vector3 = game.boat.position - global_position
	_escape_elapsed = _escape_elapsed + delta if to_player.length() > escape_distance else 0.0
	if not game.arena_mode and navigation_state != Navigation.RETREAT and (age >= encounter_seconds or (age > 8.0 and _escape_elapsed > 4.0)):
		disengage()
	var desired := _run_forward()
	var target_speed := run_speed
	match navigation_state:
		Navigation.APPROACH:
			var relative: Vector3 = global_position - _intercept_origin
			var along := relative.dot(_run_forward())
			var lateral := relative.dot(_run_right())
			var to_join := _intercept_point - global_position
			_joined_lane = _joined_lane or to_join.length() < approach_lead
			if _joined_lane:
				desired = (_run_forward() * approach_lead + _run_right() * (lane_separation - lateral)).normalized()
			else:
				desired = _arena_approach(_intercept_point, delta) if game.arena_mode else to_join.normalized()
			var predicted_along := along - _intercept_velocity.dot(_run_forward()) * navigation_time
			target_speed = clampf(run_speed + (8.0 - predicted_along) * 0.18 + maxf(0.0, absf(lateral - lane_separation) - 10.0) * 0.05,
				minf(run_speed * 0.85, sailing_speed * 0.74), sailing_speed * 1.12)
			var actual: Vector3 = global_position - game.boat.position
			var player_forward := _direction(game.heading)
			var player_right := Vector3(cos(game.heading), 0, sin(game.heading))
			if navigation_time > 2.0 and absf(actual.dot(player_forward)) < 24.0 and actual.dot(player_right) > 24.0 and actual.dot(player_right) < 46.0 and forward().dot(player_forward) > 0.90 and _avoid_left <= 0.0 and _path_clear(player_forward, 32.0):
				run_heading = game.heading
				run_speed = minf(sailing_speed * 0.96, clampf(game.boat.velocity.length(), game.SPEED * 0.85, game.SPEED * 1.05))
				run_elapsed = 0.0
				_pass_fired = false
				passes += 1
				_change_navigation(Navigation.ATTACK_RUN)
			elif navigation_time >= approach_timeout:
				last_abort = "interception missed"
				_start_turn()
		Navigation.ATTACK_RUN:
			run_elapsed += delta
			target_speed = run_speed + speed_variation * sin(float(passes) * 1.7)
			if run_elapsed >= attack_run_seconds:
				_start_turn()
		Navigation.TURN_AWAY:
			desired = _direction(run_heading + turn_away_angle)
			target_speed = sailing_speed
			if navigation_time >= turn_away_seconds:
				var player_forward := _direction(game.heading)
				var player_right := Vector3(cos(game.heading), 0, sin(game.heading))
				_staging_point = game.boat.position + player_forward * game.SPEED * 3.0 + player_right * (lane_separation + 20.0)
				_route_point = Vector3.INF
				_change_navigation(Navigation.REPOSITION)
		Navigation.REPOSITION:
			desired = _arena_approach(_staging_point, delta) if game.arena_mode else (_staging_point - global_position).normalized()
			target_speed = sailing_speed * 0.92
			if navigation_time >= maxf(3.0, return_seconds - turn_away_seconds) or global_position.distance_to(_staging_point) < 14.0:
				if managed_by_director:
					_holding_point = Vector3.INF
					_change_navigation(Navigation.HOLDING)
				else:
					receive_attack_slot()
		Navigation.HOLDING:
			desired = _holding_course(delta)
			target_speed = minf(holding_speed, sailing_speed * 0.85)
		Navigation.RETREAT:
			desired = _direction(_departure_heading)
			target_speed = sailing_speed
			var offscreen: bool = not game.camera.is_position_in_frustum(global_position + Vector3.UP * 3.0)
			if navigation_time > 4.0 and to_player.length() > cleanup_distance and (offscreen or to_player.length() > cleanup_distance + 60.0):
				_finish_escape()
				return
	desired = _safe_direction(desired, to_player, delta)
	if safety_priority >= 2 and navigation_state == Navigation.ATTACK_RUN:
		last_abort = "unsafe attack lane"
		_start_turn()
	_turn_toward(desired, delta)
	if _recovery_left > 0.0:
		target_speed = emergency_speed
	elif safety_priority >= 2:
		target_speed = minf(target_speed, sailing_speed * 0.65)
	if archetype != null:
		target_speed = minf(target_speed, sailing_speed * 1.12)
	if game.arena_mode:
		target_speed = _traffic_speed(target_speed)
	var speed_change := braking_acceleration if game.arena_mode and target_speed < _speed else acceleration
	_speed = move_toward(_speed, target_speed, delta * speed_change)
	var before := position
	velocity = forward() * _speed
	var travel := velocity * delta
	if game.arena_mode:
		travel = game.arena_return.bounded_motion(global_position - game.arena_center(), travel, game.arena_radius - 5.0)
	var collision := move_and_collide(travel, false, 0.08)
	if collision:
		contact_frames += 1
		if not _contacting:
			collisions += 1
		var normal := Vector3(collision.get_normal().x, 0, collision.get_normal().z).normalized()
		move_and_collide(collision.get_remainder().slide(normal), false, 0.08)
		if _recovery_left <= 0.0:
			_recovery_heading = atan2(normal.x, -normal.z)
			_recovery_left = recovery_seconds
			recoveries += 1
	_contacting = collision != null
	position.y = 0.0
	velocity = (position - before) / maxf(delta, 0.0001)
	_blocked_elapsed = _blocked_elapsed + delta if velocity.length() < _speed * 0.3 else 0.0
	if _blocked_elapsed > 1.0:
		if _recovery_left <= 0.0:
			var clear := _clear_course()
			_recovery_heading = atan2(clear.x, -clear.z)
			_recovery_left = recovery_seconds
			recoveries += 1
		if navigation_state not in [Navigation.RETREAT, Navigation.TURN_AWAY]:
			last_abort = "blocked route recovery"
			_start_turn()
		_blocked_elapsed = 0.0
	_update_weapon(delta)
	_update_tell()


func _traffic_speed(desired: float) -> float:
	var vessels: Array = game.enemy_encounters.living_ships()
	vessels.append(game.boat)
	for other in vessels:
		if other == self:
			continue
		var offset: Vector3 = other.global_position - global_position
		if offset.length() < 42.0 and offset.length_squared() > 0.01 and forward().dot(offset.normalized()) > 0.25:
			var clearance := player_separation if other == game.boat else ship_separation
			var following_speed: float = maxf(0.0, other.velocity.dot(forward()))
			desired = minf(desired, maxf(emergency_speed, following_speed + (offset.length() - clearance) * 0.45))
	return desired


func _change_navigation(value: Navigation) -> void:
	navigation_state = value
	navigation_time = 0.0


func _start_turn() -> void:
	if managed_by_director and navigation_state == Navigation.APPROACH:
		director.release(self)
	_change_navigation(Navigation.TURN_AWAY)


func receive_attack_slot() -> void:
	_pass_fired = false
	_capture_course()
	_change_navigation(Navigation.APPROACH)


func _holding_course(delta: float) -> Vector3:
	_holding_time += delta
	if not _holding_point.is_finite() or global_position.distance_to(_holding_point) < 14.0 or _holding_time >= holding_leg_seconds:
		_holding_time = 0.0
		var radial: Vector3 = global_position - game.arena_center()
		var angle := atan2(radial.x, -radial.z)
		_holding_point = Vector3.INF
		for radius: float in [holding_radius, game.arena_radius - 25.0, game.arena_radius - 15.0]:
			for arc: float in [holding_arc, holding_arc * 1.5]:
				var candidate: Vector3 = game.arena_center() + _direction(angle + arc * holding_direction) * radius
				if _water_lane_clear(global_position, candidate):
					_holding_point = candidate
					break
			if _holding_point.is_finite():
				break
		if not _holding_point.is_finite():
			_holding_point = global_position + _clear_course() * 25.0
	return (_holding_point - global_position).normalized()


func _change_weapon(value: Weapon) -> void:
	weapon_state = value
	weapon_time = 0.0


func _shot_lane_valid(point: Vector3) -> bool:
	var from := muzzle_position()
	var query := PhysicsRayQueryParameters3D.create(from, point, 5, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_weapon(delta: float) -> void:
	weapon_time += delta
	if navigation_state == Navigation.RETREAT:
		return
	match weapon_state:
		Weapon.READY:
			var offset: Vector3 = game.boat.position - global_position
			if navigation_state != Navigation.ATTACK_RUN or _pass_fired or cooldown > 0.0:
				return
			if offset.length() <= player_separation or offset.length() >= firing_range or port_direction().dot(offset.normalized()) < 0.90:
				return
			_lock_shot()
			if not _shot_lane_valid(locked_point):
				return
			if managed_by_director and not director.request_warning(self):
				return
			_change_weapon(Weapon.TELEGRAPH)
			game.cue_sound("warning")
		Weapon.TELEGRAPH:
			if weapon_time >= telegraph_seconds:
				if _shot_lane_valid(locked_point):
					_fire()
					_change_weapon(Weapon.FIRE)
				else:
					cancelled_shots += 1
					cooldown = reload_seconds
					_change_weapon(Weapon.RELOAD)
				_pass_fired = true
		Weapon.FIRE:
			if weapon_time >= 0.18:
				_change_weapon(Weapon.RELOAD)
		Weapon.RELOAD:
			if cooldown <= 0.0:
				_change_weapon(Weapon.READY)


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
	_joined_lane = false
	run_heading = game.heading
	_intercept_origin = game.boat.position
	_intercept_velocity = game.boat.velocity
	_route_point = Vector3.INF
	_route_check_left = 0.0
	run_speed = clampf(game.boat.velocity.length(), game.SPEED * 0.85, game.SPEED * 1.05)
	if archetype != null:
		run_speed = minf(run_speed, sailing_speed * 0.96)
	_course_age = 0.0
	lane_separation = clampf(broadside_separation, 25.0, 45.0)
	var joining_distance: float = (global_position - (_intercept_origin + _run_right() * lane_separation)).length()
	var prediction := clampf(joining_distance / maxf(1.0, sailing_speed), 2.5, 6.0)
	_intercept_point = _intercept_origin + _intercept_velocity * prediction + _run_right() * lane_separation


func _path_clear(direction: Vector3, distance: float = 30.0) -> bool:
	var terrain = game.archipelago.get_node("Terrain")
	var side := Vector3(-direction.z, 0, direction.x) * terrain_margin
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
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1, [get_rid()])
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


func _hold_avoidance(direction: Vector3, seconds: float, priority: int = 1) -> void:
	_avoid_heading = atan2(direction.x, -direction.z)
	_avoid_left = seconds
	_avoid_priority = priority


func _separation_course(away: Vector3) -> Vector3:
	var right := Vector3(cos(heading), 0, sin(heading))
	var side := 1.0 if away.dot(right) >= 0.0 else -1.0
	return (away.normalized() * 0.45 + right * side + forward() * 0.25).normalized()


func _safe_direction(desired: Vector3, to_player: Vector3, delta: float) -> Vector3:
	_avoid_left = maxf(0.0, _avoid_left - delta)
	_recovery_left = maxf(0.0, _recovery_left - delta)
	safety_priority = 0
	if _recovery_left > 0.0:
		safety_priority = 3
		return _direction(_recovery_heading)
	var committed := _direction(_avoid_heading)
	if _avoid_left > 0.0 and _avoid_priority == 3:
		safety_priority = 3
		return committed
	if not _path_clear(forward()) or not _path_clear(desired, 25.0):
		if _avoid_left <= 0.0 or _avoid_priority != 2 or not _path_clear(committed):
			_hold_avoidance(_clear_course(), 2.5, 2)
		safety_priority = 2
		return _direction(_avoid_heading)
	if _avoid_left > 0.0 and _path_clear(committed):
		safety_priority = _avoid_priority
		return committed
	var closest_away := Vector3.ZERO
	var nearest := INF
	var vessels: Array = game.enemy_encounters.living_ships() if game.arena_mode else []
	vessels.append(game.boat)
	for other in vessels:
		if other == self:
			continue
		var relative: Vector3 = global_position - other.global_position
		var relative_velocity: Vector3 = forward() * _speed - other.velocity
		var horizon := clampf(1.7 / turning_speed, 4.0, 6.0)
		var closest_time := clampf(-relative.dot(relative_velocity) / maxf(0.01, relative_velocity.length_squared()), 0.0, horizon)
		var predicted: float = (relative + relative_velocity * closest_time).length()
		var separation := player_separation if other == game.boat else ship_separation
		if relative.length() < separation or (relative.length() < 80.0 and predicted < separation):
			if predicted < nearest:
				nearest = predicted
				closest_away = relative
	if closest_away != Vector3.ZERO:
		var away := _separation_course(closest_away)
		_hold_avoidance(away if _path_clear(away) else _clear_course(), steering_commitment)
		safety_priority = 1
		return _direction(_avoid_heading)
	return desired


func _change(value: Mode) -> void:
	mode = value
	timer = 0.0


func _lock_shot() -> void:
	# Predict once and keep this fixed world point throughout the warning. No homing.
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
	flash.visible = (weapon_state == Weapon.FIRE and weapon_time < 0.11) or (weapon_state == Weapon.TELEGRAPH and fmod(weapon_time, 0.3) < 0.15)
	flash.scale = Vector3.ONE * (0.45 if weapon_state == Weapon.TELEGRAPH else 0.6 + 0.4 * clampf(1.0 - weapon_time / 0.11, 0.0, 1.0))


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
	projectiles.append({"node": ball, "position": from, "velocity": launch, "ttl": 4.0, "trail_clock": 0.0})
	game.combat_particles.muzzle(from, launch.normalized(), true)
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
			elif not hit.is_empty() and hit.collider != game.boat:
				game.combat_particles.impact(hit.position, false)
			elif hit.is_empty() and not water.is_empty():
				game.cannon.water_splash(water.position)
			shot.node.queue_free()
			projectiles.remove_at(i)
		else:
			shot.position = to
			shot.node.global_position = to
			shot.trail_clock = shot.get("trail_clock", 0.0) + delta
			if shot.trail_clock >= 0.07:
				shot.trail_clock = 0.0
				game.combat_particles.trail(to, true)


func take_hit() -> void:
	if navigation_state in [Navigation.SINKING, Navigation.ESCAPED, Navigation.DORMANT]:
		return
	hull -= 1
	hit_reaction = 0.65
	if hull <= 0:
		set_meta("destroyed", true)
		collision_layer = 0
		flash.visible = false
		_change_navigation(Navigation.SINKING)
		_change_weapon(Weapon.READY)
		set_aim_highlight(false)
		game.enemy_encounters.on_ship_sunk(self)
		game.cue_sound("victory")
	_update_cloth()


func update_visuals(delta: float) -> void:
	if not visible or navigation_state == Navigation.SINKING:
		return
	pennant.flutter(game.sea_time)
	motion.update_motion(game.ocean, self, visual, delta)
	visual.rotation.z += sin(hit_reaction * 20.0) * hit_reaction * 0.21
	_update_tell()


func disengage() -> void:
	if game.arena_mode or navigation_state in [Navigation.DORMANT, Navigation.ESCAPED, Navigation.SINKING, Navigation.RETREAT]:
		return
	var away: Vector3 = global_position - game.boat.position
	_departure_heading = atan2(away.x, -away.z)
	_change_navigation(Navigation.RETREAT)
	_change_weapon(Weapon.READY)
	flash.visible = false


func _finish_escape() -> void:
	navigation_state = Navigation.ESCAPED
	visible = false
	collision_layer = 0
	set_meta("destroyed", true)
	velocity = Vector3.ZERO
	flash.visible = false


func warning() -> String:
	if weapon_state == Weapon.TELEGRAPH:
		return "ENEMY BROADSIDE  ·  TURN TO EVADE  ·  %.1fs" % maxf(0, telegraph_seconds - weapon_time)
	if navigation_state in [Navigation.APPROACH, Navigation.ATTACK_RUN] and age < 7.0:
		return "HOSTILE %s  ·  SHOOT OR SAIL CLEAR" % display_name().to_upper()
	return ""

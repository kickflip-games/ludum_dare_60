extends CharacterBody3D
const CombatMetrics = preload("res://game/combat_event_metrics.gd")
## Planar navigation and committed cannon fire use independent state machines.

const Motion = preload("res://game/ocean/boat_wave_motion.gd")
const SHIP = preload("res://assets/kenney_ships/ship-pirate-small.glb")
const ShipMaterials = preload("res://game/ship_materials.gd")
const ClothMotion = preload("res://game/ship_cloth_motion.gd")
const SeaEffects = preload("res://game/enemy_sea_effects.gd")
const MineLayer = preload("res://game/enemy_mine_layer.gd")
const CANNON = preload("res://assets/pirate_kit/cannon.glb")
enum Mode { DORMANT, APPROACH, POSITION, TELEGRAPH, FIRE, REPOSITION, SINKING, ESCAPED, DISENGAGING }
enum Navigation { DORMANT, APPROACH, ATTACK_RUN, TURN_AWAY, REPOSITION, HOLDING, RETREAT, SINKING, ESCAPED }
enum Weapon { READY, TELEGRAPH, FIRE, RELOAD }
enum Battery { PORT, STARBOARD, BOW }

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
@export_group("Night presentation")
@export_range(0.0, 0.3, 0.01) var sail_fill: float = 0.04

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
var ship_model: Node3D
var model_materials: Array[StandardMaterial3D] = []
var sail_material: StandardMaterial3D
var flash: MeshInstance3D
var motion := Motion.new()
var projectiles: Array[Dictionary] = []
var gun_mounts: Array[Dictionary] = []
var _armament_pool: Array[Dictionary] = []
var _cloth_state := Vector4.INF
var active_battery := Battery.PORT
var sea_effects: Node3D
var mine_layer: RefCounted
var salvos_fired := 0
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
var _course_age: float = 0.0
var archetype: Resource
var presentation: Node3D
var collision_shape: CollisionShape3D
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
	_build_presentation()
	if is_instance_valid(ship_model):
		mine_layer = MineLayer.new()
		mine_layer.ship = self
		mine_layer.prepare()
		_prepare_armament()
		_build_armament(1, false, false)
	else:
		# The flagship supplies its own multi-muzzle weapon and presentation.
		flash = game._mesh(presentation, game.combat_particles.flame_mesh(), Vector3(-2.4, 1.3, -1.8), null)
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea_effects = SeaEffects.new()
	sea_effects.name = "SeaEffects"
	add_child(sea_effects)
	sea_effects.setup(self)
	reset()


func _prepare_armament() -> void:
	# Maximum production layout: three per broadside and the skiff bow gun.
	# Imported meshes/materials stay alive for the pooled hull's entire lifetime.
	for side in [Battery.PORT, Battery.STARBOARD]:
		for i in 3: _add_gun(side, Vector3.ZERO, Vector3.ZERO, 0)
	_add_gun(Battery.BOW, Vector3.ZERO, Vector3.ZERO, 0)


func _build_armament(count: int, both_sides: bool, bow: bool) -> void:
	var _profile_started := CombatMetrics.start()
	assert(count >= 1 and count <= 3, "Armament exceeds prepared ordinary ship capacity")
	for mount in _armament_pool:
		mount.gun.hide()
		mount.flash.hide()
	gun_mounts.clear()
	for side in ([Battery.PORT, Battery.STARBOARD] if both_sides else [Battery.PORT]):
		for i in count:
			var along := -1.8 if count == 1 else lerpf(-2.8, 0.2, float(i) / (count - 1))
			var sign_x := -1.0 if side == Battery.PORT else 1.0
			var deck := 1.3 if both_sides else 0.55
			var mount := _armament_pool[(0 if side == Battery.PORT else 3) + i]
			_configure_mount(mount, Vector3(sign_x * 1.1, deck, along), Vector3(sign_x * 2.4, deck + 0.75, along), sign_x * PI / 2)
	if bow:
		_configure_mount(_armament_pool[6], Vector3(0, 2.28, -4.2), Vector3(0, 3.03, -5.5), 0)
	flash = gun_mounts[0].flash
	CombatMetrics.finish("enemy_ship.gd:_build_armament", _profile_started)


func _configure_mount(mount: Dictionary, at: Vector3, muzzle: Vector3, yaw: float) -> void:
	mount.gun.position = at
	mount.gun.rotation.y = yaw
	mount.muzzle = muzzle
	mount.flash.position = muzzle
	mount.gun.show()
	gun_mounts.append(mount)


func _add_gun(battery: int, at: Vector3, muzzle: Vector3, yaw: float) -> void:
	var gun: Node3D = CANNON.instantiate()
	gun.name = "BowCannon" if battery == Battery.BOW else "PortCannon" if battery == Battery.PORT else "StarboardCannon"
	gun.position = at
	gun.rotation.y = yaw
	gun.scale = Vector3.ONE * 1.1
	presentation.add_child(gun)
	var tell: MeshInstance3D = game._mesh(presentation, game.combat_particles.flame_mesh(), muzzle, null)
	var direction := Vector3.FORWARD if battery == Battery.BOW else Vector3.LEFT if battery == Battery.PORT else Vector3.RIGHT
	tell.basis = Basis(direction, Vector3.UP, direction.cross(Vector3.UP))
	tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tell.visible = false
	_armament_pool.append({"battery": battery, "gun": gun, "muzzle": muzzle, "flash": tell})


func _battery_direction(battery: int) -> Vector3:
	return forward() if battery == Battery.BOW else port_direction() if battery == Battery.PORT else -port_direction()


func _select_battery(offset: Vector3) -> int:
	var selected := -1
	var best := cos(deg_to_rad(38.0)) if game.arena_mode else 0.90
	for mount in gun_mounts:
		var alignment: float = _battery_direction(mount.battery).dot(offset.normalized())
		if alignment > best:
			best = alignment
			selected = mount.battery
	return selected


func _mount_position(mount: Dictionary) -> Vector3:
	# Match visible barrels, including cosmetic wave heave/pitch/roll.
	return presentation.to_global(mount.muzzle)


func _build_presentation() -> void:
	ship_model = SHIP.instantiate()
	ship_model.name = "EnemyShipModel"
	ship_model.rotation.y = PI
	ship_model.scale = Vector3.ONE * 0.9
	ship_model.position = Vector3(0, -0.6, -1.62)
	presentation.add_child(ship_model)
	ship_model.add_child(ClothMotion.new())
	model_materials = ShipMaterials.prepare(ship_model)
	sail_material = ship_model.get_node("ship-pirate-small/sail-a").get_active_material(0)


func reset() -> void:
	_reset_ship(true)


func _reset_ship(clear_mines: bool) -> void:
	if is_instance_valid(sea_effects): sea_effects.reset()
	if has_meta("wave_id"):
		remove_meta("wave_id")
	if director != null:
		director.release(self)
	set_meta("defeat_recorded", false)
	managed_by_director = false
	_holding_point = Vector3.INF
	_holding_time = 0.0
	for shot: Dictionary in projectiles:
		game.cannon.projectile_visuals.release(shot.node)
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
	salvos_fired = 0
	active_battery = Battery.PORT
	for mount in gun_mounts:
		mount.flash.visible = false
	if mine_layer != null:
		if clear_mines: mine_layer.reset()
		else: mine_layer.clock = 0.0
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
	var _profile_started := CombatMetrics.start()
	archetype = profile
	sailing_speed = profile.speed
	turning_speed = profile.turn_speed
	turn_acceleration = profile.turn_acceleration
	acceleration = profile.acceleration
	hull_capacity = profile.hull
	broadside_separation = profile.broadside_separation + lane_offset
	approach_lead = profile.approach_lead
	approach_angle = profile.approach_angle
	reposition_angle = profile.reposition_angle
	attack_run_seconds = profile.attack_run_seconds
	return_seconds = profile.return_seconds
	telegraph_seconds = profile.telegraph_seconds
	reload_seconds = profile.reload_seconds
	firing_range = profile.firing_range
	_build_armament(profile.broadside_guns, profile.both_sides, profile.bow_gun)
	if mine_layer != null:
		mine_layer.clock = 0.0
		mine_layer.enabled = profile.lays_mines
		mine_layer.prepare()
	presentation.scale = Vector3.ONE
	collision_shape.shape.radius = 3.6
	collision_shape.position = Vector3(0, 1.0, -1.8)
	set_meta("target_radius", 4.2)
	set_meta("hazard_name", "the hostile " + profile.display_name.to_lower())
	_update_cloth()
	CombatMetrics.finish("enemy_ship.gd:configure_archetype", _profile_started)


func display_name() -> String:
	return archetype.display_name if archetype != null else "Cutter"


func set_aim_highlight(enabled: bool) -> void:
	var highlighted: bool = enabled and visible and not get_meta("destroyed", true)
	if highlighted == aim_highlight:
		return
	aim_highlight = highlighted
	_update_cloth()


func _update_cloth() -> void:
	var _profile_started := CombatMetrics.start()
	var damage := 0.16 * (1.0 - float(maxi(0, hull)) / maxi(1, hull_capacity))
	var impact := clampf((hit_reaction - 0.45) / 0.20, 0.0, 1.0)
	var state := Vector4(damage, impact, float(aim_highlight), sail_fill)
	if state != _cloth_state:
		_cloth_state = state
		for material in model_materials:
			var tint := Color.WHITE.darkened(damage).lerp(Color("fff0c4"), impact * 0.8)
			tint.a = material.albedo_color.a
			material.albedo_color = tint
			material.emission = Color.WHITE.lerp(Color("fff0c4"), maxf(damage, impact))
			material.emission_energy_multiplier = sail_fill + (0.20 if aim_highlight else 0.0) + impact * 0.65
	CombatMetrics.finish("enemy_ship.gd:_update_cloth", _profile_started)


func begin(at: Vector3 = Vector3.INF, coordinated: bool = false) -> void:
	var _profile_started := CombatMetrics.start()
	# Ordinary pooled hulls retain trails; the flagship keeps its specialised reset.
	if mine_layer != null: _reset_ship(false)
	else: reset()
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
	_update_cloth()
	sea_effects.begin()
	game.cue_sound("enemy")
	CombatMetrics.finish("enemy_ship.gd:begin", _profile_started)


func forward() -> Vector3:
	return Vector3(sin(heading), 0, -cos(heading))


func port_direction() -> Vector3:
	return Vector3(-cos(heading), 0, -sin(heading))


func muzzle_position() -> Vector3:
	for mount in gun_mounts:
		if mount.battery == active_battery:
			return _mount_position(mount)
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
	# Trails keep arming, hitting and expiring after sinking or pool reuse.
	if mine_layer != null:
		mine_layer.update(delta)
		if game.arena_mode and game.state != game.State.SAILING: return
	if navigation_state in [Navigation.DORMANT, Navigation.ESCAPED]:
		return
	navigation_time += delta
	hit_reaction = maxf(0, hit_reaction - delta)
	_update_cloth()
	if navigation_state == Navigation.SINKING:
		sea_effects.update_trail(delta, false)
		visual.position.y -= delta * 2.5
		visual.rotation.z += delta * 0.18
		if navigation_time >= 3.5:
			navigation_state = Navigation.ESCAPED
			visible = false
		return
	sea_effects.advance_arrival(delta)
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
			_course_age += delta
			# Refresh a stale interception only between committed legs. Guns keep
			# their warning point; steering still uses the same bounded turn rate.
			if game.arena_mode and not gun_mounts.is_empty() and game.boat.velocity.length() > 1.0 and _course_age >= 4.0 and not _route_point.is_finite() and weapon_state != Weapon.TELEGRAPH:
				_capture_course()
			var relative: Vector3 = global_position - _intercept_origin
			var along := relative.dot(_run_forward())
			var lateral := relative.dot(_run_right())
			var to_join := _intercept_point - global_position
			_joined_lane = _joined_lane or to_join.length() < approach_lead
			if _joined_lane:
				desired = (_run_forward() * approach_lead + _run_right() * (lane_separation - lateral)).normalized()
			else:
				desired = _arena_approach(_intercept_point, delta) if game.arena_mode else to_join.normalized()
			var predicted_along := along - _intercept_velocity.dot(_run_forward()) * _course_age
			target_speed = clampf(run_speed + (8.0 - predicted_along) * 0.18 + maxf(0.0, absf(lateral - lane_separation) - 10.0) * 0.05,
				minf(run_speed * 0.85, sailing_speed * 0.74), sailing_speed * 1.12)
			var actual: Vector3 = global_position - game.boat.position
			var player_forward := _direction(game.heading)
			var player_right := Vector3(cos(game.heading), 0, sin(game.heading))
			if _can_join_run(actual, player_forward, player_right) and _avoid_left <= 0.0 and _path_clear(player_forward, 32.0):
				run_heading = game.heading
				run_speed = minf(sailing_speed * 0.96, clampf(game.boat.velocity.length(), game.SPEED * 0.85, game.SPEED * 1.05))
				run_elapsed = 0.0
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
	sea_effects.update_trail(delta, true)
	sea_effects.apply_arrival()
	if gun_mounts.is_empty() or sea_effects.arrival_age >= SeaEffects.ARRIVAL_SECONDS or weapon_state != Weapon.READY:
		_update_weapon(delta)
	_update_tell()


func _can_join_run(actual: Vector3, player_forward: Vector3, player_right: Vector3) -> bool:
	# Ordinary hulls commit to a useful broadside without chasing exact parallelism.
	# The flagship keeps its specialised approach contract.
	var ordinary: bool = game.arena_mode and not gun_mounts.is_empty()
	return navigation_time > (0.5 if ordinary else 2.0) \
		and absf(actual.dot(player_forward)) < (35.0 if ordinary else 24.0) \
		and (absf(actual.dot(player_right)) if ordinary else actual.dot(player_right)) > (player_separation + 3.0 if ordinary else 24.0) \
		and (absf(actual.dot(player_right)) if ordinary else actual.dot(player_right)) < (55.0 if ordinary else 46.0) \
		and forward().dot(player_forward) > (0.78 if ordinary else 0.90)


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
	for mount in gun_mounts:
		if mount.battery != active_battery:
			continue
		var flat := (point - _mount_position(mount)) * Vector3(1, 0, 1)
		if _battery_direction(active_battery).dot(flat.normalized()) < cos(deg_to_rad(38.0)):
			return false
		var query := PhysicsRayQueryParameters3D.create(_mount_position(mount), point, 5, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _update_weapon(delta: float) -> void:
	weapon_time += delta
	if navigation_state in [Navigation.DORMANT, Navigation.ESCAPED, Navigation.SINKING, Navigation.RETREAT] or hull <= 0:
		return
	match weapon_state:
		Weapon.READY:
			var offset: Vector3 = game.boat.position - global_position
			var permitted: bool = not managed_by_director or director.owners.has(self)
			var sailing_leg: bool = navigation_state in [Navigation.APPROACH, Navigation.REPOSITION, Navigation.TURN_AWAY]
			var attack_course: bool = navigation_state == Navigation.ATTACK_RUN or (game.arena_mode and sailing_leg and absf(turn_rate) < 0.7)
			if not permitted or not attack_course or safety_priority >= 2 or cooldown > 0.0:
				return
			if offset.length() <= player_separation or offset.length() >= firing_range:
				return
			var battery := _select_battery(offset)
			if battery < 0:
				return
			active_battery = battery
			if not _lock_shot() or not _shot_lane_valid(locked_point):
				return
			if managed_by_director and not director.request_warning(self):
				return
			_change_weapon(Weapon.TELEGRAPH)
			game.cue_sound("warning")
		Weapon.TELEGRAPH:
			if weapon_time >= telegraph_seconds:
				if safety_priority < 2 and _shot_lane_valid(locked_point):
					_fire()
					_change_weapon(Weapon.FIRE)
				else:
					cancelled_shots += 1
					cooldown = reload_seconds
					_change_weapon(Weapon.RELOAD)
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


func _lock_shot() -> bool:
	# Freeze a world-space intercept at warning start. Use measured motion rather
	# than the navigation goal; the short warning may begin on an approach leg.
	var future_origin := muzzle_position() + velocity * telegraph_seconds
	var v: Vector3 = game.boat.velocity * Vector3(1, 0, 1)
	var player_at: Vector3 = game.boat.position + v * telegraph_seconds
	var r := (player_at - future_origin) * Vector3(1, 0, 1)
	var flight := intercept_time(r, v, projectile_speed)
	if flight <= 0.0 or flight >= 3.9:
		return false
	locked_point = player_at + v * flight
	locked_point.y = 0.8
	return true


static func intercept_time(r: Vector3, v: Vector3, speed: float) -> float:
	var a := v.length_squared() - speed * speed
	var b := 2.0 * r.dot(v)
	var c := r.length_squared()
	if c < 0.000001: return 0.0
	if absf(a) < 0.00001 * maxf(1.0, speed * speed):
		return -c / b if absf(b) > 0.000001 and -c / b > 0 else -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0: return -1.0
	# Stable quadratic roots, including equal-speed and receding-target cases.
	var q := -0.5 * (b + (1.0 if b >= 0 else -1.0) * sqrt(discriminant))
	var first := q / a
	var second := c / q if absf(q) > 0.000001 else -1.0
	if first > 0 and second > 0: return minf(first, second)
	return first if first > 0 else second


func _update_tell() -> void:
	for mount in gun_mounts:
		mount.flash.visible = mount.battery == active_battery and ((weapon_state == Weapon.FIRE and weapon_time < 0.11) or weapon_state == Weapon.TELEGRAPH)
		mount.flash.scale = Vector3.ONE * ((0.65 + 0.15 * sin(weapon_time * 32.0)) if weapon_state == Weapon.TELEGRAPH else 0.6 + 0.4 * clampf(1.0 - weapon_time / 0.11, 0.0, 1.0))


func _fire() -> void:
	var _profile_started := CombatMetrics.start()
	for mount in gun_mounts:
		if mount.battery == active_battery:
			_launch_ball(_mount_position(mount))
	salvos_fired += 1
	cooldown = reload_seconds
	game.cue_sound("enemy_shot")
	CombatMetrics.finish("enemy_ship.gd:_fire", _profile_started)


func _launch_ball(from: Vector3) -> void:
	var offset := locked_point - from
	var flat := Vector3(offset.x, 0, offset.z)
	var flight: float = maxf(0.2, flat.length() / projectile_speed)
	var launch := flat.normalized() * projectile_speed
	launch.y = (locked_point.y - from.y) / flight + 2.5 * maxf(0.0, flight - 1.0 / Engine.physics_ticks_per_second)
	var ball: MeshInstance3D = game.cannon.projectile_visuals.acquire(from, true)
	assert(ball != null, "Configured projectile budget must cover every live shot")
	projectiles.append({"node": ball, "position": from, "velocity": launch, "ttl": 4.0, "trail_clock": 0.0})
	game.combat_particles.muzzle(from, launch.normalized(), true)
	shots_fired += 1


func _advance_shots(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var from: Vector3 = shot.position
		var to: Vector3 = from + shot.velocity * delta
		game.cannonball_whiz(from, to, shot)
		var query := PhysicsRayQueryParameters3D.create(from, to, 7 if not gun_mounts.is_empty() else 3, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var water: Dictionary = game.ocean.water_hit(from, to, delta)
		if not water.is_empty() and not hit.is_empty() and from.distance_squared_to(water.position) < from.distance_squared_to(hit.position):
			hit = {}
		shot.velocity.y -= 5.0 * delta
		shot.ttl -= delta
		if not hit.is_empty() or not water.is_empty() or shot.ttl <= 0.0:
			# Retire before damage callbacks can clear every weapon on defeat.
			game.cannon.projectile_visuals.release(shot.node)
			projectiles.remove_at(i)
			if not hit.is_empty() and hit.collider == game.boat:
				if game.take_damage(1, "Enemy broadside hit"):
					shots_hit += 1
			elif not hit.is_empty() and hit.collider.get_meta("destructible", false):
				game.cannon._impact(hit.collider, hit.position)
			elif not hit.is_empty() and hit.collider != game.boat:
				game.combat_particles.impact(hit.position, false)
			elif hit.is_empty() and not water.is_empty():
				game.cannon.water_splash(water.position)
			if game.state != game.State.SAILING: return
		else:
			shot.position = to
			shot.node.global_position = to
			shot.trail_clock = shot.get("trail_clock", 0.0) + delta
			if shot.trail_clock >= 0.07:
				shot.trail_clock = 0.0
				game.combat_particles.trail(to, true)


func take_hit() -> void:
	var _profile_started := CombatMetrics.start()
	if navigation_state in [Navigation.SINKING, Navigation.ESCAPED, Navigation.DORMANT]:
		return
	hull -= 1
	hit_reaction = 0.65
	if hull <= 0:
		sea_effects.advance_arrival(SeaEffects.ARRIVAL_SECONDS)
		sea_effects.apply_arrival()
		set_meta("destroyed", true)
		collision_layer = 0
		flash.visible = false
		for mount in gun_mounts:
			mount.flash.visible = false
		_change_navigation(Navigation.SINKING)
		_change_weapon(Weapon.READY)
		set_aim_highlight(false)
		game.enemy_encounters.on_ship_sunk(self)
		game.cue_sound("victory")
	_update_cloth()
	CombatMetrics.finish("enemy_ship.gd:take_hit", _profile_started)


func update_visuals(delta: float) -> void:
	if not visible:
		return
	sea_effects.sync_surface()
	if navigation_state == Navigation.SINKING:
		return
	sea_effects.apply_arrival()
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
		var kind := "BOW CANNON" if active_battery == Battery.BOW else "BROADSIDE"
		return "ENEMY %s  ·  TURN TO EVADE  ·  %.1fs" % [kind, maxf(0, telegraph_seconds - weapon_time)]
	if navigation_state in [Navigation.APPROACH, Navigation.ATTACK_RUN] and age < 7.0:
		return "HOSTILE %s  ·  SHOOT OR SAIL CLEAR" % display_name().to_upper()
	return ""


func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.cannon) and is_instance_valid(game.cannon.projectile_visuals):
		for shot in projectiles: game.cannon.projectile_visuals.release(shot.node)
	projectiles.clear()
	if mine_layer != null: mine_layer.dispose()

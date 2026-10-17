extends CharacterBody3D
## One arcade cutter. Movement, telegraph and non-homing shots share the voyage clock.

const Motion = preload("res://game/ocean/boat_wave_motion.gd")
const SHIP = preload("res://assets/pirate_kit/small_ship.glb")
const CANNON = preload("res://assets/pirate_kit/cannon.glb")
enum Mode { DORMANT, APPROACH, POSITION, TELEGRAPH, FIRE, REPOSITION, SINKING, ESCAPED }

@export var sailing_speed: float = 7.0
@export var turning_speed: float = 0.85
@export var hull_capacity: int = 2
@export var firing_range: float = 62.0
@export var reload_seconds: float = 3.8
@export var telegraph_seconds: float = 1.65
@export var projectile_speed: float = 24.0
@export var encounter_seconds: float = 24.0

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
	visual = Node3D.new()
	add_child(visual)
	var model: Node3D = SHIP.instantiate()
	model.rotation.y = -PI / 2.0
	model.scale = Vector3(1.30, 0.9, 0.95)
	model.position = Vector3(0, -0.1, -1.8)
	visual.add_child(model)
	var timber = game._material(Color("3b2423"))
	game._box(visual, Vector3(0.18, 6.0, 0.18), Vector3(0, 3.1, -1.8), timber)
	sail_material = game._material(Color("a23e32"))
	game._box(visual, Vector3(4.8, 3.4, 0.09), Vector3(0, 4.3, -1.8), sail_material)
	game._box(visual, Vector3(5.2, 0.14, 0.14), Vector3(0, 6.1, -1.8), timber)
	game._box(visual, Vector3(1.6, 0.8, 0.06), Vector3(0.7, 7.0, -1.8), game._material(Color("151e23")))
	var gun: Node3D = CANNON.instantiate()
	gun.position = Vector3(-1.1, 0.55, -1.8)
	gun.rotation.y = -PI / 2.0
	gun.scale = Vector3.ONE * 1.1
	visual.add_child(gun)
	var spark := SphereMesh.new()
	spark.radius = 0.4
	spark.height = 0.8
	flash = game._mesh(visual, spark, Vector3(-2.4, 1.3, -1.8), game._material(Color("ffbe67"), 2.0))
	tell_mesh = BoxMesh.new()
	tell_line = game._mesh(game, tell_mesh, Vector3.ZERO, game._material(Color("ed9e5c"), 1.0))
	tell_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reset()


func reset() -> void:
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


func begin(at: Vector3 = Vector3.INF) -> void:
	hull = hull_capacity
	age = 0.0
	timer = 0.0
	cooldown = 0.0
	hit_reaction = 0.0
	position = at if at.is_finite() else game.boat.position + game.course_forward() * 42.0 + game.course_right() * 48.0
	territory = position
	heading = game.destination_bearing() - 1.9
	rotation.y = -heading
	mode = Mode.APPROACH
	visible = true
	collision_layer = 4
	set_meta("destroyed", false)
	sail_material.albedo_color = Color("a23e32")
	motion.reset()
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
		heading = rotate_toward(heading, desired, turning_speed * delta)
	rotation.y = -heading


func update_ship(delta: float) -> void:
	_advance_shots(delta)
	if mode in [Mode.DORMANT, Mode.ESCAPED]:
		return
	timer += delta
	hit_reaction = maxf(0, hit_reaction - delta)
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
	if age > encounter_seconds or to_player.length() > 145.0 or global_position.distance_to(territory) > 155.0:
		disengage()
		return
	var previous_heading: float = heading
	var goal: Vector3 = game.boat.position + game.course_forward() * 16.0 + game.course_right() * 29.0
	match mode:
		Mode.APPROACH:
			_turn_toward(goal - global_position, delta)
			if timer > 3.0:
				_change(Mode.POSITION)
		Mode.POSITION:
			# Port cannon faces the player while the cutter sails alongside their route.
			var broadside := Vector3(-to_player.z, 0, to_player.x)
			if to_player.length() < 18.0:
				broadside -= to_player * 1.6
			elif to_player.length() > 53.0:
				broadside += to_player * 0.5
			_turn_toward(broadside, delta)
			var alignment: float = port_direction().dot(to_player.normalized())
			if alignment > 0.91 and to_player.length() < firing_range and cooldown == 0.0:
				_lock_shot()
				_change(Mode.TELEGRAPH)
				game.cue_sound("warning")
		Mode.TELEGRAPH:
			if timer >= telegraph_seconds:
				_fire()
				_change(Mode.FIRE)
		Mode.FIRE:
			if timer > 0.18:
				_change(Mode.REPOSITION)
		Mode.REPOSITION:
			_turn_toward(goal - global_position, delta)
			if timer > 2.2:
				_change(Mode.POSITION)
	# All active states keep sailing. Local separation and a short terrain feeler prevent ramming.
	var terrain = game.archipelago.get_node("Terrain")
	var probe_point := global_position + forward() * 28.0
	if terrain.terrain_height_at(probe_point) > -3.0:
		# Choose the clearer side before reaching shore; physical collision is final authority.
		var left := forward().rotated(Vector3.UP, 1.0)
		var right := forward().rotated(Vector3.UP, -1.0)
		var left_height: float = terrain.terrain_height_at(global_position + left * 32.0)
		var right_height: float = terrain.terrain_height_at(global_position + right * 32.0)
		if mode == Mode.TELEGRAPH:
			_change(Mode.REPOSITION)
		_turn_toward(left if left_height < right_height else right, delta)
	var separation_speed: float = 1.0
	var relative_position: Vector3 = global_position - game.boat.position
	var relative_motion: Vector3 = forward() * sailing_speed - game.boat.velocity
	var closest_time: float = clampf(-relative_position.dot(relative_motion) / maxf(0.01, relative_motion.length_squared()), 0.0, 2.0)
	var closest: float = (relative_position + relative_motion * closest_time).length()
	if to_player.length() < 23.0 or (to_player.length() < 38.0 and closest < 11.0):
		# Yield to the player's route, including during a wind-up. Never hold a ramming line.
		if mode == Mode.TELEGRAPH:
			_change(Mode.REPOSITION)
		_turn_toward(-to_player.normalized() + game.course_forward() * 0.6, delta)
		separation_speed = 0.45
	heading = previous_heading + clampf(wrapf(heading - previous_heading, -PI, PI), -turning_speed * delta, turning_speed * delta)
	rotation.y = -heading
	velocity = forward() * sailing_speed * separation_speed + game.course_right() * game.voyage.current * 0.6
	var collision := move_and_collide(velocity * delta)
	if collision:
		move_and_collide(collision.get_remainder().slide(Vector3(collision.get_normal().x, 0, collision.get_normal().z).normalized()))
	position.y = 0.0
	velocity.y = 0.0
	_update_tell()


func _change(value: Mode) -> void:
	mode = value
	timer = 0.0


func _lock_shot() -> void:
	# Predict once, then show this fixed world point throughout the warning. No homing.
	var future_origin: Vector3 = muzzle_position() + velocity * telegraph_seconds
	var player_at: Vector3 = game.boat.position + game.boat.velocity * telegraph_seconds
	var r: Vector3 = player_at - future_origin
	r.y = 0.0
	var v: Vector3 = game.boat.velocity
	var a: float = v.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * r.dot(v)
	var discriminant: float = maxf(0.0, b * b - 4.0 * a * r.length_squared())
	var flight: float = clampf((-b - sqrt(discriminant)) / (2.0 * a), 0.4, 3.0)
	locked_point = player_at + v * flight
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
		shot.velocity.y -= 5.0 * delta
		shot.ttl -= delta
		if not hit.is_empty() or to.y < -0.2 or shot.ttl <= 0.0:
			if not hit.is_empty() and hit.collider == game.boat:
				if game.take_damage(1, "Enemy broadside hit"):
					shots_hit += 1
			game.cannon.water_splash(hit.position if not hit.is_empty() else to)
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
	sail_material.albedo_color = Color("612e2b")
	if hull <= 0:
		set_meta("destroyed", true)
		collision_layer = 0
		tell_line.visible = false
		flash.visible = false
		_change(Mode.SINKING)
		game.enemy_encounters.ships_sunk += 1
		game.cue_sound("victory")


func update_visuals(delta: float) -> void:
	if not visible or mode == Mode.SINKING:
		return
	motion.update_motion(game.ocean, self, visual, delta)
	visual.rotation.z += sin(hit_reaction * 20.0) * hit_reaction * 0.16
	_update_tell()


func disengage() -> void:
	mode = Mode.ESCAPED
	visible = false
	collision_layer = 0
	set_meta("destroyed", true)
	tell_line.visible = false
	flash.visible = false


func warning() -> String:
	if mode == Mode.TELEGRAPH:
		return "ENEMY BROADSIDE  ·  TURN OFF THE AMBER LINE  ·  %.1fs" % maxf(0, telegraph_seconds - timer)
	if mode in [Mode.APPROACH, Mode.POSITION] and age < 7.0:
		return "HOSTILE CUTTER  ·  SHOOT OR SAIL CLEAR"
	return ""

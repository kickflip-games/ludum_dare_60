extends "res://game/enemy_ship.gd"
## Heavy navigation is inherited. Committed multi-muzzle volleys and mines stay here.
const FLAGSHIP = preload("res://assets/kenney_ships/ship-pirate-large.glb")
const WARNING = preload("res://game/boss_warning.gdshader")
const MINE = preload("res://game/boss_mine.tscn")
enum Pattern { ROLLING, DOUBLE, SCATTER }
@export_group("Flagship volleys")
@export var rolling_gap := 0.21
@export var second_warning := 0.8
@export var minimum_attack_distance := 35.0
@export var maximum_projectiles := 12
@export var scatter_half_angle := 24.0
@export var volley_reload := 3.0
@export var double_reload := 3.4
@export_group("Flagship mines")
@export var mine_interval := 2.2
@export var phase_two_mine_interval := 1.8
@export var maximum_mines := 6:
	set(value):
		maximum_mines = value
		if is_node_ready(): _build_mine_pool()
@export var mine_trigger_radius := 7.0
@export var mine_arming_delay := 0.8
var phase_two := false
var pattern_index := 0
var pattern := Pattern.ROLLING
var salvo := 0
var volley: Array[Dictionary] = []
var warnings: Array[MeshInstance3D] = []
var mines: Array[Node3D] = []
var mine_pool: Array[Node3D] = []
var mine_clock := 0.0
var smoke_clock := 0.0
var sequence_time := 0.0
var warning_duration := 1.6
var committed_heading := 0.0
var attack_side := 1.0
var launch_history: Array[Dictionary] = []
var pattern_history: Array[int] = []
var phase_bursts := 0
var muzzle_flash_until := 0.0
var flagship_model: Node3D
var boss_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	super._ready()
	_build_mine_pool()
	collision_shape.shape.radius = 4.8
	collision_shape.position = Vector3(0, 1.2, -1.8)
	for z in [-6.0, 3.0]:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 3.6
		shape.shape = sphere
		shape.position = Vector3(0, 1.2, z)
		add_child(shape)
	set_meta("target_radius", 6.2)
	set_meta("hazard_name", "the flagship")
	var mat := ShaderMaterial.new()
	mat.shader = WARNING
	var area: MeshInstance3D = game._mesh(game, _warning_triangle(), Vector3.ZERO, mat)
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.extra_cull_margin = 4.0
	area.visible = false
	warnings.append(area)

func _warning_triangle() -> ImmediateMesh:
	# One reusable filled triangle, tessellated for the shared rolling-water shader.
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 64:
		for side in 32:
			var a := Vector2(float(side) / 32, float(ring) / 64)
			var b := Vector2(float(side + 1) / 32, float(ring) / 64)
			var c := Vector2(float(side + 1) / 32, float(ring + 1) / 64)
			var d := Vector2(float(side) / 32, float(ring + 1) / 64)
			for uv: Vector2 in [a, b, c, a, c, d]:
				mesh.surface_set_uv(uv)
				mesh.surface_add_vertex(Vector3((uv.x * 2.0 - 1.0) * uv.y, 0, -uv.y))
	mesh.surface_end()
	return mesh

func _build_presentation() -> void:
	flagship_model = FLAGSHIP.instantiate()
	flagship_model.name = "FlagshipModel"
	flagship_model.rotation.y = PI
	flagship_model.scale = Vector3.ONE * 1.25
	flagship_model.position = Vector3(0, -1.0, -1.8)
	presentation.add_child(flagship_model)
	flagship_model.add_child(ClothMotion.new())
	model_materials = ShipMaterials.prepare(flagship_model)
	boss_materials.assign(model_materials)
	sail_material = flagship_model.get_node("ship-pirate-large/sail-a").get_active_material(0)


func _update_cloth() -> void:
	super._update_cloth()
	var impact := clampf((hit_reaction - 0.45) / 0.20, 0.0, 1.0)
	for mat in boss_materials:
		mat.albedo_color = Color.WHITE.darkened(0.12 * (1.0 - float(maxi(0, hull)) / maxi(1, hull_capacity)))
		mat.emission_energy_multiplier = sail_fill + (0.16 if aim_highlight else 0.0) + impact * 0.30
	if is_instance_valid(sea_effects): sea_effects.apply_arrival()

func display_name() -> String:
	return "Flagship"

func reset() -> void:
	clear_hazards()
	super.reset()
	muzzle_flash_until = 0.0
	phase_two = false
	pattern_index = 0
	pattern = Pattern.ROLLING
	salvo = 0
	mine_clock = 0.0
	smoke_clock = 0.0
	sequence_time = 0.0
	launch_history.clear()
	pattern_history.clear()
	phase_bursts = 0

func clear_hazards() -> void:
	if is_instance_valid(sea_effects): sea_effects.reset()
	volley.clear()
	for area in warnings:
		area.visible = false
	for mine in mines:
		if is_instance_valid(mine): mine.expire()
	mines.clear()
	for shot in projectiles:
		game.cannon.projectile_visuals.release(shot.node)
	projectiles.clear()

func begin(at: Vector3 = Vector3.INF, coordinated: bool = false) -> void:
	super.begin(at, false)
	cooldown = 2.0

func update_ship(delta: float) -> void:
	# Refresh a missed interception only between committed manoeuvres, every six
	# seconds. A turning player must not strand the heavy hull on a stale lane.
	if navigation_state == Navigation.APPROACH and navigation_time >= 6.0 and weapon_state not in [Weapon.TELEGRAPH, Weapon.FIRE]:
		_capture_course()
		navigation_time = 0.0
	super.update_ship(delta)
	if hull <= 0 or not visible or game.state != game.State.SAILING:
		return
	_update_mines(delta)
	if phase_two:
		smoke_clock += delta
		if smoke_clock > 0.65:
			smoke_clock = 0.0
			game.combat_particles.smoke(visual.to_global(Vector3(0, 3, 2)))

func _update_mines(delta: float) -> void:
	for i in range(mines.size() - 1, -1, -1):
		var mine = mines[i]
		if not is_instance_valid(mine) or mine.spent:
			mines.remove_at(i)
		else:
			mine.update_mine(delta)
	# Existing hazards keep ticking, but new mines belong to the cannon attack.
	# Reload is a real opening: neither battery nor minelayer starts an attack.
	if weapon_state not in [Weapon.TELEGRAPH, Weapon.FIRE] or safety_priority >= 2:
		mine_clock = 0.0
		return
	mine_clock += delta
	var interval := phase_two_mine_interval if phase_two else mine_interval
	if mine_clock >= interval:
		# A blocked stern retries once space opens without stacking delayed drops.
		mine_clock = fmod(mine_clock, interval) if deploy_mine() else interval

func _change_navigation(value: Navigation) -> void:
	super._change_navigation(value)
	if value == Navigation.REPOSITION:
		# The slower hull stages within cannon reach rather than using a skiff's
		# long outside return leg. Capture once, then sail the whole committed leg.
		var right := Vector3(cos(game.heading), 0, sin(game.heading))
		_staging_point = game.boat.position + game.boat.velocity * 1.5 + right * (broadside_separation + 4.0)

func _safe_direction(desired: Vector3, to_player: Vector3, delta: float) -> Vector3:
	# Validate the advertised sailing leg, not an obsolete approach waypoint,
	# while a volley is committed. Real terrain/traffic avoidance still applies.
	return super._safe_direction(_direction(committed_heading) if weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE] else desired, to_player, delta)

func _turn_toward(direction: Vector3, delta: float) -> void:
	# Hold a real sailing course through a volley; safety can still abort it.
	super._turn_toward(_direction(committed_heading) if weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE] and safety_priority == 0 else direction, delta)

func _update_weapon(delta: float) -> void:
	weapon_time += delta
	if weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE] and safety_priority >= 2:
		_finish_pattern()
		cancelled_shots += 1
		return
	match weapon_state:
		Weapon.READY:
			var offset: Vector3 = game.boat.position - global_position
			if cooldown > 0.0 or safety_priority >= 2 or navigation_state not in [Navigation.APPROACH, Navigation.ATTACK_RUN, Navigation.TURN_AWAY, Navigation.REPOSITION]: return
			if offset.length() < minimum_attack_distance or offset.length() > firing_range: return
			if absf(port_direction().dot(offset.normalized())) < 0.78 or absf(turn_rate) > 0.12: return
			if not game.enemy_encounters.director.request_boss_warning(telegraph_seconds + 1.2): return
			var rotation_one := [Pattern.ROLLING, Pattern.DOUBLE]
			var rotation_two := [Pattern.ROLLING, Pattern.DOUBLE, Pattern.SCATTER, Pattern.ROLLING, Pattern.SCATTER]
			var rotation_set: Array = rotation_two if phase_two else rotation_one
			pattern = rotation_set[pattern_index % rotation_set.size()]
			salvo = 0
			if _prepare_volley(telegraph_seconds):
				pattern_index += 1
				pattern_history.append(pattern)
				if pattern_history.size() > 64: pattern_history.pop_front()
		Weapon.TELEGRAPH:
			if weapon_time >= warning_duration:
				sequence_time = weapon_time - warning_duration
				_change_weapon(Weapon.FIRE)
				_fire_due()
		Weapon.FIRE:
			sequence_time += delta
			_fire_due()
		Weapon.RELOAD:
			if cooldown <= 0.0: _change_weapon(Weapon.READY)

func _prepare_volley(seconds: float) -> bool:
	volley.clear()
	warning_duration = seconds
	committed_heading = heading
	attack_side = 1.0 if port_direction().dot(game.boat.position - position) > 0 else -1.0
	var count := 5 if pattern != Pattern.DOUBLE else 2
	var gap := rolling_gap if pattern == Pattern.ROLLING else (0.10 if pattern == Pattern.DOUBLE else 0.025)
	var future: Vector3 = position + forward() * _speed * seconds
	var target: Vector3 = game.boat.position + game.boat.velocity * (seconds + clampf(position.distance_to(game.boat.position) / projectile_speed, 0.6, 2.7))
	var aim := target - future
	aim.y = 0
	if aim.length() < 1.0: return false
	var angle_step := scatter_half_angle * 2.0 / 4.0
	var fan_sign := signf(forward().dot(Vector3(aim.z, 0, -aim.x)))
	for i in count:
		var time: float = i * gap
		var along: float = (-1.8 + i * 3.6) if pattern == Pattern.DOUBLE else -5.2 + i * (10.4 / maxf(1.0, count - 1.0))
		var muzzle: Vector3 = future + forward() * (along + _speed * time) + port_direction() * attack_side * 3.5
		var degrees: float = ((-scatter_half_angle + i * angle_step) * fan_sign) if pattern == Pattern.SCATTER else ((i - (count - 1) * 0.5) * 3.0)
		var direction := aim.normalized().rotated(Vector3.UP, deg_to_rad(degrees))
		var distance := clampf(aim.length(), 35.0, 72.0)
		var end := muzzle + direction * distance
		muzzle.y = 2.0
		end.y = 0.8
		if not _volley_lane_clear(muzzle, end):
			volley.clear()
			cooldown = 0.5
			return false
		volley.append({"origin":muzzle, "direction":direction, "end":end, "along":along, "time":time, "fired":false})
	locked_point = target
	if navigation_state == Navigation.APPROACH:
		run_heading = heading
		run_speed = _speed
		run_elapsed = 0.0
		passes += 1
		_change_navigation(Navigation.ATTACK_RUN)
	_change_weapon(Weapon.TELEGRAPH)
	# Start laying with the first warning; the double salvo shares one mine clock.
	if salvo == 0:
		mine_clock = phase_two_mine_interval if phase_two else mine_interval
	game.cue_sound("warning")
	return true

func _volley_lane_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _fire_due() -> void:
	for shot in volley:
		if shot.fired or shot.time > sequence_time: continue
		shot.fired = true
		var from: Vector3 = position + forward() * shot.along + port_direction() * attack_side * 3.5
		from.y = 2.0
		# If an avoidance manoeuvre invalidated the advertised water lane, skip it.
		if from.distance_to(shot.origin) > 3.0 or projectiles.size() >= maximum_projectiles:
			continue
		var end: Vector3 = from + shot.direction * Vector3(1, 0, 1) * from.distance_to(shot.end)
		end.y = 0.8
		if not _volley_lane_clear(from, end): continue
		var flight: float = maxf(0.2, Vector2(end.x - from.x, end.z - from.z).length() / projectile_speed)
		var launch: Vector3 = shot.direction * projectile_speed
		launch.y = (end.y - from.y + 2.5 * flight * flight) / flight
		var ball: MeshInstance3D = game.cannon.projectile_visuals.acquire(from, true)
		assert(ball != null, "Configured projectile budget must cover every live shot")
		projectiles.append({"node":ball, "position":from, "velocity":launch, "ttl":4.0, "trail_clock":0.0})
		game.combat_particles.muzzle(from, launch.normalized(), true)
		flash.global_position = from
		var direction := launch.normalized()
		var up := (Vector3.UP - direction * direction.dot(Vector3.UP)).normalized()
		flash.global_basis = Basis(direction, up, direction.cross(up))
		muzzle_flash_until = game.sea_time + 0.11
		shots_fired += 1
		launch_history.append({"pattern":pattern, "salvo":salvo, "origin":from, "warning_origin":shot.origin, "direction":shot.direction, "velocity":launch})
		if launch_history.size() > 128: launch_history.pop_front()
		game.cue_sound("enemy_shot")
	if volley.all(func(shot): return shot.fired):
		if pattern == Pattern.DOUBLE and salvo == 0:
			salvo = 1
			# Newly commit before the distinct second warning. Reserve escort spacing too.
			game.enemy_encounters.director.reserve_boss_warning(second_warning + 0.4)
			if not _prepare_volley(second_warning): _finish_pattern()
		else:
			_finish_pattern()

func _finish_pattern() -> void:
	volley.clear()
	cooldown = (double_reload if pattern == Pattern.DOUBLE else volley_reload) * (0.90 if phase_two else 1.0)
	_change_weapon(Weapon.RELOAD)
	for area in warnings: area.visible = false

func _update_tell() -> void:
	flash.visible = game.sea_time < muzzle_flash_until and not get_meta("destroyed", true)
	flash.scale = Vector3.ONE * (0.6 + 0.4 * clampf((muzzle_flash_until - game.sea_time) / 0.11, 0.0, 1.0))
	if warnings.is_empty(): return
	var area := warnings[0]
	area.visible = not volley.is_empty() and weapon_state in [Weapon.TELEGRAPH, Weapon.FIRE]
	if not area.visible: return
	var geometry := warning_geometry()
	area.global_position = geometry.origin
	area.global_basis = Basis.looking_at(geometry.direction) * Basis.from_scale(Vector3(geometry.half_width, 1, geometry.length))
	var mat: ShaderMaterial = area.material_override
	mat.set_shader_parameter("tell_color", Color("dc9e65") if pattern == Pattern.ROLLING else Color("e6c17a") if pattern == Pattern.DOUBLE and salvo == 0 else Color("cf7e73"))
	mat.set_shader_parameter("opacity", 0.23 + (0.0 if game.motion_setting == 1 else 0.03 * sin(weapon_time * 7.0)))
	game.ocean.settings.apply_waves(mat)
	game.ocean.wave_field.apply_to(mat)
	mat.set_shader_parameter("wave_time", game.ocean.wave_time)
	mat.set_shader_parameter("focus_xz", game.ocean.focus_xz)
	mat.set_shader_parameter("fade_start", game.ocean.fade_start)
	mat.set_shader_parameter("fade_end", game.ocean.fade_end)

func warning_geometry() -> Dictionary:
	# Bound the entire locked volley, including separated muzzles. The broad fill
	# advertises danger, while individual cannonballs still leave dodgeable gaps.
	var origin := Vector3.ZERO
	var direction := Vector3.ZERO
	for shot in volley:
		origin += shot.origin
		direction += shot.direction
	origin /= maxi(1, volley.size())
	direction.y = 0
	direction = direction.normalized()
	origin -= direction * 20.0
	origin.y = 0
	var side := direction.cross(Vector3.UP)
	var length := 1.0
	var slope := 0.0
	for shot in volley:
		for point: Vector3 in [shot.origin, shot.end]:
			var offset := point - origin
			var along := maxf(0.1, offset.dot(direction))
			length = maxf(length, along)
			slope = maxf(slope, (absf(offset.dot(side)) + 0.8) / along)
	return {"origin": origin, "direction": direction, "length": length, "half_width": length * slope}

func take_hit() -> void:
	if game.state != game.State.SAILING: return
	var previous := hull
	super.take_hit()
	if hull > 0 and hull < previous and not phase_two and float(hull) <= hull_capacity * 0.5:
		phase_two = true
		# Introduce the new fan on the next cycle, without interrupting current fire.
		pattern_index = 2
		phase_bursts += 1
		game.combat_particles.damage(visual.to_global(Vector3(0, 3, -2)), false)
	if hull <= 0:
		clear_hazards()
		hit_reaction = 0.0
		_update_cloth()

func mine_position_valid(at: Vector3) -> bool:
	if not game.archipelago.water_clear(at, mine_trigger_radius + 2.0): return false
	if at.distance_to(game.arena_center()) > game.arena_radius - mine_trigger_radius - 10.0: return false
	if at.distance_to(game.arena_center()) < 55.0: return false
	if at.distance_to(game.boat.position) < mine_trigger_radius + 14.0: return false
	for mine in mines:
		if is_instance_valid(mine) and not mine.spent and mine.position.distance_to(at) < mine_trigger_radius * 2.0 + 2.0: return false
	return true

func deploy_mine() -> bool:
	var at := position - forward() * 12.5
	if not mine_position_valid(at): return false
	mines = mines.filter(func(mine): return is_instance_valid(mine) and not mine.spent)
	if mines.size() >= maxi(1, maximum_mines): return false
	var mine: Node3D = null
	for candidate in mine_pool:
		if candidate.spent:
			mine = candidate
			break
	assert(mine != null, "Mine pool must cover configured maximum")
	mine.activate(at)
	mines.append(mine)
	return true

func _build_mine_pool() -> void:
	for i in range(mine_pool.size(), maxi(1, maximum_mines)):
		var mine: Node3D = MINE.instantiate()
		mine.game = game
		mine.pooled = true
		mine.trigger_radius = mine_trigger_radius
		mine.arming_delay = mine_arming_delay
		# Fixed world-space sibling; moving the ship never moves an active mine.
		game.enemy_encounters.add_child(mine)
		mine_pool.append(mine)

func warning() -> String:
	return "FLAGSHIP BROADSIDE · SAIL CLEAR" if weapon_state == Weapon.TELEGRAPH else ""

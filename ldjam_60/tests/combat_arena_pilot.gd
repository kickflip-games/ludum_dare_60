extends RefCounted

var target: CharacterBody3D
var helm_exits := 0
var avoid_left := 0.0
var avoid_heading := 0.0
var orbit := false

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for name in ["watch_starboard", "fire_starboard", "steer_port", "steer_starboard"]:
		action(name, false)

func helm(steering: float) -> void:
	action("watch_starboard", false)
	action("steer_port", steering < -0.08)
	action("steer_starboard", steering > 0.08)

func lane_clear(game, heading: float, distance: float) -> bool:
	var direction := Vector3(sin(heading), 0, -cos(heading))
	var right := Vector3(cos(heading), 0, sin(heading))
	for fraction in [0.4, 0.7, 1.0]:
		var point: Vector3 = game.boat.position + direction * distance * fraction
		if point.distance_to(game.arena_center()) > game.arena_radius - 5.0:
			return false
		if not game.archipelago.water_clear(point, 3.0):
			return false
	for margin in [Vector3.ZERO, right * 2.5, -right * 2.5]:
		var start: Vector3 = game.boat.position + margin + direction * 3.0 + Vector3.UP
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * distance, 5)
		if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func safe_heading(game, preferred: float, avoiding: bool = false) -> float:
	var chosen: float = game.heading + 1.5
	var best := INF
	for step_index in range(-8, 9):
		var candidate: float = game.heading + step_index * PI / 8.0
		var score := absf(step_index * PI / 8.0) * (1.0 if avoiding else 0.25) + absf(wrapf(candidate - preferred, -PI, PI)) * (0.3 if avoiding else 1.0)
		if score < best and lane_clear(game, candidate, 32.0):
			best = score
			chosen = candidate
	return chosen

func update(game, delta: float) -> void:
	var living: Array = game.enemy_encounters.living_ships()
	var radial: Vector3 = game.boat.position - game.arena_center()
	var waypoint: Vector3 = game.arena_center() + Vector3(36, 0, -135)
	orbit = orbit or game.boat.position.distance_to(waypoint) < 16.0
	var to_waypoint: Vector3 = waypoint - game.boat.position
	var preferred := atan2(to_waypoint.x, -to_waypoint.z)
	if orbit:
		preferred = atan2(radial.x, -radial.z) + PI / 2.0 + clampf((radial.length() - 140.0) * 0.035, -0.6, 0.6)
	avoid_left = maxf(0.0, avoid_left - delta)
	if avoid_left <= 0.0 and not lane_clear(game, game.heading, 24.0):
		avoid_heading = safe_heading(game, preferred, true)
		avoid_left = 1.0
	if avoid_left > 0.0:
		var error := wrapf(avoid_heading - game.heading, -PI, PI)
		if game.cannon.aiming:
			helm_exits += 1
		helm(error * 3.0)
		return
	target = null
	var closest := INF
	var right: Vector3 = game.cannon.starboard_direction()
	for candidate in living:
		var relative: Vector3 = candidate.position - game.boat.position
		if relative.length() < closest and relative.length() < 82.0 and relative.normalized().dot(right) > cos(deg_to_rad(38.0)):
			target = candidate
			closest = relative.length()
	var error := wrapf(preferred - game.heading, -PI, PI)
	if game.arena_mode:
		helm(error * 3.0)
		if not game.cannon.choose_cone_target().is_empty() and game.cannon.cooldown <= 0.000001:
			action("fire_starboard", true)
			action("fire_starboard", false)
		return
	if target != null and absf(error) < deg_to_rad(8.0 if game.cannon.aiming else 3.0):
		action("steer_port", false)
		action("steer_starboard", false)
		action("watch_starboard", true)
		if game.cannon.aiming and game.cannon.cooldown <= 0.0:
			var offset: Vector3 = target.collision_shape.global_position - game.cannon.shot_origin()
			var flight: float = offset.length() / game.cannon.SHOT_SPEED
			offset += target.velocity * flight
			var ray := PhysicsRayQueryParameters3D.create(game.cannon.shot_origin(), game.cannon.shot_origin() + offset, 1)
			var travel: Vector3 = (game.cannon.aimed_direction() * game.cannon.SHOT_SPEED + Vector3.UP * 0.35) * flight - Vector3.UP * 0.45 * flight * flight
			if (travel - offset).length() < target.collision_shape.shape.radius - 0.45 and game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				action("fire_starboard", true)
				action("fire_starboard", false)
	else:
		if game.cannon.aiming:
			helm_exits += 1
		helm(error * 3.0)

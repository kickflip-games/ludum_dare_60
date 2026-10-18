extends RefCounted
## Test-only timing pilot. Never loaded by gameplay; no aim correction is applied.
var evade_left: float = 0.0
var evaded: bool = false
var entries: int = 0
var steering_exits: int = 0


func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap() -> void:
	action("fire_starboard", true)
	action("fire_starboard", false)


func update(game, delta: float) -> void:
	var c = game.cannon
	var ship = game.enemy_encounters.ship
	var offset: Vector3 = ship.to_global(Vector3(0, 1, -1.8)) - c.shot_origin()
	var flight: float = offset.length() / c.SHOT_SPEED
	offset += ship.velocity * flight
	var flat := Vector3(offset.x, 0, offset.z).normalized()
	var right: Vector3 = c.starboard_direction()
	var desired: float = rad_to_deg(atan2(right.cross(flat).y, right.dot(flat)))
	# One deliberate warned dodge per trial tests the cost of leaving gun view.
	if not evaded and c.aiming and ship.mode == ship.Mode.TELEGRAPH and ship.timer > 0.8:
		evade_left = 0.6
		evaded = true
		steering_exits += 1
	if evade_left > 0:
		evade_left -= delta
		action("watch_starboard", false)
		action("steer_port", true)
		action("steer_starboard", false)
	elif c.aiming:
		action("steer_port", false)
		action("steer_starboard", false)
		if absf(desired) > 40:
			action("watch_starboard", false)
			action("steer_port", desired > 0)
			action("steer_starboard", desired < 0)
			steering_exits += 1
		else:
			var travel: Vector3 = (c.aimed_direction() * c.SHOT_SPEED + Vector3.UP * 0.35) * flight - Vector3.UP * 0.45 * flight * flight
			if (travel - offset).length() < 2.6 and c.cooldown == 0:
				tap()
	elif absf(desired) < 26:
		action("steer_port", false)
		action("steer_starboard", false)
		action("watch_starboard", true)
		entries += 1
	else:
		action("steer_port", desired > 0)
		action("steer_starboard", desired < 0)


func release() -> void:
	for name in ["watch_starboard", "fire_starboard", "steer_port", "steer_starboard", "astrolabe"]:
		action(name, false)

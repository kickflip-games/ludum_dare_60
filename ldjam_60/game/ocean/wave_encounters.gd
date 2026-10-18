extends RefCounted
## Seeded open-water events, finite regional sets, and a guaranteed quiet recovery.
enum Phase { CALM, WARNING, ACTIVE, DRAINING, RECOVERY }
const PATTERNS := [[-1, 1, 0, -2, 2, -1, 1, 0, -2, 2], [1, -1, 0, 2, -2, 1, -1, 0, 2, -2]]
# Alternate sizes immediately, then build to larger late-set crests.
const CREST_HEIGHTS := [0.65, 1.1, 0.8, 1.5, 0.95, 1.65, 1.15, 1.8, 1.35, 1.85]
# Each named area has its own ID; visiting one never consumes another area's set.
# Vector4 = world X, world Z, trigger radius, unique zone ID. No discovery-stage gate.
const REGIONS := [
	Vector4(-130, 58, 45, 0), Vector4(-195, -65, 45, 1),
	Vector4(-165, -175, 40, 2), Vector4(-25, -205, 60, 3),
	Vector4(140, -155, 50, 4), Vector4(75, 110, 38, 5),
	Vector4(140, 70, 45, 6), Vector4(350, -70, 55, 7),
	Vector4(356, 85, 50, 8), Vector4(135, -40, 45, 9),
	Vector4(-300, -260, 65, 10), Vector4(-340, 45, 65, 11),
	Vector4(-20, 270, 65, 12), Vector4(60, -330, 70, 13)]
const REGION_NAMES := ["Western approach", "Western channel", "Wreck exit", "Northern passage",
	"Twin Peaks approach", "Southern passage", "Southeastern passage", "Eastern channel",
	"Eastern reach", "Inner channel", "Northwest open sea", "Western open sea",
	"Southern open sea", "Northern open sea"]
var phase: Phase = Phase.CALM
var completed: Array[int] = []
var region_id := -1
var launched := 0
var budget := 10
var total_launched := 0
var history: Array[Dictionary] = []
var next_event := 30.0
var phase_until := 0.0
var sequence_deadline := 0.0
var route_forward := Vector2(0, -1)
var pattern_index := 0
var warning_direction := Vector2.ZERO
var warning_until := 0.0
var rng := RandomNumberGenerator.new()
var enabled := true

func reset(seed_value: int) -> void:
	rng.seed = seed_value
	phase = Phase.CALM
	completed.clear()
	region_id = -1
	launched = 0
	total_launched = 0
	history.clear()
	next_event = rng.randf_range(25.0, 45.0)
	phase_until = 0.0
	sequence_deadline = 0.0
	warning_until = 0.0

func busy() -> bool:
	return phase in [Phase.WARNING, Phase.ACTIVE, Phase.DRAINING]

func stop(field: RefCounted) -> void:
	field.clear()
	phase = Phase.CALM
	warning_until = 0.0

func warning(time: float, heading: float = 0.0) -> String:
	if phase == Phase.WARNING:
		return "Wave set approaching · hold your course"
	if time < warning_until:
		var right := Vector2(cos(heading), sin(heading))
		var forward := Vector2(sin(heading), -cos(heading))
		var side := warning_direction.dot(right)
		if absf(side) < 0.3:
			return "Wave from ahead" if warning_direction.dot(forward) < 0 else "Wave from astern"
		return "Wave from port" if side > 0 else "Wave from starboard"
	if phase in [Phase.ACTIVE, Phase.DRAINING]:
		return "Wave set · %d / %d" % [launched, budget]
	if phase == Phase.RECOVERY:
		return "Calm water · recover your bearing"
	return ""

func begin_region(id: int, forward: Vector2, time: float) -> void:
	region_id = id
	completed.append(id)
	launched = 0
	route_forward = forward.normalized()
	pattern_index = rng.randi_range(0, PATTERNS.size() - 1)
	phase = Phase.WARNING
	phase_until = time + 3.0
	sequence_deadline = time + 100.0

func update(game: Node3D, _delta: float) -> void:
	var time: float = game.sea_time
	var field = game.ocean.wave_field
	field.advance(time)
	if not enabled:
		return
	var combat: bool = game.enemy_encounters.battle_active()
	var p := Vector2(game.boat.position.x, game.boat.position.z)
	var departure: Vector3 = game.archipelago.get_node("SpawnPoints/Departure").position
	var harbour: Vector3 = game.archipelago.get_node("NavigationRegions/Lighthouse").position
	var quiet_water: bool = game.boat.position.distance_to(game.arena_center()) < 95.0 if game.arena_mode else game.boat.position.distance_to(departure) < 75.0 or game.boat.position.distance_to(harbour) < 90.0
	if phase == Phase.RECOVERY:
		if time >= phase_until:
			phase = Phase.CALM
			next_event = time + rng.randf_range(25.0, 45.0)
		return
	if phase == Phase.DRAINING:
		if field.waves.is_empty():
			history.append({"region": region_id, "crests": launched, "time": time})
			phase = Phase.RECOVERY
			phase_until = time + 20.0
		return
	if phase == Phase.WARNING:
		if time >= phase_until:
			phase = Phase.ACTIVE
			next_event = time
		return
	if phase == Phase.ACTIVE:
		# A sheltered route cannot trap the player in an endless unfinished set.
		if launched >= budget or time >= sequence_deadline:
			phase = Phase.DRAINING
			return
		if time >= next_event and field.waves.size() < field.MAX_WAVES and not combat and not game.cannon.aiming:
			var kind: int = PATTERNS[pattern_index][launched % 10]
			var height: float = CREST_HEIGHTS[launched % CREST_HEIGHTS.size()]
			if spawn(game, kind, height, route_forward):
				launched += 1
				next_event = time + rng.randf_range(1.7, 2.1)
			else:
				next_event = time + 1.5
		return
	if not quiet_water and not combat and not game.cannon.aiming and field.waves.is_empty():
		for region: Vector4 in ([] if game.arena_mode else REGIONS):
			var id := int(region.w)
			if id not in completed and p.distance_to(Vector2(region.x, region.y)) < region.z:
				var forward: Vector3 = game.course_forward()
				begin_region(id, Vector2(forward.x, forward.z), time)
				game.cue_sound("warning")
				return
	if time >= next_event:
		next_event = time + rng.randf_range(25.0, 45.0)
		if not quiet_water and not combat and not game.cannon.aiming and field.waves.is_empty():
			var forward := Vector2(sin(game.heading), -cos(game.heading))
			spawn(game, [-2, -1, 0, 1, 2][rng.randi_range(0, 4)], rng.randf_range(0.32, 0.6), forward, rng.randf_range(-12.0, 12.0))

func spawn(game: Node3D, kind: int, height: float, forward: Vector2, lateral_offset: float = 0.0) -> bool:
	var right := Vector2(-forward.y, forward.x)
	var direction := -forward
	if kind != 0:
		direction = right * (-signf(kind))
		if abs(kind) == 2:
			direction = (direction - forward * 0.65).normalized()
	var side := Vector2(-direction.y, direction.x)
	var center3: Vector3 = game.boat.to_global(Vector3(0, 0, -2.1))
	var center := Vector2(center3.x, center3.z)
	var velocity := Vector2(game.boat.velocity.x, game.boat.velocity.z)
	var lead := 3.0
	var speed := 8.0
	var width := 4.0 + height * 0.8
	var origin := center + velocity * lead - direction * speed * lead + side * lateral_offset
	var terrain = game.archipelago.get_node("Terrain")
	# Test the whole moving strip, including its trailing trough, before launch.
	for span: float in [26.0, 18.0, 12.0]:
		var lifetime := 7.0
		var safe := true
		for along in range(-3, 17):
			var distance := along * 4.0
			var strip_safe := true
			for across in range(-5, 6):
				var point: Vector2 = origin + direction * distance + side * (span * across / 5.0)
				if terrain.terrain_height_at(Vector3(point.x, 0, point.y)) > -3.0:
					strip_safe = false
					break
			if not strip_safe:
				lifetime = minf(lifetime, (distance - width) / speed)
				if lifetime < lead + 2.5:
					safe = false
				break
		if not safe:
			continue
		var id: int = game.ocean.wave_field.add_wave(origin, direction, height, width, span, speed, game.sea_time, lifetime)
		if id < 0:
			return false
		total_launched += 1
		warning_direction = direction
		warning_until = game.sea_time + lead
		game.cue_sound("warning")
		return true
	return false

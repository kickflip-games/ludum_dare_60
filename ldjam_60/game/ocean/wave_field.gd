extends RefCounted
## Finite world-space ridges. Keep the analytic profile in sync with waves.gdshaderinc.
const MAX_WAVES := 4
const MAX_HEIGHT := 2.0
const FORCE_MULTIPLIER := 1.5
var waves: Array[Dictionary] = []
var next_id := 0

func clear() -> void:
	waves.clear()
	next_id = 0

func add_wave(origin: Vector2, direction: Vector2, height: float, width: float,
		span: float, speed: float, start: float, lifetime: float = 9.0) -> int:
	if waves.size() >= MAX_WAVES or direction.length_squared() < 0.01:
		return -1
	next_id += 1
	waves.append({"id": next_id, "origin": origin, "direction": direction.normalized(),
		"height": clampf(height, 0.0, MAX_HEIGHT), "width": maxf(width, 3.0), "span": maxf(span, 12.0),
		"speed": maxf(speed, 0.1), "start": start, "lifetime": maxf(lifetime, 4.0)})
	return next_id

func advance(time: float) -> void:
	waves = waves.filter(func(w: Dictionary) -> bool: return time < w.start + w.lifetime)

static func envelope(w: Dictionary, time: float) -> float:
	var age: float = time - w.start
	return smoothstep(0.0, 0.8, age) * (1.0 - smoothstep(w.lifetime - 1.5, w.lifetime, age))

static func lobe(s: float, width: float) -> Vector2:
	var q := s / width
	if absf(q) >= 1.0:
		return Vector2.ZERO
	return Vector2(0.5 + 0.5 * cos(PI * q), -0.5 * PI / width * sin(PI * q))

static func sample_one(w: Dictionary, p: Vector2, time: float) -> Vector3:
	var d: Vector2 = w.direction
	var side := Vector2(-d.y, d.x)
	var offset: Vector2 = p - w.origin - d * w.speed * (time - w.start)
	var lateral := offset.dot(side)
	var s := offset.dot(d) + 1.4 * (cos(lateral * 0.055) - 1.0)
	var bend_slope := -0.077 * sin(lateral * 0.055)
	var u := clampf((absf(lateral) / w.span - 0.7) / 0.3, 0.0, 1.0)
	var taper := 1.0 - u * u * (3.0 - 2.0 * u)
	var taper_slope: float = -6.0 * u * (1.0 - u) * signf(lateral) / (w.span * 0.3)
	# Steeper leading face, longer back, shallow trailing trough. Broad plateau along crest.
	var ridge := lobe(s, w.width * (0.65 if s >= 0.0 else 1.35))
	var trough := lobe(s + w.width * 1.5, w.width * 0.9)
	var profile := ridge - trough * 0.16
	var a: float = w.height * envelope(w, time)
	var gradient: Vector2 = a * (d * profile.y * taper + side * (profile.x * taper_slope + profile.y * taper * bend_slope))
	return Vector3(a * profile.x * taper, gradient.x, gradient.y)

func sample(p: Vector2, time: float) -> Vector3:
	var result := Vector3.ZERO
	for w: Dictionary in waves:
		result += sample_one(w, p, time)
	return result

func push_at(p: Vector2, heading: float, time: float) -> Vector2:
	var right := Vector2(cos(heading), sin(heading))
	var result := Vector2.ZERO
	for w: Dictionary in waves:
		var h := maxf(0.0, sample_one(w, p, time).x)
		# Bow-on exposure is lower; steeper, taller ridges exert a larger shove.
		var exposure := lerpf(0.32, 1.0, absf(right.dot(w.direction)))
		result += w.direction * h * exposure * (4.0 / w.width) * 6.5
	# Scale after the original clamp: even capped crests gain exactly 50% force.
	return result.limit_length(8.0) * FORCE_MULTIPLIER

func apply_to(material: ShaderMaterial) -> void:
	var origins := PackedVector4Array()
	var shapes := PackedVector4Array()
	var timings := PackedVector4Array()
	origins.resize(MAX_WAVES)
	shapes.resize(MAX_WAVES)
	timings.resize(MAX_WAVES)
	for i in range(waves.size()):
		var w := waves[i]
		origins[i] = Vector4(w.origin.x, w.origin.y, w.direction.x, w.direction.y)
		shapes[i] = Vector4(w.height, w.width, w.span, w.speed)
		timings[i] = Vector4(w.start, w.lifetime, 0, 0)
	material.set_shader_parameter("event_count", waves.size())
	material.set_shader_parameter("event_origins", origins)
	material.set_shader_parameter("event_shapes", shapes)
	material.set_shader_parameter("event_timings", timings)

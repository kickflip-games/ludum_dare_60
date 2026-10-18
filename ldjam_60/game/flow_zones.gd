extends RefCounted
## Three world-fixed ribbons. Reward IDs persist until the session resets.
const MAX_ZONES := 3
const GAIN := 1.25
var enabled := true
var zones: Array[Dictionary] = []
var collected: Dictionary = {}
var _presented_count := -1
var _presented_active := false
var _material: ShaderMaterial

func configure(markers: Node3D) -> void:
	zones.clear()
	collected.clear()
	_presented_count = -1
	for marker: Marker3D in markers.get_children():
		if zones.size() >= MAX_ZONES:
			break
		zones.append({"id": String(marker.name), "center": Vector2(marker.global_position.x, marker.global_position.z),
			"heading": marker.rotation.y, "length": float(marker.get_meta("length", 48.0)),
			"width": float(marker.get_meta("width", 20.0)), "bend": float(marker.get_meta("bend", 3.0))})

static func distance_to_zone(point: Vector2, zone: Dictionary) -> float:
	# Identical ribbon footprint in sea.gdshader; rounded ends stay inside length.
	var offset: Vector2 = point - zone.center
	var forward := Vector2(sin(zone.heading), -cos(zone.heading))
	var right := Vector2(cos(zone.heading), sin(zone.heading))
	var y := offset.dot(forward)
	var radius: float = zone.width * 0.5
	var half_straight: float = maxf(0.01, (zone.length - zone.width) * 0.5)
	var clamped_y := clampf(y, -half_straight, half_straight)
	var bend: float = zone.bend * (1.0 - pow(clamped_y / half_straight, 2.0))
	return Vector2(offset.dot(right) - bend, y - clamped_y).length() - radius

func collect_at(point: Vector2) -> int:
	if not enabled:
		return 0
	var count := 0
	for zone: Dictionary in zones:
		if not collected.has(zone.id) and distance_to_zone(point, zone) <= 0.0:
			collected[zone.id] = true
			count += 1
	return count

func multiplier() -> float:
	return pow(GAIN, collected.size()) if enabled else 1.0

func reset() -> void:
	collected.clear()

func present(material: ShaderMaterial, active: bool) -> void:
	active = active and enabled
	if _material == material and _presented_count == collected.size() and _presented_active == active:
		return
	_material = material
	_presented_count = collected.size()
	_presented_active = active
	var frames := PackedVector4Array()
	var shapes := PackedVector4Array()
	frames.resize(MAX_ZONES)
	shapes.resize(MAX_ZONES)
	for i in zones.size():
		var z: Dictionary = zones[i]
		frames[i] = Vector4(z.center.x, z.center.y, sin(z.heading), cos(z.heading))
		shapes[i] = Vector4(z.width, z.bend, 1.0 if collected.has(z.id) else 0.0, z.length)
	material.set_shader_parameter("flow_count", zones.size() if enabled and active else 0)
	material.set_shader_parameter("flow_frames", frames)
	material.set_shader_parameter("flow_shapes", shapes)

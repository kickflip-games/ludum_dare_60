extends Control
## Small native-drawn instruments; gameplay remains owned by the crossing.
enum Kind { HULL, COMPASS, CANNON }
const CREAM := Color("f5efdc")
const GOLD := Color("e6bf7c")
const CORAL := Color("ff9e99")
const SHADE := Color("173e48")
var kind: Kind
var game: Node3D
var heading: float = 0.0
var pulse: float = 0.0
var target: Dictionary = {}
var status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -23
	status.add_theme_font_size_override("font_size", 15)
	add_child(status)
	if kind == Kind.COMPASS:
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif kind == Kind.CANNON:
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func update_presentation(delta: float) -> void:
	heading = lerp_angle(heading, game.heading, 1.0 - exp(-14.0 * delta))
	pulse = maxf(0.0, pulse - delta)
	if kind == Kind.HULL:
		status.text = "Hull critical · %d/%d" % [game.hull, game.hull_capacity] if game.hull == 1 else "Hull hit · %d/%d" % [game.hull, game.hull_capacity] if game.hit_message_left > 0 else "Hull"
		status.modulate = CORAL if game.hull == 1 or game.hit_flash > 0.0 else CREAM
		tooltip_text = "Hull: %d of %d" % [game.hull, game.hull_capacity]
	elif kind == Kind.COMPASS:
		status.text = "SPACE · sight star"
		tooltip_text = "Bow heading. The rose turns against fixed north. Hold Space to use the astrolabe."
	else:
		status.text = "Reloading" if game.cannon.cooldown > 0 else "Release F · fire" if game.cannon.aiming else "Hold F · aim"
		status.modulate = GOLD if game.cannon.cooldown == 0 else CREAM
		tooltip_text = "Starboard cannon: %.1f seconds to reload" % game.cannon.cooldown if game.cannon.cooldown > 0 else "Hold F to aim; A/D adjusts the cannon; release F to fire. Hold E to glance right."
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(game):
		return
	match kind:
		Kind.HULL: _draw_hull()
		Kind.COMPASS: _draw_compass()
		Kind.CANNON: _draw_cannon()


func _stroke(points: PackedVector2Array, color: Color, width: float = 2.0) -> void:
	draw_polyline(points, Color(SHADE, color.a * 0.8), width + 3.0, true)
	draw_polyline(points, color, width, true)


func _draw_hull() -> void:
	var low: bool = game.hull == 1
	var bounce: float = sin(pulse * 28.0) * pulse * 5.0
	for i in range(game.hull_capacity):
		var center := Vector2(15.0 + i * 30.0, 24.0 + bounce)
		var color := CORAL if low else CREAM
		if i >= game.hull:
			color = Color(CREAM, 0.22)
		elif pulse > 0.0 or low:
			color = CORAL.lerp(CREAM, 0.25 + sin(game.sea_time * 5.0) * 0.12)
		var outline := PackedVector2Array([center + Vector2(-12, 0), center + Vector2(-6, 8), center + Vector2(7, 8), center + Vector2(13, -1), center + Vector2(-12, 0)])
		if i < game.hull:
			draw_colored_polygon(outline, Color(SHADE, 0.4))
		_stroke(outline, color, 2.0)
		_stroke(PackedVector2Array([center + Vector2(0, -13), center + Vector2(0, -2), center + Vector2(8, -3), center + Vector2(0, -13)]), color, 1.5)
		if i >= game.hull:
			_stroke(PackedVector2Array([center + Vector2(-5, -2), center + Vector2(4, 6)]), color, 1.2)


func _draw_compass() -> void:
	var center := Vector2(size.x * 0.5, 42.0)
	draw_circle(center, 34.0, Color(SHADE, 0.28))
	draw_arc(center, 34.0, 0, TAU, 64, Color(CREAM, 0.68), 1.5, true)
	for tick in range(16):
		var angle: float = tick * TAU / 16.0 - heading
		var direction := Vector2(sin(angle), -cos(angle))
		var major: bool = tick % 4 == 0
		var from: float = 26.0 if major else 29.0
		_stroke(PackedVector2Array([center + direction * from, center + direction * 32.0]), Color(CREAM, 0.7 if major else 0.3), 1.0)
	var font := ThemeDB.fallback_font
	for i in range(4):
		var angle: float = i * PI / 2.0 - heading
		var at := center + Vector2(sin(angle), -cos(angle)) * 20.0
		var text_value: String = ["N", "E", "S", "W"][i]
		var width := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, at + Vector2(-width / 2, 4), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD if i == 0 else Color(CREAM, 0.65))
	# Fixed bow mark, rotating rose: no destination or course reference here.
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -40), center + Vector2(-4, -46), center + Vector2(4, -46)]), GOLD)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(-3, 4), center + Vector2(3, 4)]), CREAM)
	if absf(game.voyage.current) > 0.3:
		# A lateral drift hint, measured relative to the bow, never to the light.
		var drift: Vector3 = game.course_right() * game.voyage.current
		var local_right: float = drift.dot(game.cannon.starboard_direction())
		var direction: float = signf(local_right)
		var at := center + Vector2(0, 45)
		_stroke(PackedVector2Array([at - Vector2(9 * direction, 0), at + Vector2(9 * direction, 0), at + Vector2(5 * direction, -3)]), Color(CREAM, 0.38), 1)


func _draw_cannon() -> void:
	var center := Vector2(size.x - 28, 29)
	var progress: float = 1.0 - game.cannon.cooldown / game.cannon.RELOAD_SECONDS
	var color := GOLD if progress >= 1.0 else CREAM
	draw_circle(center, 24, Color(SHADE, 0.32))
	draw_arc(center, 24, 0, TAU, 48, Color(CREAM, 0.2), 2, true)
	if progress > 0.0:
		draw_arc(center, 24, -PI / 2, -PI / 2 + TAU * progress, 48, color, 2, true)
	if pulse > 0:
		draw_arc(center, 24 + (0.5 - pulse) * 16, 0, TAU, 48, Color(GOLD, pulse), 2, true)
	var barrel := PackedVector2Array([center + Vector2(-10, -3), center + Vector2(10, -12), center + Vector2(14, -4), center + Vector2(-6, 4), center + Vector2(-10, -3)])
	_stroke(barrel, color, 2)
	draw_circle(center + Vector2(-6, 9), 4, color)
	draw_circle(center + Vector2(8, 9), 3, color)
	_stroke(PackedVector2Array([center + Vector2(-12, 4), center + Vector2(11, 4)]), color, 2)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 28), "STARBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, SHADE)
	draw_string(font, Vector2(0, 28), "STARBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.8))

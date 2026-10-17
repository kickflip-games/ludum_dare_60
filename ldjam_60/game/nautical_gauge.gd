extends Control
## Small native-drawn instruments; gameplay remains owned by the crossing.
enum Kind { HULL, CANNON }
const CREAM := Color("f5efdc")
const GOLD := Color("e6bf7c")
const CORAL := Color("ff9e99")
const SHADE := Color("173e48")
var kind: Kind
var game: Node3D
var pulse: float = 0.0
var status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -23
	status.add_theme_font_size_override("font_size", 15)
	add_child(status)
	if kind == Kind.CANNON:
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func update_presentation(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta)
	if kind == Kind.HULL:
		if game.hit_message_left > 0.0:
			status.text = "Hull critical" if game.hull == 1 else "Hull hit"
		elif game.hull_repair_notice_left > 0.0:
			status.text = "Hull repaired"
		elif game.is_repairing_hull():
			status.text = "Repairing · %ds" % ceili(game.hull_repair_seconds - game.hull_repair_elapsed - 0.00001)
		else:
			status.text = "Hull critical" if game.hull == 1 else ""
		status.modulate = CORAL if game.hit_flash > 0.0 else GOLD if game.hull_repair_notice_left > 0.0 or game.is_repairing_hull() else CORAL if game.hull == 1 else CREAM
		tooltip_text = "Hull: %d of %d" % [game.hull, game.hull_capacity]
	else:
		status.text = "Reloading" if game.cannon.cooldown > 0 else "F · Shoot" if game.cannon.aiming else "Ready"
		status.modulate = GOLD if game.cannon.cooldown == 0 else CREAM
		tooltip_text = "Starboard cannon: %.1f seconds to reload" % game.cannon.cooldown if game.cannon.cooldown > 0 else "F enters gun view; press F again to shoot. A/D returns to steering. Hold Space to sight the stars."
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(game):
		return
	match kind:
		Kind.HULL: _draw_hull()
		Kind.CANNON: _draw_cannon()


func _stroke(points: PackedVector2Array, color: Color, width: float = 2.0) -> void:
	draw_polyline(points, Color(SHADE, color.a * 0.8), width + 3.0, true)
	draw_polyline(points, color, width, true)


func _draw_hull() -> void:
	var low: bool = game.hull == 1
	for i in range(game.hull_capacity):
		var center := Vector2(15.0 + i * 30.0, 18.0)
		var color := CORAL if low else CREAM
		if i >= game.hull:
			color = Color(CREAM, 0.48)
		elif pulse > 0.0 and game.hull_repair_notice_left > 0.0:
			color = GOLD
		elif pulse > 0.0 or low:
			color = CORAL.lerp(CREAM, 0.25 + sin(game.sea_time * 5.0) * 0.12)
		var outline := PackedVector2Array([center + Vector2(-12, 0), center + Vector2(-6, 8), center + Vector2(7, 8), center + Vector2(13, -1), center + Vector2(-12, 0)])
		if i < game.hull:
			draw_colored_polygon(outline, Color(SHADE, 0.4))
		_stroke(outline, color, 2.0)
		if i < game.hull:
			_stroke(PackedVector2Array([center + Vector2(0, -13), center + Vector2(0, -2), center + Vector2(8, -3), center + Vector2(0, -13)]), color, 1.5)
		if i >= game.hull:
			_stroke(PackedVector2Array([center + Vector2(-5, -2), center + Vector2(4, 6)]), color, 1.2)
	if game.is_repairing_hull():
		var bar := Rect2(3, 32, game.hull_capacity * 30.0 - 5.0, 2)
		draw_rect(bar, Color(CREAM, 0.48))
		bar.size.x *= clampf(game.hull_repair_elapsed / game.hull_repair_seconds, 0.0, 1.0)
		draw_rect(bar, GOLD)


func _draw_cannon() -> void:
	var center := Vector2(size.x - 20, 18)
	var progress: float = 1.0 - game.cannon.cooldown / game.cannon.RELOAD_SECONDS
	var color := GOLD if progress >= 1.0 else CREAM
	draw_circle(center, 17, Color(SHADE, 0.32))
	draw_arc(center, 17, 0, TAU, 48, Color(CREAM, 0.2), 2, true)
	if progress > 0.0:
		draw_arc(center, 17, -PI / 2, -PI / 2 + TAU * progress, 48, color, 2, true)
	if pulse > 0:
		draw_arc(center, 17 + (0.5 - pulse) * 16, 0, TAU, 48, Color(GOLD, pulse), 2, true)
	var barrel := PackedVector2Array([center + Vector2(-10, -3), center + Vector2(10, -12), center + Vector2(14, -4), center + Vector2(-6, 4), center + Vector2(-10, -3)])
	_stroke(barrel, color, 2)
	draw_circle(center + Vector2(-6, 9), 4, color)
	draw_circle(center + Vector2(8, 9), 3, color)
	_stroke(PackedVector2Array([center + Vector2(-12, 4), center + Vector2(11, 4)]), color, 2)

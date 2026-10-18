extends Control
## Native-drawn cannon status; gameplay remains owned by the crossing.
const CREAM := Color("f5efdc")
const GOLD := Color("e6bf7c")
const SHADE := Color("173e48")
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
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func update_presentation(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta)
	status.text = "Reloading" if game.cannon.cooldown > 0 else "F · Shoot" if game.cannon.aiming else "Ready"
	status.modulate = GOLD if game.cannon.cooldown == 0 else CREAM
	tooltip_text = "Starboard cannon: %.1f seconds to reload" % game.cannon.cooldown if game.cannon.cooldown > 0 else "F enters gun view; press F again to shoot. A/D returns to steering. Hold Space to sight the stars."
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(game):
		return
	_draw_cannon()


func _stroke(points: PackedVector2Array, color: Color, width: float = 2.0) -> void:
	draw_polyline(points, Color(SHADE, color.a * 0.8), width + 3.0, true)
	draw_polyline(points, color, width, true)


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

extends Control
## Camera-space slipstream: long, bold streaks rushing past the edges.
const STREAMS := 16
var strength := 0.0
var active_streams := 0
var wind_time := 0.0
var aiming_blend := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset()

func reset() -> void:
	strength = 0.0
	active_streams = 0
	visible = false
	queue_redraw()

func update_wind(held: bool, time: float, delta: float, _camera: Camera3D, reduced: bool, aiming: bool) -> void:
	strength = move_toward(strength, 1.0 if held else 0.0, maxf(delta, 0.0) * 7.0)
	visible = strength > 0.001
	active_streams = (4 if reduced else STREAMS) if visible else 0
	wind_time = time * (0.7 if reduced else 1.6)
	aiming_blend = 0.55 if aiming else 1.0
	queue_redraw()

func stream_points(stream: int) -> PackedVector2Array:
	var phase := fposmod(wind_time + float(stream) * 0.381, 1.0)
	var side := -1.0 if stream % 2 == 0 else 1.0
	# Offset each side's lanes so the effect never forms a symmetrical frame.
	var lane := fposmod(float(stream / 2) * 0.137 + (0.07 if side > 0 else 0.0), 1.0)
	var origin := size * Vector2(0.5, 0.43)
	var ray := Vector2(side * size.x * 0.5, (lane - 0.43) * size.y * 1.35)
	var travel := 0.56 + phase * 0.56
	var tail := origin + ray * travel
	var tip := origin + ray * (travel + 0.34 + float(stream % 3) * 0.06)
	var shoulder := tail.lerp(tip, 0.72)
	var across := ray.normalized().orthogonal() * clampf(size.y / 80.0, 6.0, 12.0)
	return PackedVector2Array([tail, shoulder + across, tip, shoulder - across])

func _draw() -> void:
	for stream in active_streams:
		var phase := fposmod(wind_time + float(stream) * 0.381, 1.0)
		var opacity := sin(phase * PI) * strength * aiming_blend
		var clear := Color(0.80, 0.91, 1.0, 0.0)
		var ink := Color(0.80, 0.91, 1.0, opacity)
		draw_polygon(stream_points(stream), PackedColorArray([clear, ink, clear, ink]))

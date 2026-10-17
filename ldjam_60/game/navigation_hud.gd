extends Control
## A deliberately abstract astrolabe: readings are available only while raised.

var game: Node3D
var ink := Color("e5e3cf")
var muted := Color("9aafb0")
var brass := Color("e2b873")
var dark := Color("09151b")
var serif: SystemFont
var sans: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	sans = ThemeDB.fallback_font


func _text(at: Vector2, value: String, size_value: int = 20, color: Color = ink, elegant: bool = false) -> void:
	draw_string(serif if elegant else sans, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_value, color)


func _center(at: Vector2, value: String, size_value: int = 20, color: Color = ink, elegant: bool = false) -> void:
	var font: Font = serif if elegant else sans
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_value).x
	_text(at - Vector2(width * 0.5, 0.0), value, size_value, color, elegant)


func _line(a: Vector2, b: Vector2, color: Color = muted, width: float = 1.0) -> void:
	draw_line(a, b, color, width, true)


func _draw() -> void:
	if not is_instance_valid(game) or serif == null:
		return
	var factor := get_viewport_rect().size / Vector2(1280.0, 720.0)
	draw_set_transform(Vector2.ZERO, 0.0, factor)
	if game.state == game.State.READY:
		_draw_intro()
		return
	if game.state == game.State.LOST or game.state == game.State.ARRIVED:
		_draw_end()
		return
	_draw_sailing()
	if game.read_blend > 0.05:
		_draw_instrument()


func _draw_intro() -> void:
	draw_rect(Rect2(36, 36, 654, 648), Color(0.025, 0.06, 0.08, 0.96))
	_line(Vector2(64, 68), Vector2(660, 68), brass)
	_text(Vector2(74, 108), "LUDUM DARE 60   /   OLD TECH", 16, brass)
	_text(Vector2(70, 182), "The Last", 62, ink, true)
	_text(Vector2(70, 246), "Bearing", 72, ink, true)
	_text(Vector2(74, 287), "A short crossing. A fixed star. No compass.", 20, muted)
	_line(Vector2(74, 316), Vector2(650, 316), Color("35494d"))
	_text(Vector2(74, 351), "REACH THE LIGHTHOUSE", 15, brass)
	_text(Vector2(74, 383), "Keep the North Star 30° to PORT (your left).", 22)
	_text(Vector2(74, 414), "The light only appears near the far shore.", 20, muted)
	_text(Vector2(74, 463), "A / D  or  ← / →", 21, brass)
	_text(Vector2(340, 463), "Steer the boat", 20)
	_text(Vector2(74, 502), "HOLD SPACE", 21, brass)
	_text(Vector2(340, 502), "Raise the astrolabe", 20)
	_text(Vector2(74, 540), "F  /  FIRE STARBOARD", 20, brass)
	_text(Vector2(340, 540), "Right-side cannon", 19)
	_text(Vector2(74, 568), "Boat never stops. Dodge rocks; shoot pale timber.", 18, muted)
	draw_rect(Rect2(74, 598, 576, 49), Color("c5a168"))
	_center(Vector2(362, 629), "ENTER  /  CAST OFF", 21, dark)
	_text(Vector2(74, 670), "R restart    ·    M mute    ·    Esc quit    /    ~90 seconds", 14, muted)
	_text(Vector2(872, 651), "Trust the star.", 30, brass, true)
	_text(Vector2(872, 681), "Watch the water.", 24, ink, true)


func _draw_sailing() -> void:
	draw_rect(Rect2(0, 0, 1280, 100), Color(0.02, 0.05, 0.07, 0.76))
	_text(Vector2(36, 40), "THE LAST BEARING", 23, ink, true)
	_text(Vector2(37, 68), "A CROSSING BY STARLIGHT", 12, muted)
	_text(Vector2(855, 36), "COURSE: NORTH STAR 30° TO PORT", 18, brass)
	_text(Vector2(855, 64), "Find the lighthouse beyond the wrecks.", 17, muted)
	if game.beacon_seen and game.read_blend < 0.05:
		draw_rect(Rect2(393, 116, 494, 43), Color(0.03, 0.1, 0.12, 0.92))
		_center(Vector2(640, 145), "LIGHTHOUSE SIGHTED  /  MAKE FOR THE LIGHT", 17, brass)
	elif game.elapsed < 9.0 and game.read_blend < 0.05:
		_center(Vector2(640, 145), "Hold SPACE for a bearing. There is clear water ahead.", 20, ink)
	if game.cannon.feedback_time > 0.0 and game.read_blend < 0.05:
		draw_rect(Rect2(340, 177, 600, 38), Color(0.025, 0.06, 0.08, 0.92))
		_center(Vector2(640, 203), game.cannon.feedback, 17, brass)
	draw_rect(Rect2(0, 624, 1280, 96), Color(0.025, 0.06, 0.08, 0.95))
	_line(Vector2(36, 625), Vector2(1244, 625), Color("536967"))
	_text(Vector2(36, 656), "HOLD SPACE", 18, brass)
	_text(Vector2(36, 684), "Sight the star", 18, ink)
	_line(Vector2(262, 646), Vector2(262, 697), Color("35494d"))
	_text(Vector2(289, 656), "LAST SIGHTING", 12, muted)
	var last_text := "No bearing taken"
	if game.has_reading:
		last_text = _bearing_text(game.last_reading)
	_text(Vector2(289, 684), last_text, 19)
	_text(Vector2(638, 656), "A / D  ·  ← / →", 18, brass)
	_text(Vector2(638, 684), "Port / starboard", 18)
	_text(Vector2(828, 653), "F  →  CANNON", 16, brass)
	var cannon_status := "READY · RIGHT SIDE"
	if game.reading:
		cannon_status = "LOWER INSTRUMENT"
	elif game.cannon.cooldown > 0.0:
		cannon_status = "RELOAD %.1fs" % game.cannon.cooldown
	_text(Vector2(828, 680), cannon_status, 12, muted)
	if not game.reading and game.elapsed < 19.0 and game.elapsed > 9.0:
		draw_rect(Rect2(340, 556, 600, 50), Color(0.025, 0.06, 0.08, 0.94))
		_center(Vector2(640, 587), "F fires RIGHT. Turn broadside to line up floating timber.", 18, brass)
	_text(Vector2(1028, 656), "UNDER WAY", 12, muted)
	_text(Vector2(1028, 684), "%02d:%02d   ·   R restart" % [int(game.elapsed) / 60, int(game.elapsed) % 60], 18)


func _bearing_text(angle: float) -> String:
	var degrees := rad_to_deg(wrapf(angle, -PI, PI))
	if absf(degrees) < 0.5:
		return "Star dead ahead · 000°"
	return "Star %03d° to %s" % [roundi(absf(degrees)), "PORT" if degrees > 0.0 else "STARBOARD"]


func _draw_instrument() -> void:
	var alpha: float = game.read_blend
	# Readout and sea view never coexist; the camera is tilted into the sky.
	draw_rect(Rect2(345, 119, 590, 110), Color(0.025, 0.06, 0.08, 0.94 * alpha))
	_center(Vector2(640, 147), "ASTROLABE  /  FIXED STAR SIGHT", 14, brass)
	_center(Vector2(640, 185), _bearing_text(game.heading).to_upper(), 29, ink)
	_center(Vector2(640, 213), "TARGET 30° TO PORT   ·   " + _course_hint(), 16, brass)
	var center := Vector2(640, 497)
	var radius := 112.0
	draw_circle(center, radius + 8.0, Color(0.07, 0.09, 0.09, alpha))
	draw_circle(center, radius, Color(0.15, 0.17, 0.15, alpha))
	draw_arc(center, radius, 0.0, TAU, 96, brass, 4.0, true)
	draw_arc(center, radius - 14.0, 0.0, TAU, 96, Color("8d7955"), 1.0, true)
	for tick in range(72):
		var angle := tick * TAU / 72.0
		var direction := Vector2(sin(angle), -cos(angle))
		var length_value := 18.0 if tick % 6 == 0 else 8.0
		_line(center + direction * (radius - length_value), center + direction * (radius - 3.0), brass)
	_center(center + Vector2(0, -76), "BOW", 13, muted)
	_center(center + Vector2(0, 83), "STERN", 12, muted)
	_text(center + Vector2(-105, 6), "P", 17, brass, true)
	_text(center + Vector2(91, 6), "S", 17, brass, true)
	var target_direction := Vector2(sin(-game.TARGET_HEADING), -cos(-game.TARGET_HEADING))
	_line(center + target_direction * 35.0, center + target_direction * 108.0, Color("6ca7a5"), 4.0)
	var star_direction := Vector2(sin(-game.heading), -cos(-game.heading))
	_line(center - star_direction * 32.0, center + star_direction * 100.0, brass, 3.0)
	draw_circle(center + star_direction * 100.0, 5.0, ink)
	draw_circle(center, 10.0, brass)
	draw_circle(center, 4.0, dark)
	# Label the actual world-space star if it falls inside the raised view.
	var direction := Vector3(0.0, sin(deg_to_rad(56.0)), -cos(deg_to_rad(56.0)))
	var star_at: Vector3 = game.sky_root.global_position + direction * 700.0
	if not game.camera.is_position_behind(star_at):
		var at: Vector2 = game.camera.unproject_position(star_at) / (get_viewport_rect().size / Vector2(1280, 720))
		if at.x > 40 and at.x < 1240 and at.y > 235 and at.y < 375:
			draw_arc(at, 13.0, 0.0, TAU, 32, Color("dec995"), 1.0, true)
			_text(at + Vector2(23, 5), "NORTH STAR", 12, brass)
	draw_rect(Rect2(345, 577, 590, 39), Color(0.025, 0.06, 0.08, 0.95))
	_center(Vector2(640, 603), "STILL MOVING  /  RELEASE SPACE TO WATCH THE WATER", 16, brass)


func _course_hint() -> String:
	var error: float = wrapf(game.heading - game.TARGET_HEADING, -PI, PI)
	if absf(error) < deg_to_rad(3.0):
		return "ON COURSE"
	return "STEER PORT" if error > 0.0 else "STEER STARBOARD"


func _draw_end() -> void:
	var won: bool = game.state == game.State.ARRIVED
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.05, 0.07, 0.7))
	draw_rect(Rect2(295, 198, 690, 320), Color(0.025, 0.06, 0.08, 0.98))
	_line(Vector2(329, 227), Vector2(951, 227), brass)
	_center(Vector2(640, 270), "THE CROSSING IS OVER", 15, brass)
	_center(Vector2(640, 335), "Safe harbour." if won else "Lost to the shoals.", 48, ink, true)
	var detail: String = "You reached the light in %d seconds." % int(game.elapsed) if won else game.failure_reason
	_center(Vector2(640, 380), detail, 21, muted)
	_center(Vector2(640, 416), "Old tech brought you home." if won else "Take a short sighting, then watch the bow.", 20, ink)
	draw_rect(Rect2(440, 450, 400, 45), Color("c5a168"))
	_center(Vector2(640, 480), "R  /  SAIL AGAIN", 20, dark)

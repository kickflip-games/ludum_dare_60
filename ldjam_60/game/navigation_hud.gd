extends Control
## Presentation only. Reads the crossing's authoritative state; never steers it.
const Gauge = preload("res://game/nautical_gauge.gd")
const INK := Color("f5efdc")
const MUTED := Color("d1ded7")
const BRASS := Color("e6bf7c")
const CORAL := Color("ff9e99")
const DARK := Color("173e48")
var game: Node3D
var serif: SystemFont
var sans: Font
var action_button: Button
var menu: MarginContainer
var menu_shade: TextureRect
var menu_title: Label
var menu_kicker: Label
var menu_body: Label
var menu_reference: Label
var menu_controls: GridContainer
var menu_details: Label
var menu_footer: Label
var hull_gauge: Control
var compass: Control
var cannon_gauge: Control
var gameplay_hud: Control
var threat_label: Label
var notice: Label
var instrument: Control
var _last_state: int = -1
var _last_hull: int = -1
var _last_cooldown: float = 0.0
var _combat_blend: float = 0.0
var _reading_alpha: float = 0.0
var _threat_direction: float = 1.0
var _has_threat: bool = false
var _menu_alpha: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	sans = ThemeDB.fallback_font
	theme = Theme.new()
	theme.default_font = sans
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_shadow_color", "Label", Color(DARK, 0.8))
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_outline_color", "Label", Color(DARK, 0.75))
	theme.set_constant("outline_size", "Label", 2)
	_build_menu()
	gameplay_hud = Control.new()
	gameplay_hud.name = "SailingHUD"
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay_hud)
	gameplay_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hull_gauge = _gauge("Hull", Gauge.Kind.HULL, Control.PRESET_BOTTOM_LEFT, Rect2(32, -102, 200, 72))
	compass = _gauge("HeadingCompass", Gauge.Kind.COMPASS, Control.PRESET_CENTER_BOTTOM, Rect2(-85, -142, 170, 122))
	cannon_gauge = _gauge("StarboardCannon", Gauge.Kind.CANNON, Control.PRESET_BOTTOM_RIGHT, Rect2(-206, -108, 174, 78))
	compass.heading = game.heading
	threat_label = _label(gameplay_hud, "IncomingThreat", "", 16, CORAL)
	notice = _label(gameplay_hud, "ContextNotice", "", 19)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -300
	notice.offset_right = 300
	notice.offset_top = 104
	notice.offset_bottom = 158
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_instrument()
	_sync_button()
	_process(0.0)


func _label(parent: Node, node_name: String, value: String, point_size: int = 17, color: Color = INK, elegant: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	if elegant:
		label.add_theme_font_override("font", serif)
	parent.add_child(label)
	return label


func _build_menu() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(DARK, 0.72), Color(DARK, 0.36), Color(DARK, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 1
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	menu_shade = TextureRect.new()
	menu_shade.name = "MenuTint"
	menu_shade.texture = texture
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(menu_shade)
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu_shade.offset_right = 820
	menu = MarginContainer.new()
	menu.name = "VoyageMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	menu.offset_left = 58
	menu.offset_right = 538
	menu.offset_top = -314
	menu.offset_bottom = 314
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(column)
	menu_kicker = _label(column, "Kicker", "A CROSSING BY STARLIGHT", 13, BRASS)
	menu_title = _label(column, "Title", "LATITUDE\nLINES", 61, INK, true)
	menu_title.add_theme_constant_override("line_spacing", -8)
	menu_title.add_theme_constant_override("outline_size", 0)
	menu_body = _label(column, "Subtitle", "An island sea. A distant harbour.\nFind your way home by starlight.", 18, MUTED)
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_reference = _label(column, "StarReference", "Hold Space until a star glows. Remember its direction, then steer.", 17, BRASS)
	menu_reference.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_controls = GridContainer.new()
	menu_controls.name = "Controls"
	menu_controls.columns = 2
	menu_controls.add_theme_constant_override("h_separation", 24)
	menu_controls.add_theme_constant_override("v_separation", 9)
	menu_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(menu_controls)
	for pair: Array in [["A / D   or   ← / →", "Steer"], ["Hold SPACE", "Find the guiding star"], ["F · press again to fire", "Cannon view / shoot"]]:
		_label(menu_controls, "Key", pair[0], 16, INK)
		_label(menu_controls, "Action", pair[1], 16, MUTED)
	menu_details = _label(column, "VoyageDetails", "", 21, BRASS)
	menu_details.visible = false
	action_button = Button.new()
	action_button.name = "StartOrReplay"
	action_button.custom_minimum_size = Vector2(252, 52)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 19)
	for slot: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		action_button.add_theme_color_override(slot, DARK)
	for kind: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = INK if kind == "hover" else BRASS if kind == "pressed" else Color("ebd6aa")
		style.set_corner_radius_all(14)
		style.content_margin_left = 24
		style.content_margin_right = 24
		if kind == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = INK
			style.set_border_width_all(2)
			style.set_expand_margin_all(4)
		action_button.add_theme_stylebox_override(kind, style)
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)
	menu_footer = _label(column, "Footer", "Automatic sailing · avoid reefs · 3 hits sink\nR retry     M mute     Esc quit", 14, MUTED)


func _gauge(node_name: String, kind: int, preset: int, rect: Rect2) -> Control:
	var gauge := Control.new()
	gauge.set_script(Gauge)
	gauge.kind = kind
	gauge.game = game
	gauge.name = node_name
	gameplay_hud.add_child(gauge)
	gauge.set_anchors_and_offsets_preset(preset)
	gauge.offset_left = rect.position.x
	gauge.offset_top = rect.position.y
	gauge.offset_right = rect.end.x
	gauge.offset_bottom = rect.end.y
	return gauge


func _build_instrument() -> void:
	instrument = Control.new()
	instrument.name = "Astrolabe"
	instrument.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(instrument)
	instrument.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _sync_button() -> void:
	var show_menu: bool = game.state in [game.State.READY, game.State.LOST, game.State.ARRIVED]
	menu.visible = show_menu
	menu_shade.visible = show_menu
	action_button.visible = show_menu
	gameplay_hud.visible = game.state == game.State.SAILING
	if game.state == _last_state:
		return
	_last_state = game.state
	if not show_menu:
		action_button.release_focus()
		if game.state == game.State.CASTING_OFF:
			hull_gauge.pulse = 0.0
			cannon_gauge.pulse = 0.0
			compass.heading = game.heading
			_combat_blend = 0.0
		return
	var intro: bool = game.state == game.State.READY
	var won: bool = game.state == game.State.ARRIVED
	menu_kicker.text = "A CROSSING BY STARLIGHT" if intro else "LATITUDE LINES"
	menu_title.text = "LATITUDE\nLINES" if intro else "Safe harbour." if won else "Lost at sea."
	menu_title.add_theme_font_size_override("font_size", 61 if intro else 51)
	menu_body.text = "An island sea. A distant harbour.\nFind your way home by starlight." if intro else "The light has brought you home." if won else game.failure_reason
	menu_reference.visible = intro
	menu_controls.visible = intro
	menu_details.visible = won
	menu_details.text = "Voyage time   %02d:%02d\nHull remaining   %d / %d" % [int(game.elapsed) / 60, int(game.elapsed) % 60, game.hull, game.hull_capacity]
	action_button.text = "Play   ·   Enter" if intro else "Sail again   ·   R" if won else "Try again   ·   R"
	menu_footer.text = "Automatic sailing · %d hull · avoid reefs\nR retry     M mute     Esc quit" % game.hull_capacity if intro else "Trust the star. Watch the water.\nM mute     Esc quit" if won else "The sea gives you another chance.\nM mute     Esc quit"
	action_button.grab_focus()
	_menu_alpha = 0.0 if not intro else 1.0


func _on_action_pressed() -> void:
	if game.state == game.State.READY:
		game.start_crossing()
	elif game.state in [game.State.ARRIVED, game.State.LOST]:
		game.restart()


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(gameplay_hud):
		return
	_sync_button()
	_menu_alpha = move_toward(_menu_alpha, 1.0, delta * 7.0)
	menu.modulate.a = _menu_alpha
	if game.state != game.State.SAILING:
		_reading_alpha = 0.0
		instrument.visible = false
		_last_hull = game.hull
		_last_cooldown = game.cannon.cooldown
		queue_redraw()
		return
	var combat: bool = game.enemy_encounters.battle_active()
	_combat_blend = move_toward(_combat_blend, 1.0 if combat or game.cannon.aiming or game.cannon.cooldown > 0 or game.look_blend > 0.1 else 0.0, delta * 5.0)
	_reading_alpha = smoothstep(0.0, 1.0, game.read_blend)
	if _last_hull >= 0 and game.hull != _last_hull:
		hull_gauge.pulse = 0.65
	if _last_cooldown > 0.0 and game.cannon.cooldown == 0.0:
		cannon_gauge.pulse = 0.5
	_last_hull = game.hull
	_last_cooldown = game.cannon.cooldown
	# Aim queries are made once per frame and shared by the ring and world marks.
	cannon_gauge.target = game.cannon.aim_target() if _reading_alpha < 0.9 else {}
	var urgent_hull: bool = game.hull == 1 or game.hit_message_left > 0.0 or game.hull_repair_notice_left > 0.0
	hull_gauge.modulate.a = 1.0 if urgent_hull else lerpf(0.64 + _combat_blend * 0.25, 0.0, _reading_alpha)
	cannon_gauge.modulate.a = lerpf(0.5 + _combat_blend * 0.5, 0.0, _reading_alpha)
	compass.modulate.a = (1.0 - _reading_alpha) * (1.0 - smoothstep(0.0, 0.75, game.aim_camera_blend))
	for gauge: Control in [hull_gauge, compass, cannon_gauge]:
		gauge.update_presentation(delta)
	instrument.modulate.a = _reading_alpha
	instrument.visible = _reading_alpha > 0.01
	_update_threat()
	_update_notice()
	queue_redraw()


func _star_screen_position() -> Vector2:
	# A direction at infinity: camera translation/shake cannot introduce parallax.
	return game.camera.unproject_position(game.camera.global_position + game.guiding_star_direction() * 700.0)


func star_guidance() -> Dictionary:
	# Presentation geometry only; every ray comes from the authoritative bearing.
	if not game.reading or game.state != game.State.SAILING or game.focus_strength <= 0.0:
		return {}
	var direction: Vector3 = game.guiding_star_direction()
	var at := _star_screen_position()
	var center := size * 0.5
	var bounds := Rect2(Vector2(22, 22), size - Vector2(44, 44))
	var local: Vector3 = game.camera.global_basis.inverse() * direction
	var visible := local.z < 0.0 and bounds.has_point(at)
	if visible:
		return {"visible": true, "position": at}
	# Perspective flips points behind the camera. Use camera-plane components
	# there, and the actual projected displacement for front-facing vertical exits.
	var outward := at - center if local.z < -0.0001 else Vector2(local.x, -local.y) * size
	var forward: Vector3 = -game.camera.global_basis.z
	var planar_forward := Vector2(forward.x, forward.z).normalized()
	var planar_star := Vector2(direction.x, direction.z).normalized()
	if planar_forward.dot(planar_star) < 0.0:
		# An elevated astern star projects ABOVE a pitched camera. Suggest a
		# reachable rudder turn, not a nonexistent look-up control. Exact astern
		# is a deterministic port tie; either rudder reaches the star.
		var right := Vector2(-planar_forward.y, planar_forward.x)
		var side := planar_star.dot(right)
		outward.x = (-1.0 if side <= 0.001 else 1.0) * size.x
		outward.y = clampf(outward.y, -size.y * 0.18, size.y * 0.18)
	if outward.length_squared() < 0.0001:
		outward = Vector2.LEFT
	var half_extent := bounds.size * 0.5
	var scale_to_edge := 1.0 / maxf(absf(outward.x) / half_extent.x, absf(outward.y) / half_extent.y)
	return {"visible": false, "position": center + outward * scale_to_edge}


func _update_notice() -> void:
	var value := ""
	var alpha: float = 1.0
	if game.discovery_left > 0:
		value = game.discovery_text
		alpha = minf(1.0, game.discovery_left)
	elif game.enemy_encounters.ship.age < 6.0 and game.enemy_encounters.battle_active():
		value = "Pirate cutter · F for cannon, or steer clear"
	notice.text = value
	notice.modulate.a = alpha * (1.0 - _reading_alpha)
	notice.visible = not value.is_empty()


func _update_threat() -> void:
	var ship = game.enemy_encounters.ship
	_has_threat = game.enemy_encounters.enabled and (ship.mode == ship.Mode.TELEGRAPH or not ship.projectiles.is_empty())
	threat_label.visible = _has_threat
	if not _has_threat:
		return
	var from: Vector3 = ship.global_position
	if not ship.projectiles.is_empty():
		from = ship.projectiles[0].position
	var offset: Vector3 = from - game.boat.global_position
	_threat_direction = signf(offset.dot(game.cannon.starboard_direction()))
	var right: bool = _threat_direction >= 0
	threat_label.text = "Incoming · starboard" if right else "Incoming · port"
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	threat_label.position = Vector2(size.x - 300 if right else 76.0, size.y * 0.33 - 13)
	threat_label.size = Vector2(224, 30)


func _text(at: Vector2, value: String, point_size: int = 16, color: Color = INK, centered: bool = false, elegant: bool = false) -> void:
	var font: Font = serif if elegant else sans
	if centered:
		at.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x * 0.5
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, 3, Color(DARK, color.a * 0.8))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, color)


func _line(a: Vector2, b: Vector2, color: Color = INK, width: float = 1.5) -> void:
	draw_line(a, b, Color(DARK, color.a * 0.7), width + 2.5, true)
	draw_line(a, b, color, width, true)


func _draw() -> void:
	if not is_instance_valid(game) or serif == null:
		return
	if game.state in [game.State.READY, game.State.ARRIVED, game.State.LOST]:
		return
	if game.state == game.State.CASTING_OFF:
		_text(Vector2(size.x * 0.5, size.y - 65), "Casting off…", 25, INK, true, true)
		return
	_draw_weather()
	if game.hit_flash > 0.0:
		_draw_damage_edges()
	if _has_threat:
		var at := Vector2(size.x - 48 if _threat_direction >= 0 else 48.0, size.y * 0.33)
		var side: float = 1 if _threat_direction >= 0 else -1
		var color := Color(CORAL, 0.8 + sin(game.sea_time * 14) * 0.2)
		_line(at + Vector2(-6 * side, -12), at + Vector2(6 * side, 0), color, 3)
		_line(at + Vector2(6 * side, 0), at + Vector2(-6 * side, 12), color, 3)
	if _reading_alpha > 0.01:
		_draw_instrument()
	else:
		if game.cannon.indicator_alpha > 0.01:
			_draw_cannon_sight()
		elif _combat_blend > 0.1:
			_draw_target()


func _draw_damage_edges() -> void:
	for i in range(16):
		var alpha: float = game.hit_flash * 0.32 * (1.0 - i / 16.0)
		var color := Color(CORAL, alpha)
		draw_rect(Rect2(i * 2, 0, 2, size.y), color)
		draw_rect(Rect2(size.x - i * 2 - 2, 0, 2, size.y), color)
		draw_rect(Rect2(0, i, size.x, 1), color)
		draw_rect(Rect2(0, size.y - i - 1, size.x, 1), color)


func _draw_weather() -> void:
	if game.storm_blend > 0.6:
		for i in range(16):
			var at := Vector2(fmod(i * 91.0 + game.sea_time * 95.0, size.x + 20), 140 + fmod(i * 133.0 + game.sea_time * 410.0, size.y * 0.6))
			draw_line(at, at + Vector2(-6, 24), Color(0.65, 0.8, 0.81, 0.11), 1, true)


func _draw_cannon_sight() -> void:
	# A direction sight, not a promised impact point or target lock. Ballistics
	# retain their small fixed elevation/gravity; the sight projects the yaw ray.
	var direction: Vector3 = game.cannon.aimed_direction()
	var origin: Vector3 = game.cannon.shot_origin()
	var alpha: float = game.cannon.indicator_alpha * (1.0 - _reading_alpha)
	var point: Vector3 = origin + direction * 32.0
	if game.camera.is_position_behind(point):
		return
	var at: Vector2 = game.camera.unproject_position(point)
	if not Rect2(Vector2(24, 24), size - Vector2(48, 48)).has_point(at):
		return
	var color := Color(BRASS if game.cannon.cooldown == 0.0 else INK, alpha * 0.8)
	for side in [-1, 1]:
		_line(at + Vector2(side * 6, 0), at + Vector2(side * 13, 0), color, 1.2)
		_line(at + Vector2(0, side * 6), at + Vector2(0, side * 10), color, 1.2)
	# A tiny yaw tick makes the limited arc readable without covering the target.
	var center := Vector2(size.x * 0.5, size.y * 0.62)
	_line(center + Vector2(-34, 0), center + Vector2(34, 0), Color(INK, alpha * 0.35), 1)
	for side in [-1, 1]:
		_line(center + Vector2(side * 34, -3), center + Vector2(side * 34, 3), Color(INK, alpha * 0.5), 1)
	var tick: float = -game.cannon.aim_degrees / game.cannon.max_aim_degrees * 34.0
	_line(center + Vector2(tick, -5), center + Vector2(tick, 5), color, 2)
	var hint_alpha: float = alpha * (1.0 - smoothstep(4.0, 7.0, game.cannon.mode_seconds)) if game.cannon.entries <= 2 else 0.0
	if hint_alpha > 0.01:
		_text(center + Vector2(0, -15), "F — Shoot     A/D — Steer", 14, Color(INK, hint_alpha * 0.8), true)


func _draw_target() -> void:
	var target: Dictionary = cannon_gauge.target
	if target.is_empty() or not target.aligned:
		return
	var point: Vector3 = target.body.global_position + Vector3.UP * 5.8
	if game.camera.is_position_behind(point):
		return
	var at: Vector2 = game.camera.unproject_position(point)
	if not Rect2(Vector2(36, 120), size - Vector2(72, 290)).has_point(at):
		return
	var color := Color(BRASS, _combat_blend * (1.0 - _reading_alpha))
	for side in [-1, 1]:
		_line(at + Vector2(side * 17, -8), at + Vector2(side * 24, -8), color)
		_line(at + Vector2(side * 24, -8), at + Vector2(side * 24, 4), color)
	if target.body.get_meta("target_kind", "") == "ship":
		for i in range(target.body.hull_capacity):
			draw_circle(at + Vector2((i - (target.body.hull_capacity - 1) * 0.5) * 9, 0), 2.5, color if i < target.body.hull else Color(color, 0.2))


func _draw_instrument() -> void:
	var alpha: float = _reading_alpha
	var center := Vector2(size.x * 0.5, size.y - 168 + (1.0 - alpha) * 28)
	var radius := 112.0
	var brass := Color(BRASS, alpha * 0.65)
	# An open sextant frame leaves the sky visible. No live needle or course
	# bubble gives away the solution during the searching stage.
	var a := PI * 0.20
	var b := PI * 0.80
	draw_arc(center, radius, a, b, 48, brass, 3, true)
	draw_arc(center, radius - 12, a, b, 48, Color(BRASS, alpha * 0.25), 1, true)
	for tick in range(25):
		var angle := lerpf(a, b, tick / 24.0)
		var direction := Vector2(cos(angle), sin(angle))
		var length_value: float = 12 if tick % 4 == 0 else 5
		draw_line(center + direction * (radius - length_value), center + direction * radius, brass, 1, true)
	for angle: float in [a, b]:
		_line(center, center + Vector2(cos(angle), sin(angle)) * radius, brass, 2.0)
	_line(center + Vector2(-18, -4), center + Vector2(18, -4), brass, 4)
	draw_circle(center, 4, brass)
	# A quiet central sight is present from the start; it never points north.
	var sight := size * Vector2(0.5, 0.44)
	for side in [-1, 1]:
		draw_line(sight + Vector2(side * 7, 0), sight + Vector2(side * 13, 0), Color(INK, alpha * 0.32), 1, true)
		draw_line(sight + Vector2(0, side * 7), sight + Vector2(0, side * 13), Color(INK, alpha * 0.32), 1, true)
	if not game.reading or game.focus_strength <= 0.0:
		return
	var guidance := star_guidance()
	if guidance.is_empty():
		return
	var focus: float = game.focus_strength
	var at: Vector2 = guidance.position
	var tint: Color = game.guiding_star_color()
	var pulse := 0.92 + sin(game.sea_time * (1.7 + game.voyage.stage * 0.3)) * 0.08
	var glint := Color(tint, alpha * focus * game.target_highlight_strength * pulse)
	if not guidance.visible:
		# A little peripheral shimmer, never an arrow, word or sailing marker.
		for layer in range(5, 0, -1):
			draw_circle(at, layer * 2.8, Color(tint, glint.a * 0.035 * (6 - layer)), true, -1, true)
		draw_circle(at, 1.8, glint, true, -1, true)
		draw_line(at + Vector2(-5, 0), at + Vector2(5, 0), Color(tint, glint.a * 0.6), 1, true)
		return
	# Small broken halos distinguish stages by shape as well as colour.
	var segments: int = 2 + mini(game.voyage.stage, 2)
	var halo_radius := 10.0 + sin(game.sea_time * 1.7) * 0.5
	for segment in range(segments):
		var angle: float = segment * TAU / segments + game.sea_time * 0.08
		draw_arc(at, halo_radius, angle, angle + TAU / segments - 0.6, 20, glint, 1.0, true)

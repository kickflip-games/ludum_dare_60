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
var menu_controls: GridContainer
var menu_details: Label
var menu_footer: Label
var motion_choice: OptionButton
var cannon_gauge: Control
var gameplay_hud: Control
var wave_countdown: Label
var wave_announcement: Label
var wave_label: Label
var threat_label: Label
var notice: Label
var instrument: Control
var _last_state: int = -1
var _last_cooldown: float = 0.0
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
	cannon_gauge = _gauge("StarboardCannon", Control.PRESET_BOTTOM_RIGHT, Rect2(-198, -86, 174, 62))
	wave_label = _label(gameplay_hud, "SurvivalWave", "", 16, BRASS)
	for label: Label in [wave_label]:
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_left=-180
		label.offset_right=180
		label.offset_top=20
		label.offset_bottom=44
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	wave_countdown = _label(gameplay_hud,"WaveCountdown","",13,MUTED)
	wave_announcement = _label(gameplay_hud,"WaveAnnouncement","",26,INK,true)
	for entry in [[wave_countdown,48,72],[wave_announcement,88,126]]:
		var label: Label = entry[0]
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_left=-260
		label.offset_right=260
		label.offset_top=entry[1]
		label.offset_bottom=entry[2]
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	threat_label = _label(gameplay_hud, "IncomingThreat", "", 16, CORAL)
	notice = _label(gameplay_hud, "ContextNotice", "", 17)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -300
	notice.offset_right = 300
	notice.offset_top = 142 if game.arena_mode else 40
	notice.offset_bottom = 180 if game.arena_mode else 90
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
	menu.offset_left = 48
	menu.offset_right = 488
	menu.offset_top = -270
	menu.offset_bottom = 270
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(column)
	menu_kicker = _label(column, "Kicker", "A CROSSING BY STARLIGHT", 13, BRASS)
	menu_title = _label(column, "Title", "LATITUDE\nLINES", 58, INK, true)
	menu_title.add_theme_constant_override("line_spacing", -8)
	menu_title.add_theme_constant_override("outline_size", 0)
	menu_body = _label(column, "Subtitle", "Find your way home by starlight.", 18, MUTED)
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_controls = GridContainer.new()
	menu_controls.name = "Controls"
	menu_controls.columns = 2
	menu_controls.add_theme_constant_override("h_separation", 24)
	menu_controls.add_theme_constant_override("v_separation", 9)
	menu_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(menu_controls)
	var controls := [["A / D", "Steer"], ["Hold E", "Aim cannon"], ["F", "Fire"]]
	if not game.arena_mode:
		controls.insert(1, ["Hold Space", "Find the guiding star"])
	for pair: Array in controls:
		_label(menu_controls, "Key", pair[0], 16, INK)
		_label(menu_controls, "Action", pair[1], 16, MUTED)
	menu_details = _label(column, "VoyageDetails", "", 21, BRASS)
	menu_details.visible = false
	action_button = Button.new()
	action_button.name = "StartOrReplay"
	action_button.custom_minimum_size = Vector2(180, 46)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 19)
	for slot: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		action_button.add_theme_color_override(slot, DARK)
	for kind: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = INK if kind == "hover" else BRASS if kind == "pressed" else Color("ebd6aa")
		style.set_corner_radius_all(4)
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
	motion_choice = OptionButton.new()
	motion_choice.name = "MotionSetting"
	motion_choice.add_item("Motion: Full")
	motion_choice.add_item("Motion: Reduced")
	motion_choice.selected = game.motion_setting
	motion_choice.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	motion_choice.tooltip_text = "Reduced softens banking and impacts. Waves and steering stay the same."
	motion_choice.item_selected.connect(func(index: int): game.motion_setting = index)
	column.add_child(motion_choice)


func _gauge(node_name: String, preset: int, rect: Rect2) -> Control:
	var gauge := Control.new()
	gauge.set_script(Gauge)
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
			cannon_gauge.pulse = 0.0
		return
	var intro: bool = game.state == game.State.READY
	var won: bool = game.state == game.State.ARRIVED
	menu_kicker.text = "A CROSSING BY STARLIGHT" if intro else "LATITUDE LINES"
	menu_title.text = "LATITUDE\nLINES" if intro else "Safe harbour." if won else "Lost at sea."
	menu_title.add_theme_font_size_override("font_size", 58 if intro else 48)
	menu_body.text = "Find your way home by starlight." if intro else "The light has brought you home." if won else game.failure_reason
	if intro and game.arena_mode:
		menu_kicker.text = "FIVE WAVES AT SEA"
		menu_body.text = "Survive five waves of hostile cutters.\nSail, turn and fire. The light marks the centre."
	if not intro and game.arena_mode:
		menu_title.text = "THE SEA IS YOURS" if won else "SHIP SUNK"
		menu_title.add_theme_font_size_override("font_size",36)
		menu_body.text = "All five waves defeated. You survived the night." if won else game.failure_reason
	menu_controls.visible = intro
	menu_details.visible = won
	menu_details.text = ("Survived   %02d:%02d" if game.arena_mode else "Voyage time   %02d:%02d") % [int(game.elapsed) / 60, int(game.elapsed) % 60]
	action_button.text = "Play" if intro else "Retry"
	menu_footer.text = "Enter play · Hold R to restart · M mute · Esc quit" if intro else "R retry · M mute · Esc quit"
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
	_update_wave_ui()
	_menu_alpha = move_toward(_menu_alpha, 1.0, delta * 7.0)
	menu.modulate.a = _menu_alpha
	if game.state != game.State.SAILING:
		_reading_alpha = 0.0
		instrument.visible = false
		_last_cooldown = game.cannon.cooldown
		queue_redraw()
		return
	_reading_alpha = smoothstep(0.0, 1.0, game.read_blend) if game.reading else 0.0
	if _last_cooldown > 0.0 and game.cannon.cooldown == 0.0:
		cannon_gauge.pulse = 0.5
	_last_cooldown = game.cannon.cooldown
	cannon_gauge.update_presentation(delta)
	cannon_gauge.visible = not game.reading and (game.cannon.aiming or game.cannon.cooldown > 0.0 or cannon_gauge.pulse > 0.0)
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
	if game.restart_elapsed > 0.0:
		value = "Hold R to restart"
	elif game.discovery_left > 0:
		value = game.discovery_text
		alpha = minf(1.0, game.discovery_left)
	elif not game.arena_mode and game.enemy_encounters.focus_ship().age < 4.0 and game.enemy_encounters.battle_active():
		value = "Cutter nearby · Hold E to aim"
		alpha = clampf(4.0 - game.enemy_encounters.focus_ship().age, 0.0, 1.0)
	notice.text = value
	notice.modulate.a = alpha
	notice.visible = not value.is_empty()


func _update_threat() -> void:
	var ship = game.enemy_encounters.focus_ship(true)
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
	threat_label.position = Vector2(size.x - 272 if right else 48.0, size.y * 0.33 - 13)
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
		var at := Vector2(size.x - 24 if _threat_direction >= 0 else 24.0, size.y * 0.33)
		var side: float = 1 if _threat_direction >= 0 else -1
		var color := Color(CORAL, 0.8 + sin(game.sea_time * 14) * 0.2)
		_line(at + Vector2(-6 * side, -12), at + Vector2(6 * side, 0), color, 3)
		_line(at + Vector2(6 * side, 0), at + Vector2(-6 * side, 12), color, 3)
	if game.reading and _reading_alpha > 0.01:
		_draw_instrument()
	else:
		if game.cannon.aiming and game.cannon.indicator_alpha > 0.01:
			_draw_cannon_sight()


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
	var alpha: float = game.cannon.indicator_alpha
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
		_text(center + Vector2(0, -15), "F · Fire", 14, Color(INK, hint_alpha * 0.8), true)


func _draw_instrument() -> void:
	var alpha: float = _reading_alpha
	var center := Vector2(size.x * 0.5, size.y - 154)
	var radius := 104.0
	var brass := Color(BRASS, alpha * 0.72)
	# An open sextant frame leaves the sky visible. No live needle or course
	# bubble gives away the solution during the searching stage.
	var a := PI * 0.20
	var b := PI * 0.80
	draw_arc(center, radius, a, b, 48, brass, 1.3, true)
	draw_arc(center, radius - 12, a, b, 48, Color(BRASS, alpha * 0.25), 1, true)
	for tick in range(25):
		var angle := lerpf(a, b, tick / 24.0)
		var direction := Vector2(cos(angle), sin(angle))
		var length_value: float = 9 if tick % 4 == 0 else 4
		draw_line(center + direction * (radius - length_value), center + direction * radius, brass, 1, true)
	for angle: float in [a, b]:
		_line(center, center + Vector2(cos(angle), sin(angle)) * radius, Color(BRASS, alpha * 0.4), 1.0)
	# Central alignment notch belongs to the sextant, never a second crosshair.
	_line(center + Vector2(-10, -2), center + Vector2(-3, -2), brass, 1.2)
	_line(center + Vector2(3, -2), center + Vector2(10, -2), brass, 1.2)
	_line(center + Vector2(0, -7), center + Vector2(0, 3), brass, 1.2)
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
	var guide := star_horizon_line()
	if not guide.is_empty():
		# Fade down the actual projected column; never a world-space waypoint.
		var from: Vector2 = guide.from
		var to: Vector2 = guide.to
		for step in range(32):
			var t := step / 32.0
			var opacity := 0.30 * alpha * focus * (1.0 - smoothstep(0.60, 1.0, t))
			draw_line(from.lerp(to, t), from.lerp(to, (step + 1) / 32.0), Color(INK, opacity), 1.0, true)
	# Small broken halos distinguish stages by shape as well as colour.
	var segments: int = 2 + mini(game.voyage.stage, 2)
	var halo_radius := 10.0 + sin(game.sea_time * 1.7) * 0.5
	for segment in range(segments):
		var angle: float = segment * TAU / segments + game.sea_time * 0.08
		draw_arc(at, halo_radius, angle, angle + TAU / segments - 0.6, 20, glint, 1.0, true)


func star_horizon_line() -> Dictionary:
	var guidance := star_guidance()
	if guidance.is_empty() or not guidance.visible:
		return {}
	var at: Vector2 = guidance.position
	# Intersect this screen column with the world-horizontal plane at infinity.
	# Near-plane rays vary linearly in screen Y, including camera roll and offset.
	var top: Vector3 = game.camera.project_position(Vector2(at.x, 0), 1.0) - game.camera.global_position
	var bottom: Vector3 = game.camera.project_position(Vector2(at.x, size.y), 1.0) - game.camera.global_position
	var horizon_y := size.y
	if absf(bottom.y - top.y) > 0.00001:
		horizon_y = -top.y / (bottom.y - top.y) * size.y
	var end_y := minf(horizon_y, size.y - 24.0) if horizon_y > at.y else size.y - 24.0
	if end_y <= at.y + 18.0:
		return {}
	return {"from": at + Vector2(0, 13), "to": Vector2(at.x, end_y)}


func _update_wave_ui() -> void:
	var waves = game.enemy_encounters
	var active: bool = game.arena_mode and game.state == game.State.SAILING
	wave_label.visible=active
	wave_countdown.visible=false
	wave_announcement.visible=false
	if not active:
		return
	wave_label.text="WAVE %d / 5" % maxi(1,waves.wave_number)
	if waves.phase == waves.Phase.EARLY_CLEAR:
		wave_countdown.text="WAVE CLEARED · NEXT IN %d" % ceili(waves.next_wave_in)
		wave_countdown.visible=true
	elif waves.wave_number < 5 and waves.next_wave_in>0 and waves.next_wave_in<=15:
		var seconds := ceili(waves.next_wave_in)
		wave_countdown.text="NEXT WAVE IN %02d:%02d" % [seconds/60,seconds%60]
		wave_countdown.visible=true
	if waves.announcement_left>0:
		wave_announcement.text=waves.announcement
		wave_announcement.visible=true
		var elapsed: float = 2.0-waves.announcement_left
		wave_announcement.modulate.a=minf(clampf(elapsed/0.25,0,1),clampf(waves.announcement_left/0.5,0,1))

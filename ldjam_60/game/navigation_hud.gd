extends Control
## Presentation only. Reads the crossing's authoritative state; never steers it.
const Gauge = preload("res://game/nautical_gauge.gd")
const NauticalTheme = preload("res://game/nautical_theme.gd")
const WalkthroughCard = preload("res://game/walkthrough_card.gd")
const FLEET_BANNER_SECONDS := 2.4
const FLEET_COMPLETE_SECONDS := 1.0
const WAVE_RIBBON = preload("res://assets/ui/kenney_adventure/banner_classic_curtain.png")
const STORM_NOTICE_SECONDS := 10.0
const INK := Color("f0e5cc")
const MUTED := Color("a6cac7")
const BRASS := Color("d6ac68")
const CORAL := Color("ff9e99")
const DARK := Color("102838")
var game: Node3D
var serif: Font
var sans: Font
var action_button: Button
var menu: MarginContainer
var menu_shade: TextureRect
var menu_title: Label
var menu_body: Label
var menu_controls: GridContainer
var menu_details: Label
var menu_footer: Label
var menu_column: VBoxContainer
var menu_actions: VBoxContainer
var credits_button: Button
var credits_panel: VBoxContainer
var credits_back: Button
var credits_open := false
var settings_button: Button
var main_menu_button: Button
var settings_panel: VBoxContainer
var settings_back: Button
var menu_spacer: Control
var settings_open := false
var walkthrough_button: Button
var walkthrough_card: Control
var cannon_gauge: Control
var gameplay_hud: Control
var wave_countdown: Label
var wave_announcement: Label
var boss_label: Label
var boss_health: ProgressBar
var fleet_status: CenterContainer
var fleet_circles: FleetCircles
var _fleet_group_total := 0
var _fleet_complete_left := 0.0
var _announced_fleet := 0
var _fleet_banner_left := 0.0
var threat_label: Label
var storm_warning: VBoxContainer
var storm_title: Label
var storm_instruction: Label
var _storm_notice_seen := false
var _storm_notice_left := 0.0
var notice: Label
var instrument: Control
var _last_state: int = -1
var _last_paused := false
var _last_cooldown: float = 0.0
var _reading_alpha: float = 0.0
var _threat_direction: float = 1.0
var _has_threat: bool = false
var _menu_alpha: float = 1.0


class FleetCircles extends Control:
	## One lightweight Control; records, including queued arrivals, own the count.
	var remaining := 0
	var total := 0

	func set_counts(outstanding: int, group_size: int) -> void:
		if remaining == outstanding and total == group_size:
			return
		remaining = outstanding
		total = group_size
		custom_minimum_size = Vector2(maxi(0, total * 20 - 8), 12)
		queue_redraw()

	func _draw() -> void:
		for index in total:
			var at := Vector2(6 + index * 20, 6)
			draw_circle(at + Vector2(0, 1), 7, Color("102838b3"), true, -1, true)
			if index < remaining:
				draw_circle(at, 6, Color("df9389"), true, -1, true)
			else:
				draw_circle(at, 5.5, Color("c6d6cdad"), false, 1, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = NauticalTheme.TITLE.duplicate()
	serif.fallbacks = [ThemeDB.fallback_font]
	sans = NauticalTheme.BODY
	theme = NauticalTheme.make_theme()
	_build_menu()
	resized.connect(_layout_menu)
	menu.minimum_size_changed.connect(_layout_menu.call_deferred)
	_layout_menu.call_deferred()
	gameplay_hud = Control.new()
	gameplay_hud.name = "SailingHUD"
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay_hud)
	gameplay_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cannon_gauge = _gauge("StarboardCannon", Control.PRESET_BOTTOM_RIGHT, Rect2(-198, -86, 174, 62))
	_build_fleet_status()
	boss_label = _label(gameplay_hud, "FlagshipTitle", "THE FLAGSHIP", 12, BRASS)
	boss_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_label.offset_left = -130
	boss_label.offset_right = 130
	boss_label.offset_top = 60
	boss_label.offset_bottom = 78
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health = ProgressBar.new()
	boss_health.name = "FlagshipHealth"
	boss_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health.show_percentage = false
	gameplay_hud.add_child(boss_health)
	boss_health.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_health.offset_left = -120
	boss_health.offset_right = 120
	boss_health.offset_top = 84
	boss_health.offset_bottom = 90
	for style_name in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263a42") if style_name == "background" else Color("c78d70")
		boss_health.add_theme_stylebox_override(style_name, style)
	wave_countdown = _label(gameplay_hud,"WaveCountdown","",13,MUTED)
	wave_announcement = _label(gameplay_hud,"WaveAnnouncement","",24,INK,true)
	for label: Label in [wave_countdown, wave_announcement]:
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_countdown.offset_left = -180
	wave_countdown.offset_right = 180
	wave_announcement.offset_left = -128
	wave_announcement.offset_right = 128
	wave_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ribbon := TextureRect.new()
	ribbon.name = "AdventureRibbon"
	ribbon.texture = WAVE_RIBBON
	ribbon.self_modulate = Color("d4c4ac") # Muted rust cloth and warm cream edging.
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ribbon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.show_behind_parent = true
	wave_announcement.add_child(ribbon)
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	threat_label = _label(gameplay_hud, "IncomingThreat", "", 16, CORAL)
	notice = _label(gameplay_hud, "ContextNotice", "", 17)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -300
	notice.offset_right = 300
	notice.offset_top = 172 if game.arena_mode else 40
	notice.offset_bottom = 208 if game.arena_mode else 90
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm_warning = VBoxContainer.new()
	storm_warning.name = "StormWarning"
	storm_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(storm_warning)
	storm_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	storm_warning.offset_left = -224
	storm_warning.offset_right = 224
	storm_warning.offset_top = 132
	storm_warning.offset_bottom = 210
	storm_title = _label(storm_warning, "StormTitle", "STORMY AHEAD", 28, CORAL)
	storm_instruction = _label(storm_warning, "StormInstruction", "", 17, INK)
	for label: Label in [storm_title, storm_instruction]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_instrument()
	walkthrough_card = WalkthroughCard.new()
	walkthrough_card.game = game
	add_child(walkthrough_card)
	_sync_button()
	_process(0.0)


func _build_fleet_status() -> void:
	fleet_status = CenterContainer.new()
	fleet_status.name = "FleetStatus"
	fleet_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(fleet_status)
	fleet_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	fleet_status.offset_left = 16
	fleet_status.offset_right = -16
	fleet_status.offset_top = 20
	fleet_status.offset_bottom = 32
	fleet_circles = FleetCircles.new()
	fleet_circles.name = "RemainingEnemies"
	fleet_circles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fleet_status.add_child(fleet_circles)


func _sync_fleet_circles(remaining: int, total: int = 0) -> void:
	fleet_circles.set_counts(remaining, maxi(remaining, total))


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


func _menu_button(parent: Node, node_name: String, caption: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size.y = 48 if primary else 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for slot: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(slot, NauticalTheme.NAVY)
		for kind: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(kind, NauticalTheme.button_style(kind, true))
	parent.add_child(button)
	return button


func _build_menu() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color(NauticalTheme.NAVY, 0.65), Color(NauticalTheme.NAVY, 0.28), Color(NauticalTheme.NAVY, 0.0), Color(NauticalTheme.NAVY, 0.4)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = 512
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.DOWN
	menu_shade = TextureRect.new()
	menu_shade.name = "MenuTint"
	menu_shade.texture = texture
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(menu_shade)
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu = MarginContainer.new()
	menu.name = "VoyageMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	menu_column = VBoxContainer.new()
	menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_column.add_theme_constant_override("separation", 12)
	menu_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(menu_column)
	menu_title = _label(menu_column, "Title", "BLACKWATER", 82, NauticalTheme.IVORY, true)
	menu_title.add_theme_constant_override("line_spacing", -12)
	menu_title.add_theme_constant_override("outline_size", 0)
	menu_body = _label(menu_column, "ResultReason", "", 21, NauticalTheme.SEA_GLASS)
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_details = _label(menu_column, "VoyageDetails", "", 18, NauticalTheme.BRASS)
	menu_details.visible = false
	for label: Label in [menu_title, menu_body, menu_details]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_spacer = Control.new()
	menu_spacer.name = "LighthouseBreathingRoom"
	menu_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_column.add_child(menu_spacer)
	menu_actions = VBoxContainer.new()
	menu_actions.name = "MenuActions"
	menu_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_actions.add_theme_constant_override("separation", 10)
	menu_column.add_child(menu_actions)
	action_button = _menu_button(menu_actions, "StartOrReplay", "SET SAIL", true)
	action_button.pressed.connect(_on_action_pressed)
	walkthrough_button = _menu_button(menu_actions, "Walkthrough", "WALKTHROUGH")
	walkthrough_button.tooltip_text = "Practise the controls, then begin a fresh voyage."
	walkthrough_button.pressed.connect(func(): game.start_crossing(true))
	main_menu_button = _menu_button(menu_actions, "MainMenu", "MAIN MENU")
	main_menu_button.pressed.connect(func(): game.restart(true))
	settings_button = _menu_button(menu_actions, "Settings", "SETTINGS")
	settings_button.pressed.connect(func(): _show_settings(true))
	credits_button = _menu_button(menu_actions, "Credits", "CREDITS")
	credits_button.pressed.connect(func(): _show_credits(true))
	# Legacy voyage controls remain available to retained fixtures.
	menu_controls = GridContainer.new()
	menu_controls.columns = 2
	menu_controls.add_theme_constant_override("h_separation", 24)
	menu_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_column.add_child(menu_controls)
	if not game.arena_mode:
		for pair: Array in [["A / D", "Steer"], ["Hold Space", "Find the guiding star"], ["Hold Shift", "Speed +50%"], ["Hold E", "Aim cannon"], ["F", "Fire"]]:
			_label(menu_controls, "Key", pair[0], 16)
			_label(menu_controls, "Action", pair[1], 16, MUTED)
	menu_footer = _label(menu_column, "Footer", "", 16, NauticalTheme.SEA_GLASS)
	menu_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_panel = VBoxContainer.new()
	settings_panel.name = "SettingsAndControls"
	settings_panel.add_theme_constant_override("separation", 15)
	settings_panel.visible = false
	menu_column.add_child(settings_panel)
	_label(settings_panel, "ControlsHeading", "CONTROLS", 15, NauticalTheme.BRASS)
	var help_text := "A / D or arrows   Steer\nShift   Boost while held\nMouse   Look around\nClick / Space   Fire\nE   Switch camera\nHold R   Restart voyage\nM   Mute / unmute\nEsc   Pause / resume"
	if not game.arena_mode:
		help_text = "A / D   Steer\nShift   Boost while held\nHold Space   Find the guiding star\nHold E   Aim cannon\nF   Fire\nHold R   Restart voyage\nM   Mute / unmute\nEsc   Pause / resume"
	_label(settings_panel, "FullControls", help_text, 17, NauticalTheme.IVORY)
	settings_back = _menu_button(settings_panel, "SettingsBack", "BACK")
	settings_back.pressed.connect(func(): _show_settings(false))
	credits_panel = VBoxContainer.new()
	credits_panel.name = "GameCredits"
	credits_panel.visible = false
	credits_panel.add_theme_constant_override("separation", 10)
	menu_column.add_child(credits_panel)
	for entry in [
		["Models", "3D MODELS", "Kenney · Quaternius"],
		["Coding", "CODING", "Mehdi Zahroui\nAvi Vajpeyi"],
		["Discussion", "DISCUSSION", "Kieran Davidson\nRachel Coxhead"],
		["Music", "MUSIC", "YD GDeshko"],
		["Sfx", "SOUND EFFECTS", "jdsherbert"],
	]:
		var heading := _label(credits_panel, entry[0] + "Heading", entry[1], 14, BRASS)
		var names := _label(credits_panel, entry[0] + "Names", entry[2], 21, INK)
		for label: Label in [heading, names]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var additional := _label(credits_panel, "AdditionalModel", "Mine model: Aaron Clifford (CC BY 3.0)", 13, MUTED)
	additional.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	additional.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_back = _menu_button(credits_panel, "CreditsBack", "BACK")
	credits_back.pressed.connect(func(): _show_credits(false))
	_layout_menu()


func _show_settings(open: bool) -> void:
	settings_open = open
	if open: credits_open = false
	_refresh_menu_copy()
	if open:
		settings_back.grab_focus()
	else:
		settings_button.grab_focus()


func _show_credits(open: bool) -> void:
	credits_open = open
	if open: settings_open = false
	_refresh_menu_copy()
	if open:
		credits_back.grab_focus()
	else:
		credits_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		if settings_open:
			_show_settings(false)
		elif credits_open:
			_show_credits(false)
		else:
			game.set_paused(not game.paused)
		get_viewport().set_input_as_handled()


func _layout_menu() -> void:
	if not is_instance_valid(menu) or size.x < 1.0 or size.y < 1.0: return
	var compact := size.y < 640
	var subpage_open := settings_open or credits_open
	var title_screen: bool = game.arena_mode and game.state == game.State.READY and not subpage_open
	var width := minf(560.0, size.x * 0.60) if title_screen else minf(420.0, size.x * 0.43)
	menu_actions.custom_minimum_size.x = minf(420.0, width)
	var left := (size.x - width) * 0.5
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.position = Vector2(left, 20)
	var bottom := size.y * 0.84 if game.arena_mode and not subpage_open else size.y - 20
	menu.size = Vector2(width, maxf(maxf(0, bottom - 20), menu_column.get_combined_minimum_size().y))
	menu_column.add_theme_constant_override("separation", 7 if compact else 10)
	menu_actions.add_theme_constant_override("separation", 7 if compact else 10)
	menu_spacer.visible = game.arena_mode and not subpage_open
	var title_size := (75 if compact else 93) if game.state == game.State.READY else (48 if compact else 62)
	if not game.arena_mode: title_size = 48 if compact else 58
	if subpage_open: title_size = 38 if compact else 48
	var widest := 1.0
	for line: String in menu_title.text.split("\n"):
		widest = maxf(widest, serif.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x)
	title_size = mini(title_size, floori(title_size * width / widest))
	menu_title.add_theme_font_size_override("font_size", title_size)
	menu_title.add_theme_constant_override("line_spacing", -12)
	menu_body.add_theme_font_size_override("font_size", 18 if compact else 21)
	menu_footer.add_theme_font_size_override("font_size", 15 if compact else 16)
	settings_panel.add_theme_constant_override("separation", 8 if compact else 15)
	credits_panel.add_theme_constant_override("separation", 5 if compact else 10)
	menu.queue_sort()
	menu_column.queue_sort()


func _refresh_menu_copy() -> void:
	var subpage_open := settings_open or credits_open
	var intro: bool = game.state == game.State.READY
	var won: bool = game.state == game.State.ARRIVED
	menu_title.text = "PAUSED" if game.paused else "BLACKWATER" if intro else "YOU HELD\nTHE LIGHT" if won and game.arena_mode else "Safe harbour." if won else "LOST\nAT SEA" if game.arena_mode else "Lost at sea."
	menu_body.text = "" if intro or won or game.paused else game.failure_reason
	menu_body.visible = not menu_body.text.is_empty() and not subpage_open
	menu_details.visible = not intro and not game.paused
	var clock := "%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60]
	menu_details.text = ("ALL 5 WAVES COMPLETE" if won else "WAVE %d / 5 REACHED" % maxi(1, game.enemy_encounters.wave_number)) + "   ·   " + clock if game.arena_mode else "Voyage time   " + clock
	action_button.text = "RESUME" if game.paused else "SET SAIL" if intro else "SAIL AGAIN" if won else "RETRY"
	main_menu_button.visible = not intro
	walkthrough_button.visible = intro and game.arena_mode
	menu_controls.visible = intro and not game.arena_mode and not subpage_open
	menu_footer.text = "A/D steer · Shift boost · Mouse look\nClick/Space fire · Enter set sail" if intro and game.arena_mode else "Enter set sail · M mute · Esc pause / resume" if intro else "R retry · M mute · Esc pause / resume"
	settings_panel.visible = settings_open
	credits_panel.visible = credits_open
	menu_actions.visible = not subpage_open
	menu_footer.visible = not subpage_open and not game.arena_mode
	if subpage_open:
		menu_title.text = "CREDITS" if credits_open else "SETTINGS"
		menu_details.visible = false
	_layout_menu()


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
	var show_menu: bool = game.paused or game.state in [game.State.READY, game.State.LOST, game.State.ARRIVED]
	menu.visible = show_menu
	menu_shade.visible = show_menu
	action_button.visible = show_menu
	gameplay_hud.visible = game.state == game.State.SAILING and not game.walkthrough.active and not game.paused
	if not gameplay_hud.visible and not game.paused:
		boss_label.visible = false
		boss_health.visible = false
		fleet_status.visible = false
		_announced_fleet = 0
		_fleet_banner_left = 0.0
		_sync_fleet_circles(0)
		_fleet_group_total = 0
		_fleet_complete_left = 0.0
		for label: Label in [notice, threat_label, wave_countdown, wave_announcement]:
			label.text = ""
			label.visible = false
		_has_threat = false
	if game.state == _last_state and game.paused == _last_paused:
		return
	_last_state = game.state
	_last_paused = game.paused
	if not show_menu:
		settings_open = false
		credits_open = false
		for control: Control in [action_button, settings_button, credits_button, main_menu_button, settings_back, credits_back, walkthrough_button]:
			control.release_focus()
		if game.state == game.State.CASTING_OFF:
			cannon_gauge.pulse = 0.0
		return
	settings_open = false
	credits_open = false
	_refresh_menu_copy()
	action_button.grab_focus()
	_menu_alpha = 1.0 if game.paused or game.state == game.State.READY or game.motion_setting == 1 else 0.0


func _on_action_pressed() -> void:
	if settings_open or credits_open: return
	if game.paused:
		game.set_paused(false)
	elif game.state == game.State.READY:
		game.start_crossing()
	elif game.state in [game.State.ARRIVED, game.State.LOST]:
		game.restart()


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(gameplay_hud):
		return
	_sync_button()
	if game.paused:
		menu.modulate.a = 1.0
		queue_redraw()
		return
	if game.walkthrough.active:
		queue_redraw()
		return
	if game.state == game.State.SAILING:
		_update_threat()
	_update_wave_ui(delta)
	_update_storm_warning(delta)
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


func reset_storm_notice() -> void:
	_storm_notice_seen = false
	_storm_notice_left = 0.0
	storm_warning.visible = false


func _update_storm_warning(delta: float = 0.0) -> void:
	var outside: bool = game.outside_storm_line()
	if outside and not _storm_notice_seen:
		_storm_notice_seen = true
		_storm_notice_left = STORM_NOTICE_SECONDS
	else:
		_storm_notice_left = maxf(0.0, _storm_notice_left - maxf(0.0, delta))
	if not outside or _storm_notice_left < 0.00001:
		_storm_notice_left = 0.0
	storm_warning.visible = outside and _storm_notice_left > 0.0
	var occupied_bottom: float = wave_announcement.offset_bottom if wave_announcement.visible else 112
	if wave_countdown.visible:
		occupied_bottom = maxf(occupied_bottom, wave_countdown.offset_bottom)
	storm_warning.offset_top = occupied_bottom + 20
	storm_warning.offset_bottom = storm_warning.offset_top + 78
	storm_warning.modulate.a = 1.0
	storm_instruction.text = "RETURN TO THE LIGHTHOUSE"
	notice.offset_top = storm_warning.offset_bottom + 12 if storm_warning.visible else (184 if wave_announcement.visible else (142 if game.arena_mode else 40))
	notice.offset_bottom = notice.offset_top + 48


func storm_screen_alpha() -> float:
	if not game.outside_storm_line():
		return 0.0
	# A slow 1.8-second pulse; Reduced motion keeps a steady red wash.
	return 0.11 if game.motion_setting == 1 else 0.07 + 0.09 * (0.5 + 0.5 * sin(game.elapsed * TAU / 1.8))


func _draw_storm_warning() -> void:
	var alpha := storm_screen_alpha()
	if alpha <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.015, 0.025, alpha))
	for i in 28:
		var color := Color(1.0, 0.06, 0.08, alpha * 1.8 * (1.0 - i / 28.0))
		draw_rect(Rect2(i * 2, 0, 2, size.y), color)
		draw_rect(Rect2(size.x - i * 2 - 2, 0, 2, size.y), color)
		draw_rect(Rect2(0, i, size.x, 1), color)
		draw_rect(Rect2(0, size.y - i - 1, size.x, 1), color)


func _update_notice() -> void:
	var value := ""
	var alpha: float = 1.0
	if game.restart_elapsed > 0.0:
		value = "Hold R to restart"
	elif game.discovery_left > 0:
		value = game.discovery_text
		alpha = minf(1.0, game.discovery_left)
		if game.arena_mode and (wave_announcement.visible or storm_warning.visible):
			value = ""
	elif not game.arena_mode and game.enemy_encounters.focus_ship().age < 4.0 and game.enemy_encounters.battle_active():
		value = "Hostile nearby · Hold E to aim"
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
	if game.paused or game.state in [game.State.READY, game.State.ARRIVED, game.State.LOST]:
		return
	if game.state == game.State.CASTING_OFF:
		_text(Vector2(size.x * 0.5, size.y - 65), "Casting off…", 25, INK, true, true)
		return
	_draw_weather()
	_draw_storm_warning()
	if game.hit_flash > 0.0:
		_draw_damage_edges()
	if _has_threat:
		var at := Vector2(size.x - 24 if _threat_direction >= 0 else 24.0, size.y * 0.33)
		var side: float = 1 if _threat_direction >= 0 else -1
		var color := Color(CORAL, 0.9 if game.motion_setting == 1 else 0.8 + sin(game.sea_time * 14) * 0.2)
		_line(at + Vector2(-6 * side, -12), at + Vector2(6 * side, 0), color, 3)
		_line(at + Vector2(6 * side, 0), at + Vector2(-6 * side, 12), color, 3)
	if game.reading and _reading_alpha > 0.01:
		_draw_instrument()
	elif not game.arena_mode:
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


func _update_wave_ui(delta: float = 0.0) -> void:
	var waves = game.enemy_encounters
	var active: bool = game.arena_mode and game.state == game.State.SAILING
	boss_label.visible = active and waves.boss_active()
	boss_health.visible = boss_label.visible
	if boss_health.visible:
		boss_health.max_value = waves.boss.hull_capacity
		boss_health.value = waves.boss.hull
	wave_announcement.offset_top = 110 if boss_health.visible else 44
	wave_announcement.offset_bottom = wave_announcement.offset_top + 64
	fleet_status.visible = false
	wave_countdown.visible = false
	wave_announcement.visible = false
	if not active:
		return
	var remaining := 0
	for record: Dictionary in waves.records:
		remaining += maxi(0, int(record.count) - int(record.defeated))
	if waves.wave_number == waves.ARENA_WAVES and (waves.boss_spawn_pending or waves.boss_active()):
		remaining += 1
	if waves.wave_number != _announced_fleet:
		_announced_fleet = waves.wave_number
		# Freeze this group's size: later defeats of carried survivors also leave hollows.
		_fleet_group_total = remaining
		_fleet_complete_left = 0.0
		_fleet_banner_left = FLEET_BANNER_SECONDS if waves.wave_number > 0 else 0.0
	else:
		_fleet_banner_left = maxf(0.0, _fleet_banner_left - maxf(0.0, delta))
		_fleet_complete_left = maxf(0.0, _fleet_complete_left - maxf(0.0, delta))
		if remaining == 0 and fleet_circles.remaining > 0:
			_fleet_complete_left = FLEET_COMPLETE_SECONDS
	_sync_fleet_circles(remaining, _fleet_group_total)
	fleet_status.visible = _fleet_group_total > 0 and (remaining > 0 or _fleet_complete_left > 0.0)
	if waves.phase == waves.Phase.EARLY_CLEAR:
		_fleet_banner_left = 0.0
		wave_countdown.text = "WAVE CLEARED · NEXT IN %d" % ceili(waves.next_wave_in)
		wave_countdown.visible = true
	elif waves.wave_number < waves.ARENA_WAVES and waves.next_wave_in > 0 and waves.next_wave_in <= 15:
		var seconds := ceili(waves.next_wave_in)
		wave_countdown.text = "NEXT WAVE IN %02d:%02d" % [seconds / 60, seconds % 60]
		wave_countdown.visible = true
	if _fleet_banner_left > 0.0:
		wave_announcement.text = ["", "WAVE I", "WAVE II", "WAVE III", "WAVE IV", "FINAL WAVE"][clampi(waves.wave_number, 0, waves.ARENA_WAVES)]
		wave_announcement.visible = true
		wave_announcement.modulate.a = 1.0 if game.motion_setting == 1 else clampf(_fleet_banner_left / 0.4, 0, 1)
	wave_countdown.offset_top = wave_announcement.offset_bottom + 8 if wave_announcement.visible else 52
	wave_countdown.offset_bottom = wave_countdown.offset_top + 20

extends PanelContainer
## A compact practice card; button caps reflect real inputs, not timed fake presses.
const Palette = preload("res://game/nautical_theme.gd")
const Guide = preload("res://game/walkthrough.gd")
const TITLES := ["Take the helm", "Catch the wind", "Look to the horizon", "Fire to starboard", "A closer view", "Ready for the fleets"]
var game: Node3D
var column: VBoxContainer
var progress: Label
var heading: Label
var keys: HBoxContainer
var next_button: Button
var skip_button: Button
var _step := -1
var key_styles: Array[StyleBoxFlat] = []
var caps: Array[PanelContainer] = []
var key_actions: Array[String] = []

func _label(value: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	column.add_child(label)
	return label

func _ready() -> void:
	name = "WalkthroughCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(Palette.NAVY, 0.95)
	panel.border_color = Color(Palette.BRASS, 0.65)
	panel.set_border_width_all(1)
	panel.border_width_top = 2
	panel.set_corner_radius_all(4)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	add_theme_stylebox_override("panel", panel)
	for state in range(3):
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.BRASS if state == 1 else Color("193544")
		style.border_color = Palette.IVORY if state == 1 else Palette.SEA_GLASS if state == 2 else Palette.BRASS
		style.set_border_width_all(1)
		style.border_width_bottom = 4
		style.set_corner_radius_all(5)
		key_styles.append(style)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	progress = _label("SEA TRIALS · 1 / 5", 12, Palette.BRASS)
	heading = _label("Take the helm", 24, Palette.IVORY)
	heading.add_theme_font_override("font", Palette.TITLE)
	keys = HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("separation", 12)
	column.add_child(keys)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	skip_button = Button.new()
	skip_button.text = "SKIP"
	skip_button.custom_minimum_size.y = 32
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_button.pressed.connect(func(): game.finish_walkthrough())
	row.add_child(skip_button)
	next_button = Button.new()
	next_button.text = "CONTINUE  ›"
	next_button.tooltip_text = "Try the control, then press Enter or Continue."
	next_button.add_theme_font_size_override("font_size", 16)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		next_button.add_theme_color_override(slot, Palette.NAVY)
	for kind in ["normal", "hover", "pressed", "focus"]:
		next_button.add_theme_stylebox_override(kind, Palette.button_style(kind, true))
	next_button.pressed.connect(func(): game.walkthrough.advance(game))
	row.add_child(next_button)
	game.hud.resized.connect(_layout)
	minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()

func _input(event: InputEvent) -> void:
	if game.walkthrough.active and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		game.walkthrough.advance(game)
		get_viewport().set_input_as_handled()

func _layout() -> void:
	if not is_instance_valid(game.hud) or game.hud.size.x < 1: return
	var width := minf(360, game.hud.size.x - 48)
	size = Vector2(width, 0)
	position = Vector2((game.hud.size.x - size.x) * 0.5, maxf(24, game.hud.size.y - size.y - 24))

func _cap(caption: String, action: String, width: float = 72) -> void:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(width, 44)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 21 if caption.length() < 6 else 17)
	cap.add_child(label)
	keys.add_child(cap)
	caps.append(cap)
	key_actions.append(action)

func _rebuild_keys(step: int) -> void:
	for child in keys.get_children():
		keys.remove_child(child)
		child.queue_free()
	caps.clear()
	key_actions.clear()
	match step:
		Guide.Step.STEER:
			_cap("A  /  ←", "steer_port", 122)
			_cap("D  /  →", "steer_starboard", 122)
		Guide.Step.BOOST: _cap("SHIFT", "boost_sailing", 140)
		Guide.Step.LOOK: _cap("←   MOUSE   →", "mouse", 220)
		Guide.Step.FIRE:
			_cap("LMB", "fire_mouse", 100)
			_cap("SPACE", "fire_starboard", 160)
		Guide.Step.CAMERA: _cap("E", "watch_starboard")
		Guide.Step.READY: _cap("BON VOYAGE", "", 220)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var guide = game.walkthrough
	visible = guide.active and game.state == game.State.SAILING
	if not visible: return
	if guide.step != _step:
		_step = guide.step
		heading.text = TITLES[_step]
		progress.text = "SEA TRIALS COMPLETE" if _step == Guide.Step.READY else "SEA TRIALS · %d / 5" % (_step + 1)
		_rebuild_keys(_step)
		next_button.release_focus()
		skip_button.release_focus()
		_layout.call_deferred()
	var ready: bool = guide.practiced or _step == Guide.Step.READY
	next_button.disabled = not ready
	next_button.text = "BEGIN VOYAGE  ›" if _step == Guide.Step.READY else "CONTINUE  ›"
	for i in caps.size():
		var pressed: bool = Input.is_action_pressed(key_actions[i]) if InputMap.has_action(key_actions[i]) else guide.mouse_travel > 0 if key_actions[i] == "mouse" else false
		caps[i].add_theme_stylebox_override("panel", key_styles[1 if pressed else 2 if ready else 0])
		caps[i].get_child(0).add_theme_color_override("font_color", Palette.NAVY if pressed else Palette.IVORY)

extends PanelContainer
## A compact adventure card; the existing guide still validates every real input.
const Palette = preload("res://game/nautical_theme.gd")
const Guide = preload("res://game/walkthrough.gd")
const TITLES := ["STEER", "BOOST", "LOOK", "FIRE", "CAMERA", "READY"]
const INSTRUCTIONS := ["Use A / D or the arrow keys to turn.", "Hold W or Shift to move faster.", "Move the mouse to look around.", "Press Space or click to fire.", "Press E to switch camera views.", "Press Play to start the game."]
var game: Node3D
var column: VBoxContainer
var progress: Label
var heading: Label
var instruction: Label
var keys: HBoxContainer
var next_button: Button
var skip_button: Button
var _step := -1
var key_styles: Array[StyleBoxTexture] = []
var caps: Array[PanelContainer] = []
var key_actions: Array[String] = []

func _label(value: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	column.add_child(label)
	return label

func _ready() -> void:
	name = "WalkthroughCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_theme_stylebox_override("panel", Palette.panel_style(20))
	key_styles = [Palette.keycap_style(), Palette.keycap_style(true), Palette.keycap_style(false, true)]
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	progress = _label("TUTORIAL · 1 / 5", 12, Palette.BRASS)
	heading = _label("STEER", 24, Palette.IVORY)
	heading.add_theme_font_override("font", Palette.TITLE)
	instruction = _label(INSTRUCTIONS[0], 15, Palette.SEA_GLASS)
	keys = HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_BEGIN
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("separation", 10)
	column.add_child(keys)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	skip_button = Button.new()
	skip_button.text = "SKIP"
	skip_button.custom_minimum_size = Vector2(84, 36)
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Palette.style_button(skip_button)
	skip_button.pressed.connect(func(): game.finish_walkthrough(); _process(0))
	row.add_child(skip_button)
	next_button = Button.new()
	next_button.text = "CONTINUE"
	next_button.tooltip_text = "Try the control, then press Enter or Continue."
	next_button.custom_minimum_size.y = 36
	next_button.add_theme_font_size_override("font_size", 16)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Palette.style_button(next_button, true)
	next_button.pressed.connect(func(): game.walkthrough.advance(game); _process(0))
	row.add_child(next_button)
	game.hud.resized.connect(_layout)
	minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()

func _input(event: InputEvent) -> void:
	if not game.paused and game.walkthrough.active and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		game.walkthrough.advance(game)
		_process(0)
		get_viewport().set_input_as_handled()

func _layout() -> void:
	if not is_instance_valid(game.hud) or game.hud.size.x < 1: return
	var width := minf(360, game.hud.size.x - 48)
	size = Vector2(width, 0)
	position = Vector2(maxf(24, game.hud.size.x - width - 24), maxf(24, game.hud.size.y - size.y - 24))

func _cap(caption: String, action: String, width: float = 60) -> void:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(width, 32)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 17 if caption.length() < 6 else 15)
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
			_cap("A / LEFT", "steer_port", 112)
			_cap("D / RIGHT", "steer_starboard", 112)
		Guide.Step.BOOST: _cap("W / SHIFT", "boost_sailing", 112)
		Guide.Step.LOOK: _cap("MOVE MOUSE", "mouse", 200)
		Guide.Step.FIRE:
			_cap("LMB", "fire_mouse", 84)
			_cap("SPACE", "fire_starboard", 120)
		Guide.Step.CAMERA: _cap("E", "watch_starboard")
		Guide.Step.READY: _cap("COMPLETE", "", 200)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var guide = game.walkthrough
	visible = guide.active and game.state == game.State.SAILING and not game.paused
	if not visible: return
	if guide.step != _step:
		_step = guide.step
		heading.text = TITLES[_step]
		instruction.text = INSTRUCTIONS[_step]
		_rebuild_keys(_step)
		next_button.release_focus()
		skip_button.release_focus()
		_layout.call_deferred()
	var ready: bool = guide.practiced or _step == Guide.Step.READY
	progress.text = "TUTORIAL COMPLETE" if _step == Guide.Step.READY else "TUTORIAL · %d / 5%s" % [_step + 1, " · COMPLETE" if ready else ""]
	progress.add_theme_color_override("font_color", Palette.SEA_GLASS if ready else Palette.BRASS)
	next_button.disabled = not ready
	next_button.text = "PLAY" if _step == Guide.Step.READY else "CONTINUE"
	for i in caps.size():
		var pressed: bool = Input.is_action_pressed(key_actions[i]) if InputMap.has_action(key_actions[i]) else guide.mouse_travel > 0 if key_actions[i] == "mouse" else false
		caps[i].add_theme_stylebox_override("panel", key_styles[1 if pressed else 2 if ready else 0])
		caps[i].get_child(0).add_theme_color_override("font_color", Palette.NAVY if pressed else Palette.IVORY)

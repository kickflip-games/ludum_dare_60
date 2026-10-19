extends CanvasLayer
## Own each finger for its entire gesture. Only menu taps are translated to mouse.
const Joystick = preload("res://addons/virtual_joystick_DX/vjdx_core_script.gd")
const MENU_DEVICE := 1001
const Palette = preload("res://game/nautical_theme.gd")
var game: Node3D
var enabled := false
var active := false
var portrait := false
var fingers: Dictionary = {}
var joystick: Control
var surface: Control
var fire: Button
var boost: Button
var pause_button: Button
var camera_button: Button
var rotate_hint: Label
var _layout_clock := 0.0
var _layout_key := ""
var _menu_finger := -1
var _previous_emulation := true

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	enabled = game.arena_mode and DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		enabled = game.arena_mode and (enabled or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0")))
		enabled = enabled or bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('touch') === '1'"))
	for arg in OS.get_cmdline_user_args():
		if arg == "--touch-controls": enabled = game.arena_mode
	surface = Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.theme = Palette.make_theme()
	joystick = Joystick.new()
	joystick.joystick_radius = 62
	joystick.thumb_radius = 23
	joystick.deadzone = 0.12
	joystick.joystick_mode = Joystick.JoystickMode.STATIC
	joystick.use_directional_mapping = false # Horizontal actions only; no UI up/down.
	joystick.auto_hide_on_physical_input = false
	joystick.auto_show_on_touch = false
	joystick.haptic_enabled = false
	joystick.color_js_base = Color(Palette.NAVY, 0.55)
	joystick.color_js_border = Color(Palette.SEA_GLASS, 0.35)
	joystick.color_js_thumb = Color(Palette.IVORY, 0.65)
	joystick.color_js_thumb_active = Color(Palette.BRASS, 0.85)
	surface.add_child(joystick)
	# The router is the only input listener; addon still owns its stick index/math.
	joystick.set_process_input(false)
	joystick.joystick_moved.connect(_steer)
	joystick.joystick_released.connect(func(): _steer(Vector2.ZERO))
	fire = _button("FIRE", 108, 24)
	boost = _button("BOOST", 72, 16)
	pause_button = _button("II", 60, 24)
	camera_button = _button("VIEW", 60, 14)
	rotate_hint = Label.new()
	rotate_hint.text = "Rotate your phone"
	rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_hint.add_theme_font_size_override("font_size", 26)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(rotate_hint)
	_layout()
	_refresh()
	if enabled: game.hud._refresh_menu_copy()

func _button(caption: String, diameter: float, points: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.size = Vector2.ONE * diameter
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", points)
	for kind in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.NAVY, 0.65 if kind != "pressed" else 0.9)
		style.border_color = Color(Palette.BRASS, 0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(roundi(diameter / 2))
		button.add_theme_stylebox_override(kind, style)
	surface.add_child(button)
	return button

func _steer(value: Vector2) -> void:
	for action in ["steer_port", "steer_starboard"]: Input.action_release(action)
	if value.x < 0: Input.action_press("steer_port", -value.x)
	if value.x > 0: Input.action_press("steer_starboard", value.x)

func available() -> bool:
	return enabled and active and not portrait

func _playable() -> bool:
	return enabled and game.state == game.State.SAILING and not game.paused and game._window_focused and not game.hud.settings_open and not game.hud.credits_open and not game.diagnostics.panel.visible

func _process(delta: float) -> void:
	_layout_clock -= delta
	if _layout_clock <= 0:
		_layout_clock = 0.25
		_layout()
	_refresh()

func _refresh() -> void:
	var next_active := _playable()
	if active and not next_active: reset_touches()
	active = next_active
	surface.visible = enabled
	for control in [joystick, fire, boost, pause_button]: control.visible = available()
	camera_button.visible = available() and game.walkthrough.active and game.walkthrough.step == game.Walkthrough.Step.CAMERA
	rotate_hint.visible = enabled and portrait

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var inset := Vector4.ZERO
	var next_portrait := get_window().size.x < get_window().size.y
	var physical := Vector2(get_window().size)
	if enabled and OS.has_feature("web"):
		# CSS safe-area insets are relative to the iframe, never the parent page.
		var info = JSON.parse_string(str(JavaScriptBridge.eval("""JSON.stringify((() => {
			let p = document.getElementById('touch-safe-area');
			if (!p) { p = document.createElement('div'); p.id = 'touch-safe-area'; p.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)'; document.body.appendChild(p); }
			const s = getComputedStyle(p);
			return [innerWidth, innerHeight, parseFloat(s.paddingLeft), parseFloat(s.paddingTop), parseFloat(s.paddingRight), parseFloat(s.paddingBottom), screen.width < screen.height];
		})())""")))
		if info is Array and info.size() == 7:
			physical = Vector2(info[0], info[1])
			# Viewport KEEP letterboxing already supplies part of the safe margin.
			var scale_css := minf(physical.x / view.x, physical.y / view.y)
			var bars := (physical - view * scale_css) * 0.5
			inset = Vector4(maxf(0, info[2] - bars.x), maxf(0, info[3] - bars.y), maxf(0, info[4] - bars.x), maxf(0, info[5] - bars.y)) / scale_css
			next_portrait = info[6]
	var key := str([view, physical, inset, next_portrait, enabled])
	if key == _layout_key: return
	_layout_key = key
	reset_touches()
	portrait = next_portrait
	var left := 18.0 + inset.x
	var right := view.x - 18 - inset.z
	var bottom := view.y - 18 - inset.w
	joystick.size = Vector2(124, 124)
	joystick.position = Vector2(left + 12, bottom - 136)
	joystick.region_x = left
	joystick.region_y = bottom - 180
	joystick.region_w = 180
	joystick.region_h = 180
	fire.position = Vector2(right - 108, bottom - 112)
	boost.position = Vector2(right - 192, bottom - 76)
	pause_button.position = Vector2(right - 60, 14 + inset.y)
	camera_button.position = Vector2(right - 124, 14 + inset.y)
	rotate_hint.position = Vector2(0, view.y * 0.45)
	rotate_hint.size.x = view.x
	# Move reload feedback away from FIRE, keeping wave/boss information unchanged.
	if enabled:
		game.hud.cannon_gauge.offset_top = -234 - inset.w
		game.hud.cannon_gauge.offset_bottom = -172 - inset.w
		game.hud.cannon_gauge.offset_left = -198 - inset.z
		game.hud.cannon_gauge.offset_right = -24 - inset.z

func _button_at(node: Node, point: Vector2) -> bool:
	if node is BaseButton and node.is_visible_in_tree() and not node.disabled and node.get_global_rect().has_point(point): return true
	for child in node.get_children():
		if _button_at(child, point): return true
	return false

func _menu_mouse(event: InputEventScreenTouch) -> void:
	var mouse := InputEventMouseButton.new()
	mouse.device = MENU_DEVICE
	mouse.position = event.position
	mouse.global_position = event.position
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
	mouse.pressed = event.pressed and not event.canceled
	var motion := InputEventMouseMotion.new()
	motion.device = MENU_DEVICE
	motion.position = event.position
	motion.global_position = event.position
	get_viewport().push_input(motion, true)
	get_viewport().push_input(mouse, true)

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
	_refresh()
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if fingers.has(event.index): return
			var owner := "blocked"
			if _button_at(game.hud, event.position) or _button_at(game.diagnostics, event.position):
				if _menu_finger == -1:
					_menu_finger = event.index
					owner = "ui"
			elif game.hud.walkthrough_card.is_visible_in_tree() and game.hud.walkthrough_card.get_global_rect().has_point(event.position):
				pass # Text/card space never becomes a camera gesture.
			elif available():
				if _inside(pause_button, event.position): owner = "pause"
				elif camera_button.visible and _inside(camera_button, event.position): owner = "view"
				elif _inside(fire, event.position):
					if not fingers.values().has("fire"): owner = "fire"
				elif _inside(boost, event.position):
					if not fingers.values().has("boost"): owner = "boost"
				elif Rect2(joystick.region_x, joystick.region_y, joystick.region_w, joystick.region_h).has_point(event.position):
					if not fingers.values().has("steer"): owner = "steer"
				elif not fingers.values().has("look"): owner = "look"
			fingers[event.index] = owner
			match owner:
				"ui": _menu_mouse(event)
				"pause": game.set_paused(true)
				"view": game.arena_cannon_view = not game.arena_cannon_view
				"steer": joystick._input(event)
				"fire":
					fire.set_pressed_no_signal(true)
					game.set_touch_fire(true)
				"boost":
					boost.set_pressed_no_signal(true)
					Input.action_press("boost_sailing")
		else:
			var owner: String = fingers.get(event.index, "blocked")
			fingers.erase(event.index) # Release before a menu callback can reset us.
			match owner:
				"ui":
					_menu_finger = -1
					_menu_mouse(event)
				"steer": joystick.release()
				"fire":
					fire.set_pressed_no_signal(false)
					game.set_touch_fire(false)
					if event.canceled:
						game._fire_armed = false
						game.cannon.cancel_aim()
				"boost":
					boost.set_pressed_no_signal(false)
					Input.action_release("boost_sailing")
	elif available():
		match fingers.get(event.index, "blocked"):
			"steer": joystick._input(event)
			"look": game.apply_camera_look(Vector2(event.relative.x, 0))
	get_viewport().set_input_as_handled()

func _inside(button: Control, point: Vector2) -> bool:
	return point.distance_to(button.position + button.size * 0.5) <= button.size.x * 0.5

func reset_touches() -> void:
	if is_instance_valid(joystick): joystick.release()
	if fingers.values().has("fire") and is_instance_valid(game.cannon):
		game.set_touch_fire(false)
		game._fire_armed = false
		game.cannon.cancel_aim()
	if fingers.values().has("boost"): Input.action_release("boost_sailing")
	if is_instance_valid(fire): fire.set_pressed_no_signal(false)
	if is_instance_valid(boost): boost.set_pressed_no_signal(false)
	# Cancel a GUI press without activating it, including focus/resize interruption.
	if _menu_finger != -1:
		var cancel := InputEventScreenTouch.new()
		cancel.position = Vector2(-1000, -1000)
		_menu_mouse(cancel)
	_menu_finger = -1
	fingers.clear()

func _exit_tree() -> void:
	reset_touches()
	Input.emulate_mouse_from_touch = _previous_emulation

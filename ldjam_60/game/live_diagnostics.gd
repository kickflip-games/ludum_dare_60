extends CanvasLayer
## Opt-in, bounded local recorder. Browser lifecycle protection remains active when off.
const NauticalTheme = preload("res://game/nautical_theme.gd")
const KEEP_SECONDS := 240.0
const FRAME_LIMIT := 40000
const EVENT_LIMIT := 2000
const SAMPLE_LIMIT := 1200
const ACTIONS := ["steer_port", "steer_starboard", "boost_sailing", "fire_starboard", "fire_mouse", "watch_starboard", "restart_crossing"]
const WEB_RESOLUTIONS := [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1280, 720)]
var resolution_index := 1
var game
var enabled := false
var applied_steering := 0.0
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var frame_times := PackedFloat64Array()
var frame_intervals := PackedFloat32Array()
var _cursor := 0
var _count := 0
var _last_frame := 0
var _last_sample := 0
var _last_summary := 0
var _browser: JavaScriptObject
var _has_browser := false
var panel: PanelContainer
var live: Label
var stats: Label
var timeline: Label
var recording_button: CheckButton
var status: Label
var build_info: Dictionary = {"git_sha": "development", "dirty": true}
var _summary := {}
var _observed_fixture_actions := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	if FileAccess.file_exists("res://game/build_info.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://game/build_info.json"))
		if data is Dictionary: build_info = data
	frame_times.resize(FRAME_LIMIT)
	frame_intervals.resize(FRAME_LIMIT)
	if OS.has_feature("web"):
		_browser = JavaScriptBridge.get_interface("BlackwaterRuntime")
		_has_browser = is_instance_valid(_browser)
		set_resolution(resolution_index)
	_build_panel()

func note(kind: String, data: Dictionary = {}) -> void:
	if not enabled: return
	var t := Time.get_ticks_msec()
	events.append({"t_ms": t, "kind": kind, "data": data})
	while events.size() > EVENT_LIMIT or (not events.is_empty() and events[0].t_ms < t - KEEP_SECONDS * 1000):
		events.pop_front()

func steering(value: float) -> void:
	if enabled and not is_equal_approx(value, applied_steering):
		note("movement_steering", {"value": value})
	applied_steering = value

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		events.clear()
		_observed_fixture_actions.clear()
		samples.clear()
		_cursor = 0
		_count = 0
		_last_frame = 0
		_last_sample = 0
		_last_summary = 0
		_summary = {}
		note("recording_started", {"build": build_info})
	if _has_browser: JavaScriptBridge.get_interface("BlackwaterRuntime").setRecording(value)
	recording_button.set_pressed_no_signal(value)
	live.visible = value and not panel.visible
	_refresh_stats()

func open_panel() -> void:
	game.set_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.visible = true
	note("diagnostics_open")
	live.visible = false
	recording_button.grab_focus()
	_refresh_stats()

func close_panel() -> void:
	note("diagnostics_close")
	panel.visible = false
	live.visible = enabled
	# Closing diagnostics never implicitly resumes a voyage.
	if game.paused: game.hud.action_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8 or event.keycode == KEY_F8:
			if panel.visible: close_panel()
			else: open_panel()
			get_viewport().set_input_as_handled()
		elif panel.visible and event.keycode == KEY_ESCAPE:
			close_panel()
			get_viewport().set_input_as_handled()
	if not enabled: return
	for action: String in ACTIONS:
		if event.is_action(action) and not event.is_echo():
			if event is InputEventAction:
				if _observed_fixture_actions.get(action) == event.is_pressed(): continue
				_observed_fixture_actions[action] = event.is_pressed()
			note("godot_input", {"action": action, "pressed": event.is_pressed()})

func poll_lifecycle() -> void:
	if not _has_browser: return
	# Retain focus loss across inactive browser frames and consume before motion.
	var flags: int = _browser.takeLifecycle()
	if flags & 1: game.application_focus_changed(false, "browser_focus_loss")
	if flags & 2: game.application_focus_changed(browser_focused(), "browser_focus_restore")
	if flags & 4 and not game.paused: game.set_paused(true)

func browser_focused() -> bool:
	return JavaScriptBridge.get_interface("BlackwaterRuntime").isFocused() == true if _has_browser else game._window_focused

func focus_canvas() -> void:
	if _has_browser:
		JavaScriptBridge.get_interface("BlackwaterRuntime").focusCanvas()
		game._window_focused = browser_focused()

func can_capture() -> bool:
	return JavaScriptBridge.get_interface("BlackwaterRuntime").canCapture() == true if _has_browser else not OS.has_feature("web")

func pause_audio(value: bool) -> void:
	if _has_browser: JavaScriptBridge.get_interface("BlackwaterRuntime").pauseAudio(value)

func _process(_delta: float) -> void:
	poll_lifecycle()
	if not enabled: return
	var now := Time.get_ticks_usec()
	if _last_frame > 0:
		frame_times[_cursor] = now / 1000.0
		frame_intervals[_cursor] = (now - _last_frame) / 1000.0
		_cursor = (_cursor + 1) % FRAME_LIMIT
		_count = mini(_count + 1, FRAME_LIMIT)
	_last_frame = now
	if now - _last_sample >= 200000:
		_last_sample = now
		samples.append(_sample())
		while samples.size() > SAMPLE_LIMIT or (not samples.is_empty() and samples[0].t_ms < now / 1000.0 - KEEP_SECONDS * 1000): samples.pop_front()
	if now - _last_summary >= 1000000:
		_last_summary = now
		_summary = summarize(_recent_frames())
		_refresh_stats()

func _sample() -> Dictionary:
	var actions := {}
	for action: String in ACTIONS: actions[action] = Input.get_action_strength(action)
	var browser = JSON.parse_string(JavaScriptBridge.get_interface("BlackwaterRuntime").snapshot()) if _has_browser else null
	return {"t_ms": Time.get_ticks_msec(), "game_state": game.State.keys()[game.state], "paused": game.paused,
		"diagnostics_panel_open": panel.visible,
		"window_focused": game._window_focused, "pointer_mode": Input.mouse_mode,
		"actions": actions, "movement_steering": applied_steering, "turn_input": game.turn_input,
		"look_yaw": game.look_yaw, "look_target": game.look_target,
		"wave": game.enemy_encounters.wave_number, "hull": game.hull,
		"viewport_texture_reported": _render_size(),
		"viewport_internal": _internal_size(),
		"content_scale_size": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"content_scale_mode": get_window().content_scale_mode, "content_scale_aspect": get_window().content_scale_aspect,
		"viewport_stretch_scale": [get_viewport().get_stretch_transform().get_scale().x, get_viewport().get_stretch_transform().get_scale().y],
		"display_window": [get_window().size.x, get_window().size.y],
		"viewport_logical": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"physics_frame": Engine.get_physics_frames(), "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"render_frame": Engine.get_frames_drawn(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"static_memory_bytes": _positive_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes": _positive_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"audio": game.audio_diagnostic_state(), "browser": browser}

func _positive_monitor(monitor: Performance.Monitor):
	var value := Performance.get_monitor(monitor)
	return value if value > 0 else null

func _render_size() -> Array:
	var dimensions := get_viewport().get_texture().get_size()
	return [dimensions.x, dimensions.y]

func _internal_size() -> Array:
	# Root Window does not expose its raw viewport size. Reconstruct it from the
	# logical rect and canvas stretch; verify physical storage independently in JS.
	var dimensions := get_viewport().get_visible_rect().size
	if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		dimensions = (dimensions * get_viewport().get_stretch_transform().get_scale()).round()
	return [dimensions.x, dimensions.y]

func _recent_frames() -> Array:
	var rows := []
	var cutoff := Time.get_ticks_msec() - KEEP_SECONDS * 1000
	for i in _count:
		var index := (_cursor - _count + i + FRAME_LIMIT) % FRAME_LIMIT
		if frame_times[index] >= cutoff: rows.append([snappedf(frame_times[index], 0.001), snappedf(frame_intervals[index], 0.001)])
	return rows

static func summarize(rows: Array) -> Dictionary:
	var values: Array[float] = []
	var slow := 0
	var dropped := 0
	var sum := 0.0
	for row in rows:
		var ms := float(row[1])
		values.append(ms)
		sum += ms
		if ms > 33.334: slow += 1
		dropped += maxi(0, roundi(ms / (1000.0 / 60)) - 1)
	if values.is_empty(): return {"frames": 0}
	values.sort()
	var median: float = values[floori((values.size() - 1) * 0.5)]
	return {"frames": values.size(), "duration_s": sum / 1000.0, "mean_ms": sum / values.size(),
		"median_ms": median, "p95_ms": values[ceili((values.size() - 1) * 0.95)],
		"p99_ms": values[ceili((values.size() - 1) * 0.99)], "max_ms": values[-1],
		"fps_median": 1000.0 / maxf(median, 0.001),
		"fps_p95": 1000.0 / maxf(values[floori((values.size() - 1) * 0.05)], 0.001),
		"fps_p99": 1000.0 / maxf(values[floori((values.size() - 1) * 0.01)], 0.001), "slow_frames_over_33_ms": slow,
		"estimated_missed_60hz_slots": dropped}

func report() -> Dictionary:
	var frames := _recent_frames()
	var browser: Dictionary = JSON.parse_string(JavaScriptBridge.get_interface("BlackwaterRuntime").report()) if _has_browser else {}
	if browser.has("raf_frames"): browser["frame_summary"] = summarize(browser.raf_frames)
	var cutoff := Time.get_ticks_msec() - KEEP_SECONDS * 1000
	return {"schema": 2, "build": build_info, "godot": Engine.get_version_info(),
		"platform": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"recording_enabled": enabled, "retention_seconds": KEEP_SECONDS,
		"created_utc": Time.get_datetime_string_from_system(true), "engine_clock_ms": Time.get_ticks_msec(),
		"browser_clock_ms": _browser.clockMs() if _has_browser else null,
		"frame_columns": ["engine_ms", "interval_ms"], "engine_frames": frames, "frame_summary": summarize(frames),
		"current_state": _sample(), "samples": samples.filter(func(s): return s.t_ms >= cutoff),
		"events": events.filter(func(e): return e.t_ms >= cutoff), "browser": browser,
		"counter_notes": "viewport_internal is reconstructed from the logical rect and canvas stretch; viewport_texture_reported is the root ViewportTexture getter and may include stretch again. Browser GPU attachments and drawing buffer are independent observations. Frame intervals use wall time including pauses. Null memory means unavailable. Engine/browser clocks are joined using export clock_ms values."}

func export_report() -> void:
	var data := JSON.stringify(report())
	var filename := "blackwater-%s.json" % str(build_info.get("git_sha", "development")).left(12)
	if _has_browser:
		JavaScriptBridge.get_interface("BlackwaterRuntime").offerExport(data, filename)
	else:
		var file := FileAccess.open("user://" + filename, FileAccess.WRITE)
		if file:
			file.store_string(data)
			status.text = "Saved " + ProjectSettings.globalize_path("user://" + filename)
		else: status.text = "Could not save diagnostics: " + str(FileAccess.get_open_error())

func _refresh_stats() -> void:
	var summary_text := "Recording · collecting frame intervals" if enabled else "Recorder off · no performance or input history collected"
	if enabled and _summary.get("frames", 0) > 0:
		summary_text = "%.1f FPS · frame median %.1f / p95 %.1f / p99 %.1f / max %.1f ms" % [_summary.fps_median, _summary.median_ms, _summary.p95_ms, _summary.p99_ms, _summary.max_ms]
	live.text = summary_text + "\nF8 diagnostics · steering %.1f · viewport %s" % [game.turn_input, str(_internal_size())]
	if not events.is_empty():
		var recent := PackedStringArray()
		for i in range(maxi(0, events.size() - 2), events.size()): recent.append("%.1fs %s" % [events[i].t_ms / 1000.0, events[i].kind])
		live.text += "\n" + " · ".join(recent)
	stats.text = summary_text + "\nViewport %s · texture getter %s\nFocus %s · paused %s · steering %.1f\nMusic %s · ocean %s · generator skips %s" % [_internal_size(), _render_size(), game._window_focused, game.paused, game.turn_input, "sample" if game._music.playback_type == AudioServer.PLAYBACK_TYPE_SAMPLE else "stream", "generator" if game.diagnostic_generator else "loop sample", game.audio_diagnostic_state().generator_skips]
	var lines := PackedStringArray()
	for i in range(maxi(0, events.size() - 5), events.size()):
		lines.append("%.1fs  %s  %s" % [events[i].t_ms / 1000.0, events[i].kind, JSON.stringify(events[i].data).left(120)])
	timeline.text = "Recent events\n" + "\n".join(lines)

func set_resolution(index: int) -> void:
	# Native quality and its diagnostic comparisons remain unchanged.
	var window := get_window()
	if OS.has_feature("web"):
		_apply_web_resolution(index)
		return
	window.content_scale_size = Vector2i(960, 540) if index == 0 else Vector2i(1280, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if index == 2 else Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if index == 2 else Window.CONTENT_SCALE_ASPECT_KEEP
	note("resolution", {"mode": index, "size": str(window.content_scale_size)})

func _apply_web_resolution(index: int) -> void:
	resolution_index = index if index >= 0 and index < WEB_RESOLUTIONS.size() else 1
	var window := get_window()
	# Switch mode first, so a previous/invalid canvas setting cannot allocate at
	# window resolution during a size change. No Web path selects canvas mode.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.content_scale_size = WEB_RESOLUTIONS[resolution_index]
	note("resolution", {"preset": resolution_index, "size": str(window.content_scale_size), "scaling": "viewport_keep"})

func _build_panel() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = NauticalTheme.make_theme()
	root.theme.default_font_size = 15
	add_child(root)
	live = Label.new()
	live.position = Vector2(12, 10)
	live.add_theme_font_size_override("font_size", 14)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(live)
	live.visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 20
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", NauticalTheme.panel_style(16))
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "DIAGNOSTICS · " + str(build_info.get("git_sha", "development")).left(12) + (" (modified)" if build_info.get("dirty", false) else "")
	column.add_child(title)
	var help := Label.new()
	help.text = "Local only · keeps up to 4 minutes · Export JSON when a problem happens\nClose, then Resume to play. Music mode changes restart the track. F8 reopens."
	column.add_child(help)
	recording_button = CheckButton.new()
	recording_button.text = "Record diagnostics (off by default)"
	recording_button.toggled.connect(set_enabled)
	column.add_child(recording_button)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 14)
	column.add_child(stats)
	_add_options(column, "Audio", ["Music + ocean + effects", "Music only", "Ocean only", "Both + cannon effects"], func(i): game.set_diagnostic_audio(i))
	_add_options(column, "Music playback", ["Sample (Web default)", "Stream (comparison)"], func(i): game.set_music_playback(i == 0), 0 if OS.has_feature("web") else 1)
	_add_options(column, "Ocean playback", ["Loop sample (default)", "Generator (comparison, records skips)"], func(i): game.set_ocean_generator(i == 1))
	if OS.has_feature("web"):
		_add_options(column, "Render resolution", ["Performance: 640 x 360", "Standard: 960 x 540 (default)", "High: 1280 x 720"], set_resolution, resolution_index)
	else:
		_add_options(column, "Render resolution", ["960 x 540", "1280 x 720", "Original canvas scaling (comparison)"], set_resolution, 2)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for caption: String in ["Export Diagnostics", "Close"]:
		var button := Button.new()
		button.text = caption
		NauticalTheme.style_button(button)
		button.pressed.connect(export_report if caption == "Export Diagnostics" else close_panel)
		buttons.add_child(button)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	column.add_child(status)
	timeline = Label.new()
	timeline.add_theme_font_size_override("font_size", 13)
	column.add_child(timeline)
	panel.visible = false

func _add_options(parent: Node, caption: String, choices: Array, on_change: Callable, selected: int = 0) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 165
	row.add_child(label)
	# Plain cycling buttons avoid native PopupMenu windows in Web templates.
	var options := Button.new()
	options.text = str(choices[selected]) + "  >"
	NauticalTheme.style_button(options)
	options.add_theme_font_size_override("font_size", 15)
	var index := [selected]
	options.pressed.connect(func():
		index[0] = (index[0] + 1) % choices.size()
		options.text = str(choices[index[0]]) + "  >"
		on_change.call(index[0]))
	row.add_child(options)


func _exit_tree() -> void:
	if _has_browser: JavaScriptBridge.get_interface("BlackwaterRuntime").detach()

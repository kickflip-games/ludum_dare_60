extends Node
## Open ui_review.tscn and press F6. All controls here are test-only.
const States = preload("res://tests/ui_review_states.gd")
var game
var states: RefCounted
var index := 0
var toolbar: PanelContainer
var picker: OptionButton
var description: Label
var capturing := false
var output := "res://../build/ui_review/current"


func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	add_child(game)
	states = States.new(game)
	_build_toolbar()
	show_state(0)
	DisplayServer.window_set_title("Blackwater — UI review")


func _build_toolbar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	toolbar = PanelContainer.new()
	layer.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left = 10
	toolbar.offset_right = -10
	toolbar.offset_top = 8
	var column := VBoxContainer.new()
	toolbar.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	for item: Array in [["‹ Previous", -1], ["Next ›", 1]]:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(step.bind(item[1]))
		row.add_child(button)
	picker = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.focus_mode = Control.FOCUS_NONE
	for entry: Array in States.CASES:
		picker.add_item(entry[1])
	picker.item_selected.connect(show_state)
	row.add_child(picker)
	var save := Button.new()
	save.text = "Screenshot · S"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(capture)
	row.add_child(save)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	column.add_child(description)


func show_state(value: int) -> void:
	if capturing:
		return
	index = wrapi(value, 0, States.CASES.size())
	states.apply(index)
	# Menu actions belong to the real game; review navigation uses its own toolbar.
	game.hud.action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.select(index)
	description.text = "%d/%d · %s  |  ←/→ browse · H hide panel · S save · Esc quit" % [index + 1, States.CASES.size(), States.CASES[index][2]]
	var problem: String = states.problem(index)
	if not problem.is_empty():
		push_error(problem)
	_hover_tooltip.call_deferred()


func step(direction: int) -> void:
	show_state(index + direction)


func _notification(what: int) -> void:
	# The game clears star focus when its window loses focus; restore the fixture
	# when returning to this review window.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and states != null:
		show_state.call_deferred(index)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT, KEY_PAGEDOWN, KEY_BRACKETRIGHT: step(1)
		KEY_LEFT, KEY_PAGEUP, KEY_BRACKETLEFT: step(-1)
		KEY_HOME: show_state(0)
		KEY_END: show_state(States.CASES.size() - 1)
		KEY_H: toolbar.visible = not toolbar.visible
		KEY_S: capture()
		KEY_ESCAPE: get_tree().quit()
	get_viewport().set_input_as_handled()


func _hover_tooltip() -> void:
	await get_tree().process_frame
	var control: Control = states.tooltip_control(index)
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center() if control != null else Vector2(4, 4)
	get_viewport().push_input(motion)


func capture() -> void:
	if capturing:
		return
	if DisplayServer.get_name() == "headless":
		push_error("Screenshots need a real renderer.")
		return
	capturing = true
	var was_visible := toolbar.visible
	toolbar.hide()
	await get_tree().process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path := output.path_join("%02d-%s.png" % [index + 1, States.CASES[index][0]])
	var result := get_viewport().get_texture().get_image().save_png(path)
	toolbar.visible = was_visible
	capturing = false
	print("UI REVIEW screenshot: %s (error %d)" % [ProjectSettings.globalize_path(path), result])

extends SceneTree
## Test-only gallery coverage, navigation, frozen feedback and clean lifecycle.
const States = preload("res://tests/ui_review_states.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)


func key(_viewer: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)


func _run() -> void:
	var viewer = load("res://tests/ui_review.tscn").instantiate()
	root.add_child(viewer)
	await process_frame
	await process_frame
	check(viewer.index == 0, "review starts at title")
	for index in range(States.CASES.size()):
		viewer.show_state(index)
		await process_frame
		check(viewer.states.problem(index).is_empty(), "state: " + States.CASES[index][0])
		var before: float = viewer.game.elapsed
		var flash: float = viewer.game.hit_flash
		await process_frame
		check(viewer.game.elapsed == before and viewer.game.hit_flash == flash, "simulation/feedback stay frozen: " + States.CASES[index][0])
	viewer.show_state(0)
	await process_frame
	check(viewer.game.hull == 3 and not viewer.game.hud.threat_label.is_visible_in_tree() and not viewer.game.archipelago.debug_layer.visible, "title after danger/chart clears transient state")
	key(viewer, KEY_LEFT)
	check(viewer.index == States.CASES.size() - 1, "previous wraps to last state")
	key(viewer, KEY_RIGHT)
	check(viewer.index == 0, "next wraps to title")
	key(viewer, KEY_RIGHT)
	check(viewer.index == 1, "next selects casting off")
	viewer.picker.item_selected.emit(13)
	check(viewer.index == 13 and viewer.game.cannon.aiming, "picker selects real cannon view")
	key(viewer, KEY_H)
	check(not viewer.toolbar.visible, "H hides review controls")
	key(viewer, KEY_RIGHT)
	check(viewer.index == 14, "keyboard browsing still works with panel hidden")
	key(viewer, KEY_H)
	check(viewer.toolbar.visible, "H restores review controls")
	key(viewer, KEY_HOME)
	key(viewer, KEY_ENTER)
	check(viewer.game.state == viewer.game.State.READY, "game input cannot advance frozen title")
	key(viewer, KEY_END)
	check(viewer.index == States.CASES.size() - 1, "End selects last state")
	if DisplayServer.get_name() != "headless":
		viewer.show_state(13)
		await process_frame
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
		await viewer.capture()
		var screenshot := ProjectSettings.globalize_path(viewer.output).path_join("14-cannon.png")
		check(FileAccess.file_exists(screenshot), "S capture saves a clean game frame")
		check(viewer.toolbar.visible and not viewer.capturing, "capture restores review controls")
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(viewer.output).path_join("review-controls.png"))
	print("UI REVIEW: %d checks, %d failures" % [checks, failures])
	viewer.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

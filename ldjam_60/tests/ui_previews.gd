extends SceneTree
## Capture the same frozen states used by ui_review.tscn, plus a local HTML gallery.
const States = preload("res://tests/ui_review_states.gd")
var game
var states: RefCounted
var output := "res://../build/ui_review/current"
var requested_size := Vector2i(1280, 720)
var failures := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			if dimensions.size() != 2 or int(dimensions[0]) < 900 or int(dimensions[1]) < 506:
				push_error("Use --size=WIDTHxHEIGHT, at least 900x506.")
				quit(1)
				return
			requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI previews require a real renderer.")
		quit(1)
		return
	output = ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create capture directory: " + output)
		quit(1)
		return
	root.gui_embed_subwindows = true
	root.size = requested_size
	await process_frame
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	states = States.new(game)
	var cards := ""
	for index in range(States.CASES.size()):
		states.apply(index)
		await process_frame
		await process_frame
		var problem: String = states.problem(index)
		if not problem.is_empty():
			push_error(problem)
			failures += 1
		var control: Control = states.tooltip_control(index)
		var motion := InputEventMouseMotion.new()
		motion.position = control.get_global_rect().get_center() if control != null else Vector2(4, 4)
		root.push_input(motion)
		if control != null:
			await create_timer(0.8).timeout # Real native tooltip, including its delay.
		for frame in range(8):
			await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
		var pixels := root.get_texture().get_image()
		var filename := "%02d-%s.png" % [index + 1, States.CASES[index][0]]
		var result := pixels.save_png(output.path_join(filename))
		if pixels.get_size() != requested_size or result != OK:
			push_error("Capture failed or size mismatch: " + filename)
			failures += 1
		print("UI CAPTURE %s: %s error=%d" % [filename, pixels.get_size(), result])
		cards += '<article><a href="%s"><img loading="lazy" src="%s" alt="%s"></a><h2>%02d · %s</h2><p>%s</p></article>\n' % [filename, filename, States.CASES[index][1].xml_escape(), index + 1, States.CASES[index][1].xml_escape(), States.CASES[index][2].xml_escape()]
	var gallery := FileAccess.open(output.path_join("index.html"), FileAccess.WRITE)
	if gallery == null:
		failures += 1
	else:
		gallery.store_string('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Latitude Lines — UI review</title><style>body{background:#102d35;color:#f5efdc;font:16px system-ui;margin:24px}header{max-width:900px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,520px),1fr));gap:24px}article{background:#173e48;padding:12px;border-radius:10px}img{width:100%;display:block}h2{font-size:18px;color:#e6bf7c}p{line-height:1.5}a{color:#e6bf7c}</style><header><h1>Latitude Lines · UI review</h1><p>34 frozen states from the real game renderer. Click any screenshot for full size. These are staged presentation fixtures, not a human playthrough. The final chart is development-only. Authored tooltips are shown with hover enabled by the test; gameplay gauges currently ignore mouse input.</p><p>Live browser: open <strong>tests/ui_review.tscn</strong> in Godot and press <strong>F6</strong>. Use ←/→ or the picker, H to hide the review panel, S to save a clean frame.</p></header><main>''' + cards + "</main></html>")
	print("UI PREVIEWS: %d captures, %d failures — %s" % [States.CASES.size(), failures, output])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

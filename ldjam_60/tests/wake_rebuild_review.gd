extends SceneTree
## Optional paired geometry/CPU check against an unmodified wake script snapshot.
## --reference=/absolute/path/wake_before.gd --output=/tmp/wake-review.json
const Wake = preload("res://game/ocean/wake_trail.gd")
var reference := ""
var output := "/tmp/blackwater-wake-review.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): reference = arg.trim_prefix("--reference=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if reference.is_empty():
		push_error("Supply --reference with the original wake script snapshot")
		quit(2)
		return
	var legacy := GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string(reference)
	if legacy.reload() != OK: quit(2); return
	var old = legacy.new()
	var current = Wake.new()
	for wake in [old, current]:
		root.add_child(wake)
		var material := ShaderMaterial.new()
		material.shader = load("res://game/ocean/wake.gdshader")
		wake.setup(material)
	var max_error := 0.0
	var checks := 0
	for hz in [30, 60, 120]:
		old.clear_path()
		current.clear_path()
		var at := Vector3.ZERO
		for tick in 12*hz:
			var time: float = float(tick)/hz
			var heading := sin(time*0.6)
			var speed := 22.0 if time<6 else 0.0
			at += Vector3(sin(heading), 0, -cos(heading))*speed/hz
			if tick == 5*hz: at += Vector3(50, 0, 0)
			for wake in [old, current]: wake.advance_path(at, time, 1.0/hz, speed/7.5, heading)
			if tick%hz != 0: continue
			checks += 1
			for kind in 2:
				var a: Array = old.buffers[kind]
				var b: Array = current.buffers[kind]
				assert(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX])
				assert(a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV])
				assert(a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR])
				for i in a[Mesh.ARRAY_VERTEX].size():
					max_error = maxf(max_error, a[Mesh.ARRAY_VERTEX][i].distance_to(b[Mesh.ARRAY_VERTEX][i]))
	assert(max_error < 0.0001, "Wake positions must retain the original shape")
	var results := []
	# Alternate order across rounds to reduce ordering/thermal bias.
	for round_index in 6:
		for label in (["before", "after"] if round_index%2 == 0 else ["after", "before"]):
			var wake = old if label == "before" else current
			var started := Time.get_ticks_usec()
			for tick in 1200:
				var time: float = float(tick)/60
				wake.advance_path(Vector3(sin(time)*10, 0, -time*12), time, 1.0/60, 2.0, time*0.1)
			results.append({"case":label, "round":round_index, "us_per_update":float(Time.get_ticks_usec()-started)/1200})
	var report := {"geometry_checks":checks, "max_vertex_error_m":max_error, "timings":results,
		"note":"CPU advance_path timing; headless runs do not measure GPU cost or whole-game FPS."}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WAKE REVIEW " + JSON.stringify(report))
	old.queue_free()
	current.queue_free()
	await process_frame
	quit()

extends SceneTree
## Exercise audio cleanup after title, pause and both results, then the main close hook.
const Shutdown = preload("res://game/audio_shutdown.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	for state in ["title", "paused", "victory", "loss"]:
		var game = load("res://game/crossing.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.cannon.set_physics_process(false)
		check(auto_accept_quit and not game._owns_quit_request, state + ": fixture leaves window quit policy alone")
		check(game._music.playing, state + ": real music playback is active")
		if state != "title":
			game.start_crossing()
			game._physics_process(game.CAST_OFF_SECONDS)
			if state == "paused": game.set_paused(true)
			elif state == "victory": game.begin_result(true)
			else: game.take_damage(game.hull_capacity, "shutdown fixture")
		var released := await Shutdown.release_scene(game, self)
		check(released and not is_instance_valid(game), state + ": all audio releases before scene teardown completes")
		check(not paused, state + ": teardown leaves no stale tree pause")
	# change_scene_to_file follows the actual main-scene lifecycle, unlike add_child.
	check(change_scene_to_file("res://game/crossing.tscn") == OK, "main scene loads normally")
	await scene_changed
	var main = current_scene
	check(main._owns_quit_request and not auto_accept_quit, "main scene owns the native window-close request")
	check(await Shutdown.release_scene(main, self) and auto_accept_quit, "scene unload restores the previous native quit policy")
	check(change_scene_to_file("res://game/crossing.tscn") == OK, "main scene reloads after cleanup")
	await scene_changed
	main = current_scene
	if failures:
		await Shutdown.release_scene(main, self)
		print("AUDIO SHUTDOWN: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	main.set_physics_process(false)
	main.start_crossing()
	main._physics_process(main.CAST_OFF_SECONDS)
	main.set_paused(true)
	check(paused, "main scene is paused before closing")
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	# A repeated close must not enqueue another teardown. Exit comes from the hook.
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(main._closing, "paused main scene accepts repeated close requests once")
	print("AUDIO SHUTDOWN: %d checks, %d failures; awaiting native close cleanup" % [checks, failures])

extends RefCounted
## Finish queued audio fades before destroying a scene/process. Only used at teardown.
const TIMEOUT_MS := 500

static func stop_players(scene: Node) -> Array[WeakRef]:
	var pending: Array[WeakRef] = []
	var players := scene.find_children("*", "AudioStreamPlayer", true, false)
	players.append_array(scene.find_children("*", "AudioStreamPlayer2D", true, false))
	players.append_array(scene.find_children("*", "AudioStreamPlayer3D", true, false))
	for player in players:
		if player.has_stream_playback():
			pending.append(weakref(player.get_stream_playback()))
		player.stop()
		player.stream = null
	return pending

static func drain(tree: SceneTree, pending: Array[WeakRef]) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while pending.any(func(playback: WeakRef) -> bool: return playback.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_error("Audio playback did not release within the shutdown deadline")
			return false
		# Fixed-fps/headless fixtures can run faster than the audio mixer. Yield a
		# real millisecond as well as a frame; never delay the browser's main thread.
		if not OS.has_feature("web"): OS.delay_msec(1)
		await tree.process_frame
	return true

static func release_scene(scene: Node, tree: SceneTree) -> bool:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var pending := stop_players(scene)
	# process_frame precedes drawing; allow one complete frame of queued uploads
	# before freeing a scene that may have just been created.
	for frame in 2: await tree.process_frame
	scene.queue_free()
	await tree.process_frame
	return await drain(tree, pending)

static func close_scene(scene: Node) -> void:
	var tree := scene.get_tree()
	var clean := await release_scene(scene, tree)
	tree.quit(0 if clean else 1)

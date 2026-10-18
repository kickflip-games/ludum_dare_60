extends SceneTree
## Actual Ogg playback, loop boundary, mute and voyage lifecycle checks.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func _run() -> void:
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var music: AudioStreamPlayer = game._music
	check(music.playing and game.state == game.State.READY, "music starts on title")
	check(music.stream is AudioStreamOggVorbis and music.stream.loop, "supplied Ogg loops")
	check(music.stream.get_length() > 41.0 and music.stream.get_length() < 42.0, "full supplied track loaded")
	check(music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "stream playback selected for Web")
	music.seek(music.stream.get_length() - 0.15)
	await create_timer(0.6).timeout
	check(music.playing and music.get_playback_position() < 2.0, "playback crosses loop boundary")
	var mute := InputEventAction.new()
	mute.action = "mute_sea"
	mute.pressed = true
	game._unhandled_input(mute)
	check(not game._sound_enabled and music.volume_db == -80.0, "M mutes music with existing sound")
	game.start_crossing()
	game.set_paused(true)
	await process_frame
	check(not music.can_process(), "game pause suspends music")
	game.set_paused(false)
	check(music.can_process() and music.playing, "resume keeps the same playing stream")
	game.restart()
	check(game._music == music and music.volume_db == -80.0, "retry preserves one player and mute")
	game._unhandled_input(mute)
	check(game._sound_enabled and music.volume_db == -18.0, "M restores background volume")
	for ending in [game.State.LOST, game.State.ARRIVED]:
		game.state = ending
		await process_frame
		check(music.playing, "result screen retains music: %s" % ending)
	game.restart(true)
	check(game.state == game.State.READY and game.get_node("BackgroundMusic") == music, "main menu reuses music")
	game.remove_child(music)
	game.free()
	check(not music.playing, "scene exit stops music")
	music.free()
	print("Music: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

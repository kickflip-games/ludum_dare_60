extends "res://tests/arcade_controls_smoke.gd"
## Normal camera, matched flash sequence and dedicated native thunder playback.

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	if output.is_empty(): output = "/tmp/blackwater-lightning"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.enemy_encounters._begin_wave()
	game.hud._process(3.2)
	for i in 90: game._update_view(1.0 / 60)
	var lightning = game.storm_lightning
	await capture("01-before")
	lightning.next_strike_in = 0
	game._update_view(0)
	game._update_view(0.05)
	await capture("02-flash-peak")
	game._update_view(0.15)
	await capture("03-flash-decay")
	game._update_view(0.3)
	await capture("04-after")
	game._update_view(2.5)
	check(lightning.player.playing, "dedicated native thunder playback starts after delay")
	check(lightning.player != game._danger_audio, "thunder does not interrupt the danger cue player")
	check(lightning.player.stream.save_to_wav(output.path_join("thunder.wav")) == OK, "save exact runtime thunder sample")
	await create_timer(0.2).timeout
	game._sound_enabled = false
	game._update_view(0.01)
	check(not lightning.player.playing, "mute stops a rumble already playing")
	lightning.next_strike_in = 0
	game._update_view(0)
	game._update_view(3)
	check(not lightning.player.playing, "muted pending thunder remains silent")
	game._sound_enabled = true
	lightning.next_strike_in = 0
	game._update_view(0)
	game._update_view(3)
	check(lightning.player.playing, "unmuted later strike plays thunder again")
	game.restart()
	check(not lightning.player.playing and lightning.pending_thunder < 0, "Retry stops ongoing thunder and pending events")
	game.state = game.State.SAILING
	game.motion_setting = 1
	lightning.next_strike_in = 0
	game._update_view(0)
	game._update_view(0.05)
	await capture("05-reduced-no-flash")
	game.queue_free()
	await process_frame
	print("STORM LIGHTNING NATIVE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

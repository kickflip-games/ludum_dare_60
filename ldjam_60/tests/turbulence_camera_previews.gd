extends "res://tests/dynamic_water_previews.gd"
## Development-only production fixture. No fixture or control ships in release.
var views_only := false
var effects := true

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/water_review/turbulence_camera/after")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--clip": record_clip = true
		if arg == "--views-only": views_only = true
		if arg == "--no-effects": effects = false
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output.path_join("clip"))
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.development_tools = true
	if "development_spray" in game:
		game.development_spray = effects
		game.development_overlays = effects
		game.development_sound = effects
	await physics_frame
	place()
	await capture("01-calm-deck")
	game.starboard_look = true
	await advance(0.4)
	await capture("02-glance")
	game.starboard_look = false
	game.cannon.set_fire_held(true)
	game.cannon.set_fire_held(false)
	await advance(0.6)
	await capture("03-real-cannon")
	game.reading = true
	for frame in range(120): game._update_view(DT)
	game.hud._process(DT)
	await capture("04-sighting")
	if not views_only:
		for scenario in ["front","port","starboard","oblique","four"]:
			place()
			var directions := {"front":Vector2.DOWN,"port":Vector2.RIGHT,"starboard":Vector2.LEFT,"oblique":Vector2(1,1).normalized()}
			if scenario == "four":
				for direction: Vector2 in directions.values(): crest(direction,1.85,3.0)
			else:
				crest(directions[scenario],1.85,3.0)
			await advance(2.8,0.0,record_clip)
			await capture(scenario+"-impact")
			await advance(5.2,0.0,record_clip)
			await capture(scenario+"-recovery")
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":frames,"trace":trace},"\t"))
	game.queue_free()
	await process_frame
	quit()

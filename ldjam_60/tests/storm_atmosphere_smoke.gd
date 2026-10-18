extends "res://tests/arcade_controls_smoke.gd"
## Cosmetic storm, opt-out, shared time, reset and live simultaneous inputs.

func _run() -> void:
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
	var effect = game.storm_atmosphere
	var material: ShaderMaterial = effect.shader_material
	game._update_view(0)
	check(effect.visible and effect.layer < game.hud.get_parent().layer, "storm renders beneath HUD and menus")
	check(effect.screen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "storm cannot capture menu or firing clicks")
	check(is_equal_approx(game.storm_blend, game.arena_storm_strength), "retry immediately restores authored arena storm")
	check(float(game.sky_material.get_shader_parameter("cloud_density")) > game.cloud_density, "storm thickens existing clouds")
	var field = game.ocean.wave_field
	var height: float = game.ocean.height_at(Vector2(game.boat.position.x, game.boat.position.z))
	var position: Vector3 = game.boat.position
	game.storm_post_enabled = false
	game._update_view(0)
	check(not effect.visible, "post-processing has an independent editor opt-out")
	check(game.ocean.wave_field == field and game.ocean.height_at(Vector2(position.x, position.z)) == height and game.boat.position == position,
		"post toggle preserves wave sampling and physical hull")
	game.storm_post_enabled = true
	game.sea_time = 35.25
	game._update_view(0)
	check(material.get_shader_parameter("visual_time") == game.sea_time, "rain uses shared sea time")
	game.motion_setting = 1
	game._update_view(0)
	check(material.get_shader_parameter("rain_amount") == 0.0 and effect.visible, "Reduced motion retains static grade without moving rain")
	game.motion_setting = 0
	game.weather_enabled = false
	game._update_view(0)
	check(not effect.visible and game.sky_material.get_shader_parameter("cloud_density") == game.cloud_density, "weather opt-out removes storm overlay and added cover")
	game.weather_enabled = true
	game.arena_mode = false
	game._update_view(0)
	check(not effect.visible, "legacy voyage presentation remains independent")
	game.arena_mode = true
	game.restart()
	game.state = game.State.SAILING
	key(KEY_D, true)
	key(KEY_SPACE, true)
	key(KEY_SHIFT, true)
	step(2)
	check(game.turn_input == 1 and game.cannon.shots_fired >= 2 and game.boosting, "storm permits simultaneous steering, held fire and boost")
	key(KEY_D, false)
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	step(0.1)
	check(game.turn_input == 0 and not game.boosting, "release remains responsive in storm")
	game.boat.position = game.arena_center() + Vector3(game.arena_radius + 30, 0, 0)
	for i in 600: game._update_view(1.0 / 60)
	check(game.storm_blend > 0.99 and game.hull == game.hull_capacity, "outer storm intensifies without weather damage")
	for ending in [game.State.LOST, game.State.ARRIVED, game.State.READY]:
		game.state = ending
		game.restart(ending == game.State.READY)
		check(is_equal_approx(game.storm_blend, game.arena_storm_strength) and material.get_shader_parameter("visual_time") == 0.0,
			"state %d retry clears outer weather and rain clock" % ending)
	game.queue_free()
	await process_frame
	print("STORM ATMOSPHERE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

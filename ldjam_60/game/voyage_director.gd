extends RefCounted
## Three sequential regional discoveries. Navigation forces live in wave_sailing.gd.
enum Stage { WRECK, TWIN_PEAKS, LIGHTHOUSE, COMPLETE }
var stage: Stage = Stage.WRECK

func reset(_seed_value: int) -> void:
	stage = Stage.WRECK

func region(game: Node3D) -> Marker3D:
	return game.archipelago.get_node("NavigationRegions").get_child(mini(stage, Stage.LIGHTHOUSE))

func set_target(game: Node3D) -> void:
	game.target = region(game).global_position
	game.focus_elapsed = 0.0
	game.focus_strength = 0.0
	game.has_reading = false
	# Clear the previous star immediately, including between physics and HUD updates.
	if is_instance_valid(game.sky_material):
		game.sky_material.set_shader_parameter("active_star", mini(stage, Stage.LIGHTHOUSE))
		game.sky_material.set_shader_parameter("target_focus", 0.0)
	if is_instance_valid(game.hud):
		game.hud._update_sighting_text()

func update_progress(game: Node3D) -> void:
	if stage == Stage.COMPLETE or game.state != game.State.SAILING:
		return
	var destination := region(game)
	if game.boat.global_position.distance_to(destination.global_position) > destination.radius:
		return
	game.cue_sound("victory")
	stage = (stage + 1) as Stage
	if stage == Stage.COMPLETE:
		game.show_discovery("Lighthouse Harbour · home at last", 2.8)
		game.state = game.State.ARRIVED
	else:
		set_target(game)
		game.show_discovery(destination.display_name + " found", 2.8)

extends "res://tests/arcade_controls_smoke.gd"
## Original player and supplied pirate ships in chase/close cameras and damage.

func capture(label: String) -> void:
	# Static combat/model fixtures show settled ships; arrival stages have their own preview.
	for vessel in game.enemy_encounters.combat_ships():
		if vessel.visible:
			vessel.sea_effects.advance_arrival(1.0)
			vessel.sea_effects.apply_arrival()
	await super.capture(label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	if output.is_empty(): output = "/tmp/latitude-ship-models"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	fresh()
	for i in 3:
		var enemy = game.enemy_encounters.ships[i]
		enemy.configure_archetype(load("res://game/enemies/%s.tres" % ["cutter", "skiff", "heavy"][i]))
		enemy.begin(game.boat.position + Vector3(24 + i * 15, 0, -8 + i * 8))
		enemy.heading = 0
		enemy.rotation.y = 0
	var boss = game.enemy_encounters.boss
	boss.begin(game.boat.position + Vector3(62, 0, -15))
	boss.heading = 0
	boss.rotation.y = 0
	for i in 60: game._update_view(1.0 / 60)
	await capture("01-player-and-fleet")
	game.arena_cannon_view = true
	for i in 60: game._update_view(1.0 / 60)
	await capture("02-close-cannon")
	game.arena_cannon_view = false
	for i in 60: game._update_view(1.0 / 60)
	game.take_damage(1, "Ship presentation check")
	game.hit_flash = 0
	game.boat_damage.update(game.hull, game.hull_capacity, 0)
	await capture("03-player-damaged")
	game.damage_immunity = 0
	game.take_damage(1, "Ship presentation check")
	game.hit_flash = 0
	game.boat_damage.update(game.hull, game.hull_capacity, 0)
	await capture("04-player-heavy-damage")
	root.size = Vector2i(900, 506)
	await capture("05-small-fleet")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

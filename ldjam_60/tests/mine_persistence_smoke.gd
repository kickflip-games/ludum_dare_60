extends "res://tests/starboard_cone_smoke.gd"
## Permanent mine hazards, physical cannon hits, obstructions and pool cleanup.

func fresh() -> void:
	super.fresh()
	# Isolate physical mine hits from the retained swell-blocks-low-shots mechanic.
	var settings = game.ocean.settings.duplicate()
	settings.height_multiplier = 0.0
	game.ocean.configure(settings)

func _run() -> void:
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var c = game.cannon
	var mine = game.enemy_encounters.ship.mine_layer.pool[0]
	for hz in [30, 60, 120]:
		for age in [0.0, 3600.0]:
			fresh()
			mine.activate(c.cone_point(0, 25))
			mine.update_mine(age)
			await sync()
			check(not mine.spent and mine.visible and mine.collision_layer == 8, "mine persists and stays shootable at age %.0f" % age)
			check(c.choose_cone_target().get("body") == mine, "cannon acquires the mine inside its existing cone")
			if hz == 60 and age > 0: await capture("01-persistent-mine")
			var hull_before: int = game.hull
			check(c.fire(), "normal player cannon fires at the mine")
			for tick in hz * 2:
				c.advance(1.0 / hz)
				if c.projectiles.is_empty(): break
			check(mine.spent and not mine.visible and mine.collision_layer == 0 and c.feedback == "MINE DESTROYED", "%d Hz physical cannonball destroys %s mine" % [hz, "armed" if age > 0 else "unarmed"])
			check(game.hull == hull_before, "shooting from outside the ring does not hurt the player")
			check(c.cone_candidate(mine).is_empty(), "destroyed mine cannot be acquired again")
			if hz == 60 and age > 0: await capture("02-shot-mine")
	fresh()
	mine.activate(c.cone_point(0, 25))
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 12, 12)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = c.cone_point(0, 12)
	await sync()
	check(c.cone_candidate(mine).is_empty(), "solid obstacles block mine acquisition")
	c.fire()
	for tick in 120: c.advance(1.0 / 60)
	check(not mine.spent and c.feedback.contains("SOLID REEF"), "physical cannonball cannot shoot a mine through a solid")
	wall.queue_free()
	await physics_frame
	mine.activate(c.cone_point(c.cone_half_angle + 5, 25))
	check(c.cone_candidate(mine).is_empty(), "mine outside the firing cone is not acquired")
	mine.activate(c.cone_point(0, c.cone_range + 5))
	check(c.cone_candidate(mine).is_empty(), "mine beyond cannon range is not acquired")
	# Use an owned trail to exercise normal retry cleanup.
	game.enemy_encounters.ship.mine_layer.mines.append(mine)
	game.restart()
	check(mine.spent and mine.collision_layer == 0, "retry clears persistent mine and its shot collider")
	game.queue_free()
	await process_frame
	print("MINE PERSISTENCE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

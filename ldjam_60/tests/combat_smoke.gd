extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func _run() -> void:
	var game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	check(game.hull == 3 and not game.cannon.fire(), "three-hit hull and cannon gated on the title")
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.current_strength = 0.0
	game.gust_strength = 0.0
	game.heading = game.TARGET_HEADING
	# Isolate collision damage from navigation landmarks and arrival triggers.
	game._add_hazard(Vector3(400, 0, 360), 3.0, "rock")
	var rock: Dictionary = game.obstacles.back()
	game.boat.position = rock.position - Vector3(sin(game.heading), 0, -cos(game.heading)) * (rock.radius + 3.0)
	await physics_frame
	game.advance_sailing(1.0, 0.0)
	check(game.hull == 2 and game.state == game.State.SAILING, "actual rock collision damages but does not instantly sink")
	for i in range(60):
		game.take_damage(1, "repeated contact")
	check(game.hull == 2, "short immunity rejects per-frame repeated damage")
	check(game.hit_flash > 0.0 and game.damage_shake_left > 0.0, "hit gives restrained camera impulse and hull flash")
	game.damage_immunity = 0.0
	check(game.take_damage(1, "second breach") and game.hull == 1, "second significant hit leaves one hull")
	game.damage_immunity = 0.0
	check(game.take_damage(1, "third breach") and game.state == game.State.LOST, "third significant hit sinks the boat")
	game._update_view(1.0)
	game._update_view(1.0)
	check(game.boat_visual.position.y < -1.5, "sinking lowers the visual hull while physics root stays planar")
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	check(game.hull == 3 and game.damage_immunity == 0.0 and game.hits_taken == 0, "retry restores hull and damage state")
	game.heading = game.TARGET_HEADING
	game._update_view(1.0)
	var origin: Vector3 = game.cannon.shot_origin()
	var at: Vector3 = origin + game.cannon.starboard_direction() * 22.0
	at.y = 0.0
	game._add_hazard(at, 3.0, "debris")
	var body = game.obstacles[-1].body
	await physics_frame
	check(game.cannon.aim_target().get("aligned", false), "fixed broadside cue aligns with a real raycast target")
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	check(game.cannon.fire() and game.cannon.flash.visible, "cannon fires with visible muzzle flash")
	check(not game.cannon.fire(), "reload prevents immediate second shot")
	check(absf(game.cannon.projectiles[0].velocity.dot(Vector3(sin(game.heading), 0, -cos(game.heading)))) < 0.01,
		"projectile still fires perpendicular to the bow")
	for i in range(45):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
	check(body.get_meta("destroyed") and body.collision_layer == 0, "correctly positioned broadside destroys timber and collision")
	check(game.cannon.feedback.contains("TIMBER") and game.cannon.effects.size() > 0, "timber impact gives splinters and splash feedback")
	game.cannon.advance(2.0)
	game.reading = true
	check(not game.cannon.fire(), "astrolabe must be lowered to fire")
	game.reading = false
	game.cannon.fire()
	for i in range(120):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
		if game.cannon.projectiles.is_empty():
			break
	check(game.cannon.feedback.contains("SPLASH"), "a missed cannonball gives distinct water-hit feedback")
	game.restart()
	game.state = game.State.SAILING
	game.boat.position = Vector3(400, 0, 320)
	game.heading = 0.0
	game.boat.rotation.y = 0.0
	game._update_view(1.0)
	var barrels_at: Vector3 = game.cannon.shot_origin() + game.cannon.starboard_direction() * 22.0
	barrels_at.y = 0.0
	game._add_hazard(barrels_at, 2.5, "barrels")
	var barrels = game.obstacles.back().body
	await physics_frame
	game.boat.position = barrels_at - Vector3(0, 0, -1) * 5.0
	game.advance_sailing(1.0, 0.0)
	check(game.hull == 2 and game.hit_message.contains("BARRELS"), "floating barrels physically obstruct sailing and damage the hull")
	game.boat.position = Vector3(400, 0, 320)
	game.boat.rotation.y = 0.0
	game._update_view(1.0)
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	check(game.cannon.fire(), "barrel cluster can be targeted with the existing broadside")
	for i in range(60):
		game.cannon.advance(1.0 / 60.0)
		await physics_frame
	check(barrels.get_meta("destroyed") and barrels.collision_layer == 0 and not barrels.visible, "real cannonball clears the barrel cluster and its collision")
	game.restart()
	check(game.cannon.projectiles.is_empty() and game.cannon.effects.is_empty(), "retry clears all shots, splash rings, and reload")
	check(game.obstacles.size() == game.archipelago.get_node("Hazards").get_child_count() + 1, "retry restores all authored obstacles without accumulating debris")
	game.queue_free()
	await process_frame
	print("COMBAT CHECK: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

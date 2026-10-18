extends "res://tests/naval_ai_smoke.gd"

func independent_states() -> void:
	var game = await make_game()
	var ship = game.enemy_encounters.ship
	game.boat.position = Vector3(215, 0, 325)
	game.heading = PI / 2.0
	game.boat.rotation.y = -game.heading
	game.boat.velocity = Vector3.RIGHT * game.SPEED
	ship.configure_archetype(load("res://game/enemies/cutter.tres"))
	ship.begin(game.boat.position + Vector3(16, 0, 60))
	var seen := {}
	var sails_while_warning := 0.0
	var sails_while_reload := 0.0
	var committed := true
	var independent := true
	var trace: Array[Dictionary] = []
	for frame in 20 * 60:
		var at: Vector3 = ship.position
		var course: float = ship.run_heading
		var previous: int = ship.navigation_state
		var previous_weapon: int = ship.weapon_state
		game.advance_sailing(1.0 / 60.0, 0.0)
		ship.update_ship(1.0 / 60.0)
		if previous == ship.Navigation.APPROACH and ship.navigation_state == previous:
			committed = committed and (course == ship.run_heading or ship._course_age < 0.001)
		if previous_weapon == ship.Weapon.TELEGRAPH:
			sails_while_warning += ship.position.distance_to(at)
		if previous_weapon == ship.Weapon.RELOAD:
			sails_while_reload += ship.position.distance_to(at)
		if previous_weapon != ship.weapon_state and previous == ship.Navigation.ATTACK_RUN and ship.navigation_state == previous:
			independent = independent and ship.navigation_time > 0.0
		seen[ship.navigation_state] = true
		if frame % 30 == 0:
			trace.append({"seconds": ship.age, "navigation": ship.navigation_state,
				"weapon": ship.weapon_state, "heading": ship.heading,
				"x": ship.position.x, "z": ship.position.z})
		await physics_frame
	check(committed, "approach course changes only at the bounded four-second interception refresh")
	check(independent and sails_while_warning > 2.0 and sails_while_reload > 10.0,
		"weapon transitions preserve the sailing clock and actual forward motion")
	check(seen.has(ship.Navigation.ATTACK_RUN) and seen.has(ship.Navigation.TURN_AWAY) and seen.has(ship.Navigation.REPOSITION),
		"independent navigation completes attack, broad turn and reposition")
	results.append({"single_state_trace": trace, "warning_travel": sails_while_warning, "reload_travel": sails_while_reload})
	game.queue_free()
	await process_frame

func _run() -> void:
	await route("cutter", 30)
	await route("cutter", 60)
	await route("heavy", 60)
	await independent_states()
	var stationary := await broadside("heavy", false)
	var dodged := await broadside("heavy", true)
	check(stationary.hits > 0 and dodged.hits < stationary.hits, "changing course spoils a real committed broadside")
	var output := FileAccess.open("/tmp/latitude-attack-runs.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	print("ATTACK RUN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Exercise cosmetic state through real damage/repair paths, with negative controls.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1


func reset_voyage() -> void:
	game.restart()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(400, 0, -280)
	game.heading = 0.0
	game._update_view(0.0)


func sail(seconds: float, fps: int = 60) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var delta := minf(remaining, 1.0 / fps)
		game._physics_process(delta)
		remaining -= delta


func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	var visuals = game.boat_damage
	check(not game.take_damage(1, "title contact") and visuals.severity == 0, "title cannot take damage or show scratches")
	reset_voyage()
	check(not visuals.light_marks.visible and not visuals.heavy_marks.visible and visuals.flash_strength == 0.0, "fresh full-health boat has no damage effects")
	check(visuals.light_marks.get_parent() == game.boat_visual and visuals.heavy_marks.get_parent() == game.boat_visual, "scratches follow the rocking visual pivot, separate from collision")
	var imported: Node3D = game.PLAYER_SAIL_BOAT.instantiate()
	var original := imported.get_node("RootNode/Boat") as MeshInstance3D
	var player := game.boat_visual.get_node("SailBoatPlayer/RootNode/Boat") as MeshInstance3D
	check(player.mesh == original.mesh and player.get_active_material(0) != original.get_active_material(0), "mesh is shared but hit-flash materials are unique to the player")
	imported.free()
	check(not game.take_damage(0, "empty contact") and not game.take_damage(-1, "invalid contact") and game.hull == 3 and game.hits_taken == 0 and visuals.flash_strength == 0.0, "non-positive damage neither heals nor triggers hit feedback")
	sail(2.0)
	check(visuals.severity == 0 and visuals.flash_strength == 0.0 and game.hits_taken == 0, "time passing without a hit never creates damage feedback")
	check(game.take_damage(1, "first hit") and visuals.severity == 1 and visuals.light_marks.visible and not visuals.heavy_marks.visible, "accepted single hit immediately reveals only the two stern scratches")
	check(visuals.flash_strength == 1.0 and visuals.wood[0].emission_energy_multiplier > 0.0 and game.hit_message == "FIRST HIT", "accepted damage immediately gives a short wood flash and keeps the damage reason")
	game._update_view(0.1)
	var faded: float = visuals.flash_strength
	for contact in range(60):
		game.take_damage(1, "immune contact")
	check(game.hull == 2 and game.hits_taken == 1 and visuals.flash_strength == faded, "rapid immune contacts cannot accumulate damage or retrigger the flash")
	game._update_view(0.1)
	check(visuals.flash_strength == 0.0 and visuals.red_strength == 0.0 and visuals.wood[0].emission_energy_multiplier == 0.0 and visuals.light_marks.visible and visuals.smoke.visible, "impact red clears within 0.2 seconds while smoke and scratches persist")
	sail(game.hit_immunity_seconds + 0.01)
	check(game.take_damage(1, "second hit") and game.hull == 1 and visuals.heavy_marks.visible and visuals.light_marks.visible, "a second hit after immunity adds heavy damage without losing the stern marks")
	check(visuals.severity == 2 and visuals.smoke.visible, "critical hull has persistent smoke immediately")
	var before: Vector3 = game.boat.position
	var heading: float = game.heading
	Input.action_press("steer_starboard")
	sail(0.3)
	Input.action_release("steer_starboard")
	check(game.boat.position.distance_to(before) > 0.5 and absf(game.heading - heading) > 0.01, "heavily damaged boat keeps automatic forward motion and real steering input")
	sail(7.69)
	check(game.hull == 1 and visuals.severity == 2, "heavy marks persist until the full unchanged eight-second interval")
	sail(0.01)
	check(game.hull == 2 and visuals.severity == 1 and not visuals.heavy_marks.visible, "first automatic repair immediately removes heavy marks")
	sail(8.0)
	check(game.hull == 3 and visuals.severity == 0 and not visuals.light_marks.visible and visuals.flash_strength == 0.0, "second automatic repair removes every mark and leaves no flash")
	check(game.take_damage(1, "hit after repair") and visuals.severity == 1 and visuals.flash_strength == 1.0, "damage and hit feedback return after complete recovery")
	sail(7.0)
	check(game.take_damage(1, "interrupt repair") and game.hull_repair_elapsed == 0.0 and visuals.severity == 2, "another hit during recovery immediately increases damage and resets existing progress")
	sail(1.0)
	check(game.hull == 1 and visuals.severity == 2, "interrupted repair cannot complete using time before the new hit")
	check(game.restore_hull(99) and game.hull == 3 and visuals.severity == 0 and not game.restore_hull(1), "salvage restoration clamps at capacity and clears scratches")
	for fixture in [[100, 67, 0], [100, 66, 1], [100, 34, 1], [100, 33, 2], [3, 2, 1], [3, 1, 2], [6, 6, 0], [6, 4, 1], [6, 2, 2], [1, 1, 0], [1, 0, 2]]:
		visuals.update(fixture[1], fixture[0], 0.0)
		check(visuals.severity == fixture[2], "health percentage drives severity at %d/%d" % [fixture[1], fixture[0]])
	check(not visuals.smoke.visible, "zero hull stops persistent smoke before sinking")
	var canvas := (game.boat_visual.get_node("SailBoatPlayer/RootNode/Sail") as MeshInstance3D).get_active_material(1) as ShaderMaterial
	for fps in [30, 60, 120]:
		reset_voyage()
		game.take_damage(1, "flash cadence")
		sail(0.2, fps)
		check(visuals.flash_strength == 0.0 and visuals.severity == 1, "short flash expires and marks remain at %d Hz" % fps)
		var before_smoke: int = visuals.smoke_emitted
		for frame in fps * 2: game._update_view(1.0 / fps)
		check(visuals.smoke_emitted - before_smoke in range(12, 15) and visuals.red_strength == 0.0, "strong damaged smoke persists without red glow at %d Hz" % fps)
		var frozen: float = visuals.smoke_clock
		game._update_view(0.0)
		check(is_equal_approx(frozen, visuals.smoke_clock), "zero simulation delta freezes hull smoke")
		check(canvas.get_shader_parameter("damage_glow") == 0.0, "sail returns to restrained scorch after impact")
		game.restore_hull(99)
		check(visuals.red_strength == 0.0 and canvas.get_shader_parameter("damage_glow") == 0.0 and visuals.wood[0].albedo_color == visuals._wood_colors[0] and canvas.get_shader_parameter("canvas_color") == visuals._canvas_color, "full repair restores original wood and canvas")
		game.damage_immunity = 0.0
		game.take_damage(2, "critical pulse")
		game._update_view(0.2)
		before_smoke = visuals.smoke_emitted
		for frame in fps * 2: game._update_view(1.0 / fps)
		check(visuals.smoke_emitted - before_smoke in range(24, 27) and visuals.red_strength == 0.0, "critical smoke is more frequent without persistent glow at %d Hz" % fps)
	reset_voyage()
	# Real ballistic path and physics raycast, no direct damage call in this fixture.
	var ship = game.enemy_encounters.ship
	ship.begin(game.boat.position + Vector3(30, 0, 0))
	ship.locked_point = game.boat.position + Vector3(0, 0.65, -0.5)
	await physics_frame
	ship._fire()
	for frame in range(240):
		ship._advance_shots(1.0 / 60.0)
		if ship.projectiles.is_empty():
			break
		await physics_frame
	check(ship.shots_hit == 1 and game.hull == 2 and visuals.severity == 1 and visuals.flash_strength > 0.0, "enemy cannonball really damages the player and triggers scratches/flash")
	reset_voyage()
	game.damage_immunity = 0.0
	game.take_damage(99, "lethal hit")
	sail(1.5)
	check(game.hull == 0 and game.state == game.State.LOST and visuals.severity == 2 and game.boat_visual.position.y < -1.5, "lethal damage preserves loss and the existing visual sinking")
	check(not game.take_damage(1, "late hit") and not game.restore_hull(3), "lost boat accepts neither new damage feedback nor repair")
	var retry := InputEventAction.new()
	retry.action = "restart_crossing"
	retry.pressed = true
	game._unhandled_input(retry)
	check(game.state == game.State.CASTING_OFF and game.hull == 3 and visuals.severity == 0 and visuals.flash_strength == 0.0 and visuals.red_strength == 0.0 and visuals.smoke_clock == 0.0 and not visuals.smoke.visible and not visuals.light_marks.visible and not visuals.heavy_marks.visible, "real retry input clears all persistent and transient damage effects")
	game.hud._process(0.0)
	check(game.hud.gameplay_hud.get_node_or_null("Hull") == null and not game.hud.menu_details.text.contains("Hull"), "neither gameplay nor result UI contains a hull indicator")
	print("DAMAGE CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

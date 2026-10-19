extends SceneTree
## Current arena health paths, finite visual budget and native gameplay-camera review.
var game
var checks := 0
var failures := 0
var capture_frames := false
var output := "/tmp/blackwater-hull-condition"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture_frames = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func step(seconds: float) -> void:
	# Manual review ticks own focus, as in the controls fixtures. Real-time checks
	# below still use normal notifications and callbacks.
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.set_paused(false, false)
	for frame in roundi(seconds * 60):
		game._physics_process(1.0 / 60)
		game.cannon._physics_process(1.0 / 60)

func capture(label: String) -> void:
	game.hud._process(0)
	if not capture_frames: return
	for frame in 3: await process_frame
	game.set_paused(false, false)
	game.hud._process(0)
	RenderingServer.force_draw(true, 1.0 / 60)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "captured " + label)

func fresh() -> void:
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.restart(true)
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(0, 0, 115)
	game.heading = 0.0
	game.sea_time = 14
	game.boat_motion.reset()
	game.ocean.reset_wake(game.heading)
	game._sailing_camera_initialized = false
	game._update_view(0)

func realtime_check() -> void:
	# Normal Godot callbacks verify the emitter while the actual ship sails.
	root.size = Vector2i(1280, 720)
	fresh()
	game.set_physics_process(true)
	game.cannon.set_physics_process(true)
	await create_timer(0.4).timeout
	var fx = game.boat_damage
	check(game.state == game.State.SAILING and not fx.smoke.visible, "real-time full hull sails without smoke")
	game.take_damage(1, "real-time first hit")
	check(fx.flash_strength == 1, "real-time accepted hit flashes immediately")
	await create_timer(1.4).timeout
	check(game.hull == 2 and fx.severity == 1 and fx.smoke.visible and fx.flash_strength == 0 and fx.smoke_clock > 1.2, "real-time damaged state persists after the flash")
	await capture("realtime-damaged")
	game.damage_immunity = 0
	game.take_damage(1, "real-time critical hit")
	await create_timer(1.4).timeout
	check(game.hull == 1 and fx.severity == 2 and fx.smoke_emitted >= 12, "real-time critical hull emits denser smoke")
	await capture("realtime-critical")
	game.restore_hull(1)
	check(fx.severity == 1 and fx.smoke_emitted == 1, "real-time partial repair replaces the plume immediately")
	game.restore_hull(1)
	check(not fx.smoke.visible and fx.smoke_emitted == 0, "real-time full repair clears smoke")
	game.restart()
	await create_timer(game.CAST_OFF_SECONDS + 0.15).timeout
	check(game.state == game.State.SAILING and game.hull == 3 and not fx.smoke.visible, "real-time restart restores a clean healthy ship")
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)

func _run() -> void:
	if capture_frames and DisplayServer.get_name() == "headless":
		push_error("Native renderer required for capture")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	var fx = game.boat_damage
	var pool_id: int = fx.smoke.get_instance_id()
	check(not fx.smoke.visible and fx.smoke_emitted == 0, "title has no smoke")
	for dimensions in [Vector2i(1280, 720), Vector2i(900, 506)]:
		root.size = dimensions
		for frame in 3: await process_frame
		fresh()
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		check(fx.severity == 0 and not fx.smoke.visible, label + " full hull is clean")
		await capture(label + "-01-healthy")
		check(game.take_damage(1, "hull smoke fixture") and fx.flash_strength == 1 and fx.smoke.visible, label + " first hit flashes and starts damage smoke")
		await capture(label + "-02-hit")
		step(1)
		check(game.hull == 2 and fx.severity == 1 and fx.red_strength == 0 and fx.smoke_emitted >= 4, label + " mid hull keeps obvious smoke after impact ends")
		await capture(label + "-03-damaged")
		# Compare a brief animated run with the unchanged chase camera and real movement.
		for sample in 4:
			step(0.15)
			await capture(label + "-damaged-%02d" % sample)
		game.damage_immunity = 0
		check(game.take_damage(1, "critical fixture"), label + " second hit respects authoritative hull")
		step(1)
		check(game.hull == 1 and fx.severity == 2 and fx.red_strength == 0 and fx.smoke_emitted >= 9, label + " critical has persistent denser smoke")
		await capture(label + "-04-critical")
		for sample in 4:
			step(0.15)
			await capture(label + "-critical-%02d" % sample)
		game.arena_cannon_view = true
		step(0.6)
		await capture(label + "-05-critical-cannon")
		game.arena_cannon_view = false
		step(0.6)
		var clock: float = fx.smoke_clock
		game.set_paused(true)
		game._physics_process(0.5)
		check(fx.smoke_clock == clock, label + " pause freezes smoke")
		game.set_paused(false, false)
		check(game.restore_hull(1) and game.hull == 2 and fx.severity == 1 and fx.smoke_emitted == 1, label + " partial repair replaces critical plume immediately")
		step(0.5)
		await capture(label + "-06-partly-repaired")
		# Exercise unchanged automatic eight-second recovery, holding only fixture position.
		var hp: int = game.hull
		game.elapsed += game.hull_repair_seconds
		game._update_hull_recovery(game.hull_repair_seconds)
		check(game.hull == hp + 1 and not fx.smoke.visible and fx.smoke_emitted == 0, label + " automatic repair clears smoke completely")
		await capture(label + "-07-repaired")
		game.damage_immunity = 0
		game.take_damage(2, "restart critical")
		step(0.5)
		game.restart()
		check(game.hull == 3 and fx.severity == 0 and not fx.smoke.visible and fx.smoke_clock == 0 and fx.smoke_emitted == 0, label + " restart clears condition and every smoke slot")
		step(game.CAST_OFF_SECONDS)
		await capture(label + "-08-restarted")
	# An actual first-wave early clear repairs critical hull through the normal scheduler.
	fresh()
	var enemies = game.enemy_encounters
	enemies.resume_wave(1)
	game.take_damage(2, "early-clear repair")
	step(0.5)
	for frame in 4:
		enemies.spawn_remaining = 0
		enemies._update_arena(0)
		for ship in enemies.living_ships():
			while ship.hull > 0: game.cannon._impact(ship, ship.position + Vector3.UP)
	enemies._update_arena(0)
	check(enemies.phase == enemies.Phase.EARLY_CLEAR and game.hull == 2 and fx.severity == 1 and fx.smoke_emitted == 1, "actual early wave clear reduces critical smoke immediately")
	game.combat_particles.muzzle(game.boat.position + Vector3.UP, Vector3.RIGHT)
	var emitted: int = game.combat_particles.emitted
	game.restore_hull(1)
	check(not fx.smoke.visible and game.combat_particles.emitted == emitted, "full repair removes only hull smoke and preserves combat effects")
	# Budget, no backlog bursts, threshold changes, death and terminal-state cleanup.
	var nodes := get_node_count()
	for frame in 600: fx.update(1, 3, 0, 1.0 / 60)
	check(get_node_count() == nodes and fx.smoke.multimesh.instance_count == 16 and fx.smoke.get_instance_id() == pool_id, "sustained critical smoke uses one fixed sixteen-puff batch without allocating nodes")
	var count: int = fx.smoke_emitted
	fx.update(1, 3, 0, 600)
	check(fx.smoke_emitted - count <= 2, "long frames cannot launch an emission backlog")
	fx.update(3, 3, 0)
	if DisplayServer.get_name() != "headless":
		var empty := true
		for index in 16: empty = empty and fx.smoke.multimesh.get_instance_color(index).a == 0
		check(empty and not fx.smoke.visible, "healthy reset erases every live instance")
	else:
		check(not fx.smoke.visible and fx.smoke_emitted == 0, "healthy reset hides smoke and resets emission")
	game.damage_immunity = 0
	game.take_damage(1, "no duplicate hit")
	count = fx.smoke_emitted
	check(not game.take_damage(1, "immune") and not game.take_damage(0, "empty") and fx.smoke_emitted == count, "immune/invalid damage cannot duplicate smoke or change health")
	game.damage_immunity = 0
	game.take_damage(9, "sinking")
	check(not fx.smoke.visible and game.state == game.State.LOST, "death stops persistent smoke before the sinking result")
	game.restart(true)
	check(not fx.smoke.visible and fx.smoke_clock == 0, "Main Menu clears smoke")
	fresh()
	game.take_damage(1, "terminal cleanup")
	game.begin_result(true)
	game._physics_process(0.1)
	check(not fx.smoke.visible, "victory settles without a stale hull emitter")
	check(game.hud.gameplay_hud.get_node_or_null("Hull") == null, "no health HUD was added")
	if OS.get_cmdline_user_args().has("--realtime"):
		await realtime_check()
	var clean := await preload("res://game/audio_shutdown.gd").release_scene(game, self)
	check(clean, "shutdown releases all audio playbacks")
	print("HULL CONDITION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

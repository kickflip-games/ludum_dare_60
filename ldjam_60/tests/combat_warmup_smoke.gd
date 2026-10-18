extends SceneTree
## A real renderer is required: verify menu-time work has no gameplay side effects.
var game
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("WARMUP: real renderer required")
		quit(2)
		return
	root.gui_disable_input = true
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	var particles = game.combat_particles
	var buffer: PackedFloat32Array = particles.mesh.buffer.duplicate()
	var particle_time = particles.material.get_shader_parameter("effect_time")
	var camera_mask: int = game.camera.cull_mask
	var hull: int = game.hull
	var state: int = game.state
	var warmup = game.cannon.combat_warmup
	var started := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute("/tmp/blackwater-first-shot")
	var warm_frame := 0
	while not warmup.complete and Time.get_ticks_msec()-started < 10000:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/blackwater-first-shot/warm-%02d.png" % warm_frame)
		warm_frame += 1
	check(warmup.complete,"Warm-up completes from home menu")
	await process_frame
	check(warmup.get_child_count() == 0,"Temporary warm-up nodes released")
	check(game.state == state and game.hull == hull,"Menu state and hull retained")
	check(game.cannon.shots_fired == 0 and game.cannon.projectiles.is_empty(),"No weapon fired during warm-up")
	check(game.cannon.projectile_visuals.leased.is_empty(),"No projectile lease consumed")
	check(not game.cannon.flash.visible and not game.cannon.flash_light.visible,"Main-world muzzle effects stay hidden")
	check(particles.mesh.buffer == buffer and particles.emitted == 0,"Real particle instance data stays untouched")
	check(particles.material.get_shader_parameter("effect_time") == particle_time and not particles.batch.visible,"Real particle material and visibility stay untouched")
	check(game.camera.cull_mask == camera_mask,"Camera visibility mask restored")
	check(game.cannon.effects.is_empty(),"No real splash emitted")
	check(not game.cannon._shot_audio.playing and not game.cannon._water_audio.playing,"No weapon or splash sound")
	var boss = game.enemy_encounters.boss
	check(boss.mines.is_empty() and boss.mine_pool.all(func(m): return m.spent and not m.visible),"No mine activated")
	DirAccess.make_dir_recursive_absolute("/tmp/blackwater-first-shot")
	RenderingServer.force_draw(true,0)
	root.get_texture().get_image().save_png("/tmp/blackwater-first-shot/menu.png")
	game.queue_free()
	await process_frame
	print("COMBAT WARMUP: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

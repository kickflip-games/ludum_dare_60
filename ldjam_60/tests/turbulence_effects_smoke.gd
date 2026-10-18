extends "res://tests/dynamic_water_previews.gd"
var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	place()
	var effects = game.turbulence_effects
	var initial_nodes := get_node_count()
	for i in range(60): game._update_view(DT)
	check(effects.emitted==0 and effects.active_count==0 and effects.envelope==0,"calm has no invented impact timers or spray bursts")
	var event := {"id":7,"strength":1.0,"direction":Vector3.RIGHT,"time":game.sea_time}
	game.deck_response.events.assign([event])
	game.deck_response.snapped = false
	effects.update_effects(game,DT)
	check(effects.emitted==1 and effects.last_events==[7] and effects.bursts[0].origin.x < game.boat.position.x,"camera contact drives a burst on the struck port side with the same wave ID")
	check(effects.active_count>0 and effects.active_count<=effects.CAPACITY,"impact spray uses a fixed bounded MultiMesh")
	game.deck_response.events.clear()
	for i in range(120): effects.update_effects(game,DT)
	check(effects.active_count==0 and effects.envelope<0.01,"spray and streaks expire without a later crest")
	# Repeated overlapping impacts replace pool slots; never allocate nodes.
	for i in range(100):
		game.deck_response.events.clear()
		for j in range(4):
			game.deck_response.events.append({"id":100+i*4+j,"strength":1.0,"direction":Vector3.RIGHT})
		effects.update_effects(game,DT)
	check(get_node_count()==initial_nodes and effects.bursts.size()==2 and effects.mesh.instance_count==64,"repeated four-wave impacts retain two burst slots, 64 instances and stable node count")
	game.deck_response.events.clear()
	game.ocean_quality = 0
	effects.reset()
	game.deck_response.events.assign([event,{"id":8,"strength":1.0,"direction":Vector3.LEFT}])
	effects.update_effects(game,DT)
	check(effects.active_count<=20 and effects.emitted==2,"Low quality caps hull droplets and disables decorative crest spray")
	game.development_spray = false
	game.development_overlays = false
	effects.update_effects(game,DT)
	check(effects.active_count==0 and effects.overlay.material.get_shader_parameter("strength")==0,"development isolation switches remove effects independently")
	game.development_spray = true
	game.development_overlays = true
	game.deck_response.events.clear()
	# Footprint is fixed in world space across a mesh recenter and decays on recovery.
	game.wave_encounters.begin_region(10,Vector2.UP,game.sea_time)
	for i in range(120): game.ocean.update_turbulence(game.wave_encounters,DT)
	var center: Vector2 = game.ocean.turbulence_center
	var intensity: float = game.ocean.turbulence_intensity
	game.boat.position += Vector3(10,0,10)
	game.ocean.update_surface(game.boat.position,game.sea_time,DT,1,game.heading)
	game.ocean.update_turbulence(game.wave_encounters,DT)
	check(game.ocean.turbulence_center==center and intensity>0.5,"rough-water footprint stays at its authored region when the boat and mesh move")
	game.wave_encounters.phase = game.wave_encounters.Phase.RECOVERY
	game.wave_encounters.phase_until = game.sea_time+10.0
	for i in range(300): game.ocean.update_turbulence(game.wave_encounters,DT)
	check(game.ocean.turbulence_intensity<0.001,"rough-water envelope fades continuously through protected recovery")
	game.hud.motion_choice.select(1)
	game.hud.motion_choice.item_selected.emit(1)
	check(game.motion_setting==1 and game.motion_amount()==0.28,"menu provides working Full and Reduced motion selection")
	for i in range(2):
		game.restart()
		check(effects.active_count==0 and effects.emitted==0 and effects.envelope==0 and game.ocean.turbulence_intensity==0,"retry clears pools, overlay and rough-water footprint")
	check(game.motion_setting==1,"motion preference survives retry")
	print("TURBULENCE EFFECTS: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

extends SceneTree
## Presentation budgets and motion gates exercised in the production arena.
var game
var checks := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func place() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = Vector3(345,0,230)
	game.heading = 0.0
	game.sea_time = 0.0
	game.actual_speed = 0.0
	game._update_view(1.0/60)

func travel(speed: float, seconds: float, hz: int = 60, turn: float = 0.0) -> void:
	for i in range(roundi(seconds*hz)):
		var dt := 1.0/hz
		game.heading += turn*dt
		game.boat.position += Vector3(sin(game.heading),0,-cos(game.heading))*speed*dt
		game.actual_speed = speed
		game.sea_time += dt
		game._update_view(dt)

func wake_width() -> float:
	var v: PackedVector3Array = game.ocean.wake_root.buffers[0][Mesh.ARRAY_VERTEX]
	return v[0].distance_to(v[1])

func bow_active() -> int:
	var total := 0
	for d in game.turbulence_effects.bow_drops:
		if d.age<d.life: total += 1
	return total

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await process_frame
	var fx = game.turbulence_effects
	var wake = game.ocean.wake_root
	place()
	await process_frame
	var nodes := get_node_count()
	var resources := [wake.meshes[0].get_instance_id(),wake.meshes[1].get_instance_id(),fx.mesh.get_instance_id()]
	var rates: Array[int] = []
	for hz in [30,60,120]:
		place()
		travel(0,2,hz)
		check(wake.count==0 and fx.bow_emitted==0 and fx.active_count==0,"idle has no foam or spray at %d Hz"%hz)
		# Deliberately stale speed: actual displacement still prevents blocked spray.
		for i in range(hz):
			game.actual_speed = 22.0
			game.sea_time += 1.0/hz
			game._update_view(1.0/hz)
		check(wake.count==0 and fx.bow_emitted==0,"blocked hull ignores commanded/stale speed at %d Hz"%hz)
		place()
		travel(7.5,4,hz)
		var normal: int = fx.bow_emitted
		var width := wake_width()
		var strength: float = game.ocean.wake_strength
		check(normal>=4 and bow_active()>0 and wake.count>=55,"ordinary moving waves produce bow spray and 15 Hz wake at %d Hz"%hz)
		rates.append(normal)
		place()
		travel(11.25,4,hz)
		check(fx.bow_emitted>normal and wake_width()>width*1.08 and game.ocean.wake_strength>strength*1.4,"Shift speed strengthens width, foam and spray at %d Hz"%hz)
		place()
		travel(21.97265625,4,hz)
		check(wake_width()>width*1.35 and game.ocean.wake_strength>strength*2.7,"full flow rewards remain visible beyond normal/boost clamp at %d Hz"%hz)
		travel(0,0.9,hz)
		check(bow_active()==0,"bow droplets expire after stopping at %d Hz"%hz)
		travel(0,5,hz)
		var visible := false
		for color: Color in wake.buffers[0][Mesh.ARRAY_COLOR]: visible = visible or color.a>0.001
		check(not visible and fx.active_count==0,"all old foam and spray fade at %d Hz"%hz)
	check(rates.max()-rates.min()<=4,"bow emission rate remains consistent at 30/60/120 Hz")
	place()
	var height: float = game.ocean_settings.height_multiplier
	game.ocean_settings.height_multiplier = 0.0
	travel(7.5,3)
	check(fx.bow_emitted==0,"flat water has no invented periodic bow spray")
	game.ocean_settings.height_multiplier = height
	place()
	travel(7.5,2)
	var slot: int = wake.cursor
	var point: Vector3 = wake.points[slot]
	var direction: Vector2 = wake.directions[slot]
	travel(7.5,2,60,0.72)
	check(wake.points[slot]==point and wake.directions[slot]==direction and direction.dot(wake.directions[wake.cursor])<0.3,"hard turn retains deposited world positions and headings")
	# Emitted positions are fixed even if the owning renderer follows the ship.
	var d: Dictionary = fx.bow_drops[fx.bow_cursor]
	var origin: Vector3 = d.origin
	travel(7.5,0.05)
	check(d.origin==origin,"live bow droplets keep their world-space emission origin")
	game.boat.position += Vector3(100,0,0)
	game._update_view(1.0/60)
	check(wake.count==0 and fx.active_count==0,"teleport clears both pools")
	place()
	game.ocean_quality = 0
	travel(22,5)
	check(bow_active()<=4 and fx.mesh.instance_count==64,"Low quality limits bow slots to four within the same 64-instance draw")
	game.ocean_quality = 1
	place()
	fx.reset()
	game.deck_response.snapped = false
	game.deck_response.events.assign([{"id":101,"strength":1.0,"direction":Vector3.RIGHT}])
	fx.update_effects(game,1.0/60)
	var burst: Dictionary = fx.bursts[0]
	check(fx.emitted==1 and burst.origin.x<game.boat.position.x and burst.direction.x<0,"strong directional impact emits from and toward the struck port side")
	for i in range(8): fx.update_effects(game,1.0/60)
	check(fx.emitted==1,"duplicate delivery of one crest ID cannot retrigger a splash")
	var strong_strength: float = burst.strength
	fx.reset()
	game.deck_response.events.assign([{"id":102,"strength":0.15,"direction":Vector3.LEFT}])
	fx.update_effects(game,1.0/60)
	check(fx.bursts[0].origin.x>game.boat.position.x and fx.bursts[0].direction.x>0 and fx.bursts[0].strength<strong_strength,"weak starboard encounter has correct side and lower splash energy")
	game.deck_response.events.clear()
	travel(7.5,20,60,0.12)
	await process_frame
	check(get_node_count()==nodes and resources==[wake.meshes[0].get_instance_id(),wake.meshes[1].get_instance_id(),fx.mesh.get_instance_id()] and wake.count<=96,"prolonged sailing reuses node, mesh and history budgets")
	for ending in [game.State.LOST,game.State.ARRIVED]:
		game.state = ending
		game._update_view(1.0/60)
		check(fx.active_count==0 and bow_active()==0,"ending clears spray immediately")
	game.restart()
	check(wake.count==0 and fx.active_count==0 and fx.bow_emitted==0,"retry clears foam and bow state")
	print("OCEAN JUICE: %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

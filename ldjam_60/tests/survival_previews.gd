extends SceneTree
## Native, protected review fixture: real movement/AI/production wave clock.
## Protection prevents damage from truncating UI captures; not a won playthrough.
var game
var output := "/tmp/latitude-timed-waves/rendered"
var metrics: Array[Dictionary]=[]

func visible_targets() -> int:
	var count:=0
	for cutter in game.enemy_encounters.living_ships():
		var target: Vector3=cutter.position+Vector3.UP*3
		var ray:=PhysicsRayQueryParameters3D.create(game.camera.position,target,1)
		if game.camera.is_position_in_frustum(target) and game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			count+=1
	return count


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	_run.call_deferred()

func capture(label: String) -> void:
	game.hud._process(1.0)
	await process_frame
	RenderingServer.force_draw(true,1.0/60)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	metrics.append({"frame":label,"wave":game.enemy_encounters.wave_number,
		"living":game.enemy_encounters.living_ships().size(),"queued":game.enemy_encounters.spawn_queue.size(),
		"clock":game.enemy_encounters.clock,"timer":game.enemy_encounters.next_wave_in,"visible_targets":visible_targets()})
	print("SURVIVAL CAPTURE: "+label)

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	game=load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	game.start_crossing()
	game._physics_process(game.CAST_OFF_SECONDS)
	game.damage_immunity=10000
	var seen: Array[int]=[]
	var countdown_captured:=false
	var combat_seen: Array[int]=[]
	for frame in 22000:
		# Follow the already-tested open outer circuit through real A/D inputs.
		var offset: Vector3=game.boat.position-game.arena_center()
		var angle:=atan2(offset.x,-offset.z)+0.12
		var goal: Vector3=game.arena_center()+Vector3(sin(angle),0,-cos(angle))*126
		var delta: Vector3=goal-game.boat.position
		var error: float=wrapf(atan2(delta.x,-delta.z)-game.heading,-PI,PI)
		Input.action_press("steer_port",1) if error< -0.025 else Input.action_release("steer_port")
		Input.action_press("steer_starboard",1) if error>0.025 else Input.action_release("steer_starboard")
		game._physics_process(1.0/60)
		game.cannon.advance(1.0/60)
		var waves=game.enemy_encounters
		if waves.wave_number in [1,3,5] and waves.wave_number not in seen and waves.announcement_left<1.6:
			seen.append(waves.wave_number)
			await capture("wave-%d-incoming"%waves.wave_number)
		if waves.wave_number==2 and waves.next_wave_in<12.1 and waves.next_wave_in>11.9 and not countdown_captured:
			countdown_captured=true
			await capture("next-wave-countdown")
		if frame%120==0:
			await process_frame
		if waves.wave_number in [1,3] and waves.wave_number not in combat_seen and waves.clock-waves.records.back().started>5 and visible_targets()>0:
			combat_seen.append(waves.wave_number)
			await capture("wave-%d-combat"%waves.wave_number)
		if seen.size()==3 and waves.wave_number==5 and waves.clock>244 and visible_targets()>0:
			await capture("final-wave-combat")
			break
	Input.action_release("steer_port")
	Input.action_release("steer_starboard")
	# Additional state fixtures use the same scheduler and impact handling. They
	# explicitly stage clears, rather than representing player combat success.
	game.restart()
	await physics_frame
	game.state=game.State.SAILING
	game.damage_immunity=10000
	var waves=game.enemy_encounters
	waves.update_encounters(1.0/60)
	for cutter in waves.living_ships():
		while cutter.hull>0:game.cannon._impact(cutter,cutter.position)
	waves.update_encounters(1.0/60)
	game._update_view(0.2)
	await capture("early-clear")
	# Rapid configured durations preserve queue/kill accounting in this fixture.
	waves.survival_settings.spawn_interval=0.1
	for frame in 20000:
		for cutter in waves.living_ships():
			while cutter.hull>0:game.cannon._impact(cutter,cutter.position)
		waves.update_encounters(1.0/60)
		game.sea_time+=1.0/60
		if game.state==game.State.ARRIVED:break
	game._update_view(1)
	await capture("victory")
	game.restart()
	await physics_frame
	game.state=game.State.SAILING
	game.damage_immunity=0
	game.take_damage(3,"Enemy broadside hit")
	game._update_view(1)
	await capture("defeat")
	var file:=FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	game.queue_free()
	await process_frame
	quit()

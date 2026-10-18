extends Node
## Real rendered frame intervals; event CPU timings do not include GPU execution.
const CASES := ["idle_sailing", "first_player_shot", "first_enemy_shot", "simultaneous_shots", "first_flagship_volley", "first_mine", "recycled_mines", "full_combat"]
var game
var boss
var phase := -1
var elapsed := 0.0
var pulse := 0.0
var tick := 0
var last_tick := 0
var frames: Array[float] = []
var event_us: Array[float] = []
var results: Array[Dictionary] = []
var label := "before"
var output := "/tmp/blackwater-runtime"
var done := false
var peak_draws := 0.0
var peak_nodes := 0
var peak_resources := 0.0
var entered := false
var captures := false
# Diagnostic ablations are benchmark-only; normal gameplay never reads these.
var probe := ""
var first_shot_only := false
var first_update_us: Array[float] = []
var first_cannon_us: Array[float] = []
func _ready() -> void:
	captures = "--captures" in OS.get_cmdline_user_args()
	first_shot_only = "--first-shot-only" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="): probe = arg.trim_prefix("--probe=")
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if OS.has_feature("web"):
		label = JavaScriptBridge.eval("new URLSearchParams(location.search).get('label') || 'before'")
		probe = JavaScriptBridge.eval("new URLSearchParams(location.search).get('probe') || ''")
		first_shot_only = JavaScriptBridge.eval("new URLSearchParams(location.search).has('first-shot-only')")
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size = Vector2i(1280,720)
	get_tree().root.size = Vector2i(1280,720)
	seed(60)
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.cannon.set_physics_process(false)
	game.restart(true)
	game.state = game.State.SAILING
	game._sound_enabled = false
	game.damage_immunity = 10000
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.hud.hide()
	game.boat.position = game.arena_center() + Vector3(0,0,90)
	game.heading = 0
	for i in 5:
		var ship = game.enemy_encounters.ships[i]
		ship.configure_archetype(load("res://game/enemies/%s.tres" % ["cutter","skiff","heavy"][i%3]))
		ship.begin(game.boat.position + Vector3(20+i*4,0,-18+i*9))
		ship.heading = 0
		ship.rotation.y = 0
		ship.sea_effects.advance_arrival(1)
		ship.sea_effects.apply_arrival()
	boss = game.enemy_encounters.boss
	boss.begin(game.boat.position + Vector3(40,0,30))
	boss.heading = 0
	boss.rotation.y = 0
	boss._speed = 0
	boss.sea_effects.advance_arrival(1)
	boss.sea_effects.apply_arrival()
	game._update_view(1)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = game.boat.position + Vector3(50,45,65)
	camera.look_at(game.boat.position + Vector3(15,0,0))
	camera.current = true
	last_tick = Time.get_ticks_usec()
func _process(delta: float) -> void:
	if done: return
	var now := Time.get_ticks_usec()
	var interval := (now-last_tick)/1000.0
	last_tick = now
	tick += 1
	if phase < 0:
		if tick > 180: _next_phase()
		return
	if entered:
		frames.append(interval)
		peak_draws = maxf(peak_draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_nodes = maxi(peak_nodes, get_tree().get_node_count())
		peak_resources = maxf(peak_resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	entered = true
	elapsed += delta
	pulse -= delta
	if pulse <= 0:
		pulse = 0.75 if phase in [6,7] else 1000
		var started := Time.get_ticks_usec()
		_event()
		if captures and event_us.is_empty() and not OS.has_feature("web"):
			capture_event.call_deferred(CASES[phase])
		event_us.append(float(Time.get_ticks_usec()-started))
	# Real delta, same physical collision and VFX update paths as gameplay.
	game.sea_time += delta
	game.ocean.update_surface(game.boat.position, game.sea_time, delta, 1.0, game.heading)
	var cannon_started := Time.get_ticks_usec()
	game.cannon.advance(delta)
	if first_cannon_us.size() < 12: first_cannon_us.append(float(Time.get_ticks_usec()-cannon_started))
	if phase == 1:
		if probe == "no_light": game.cannon.flash_light.hide()
		if probe == "no_flame": game.cannon.flash.hide()
		if probe == "no_ball":
			for shot in game.cannon.projectiles: shot.node.hide()
	for ship in game.enemy_encounters.ships:
		if phase == 7: ship.update_ship(delta)
		else: ship._advance_shots(delta)
		ship._update_tell()
	if phase == 7: boss.update_ship(delta)
	else: boss._advance_shots(delta)
	boss._update_tell()
	for mine in boss.mines:
		if is_instance_valid(mine) and not mine.spent: mine.update_mine(delta)
	if phase == 7:
		game.wave_encounters.enabled = true
		game.wave_encounters.update(game,delta)
	if first_update_us.size() < 12: first_update_us.append(float(Time.get_ticks_usec()-now))
	if elapsed >= 3.0:
		var record := metrics()
		results.append(record)
		print("RUNTIME_PHASE " + JSON.stringify(record))
		if captures and not OS.has_feature("web"):
			DirAccess.make_dir_recursive_absolute(output)
			RenderingServer.force_draw(true,0)
			get_viewport().get_texture().get_image().save_png(output.path_join(label+"-"+CASES[phase]+".png"))
		_next_phase()
func capture_event(case_name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"-"+case_name+"-event.png"))

func _event() -> void:
	if phase in [1,7]:
		game.cannon.cooldown = 0
		if probe == "no_particles": game.combat_particles.enabled = false
		game.cannon.fire()
	if phase in [2,3,7]:
		for i in (1 if phase == 2 else 5):
			var ship = game.enemy_encounters.ships[i]
			ship.locked_point = game.boat.position + Vector3(0,2,4)
			ship._fire()
	if phase in [4,7]:
		boss.pattern = boss.Pattern.SCATTER
		if boss._prepare_volley(1.6):
			boss.weapon_time = 0
			for shot in boss.volley: shot.fired = false
			boss.sequence_time = 0.6
			boss._fire_due()
			print("VOLLEY_PROJECTILES ", boss.projectiles.size())
	if phase in [5,6,7]:
		if phase in [6,7]:
			for mine in boss.mines:
				if is_instance_valid(mine): mine.expire()
			boss.mines.clear()
		boss.position = game.boat.position + Vector3(38,0,25)
		boss.deploy_mine()
		if phase in [6,7] and not boss.mines.is_empty():
			game.combat_particles.damage(boss.mines[0].model.global_position, false)
			game.cannon.water_splash(boss.mines[0].model.global_position, false)
	if phase == 7:
		game.combat_particles.smoke(boss.position + Vector3.UP*3)
func percentile(values: Array[float], f: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*f))] if not sorted.is_empty() else 0
func metrics() -> Dictionary:
	return {"case":CASES[phase],"first_frames_ms":frames.slice(0,12),"first_update_us":first_update_us.duplicate(),"first_cannon_us":first_cannon_us.duplicate(),"peak_draw_calls":peak_draws,"peak_nodes":peak_nodes,"peak_resources":peak_resources,"frames":frames.size(),"median_ms":percentile(frames,0.5),"p95_ms":percentile(frames,0.95),"p99_ms":percentile(frames,0.99),"max_ms":percentile(frames,1),"event_cpu_us":event_us.duplicate(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":get_tree().get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
func _next_phase() -> void:
	phase += 1
	if phase == (2 if first_shot_only else CASES.size()):
		done = true
		var report := {"label":label,"probe":probe,"first_shot_only":first_shot_only,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().size),"render_size":str(get_viewport().get_texture().get_size()),"phases":results}
		print("RUNTIME_RESULT "+JSON.stringify(report))
		if OS.has_feature("web"):
			JavaScriptBridge.eval("document.title='Runtime benchmark complete';window.runtimeBenchmark="+JSON.stringify(report))
		else:
			var file := FileAccess.open(output.path_join(label+".json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  "))
			file.close()
			get_tree().quit()
		return
	peak_draws = 0
	peak_nodes = 0
	peak_resources = 0
	elapsed = 0
	pulse = 0
	entered = false
	first_update_us.clear()
	first_cannon_us.clear()
	frames.clear()
	event_us.clear()

extends Node
## Rendered event windows, normal audio/HUD, deterministic production event calls.
## Probes are deliberately confined to this fixture and its copied materials.
const Metrics = preload("res://game/combat_event_metrics.gd")
const CASES := ["ordinary_spawn", "archetype_reuse", "wave_arrivals", "first_volley", "repeated_volley", "hull_hit", "lethal_hit", "simultaneous_hits", "player_cannon_hit", "player_mine_hit", "full_combat"]
var game
var camera: Camera3D
var phase := -1
var elapsed := 0.0
var last_tick := 0
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var results: Array[Dictionary] = []
var label := "before"
var probe := ""
var case_filter := PackedStringArray()
var output := "/tmp/blackwater-combat"
var full_seconds := 60.0
var full_only := false
var next_event := 0.75
var fired := false
var done := false
var warm_frames := 0
var capture := false
var capture_index := 0
var warmup_ms := 0.0
var rendered_ticks := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Combat frame benchmarks require the real Compatibility renderer")
		get_tree().quit(2)
		return
	if not OS.has_feature("web") and "--manual-render" not in OS.get_cmdline_user_args():
		push_error("Use --disable-render-loop -- --manual-render for native combat measurements")
		get_tree().quit(2)
		return
	RenderingServer.frame_post_draw.connect(_drawn)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--cases="): case_filter = arg.trim_prefix("--cases=").split(",",false)
		if arg.begins_with("--probe="): probe = arg.trim_prefix("--probe=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--full-seconds="): full_seconds = float(arg.trim_prefix("--full-seconds="))
	full_only = "--full-only" in OS.get_cmdline_user_args()
	capture = "--captures" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		label = JavaScriptBridge.eval("new URLSearchParams(location.search).get('label') || 'before'")
		case_filter = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('cases') || ''")).split(",",false)
		probe = JavaScriptBridge.eval("new URLSearchParams(location.search).get('probe') || ''")
		full_only = JavaScriptBridge.eval("new URLSearchParams(location.search).has('full-only')")
		full_seconds = float(JavaScriptBridge.eval("Number(new URLSearchParams(location.search).get('full-seconds') || 60)"))
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size = Vector2i(1280,720)
	get_tree().root.size = Vector2i(1280,720)
	seed(6019)
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = game.arena_center() + Vector3(45,45,150)
	camera.look_at(game.arena_center() + Vector3(15,0,90))
	camera.current = true
	DirAccess.make_dir_recursive_absolute(output)
	last_tick = Time.get_ticks_usec()

func _drawn() -> void:
	rendered_ticks += 1

func _process(_delta: float) -> void:
	if done: return
	if not OS.has_feature("web"): RenderingServer.force_draw(true,_delta)
	var now := Time.get_ticks_usec()
	var interval := (now-last_tick)/1000.0
	last_tick = now
	if phase < 0:
		if OS.has_feature("web") and not JavaScriptBridge.eval("window.combatStarted === true"): return
		warm_frames += 1
		if warm_frames > 120 and game.cannon.combat_warmup.complete:
			warmup_ms = game.cannon.combat_warmup.elapsed_ms
			if full_only: phase = CASES.size()-2
			_next_phase()
		return
	if elapsed < 0: return
	samples.append({"time":elapsed,"ms":interval,"drawn_frames":rendered_ticks,
		"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes":get_tree().get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	if elapsed >= (full_seconds if CASES[phase] == "full_combat" else 4.0):
		_finish_phase()

func _physics_process(delta: float) -> void:
	if phase < 0 or done: return
	elapsed += delta
	# Automated browser fixture requires no pointer capture. Normal game logic,
	# audio generator, HUD drawing, ocean, VFX and AI continue running unchanged.
	game._web_had_mouse_capture = false
	game._window_focused = true
	if CASES[phase] == "full_combat":
		if game.state != game.State.SAILING:
			game.restart()
			game.state = game.State.SAILING
		if elapsed >= next_event:
			next_event += 1.5
			_time_event("player_fire", func(): game.cannon.fire())
		if not fired and elapsed >= minf(12,full_seconds*0.5):
			fired = true
			_time_event("wave_skip", func(): game.enemy_encounters.debug_skip_wave())
		var radial: Vector3 = game.boat.position-game.arena_center()
		var desired := atan2(radial.x,-radial.z)+PI/2+clampf((radial.length()-110.0)*0.03,-0.6,0.6)
		var steering := clampf(wrapf(desired-game.heading,-PI,PI)*2,-1,1)
		Input.action_press("steer_starboard",maxf(0,steering))
		Input.action_press("steer_port",maxf(0,-steering))
	else:
		for ship in game.enemy_encounters.ships:
			ship.cooldown = 100.0
			ship.update_ship(delta)
		if elapsed >= next_event and not fired:
			fired = true
			_time_event(CASES[phase], _event)
			if capture: _capture.call_deferred(CASES[phase])
		if CASES[phase] == "repeated_volley" and elapsed >= 2.25 and next_event < 2:
			next_event = 3
			_time_event("repeat", _event)
		if probe == "no_arrival":
			for ship in game.enemy_encounters.combat_ships():
				ship.sea_effects.advance_arrival(1.0)
				ship.sea_effects.apply_arrival()
	if capture and CASES[phase] == "full_combat" and elapsed >= capture_index * 0.1:
		capture_index += 1
		if capture_index <= 100: _capture.call_deferred("clip-%03d" % capture_index)

func _time_event(event_name: String, action: Callable) -> void:
	var before := Metrics.samples.duplicate(true)
	var nodes := get_tree().get_node_count()
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var start := Time.get_ticks_usec()
	action.call()
	var cpu := Time.get_ticks_usec()-start
	var paths := {}
	for key in Metrics.samples:
		var old: Dictionary = before.get(key,{"calls":0,"total_us":0})
		paths[key] = {"calls":Metrics.samples[key].calls-old.calls,"total_us":Metrics.samples[key].total_us-old.total_us}
	events.append({"event":event_name,"time":elapsed,"frame_index":samples.size(),"cpu_us":cpu,
		"node_delta":get_tree().get_node_count()-nodes,
		"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,
		"paths":paths,"player_hull":game.hull})

func _spawn(index: int, kind: String) -> void:
	var ship = game.enemy_encounters.ships[index]
	ship.configure_archetype(load("res://game/enemies/"+kind+".tres"))
	ship.begin(game.arena_center()+Vector3(18+index*15,0,90-index*12))
	ship.heading = 0
	ship.rotation.y = 0

func _event() -> void:
	var ship = game.enemy_encounters.ships[0]
	match CASES[phase]:
		"ordinary_spawn": _spawn(0,"cutter")
		"archetype_reuse": _spawn(0,"heavy")
		"wave_arrivals":
			game.enemy_encounters._begin_wave()
			game.enemy_encounters.debug_skip_wave()
			for i in 3:
				if not game.enemy_encounters.spawn_queue.is_empty(): game.enemy_encounters._spawn_queued()
		"first_volley", "repeated_volley":
			ship.locked_point = game.boat.position + Vector3.UP
			ship.weapon_state = ship.Weapon.FIRE
			ship.weapon_time = 0
			ship._fire()
			ship._update_tell()
		"hull_hit", "lethal_hit", "simultaneous_hits":
			for i in (3 if CASES[phase] == "simultaneous_hits" else 1):
				var target = game.enemy_encounters.ships[i]
				game.cannon._impact(target,target.presentation.global_position+Vector3.UP)
		"player_cannon_hit":
			game.damage_immunity = 0
			ship.locked_point = game.boat.position + Vector3.UP
			ship._launch_ball(game.boat.position + Vector3(0,1,8))
			ship._advance_shots(0.4)
		"player_mine_hit":
			game.damage_immunity = 0
			var mine = ship.mine_layer.pool[0]
			mine.activate(game.boat.position)
			mine.update_mine(1.3)

func _next_phase() -> void:
	phase += 1
	while phase < CASES.size() and not case_filter.is_empty() and CASES[phase] not in case_filter:
		phase += 1
	if phase >= CASES.size():
		done = true
		Metrics.enabled = false
		Input.action_release("steer_starboard")
		Input.action_release("steer_port")
		var report := {"label":label,"probe":probe,"engine":Engine.get_version_info().string,
			"adapter":RenderingServer.get_video_adapter_name(),"render_size":str(get_viewport().get_texture().get_size()),
			"warmup_ms":warmup_ms,"phases":results}
		print("COMBAT_RESULT "+JSON.stringify(report))
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.combatBenchmark="+JSON.stringify(report)+";document.title='Combat benchmark complete';fetch('/result',{method:'POST',body:JSON.stringify(window.combatBenchmark)})")
		else:
			var file := FileAccess.open(output.path_join(label+"-"+probe+".json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  "))
			get_tree().quit()
		return
	Metrics.enabled = false
	game.restart()
	game.state = game.State.SAILING
	if CASES[phase] != "full_combat":
		game.boat.position = game.arena_center()+Vector3(0,0,112)
		game.heading = 0
	game.enemy_encounters.enabled = CASES[phase] == "full_combat"
	game.wave_encounters.enabled = CASES[phase] == "full_combat"
	game._sound_enabled = probe != "no_audio"
	game.set_process(probe != "no_audio")
	game._music.stream_paused = probe == "no_audio"
	game.combat_particles.enabled = probe != "no_vfx"
	if probe == "no_vfx":
		for pair in game.cannon.splash_pool:
			for effect in pair: effect.node.layers = 0
	if CASES[phase] in ["archetype_reuse","first_volley","repeated_volley","hull_hit","lethal_hit","simultaneous_hits","player_cannon_hit","player_mine_hit"]:
		for i in (3 if CASES[phase] == "simultaneous_hits" else 1):
			_spawn(i,"heavy" if CASES[phase] == "hull_hit" else "cutter")
			var ship = game.enemy_encounters.ships[i]
			ship.sea_effects.advance_arrival(1)
			ship.sea_effects.apply_arrival()
			if CASES[phase] == "lethal_hit": ship.hull = 1
			if probe == "no_flame":
				for mount in ship.gun_mounts: mount.flash.layers = 0
			if probe == "no_ball":
				for ball in game.cannon.projectile_visuals.free_nodes: ball.layers = 0
	game.camera.current = CASES[phase] == "full_combat"
	camera.current = CASES[phase] != "full_combat"
	elapsed = -1.0 # settle phase setup outside the measured event window
	next_event = 0.75
	fired = false
	samples.clear()
	events.clear()
	Metrics.samples.clear()
	Metrics.enabled = true
	last_tick = Time.get_ticks_usec()

func _finish_phase() -> void:
	var intervals: Array[float] = []
	var draws := 0.0
	var nodes := 0
	var resources := 0.0
	var rendered_advances := 0
	var last_drawn := -1
	for sample in samples:
		if int(sample.drawn_frames) > last_drawn: rendered_advances += 1
		last_drawn = int(sample.drawn_frames)
		intervals.append(sample.ms)
		draws = maxf(draws,sample.draws)
		nodes = maxi(nodes,sample.nodes)
		resources = maxf(resources,sample.resources)
	intervals.sort()
	var windows := []
	for event in events:
		windows.append({"event":event.event,"frames":samples.slice(maxi(0,event.frame_index-8),event.frame_index+16)})
	var record := {"case":CASES[phase],"frames":samples.size(),"rendered_advances":rendered_advances,"p95_ms":_percentile(intervals,0.95),
		"p99_ms":_percentile(intervals,0.99),"max_ms":_percentile(intervals,1.0),"median_ms":_percentile(intervals,0.5),
		"peak_draws":draws,"peak_nodes":nodes,"peak_resources":resources,"events":events.duplicate(true),
		"windows":windows,"paths":Metrics.samples.duplicate(true),"all_frames":samples.duplicate(true)}
	record["rendered_fraction"] = float(rendered_advances)/maxi(1,samples.size())
	record["timing_valid"] = OS.has_feature("web") or record.rendered_fraction >= 0.95
	if not record.timing_valid: push_warning("Obscured native window: reject timing phase " + CASES[phase])
	results.append(record)
	print("COMBAT_PHASE "+JSON.stringify({"case":record.case,"p99_ms":record.p99_ms,"max_ms":record.max_ms,"events":record.events}))
	_next_phase()

func _percentile(sorted: Array[float], fraction: float) -> float:
	return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))] if not sorted.is_empty() else 0

func _capture(case_name: String) -> void:
	if OS.has_feature("web"): return
	RenderingServer.force_draw(true,0)
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"-"+case_name+".png"))

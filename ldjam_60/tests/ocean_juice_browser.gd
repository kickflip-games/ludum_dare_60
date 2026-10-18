extends Node
## Paired 1280x720 arena workloads: idle, cruise, boost, four crests, five ships.
const SCENARIOS := ["idle","cruise","boost","four_crests","combat"]
var game
var run_index := 0
var version := "final"
var cohort := "ocean"
var scenario := 0
var quality := 1
var elapsed := 0.0
var last_tick := 0
var samples: Array[float] = []
var draws: Array[float] = []
var maximum_effects := 0
var maximum_enemies := 0
var first_nodes := 0
var minimum_nodes := 100000
var maximum_nodes := 0
var finished := false
var cycle := -1


func _ready() -> void:
	var params = JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))")) if OS.has_feature("web") else {}
	run_index = int(params.get("run","0"))
	version = str(params.get("version","final"))
	cohort = str(params.get("cohort","ocean"))
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	game.set_process_unhandled_input(false)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	start_workload()

func start_workload() -> void:
	scenario = run_index%5
	quality = (run_index/5)%2
	elapsed = 0.0
	cycle = -1
	samples.clear()
	draws.clear()
	maximum_effects = 0
	maximum_enemies = 0
	minimum_nodes = 100000
	maximum_nodes = 0
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = scenario==4
	game.weather_enabled = false
	game._sound_enabled = false
	game.boat.position = Vector3(345,0,230)
	game.heading = 0.0
	game.sea_time = 0.0
	game.phase_banner_left = 0.0
	game.ocean_quality = quality
	game.ocean.set_quality(quality)
	game.boosting = scenario==2
	game.damage_immunity = 1000.0
	if scenario==4:
		var manager = game.enemy_encounters
		for i in range(4):
			manager._begin_wave()
			manager.spawn_queue.clear()
		manager.spawn_queue.assign([4,4,4,4,4])
		for i in range(5): manager._spawn_queued()
	game._update_view(1.0/60)
	first_nodes = get_tree().get_node_count()
	last_tick = Time.get_ticks_usec()
	if OS.has_feature("web"):
		var status := "%s: %s / quality %d — 4s warmup + 12s sample"%[version,SCENARIOS[scenario],quality]
		JavaScriptBridge.eval("document.title='Ocean review';document.getElementById('bench-status').textContent="+JSON.stringify(status))

func _process(delta: float) -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	var interval := float(now-last_tick)/1000.0
	last_tick = now
	elapsed += delta
	var dt := minf(delta,1.0/30)
	if scenario==0:
		game.sea_time += dt
		game.actual_speed = 0.0
	else:
		game.advance_sailing(dt,0.45)
	if scenario==3:
		var next := int(elapsed/8.0)
		if cycle!=next:
			cycle = next
			game.ocean.wave_field.waves.clear()
			game.ocean.wave_field.invalidate()
			var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
			for i in range(4):
				var d := Vector2.RIGHT.rotated(i*PI/2+0.15)
				game.ocean.wave_field.add_wave(Vector2(center.x,center.z)-d*24,d,1.85,4.8,30,8,game.sea_time+i*0.2,8)
	game._update_view(dt)
	game.cannon.advance(dt)
	game.hud._process(dt)
	maximum_effects = maxi(maximum_effects,game.turbulence_effects.active_count)
	maximum_enemies = maxi(maximum_enemies,game.enemy_encounters.living_ships().size())
	if elapsed<4.0:
		first_nodes = get_tree().get_node_count()
	else:
		samples.append(interval)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		minimum_nodes = mini(minimum_nodes,get_tree().get_node_count())
		maximum_nodes = maxi(maximum_nodes,get_tree().get_node_count())
	if elapsed<16.0: return
	finished = true
	samples.sort()
	draws.sort()
	var wake = game.ocean.wake_root
	var data := {"cohort":cohort,"version":version,"run":run_index,"quality":quality,"scenario":SCENARIOS[scenario],
		"samples":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],
		"max_effects":maximum_effects,"spray_capacity":game.turbulence_effects.mesh.instance_count,"max_enemies":maximum_enemies,
		"nodes_start":first_nodes,"nodes_end":get_tree().get_node_count(),"nodes_min":minimum_nodes,"nodes_max":maximum_nodes,
		"draw_calls":draws[draws.size()/2],"wake_vertices":wake.meshes[0].surface_get_array_len(0)+wake.meshes[1].surface_get_array_len(0),
		"wake_meshes":wake.meshes.size(),"wake_samples":wake.count,"viewport":str(get_viewport().size),"renderer":RenderingServer.get_video_adapter_name()}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.oceanBenchmark="+JSON.stringify(data)+";fetch('/result',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({result:window.oceanBenchmark,userAgent:navigator.userAgent})})")
	else:
		print("OCEAN BROWSER "+JSON.stringify(data))
	if run_index<9:
		run_index += 1
		finished = false
		start_workload()
	elif OS.has_feature("web"):
		if version=="baseline":
			JavaScriptBridge.eval("location.href="+JSON.stringify("/final/index.html?version=final&run=0&cohort="+cohort))
		else:
			JavaScriptBridge.eval("document.title='Ocean review complete';document.getElementById('bench-status').textContent='Complete: 10 final workloads saved locally'")
	else:
		get_tree().quit()

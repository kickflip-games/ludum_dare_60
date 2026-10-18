extends Node
## Separate development export. Release export excludes this directory.
var game
var elapsed := 0.0
var cycle := -1
var samples: Array[float] = []
var last_tick := 0
var maximum_effects := 0
var baseline := false
var run_index := 0
var finished := false
var first_nodes := 0
var cohort := "final"

func _ready() -> void:
	var params = JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))")) if OS.has_feature("web") else {}
	run_index = int(params.get("run","0"))
	cohort = str(params.get("cohort","final"))
	baseline = str(params.get("version","final"))=="baseline"
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = Vector3(-300,0,-330)
	game.heading = 0.0
	game.actual_speed = 0.0
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	game.sea_time = 0.0
	game.ocean_quality = (run_index/2)%2
	game._sound_enabled = false
	first_nodes = get_tree().get_node_count()
	last_tick = Time.get_ticks_usec()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('bench-status').textContent='Running '+location.search+' — 10s warmup + 30s sample'")

func _process(delta: float) -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	var interval := float(now-last_tick)/1000.0
	last_tick = now
	elapsed += delta
	if elapsed<10.0: first_nodes = get_tree().get_node_count()
	if elapsed>=10.0: samples.append(interval)
	var next_cycle := int(elapsed/8.0)
	if cycle!=next_cycle:
		cycle = next_cycle
		# Expire the fixture's old waves without reusing event IDs. The production
		# director also keeps IDs monotonic between retries, so contacts can repeat.
		game.ocean.wave_field.waves.clear()
		if run_index%2==1:
			var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
			for i in range(4):
				var d := Vector2.RIGHT.rotated(i*PI/2.0+0.15)
				game.ocean.wave_field.add_wave(Vector2(center.x,center.z)-d*24.0,d,1.85,4.8,30,8,elapsed+float(i)*0.2,8)
	game.sea_time = elapsed
	game.ocean.wave_field.advance(elapsed)
	game._update_view(minf(delta,0.1))
	game.cannon.advance(minf(delta,0.1))
	game.hud._process(delta)
	if "turbulence_effects" in game: maximum_effects = maxi(maximum_effects,game.turbulence_effects.active_count)
	if elapsed<40.0: return
	finished = true
	samples.sort()
	var above := 0
	for value in samples:
		if value>33.3: above+=1
	var data := {"cohort":cohort,"version":"baseline" if baseline else "final","run":run_index,"quality":game.ocean_quality,"waves":4 if run_index%2==1 else 0,
		"samples":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)],
		"above_33_3_ms":above,"max_effects":maximum_effects,"nodes_start":first_nodes,"nodes_end":get_tree().get_node_count(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"memory_bytes":OS.get_static_memory_usage(),"viewport":str(get_viewport().size),"renderer":RenderingServer.get_video_adapter_name()}
	if OS.has_feature("web"):
		var payload := JSON.stringify(data)
		var next_version := "final" if baseline else "baseline"
		var next_run := run_index if baseline else run_index+1
		var next := "/%s/index.html?version=%s&run=%d&cohort=%s" % [next_version,next_version,next_run,cohort]
		var script := "fetch('/result',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({result:%s,userAgent:navigator.userAgent})}).then(()=>{document.getElementById('bench-status').textContent=%s;%s})" % [payload,JSON.stringify(payload),"" if next_run>=12 else "location.href="+JSON.stringify(next)+";"]
		JavaScriptBridge.eval(script)
	else:
		print(JSON.stringify(data))

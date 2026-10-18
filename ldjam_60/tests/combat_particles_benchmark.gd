extends Node
## Fixed gameplay camera: alternating idle and saturated particle batches.
## Run this scene natively, or as the main scene of a separate development Web export.
var full_vfx := false
const FULL_PHASES := ["idle", "player", "enemy", "hull", "water", "mixed", "expired"]
var game
var fx
var phase := -1
var phase_time := 0.0
var burst_clock := 0.0
var last_tick := 0
var intervals: Array[float] = []
var update_costs: Array[float] = []
var draws: Array[float] = []
var results: Array[Dictionary] = []
var initial_nodes := 0
var finished := false
const PHASE_SECONDS := 10.0
const WARMUP_SECONDS := 3.0

func _ready() -> void:
	full_vfx = "--full-vfx" in OS.get_cmdline_user_args()
	if full_vfx:
		get_tree().root.size = Vector2i(1280, 720)
	game = load("res://game/crossing.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game._sound_enabled = false
	game.boat.transform = Transform3D(Basis.IDENTITY, Vector3(310, 0, 342))
	game.heading = 0.0
	game.sea_time = 12.0
	game.ocean.wave_time = 12.0
	game._update_view(1.0)
	game.hud._process(0.0)
	if full_vfx:
		for index in 5:
			var ship = game.enemy_encounters.ships[index]
			ship.configure_archetype(load("res://game/enemies/%s.tres" % ["skiff", "cutter", "heavy"][index % 3]))
			ship.begin(game.boat.position + Vector3(22 + index * 5, 0, -15 + index * 7))
			ship.heading = 0.0
			ship.rotation.y = 0.0
			ship.update_visuals(0.0)
	fx = game.combat_particles
	initial_nodes = get_tree().get_node_count()
	last_tick = Time.get_ticks_usec()
	_next_phase()

func _next_phase() -> void:
	phase += 1
	phase_time = 0.0
	burst_clock = 0.0
	intervals.clear()
	update_costs.clear()
	draws.clear()
	fx.reset()
	if phase == (7 if full_vfx else 6):
		finished = true
		var report := {"phases": results, "capacity": fx.CAPACITY, "nodes_start": initial_nodes,
			"nodes_end": get_tree().get_node_count(), "viewport": str(get_viewport().size),
			"renderer": RenderingServer.get_video_adapter_name(), "full_vfx": full_vfx}
		print("PARTICLE BENCHMARK " + JSON.stringify(report))
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.particleBenchmark=" + JSON.stringify(report) + ";document.title='Particle benchmark complete';fetch('/result',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(window.particleBenchmark)})")
		else:
			get_tree().quit()
	elif OS.has_feature("web"):
		JavaScriptBridge.eval("document.title='Particle benchmark %d/6: %s'" % [phase + 1, "saturated" if phase % 2 else "idle"])

func _process(delta: float) -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	var interval := (now - last_tick) / 1000.0
	last_tick = now
	phase_time += delta
	if phase == 0 and phase_time < WARMUP_SECONDS:
		initial_nodes = get_tree().get_node_count()
	var started := Time.get_ticks_usec()
	if full_vfx:
		_full_effects(delta)
	elif phase % 2 == 1:
		burst_clock -= delta
		if burst_clock <= 0.0:
			burst_clock = 0.1
			# More bursts than five live enemies can fire; all in the view frustum.
			for index in 5:
				var at: Vector3 = game.boat.position + Vector3(-5 + index * 3, 1, -6 - index * 2)
				fx.muzzle(at, Vector3.RIGHT, true)
				fx.damage(at, true)
		fx.advance(delta)
		fx.set_process(false)
	var cost := float(Time.get_ticks_usec() - started)
	if phase_time >= WARMUP_SECONDS:
		intervals.append(interval)
		update_costs.append(cost)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if phase_time >= (8.0 if full_vfx else PHASE_SECONDS):
		intervals.sort()
		update_costs.sort()
		draws.sort()
		var total := 0.0
		for value in update_costs: total += value
		var result := {"saturated": phase % 2 == 1, "samples": intervals.size(),
			"median_ms": intervals[intervals.size() / 2], "p95_ms": intervals[int(intervals.size() * 0.95)],
			"particle_cpu_mean_us": total / update_costs.size(), "particle_cpu_p95_us": update_costs[int(update_costs.size() * 0.95)],
			"draw_calls": draws[draws.size() / 2], "nodes": get_tree().get_node_count(), "case": FULL_PHASES[phase] if full_vfx else "saturated" if phase % 2 else "idle", "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
		results.append(result)
		print("PARTICLE PHASE " + JSON.stringify(result))
		_next_phase()


func _full_effects(delta: float) -> void:
	burst_clock -= delta
	if phase in [1, 2, 3, 4, 5] and burst_clock <= 0.0:
		burst_clock = 0.18 if phase in [4, 5] else 0.3
		if phase in [1, 5]:
			fx.muzzle(game.cannon.shot_origin(), game.cannon.aimed_direction())
			game.cannon.flash_time = 0.11
		if phase in [2, 5]:
			for ship in game.enemy_encounters.ships:
				if ship.visible:
					fx.muzzle(ship.muzzle_position(), ship.port_direction(), true)
					ship.flash.visible = true
		if phase in [3, 5]:
			for index in 3:
				fx.impact(game.boat.position + Vector3(20 + index * 6, 1.5, -8 + index * 5), true, index == 2)
		if phase in [4, 5]:
			for index in 2:
				game.cannon.water_splash(game.boat.position + Vector3(10 + index * 6, 0, -4 + sin(phase_time) * 7), false)
	if burst_clock < 0.18:
		for ship in game.enemy_encounters.ships: ship.flash.visible = false
	game.cannon.advance(delta)
	fx.advance(delta)
	fx.set_process(false)

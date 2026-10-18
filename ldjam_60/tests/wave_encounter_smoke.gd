extends SceneTree
const Field = preload("res://game/ocean/wave_field.gd")
const Sailing = preload("res://game/ocean/wave_sailing.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func trial(height: float, direction: Vector2, hz: int, counter: bool = false, delay: float = 0.0) -> Dictionary:
	var field := Field.new()
	var sailing := Sailing.new()
	var d := direction.normalized()
	# Preserve the established isolated 6.3 m/s force-profile regression.
	# star_turbulence_smoke exercises full production speed and summoned crests.
	field.add_wave(Vector2(0,-18.9) - d * 24.0, d, height, 4.0, 26.0, 8.0, 0.0, 8.0)
	var p := Vector2.ZERO
	var heading := 0.0
	var max_yaw := 0.0
	for frame in range(hz * 8):
		var time := (frame + 1.0) / hz
		var steer := 0.0
		if counter and time >= delay:
			steer = clampf(-heading * 3.0 - p.x * 0.12 - sailing.drift.x * 0.22, -1, 1)
		heading = sailing.step(field, p, heading, steer, time, 1.0 / hz,6.3)
		p += sailing.displacement
		max_yaw = maxf(max_yaw, absf(heading))
	return {"x": p.x, "z": p.y, "heading": heading, "max_yaw": max_yaw}

func _run() -> void:
	var field := Field.new()
	field.add_wave(Vector2(-24, 0), Vector2.RIGHT, 0.9, 4.5, 24, 8, 0, 8)
	check(field.sample(Vector2(0, 12), 3).x > 0.85 and field.sample(Vector2(4, 0), 3).x == 0,
		"long crest stays tall across its span and falls away across its narrow front")
	check(field.sample(Vector2(0, 25), 3).length() == 0, "finite crest has smooth bounded ends")
	var derivative_error := 0.0
	for x in range(-20, 20):
		var p := Vector2(x * 0.43, 19.3 + x * 0.17)
		var s := field.sample(p, 3)
		var dx := (field.sample(p + Vector2(0.001, 0), 3).x - field.sample(p - Vector2(0.001, 0), 3).x) / 0.002
		var dz := (field.sample(p + Vector2(0, 0.001), 3).x - field.sample(p - Vector2(0, 0.001), 3).x) / 0.002
		derivative_error = maxf(derivative_error, maxf(absf(dx - s.y), absf(dz - s.z)))
	check(derivative_error < 0.001, "analytic ridge, trough and end gradients match finite differences")
	var calm := trial(0, Vector2.RIGHT, 60)
	check(absf(calm.x) < 0.0001 and absf(calm.heading) < 0.0001, "calm water has no uncommanded drift or yaw")
	var small := trial(0.35, Vector2(1, -0.5), 60)
	var large := trial(1.0, Vector2(1, -0.5), 60)
	var mirror := trial(1.0, Vector2(-1, -0.5), 60)
	var corrected := trial(1.0, Vector2(1, -0.5), 60, true)
	var late := trial(1.0, Vector2(1, -0.5), 60, true, 6.5)
	print("RESPONSE small=%s large=%s counter=%s late=%s" % [small, large, corrected, late])
	check(absf(large.x) > absf(small.x) * 1.5 and large.max_yaw > small.max_yaw, "larger oblique waves cause more drift and turning")
	check(absf(large.x + mirror.x) < 0.001 and absf(large.heading + mirror.heading) < 0.001, "port and starboard encounters mirror one another")
	check(absf(corrected.x) < absf(large.x) * 0.5 and absf(corrected.x) < absf(late.x), "timely countersteering reduces route error more than no or late correction")
	check(large.heading > deg_to_rad(20) and absf(corrected.heading) < absf(large.heading) * 0.25,
		"wave force leaves a meaningful heading change that the rudder can counter")
	var broadside := trial(0.72, Vector2.RIGHT, 60)
	check(broadside.heading > deg_to_rad(10), "a side-on crest turns the bow instead of only sliding the hull")
	var frontal := trial(1.0, Vector2.DOWN, 60)
	check(absf(frontal.x) < 0.0001 and absf(frontal.heading) < 0.0001 and frontal.z > calm.z, "centred frontal wave slows progress without arbitrary yaw")
	var slow := trial(1.0, Vector2(1, -0.5), 30)
	var fast := trial(1.0, Vector2(1, -0.5), 120)
	print("RATE COMPARISON 30=%s 120=%s" % [slow, fast])
	check(absf(slow.x - fast.x) < 0.15 and absf(slow.heading - fast.heading) < 0.01, "wave response remains consistent at 30, 60 and 120 Hz")
	field.advance(8.1)
	check(field.waves.is_empty() and field.sample(Vector2.ZERO, 8.1) == Vector3.ZERO, "finite waves expire completely")
	var game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.boat.position = Vector3(-380, 0, -350)
	game.boat.rotation = Vector3.ZERO
	game.heading = 0
	game.boat.velocity = Vector3.ZERO
	var director = game.wave_encounters
	director.begin_region(0, Vector2(0, -1), 0)
	var max_active := 0
	var reached_recovery := false
	var launch_times: Array[float] = []
	var launch_heights: Array[float] = []
	for frame in range(6000):
		game.sea_time = frame / 60.0
		director.update(game, 1.0 / 60.0)
		max_active = maxi(max_active, game.ocean.wave_field.waves.size())
		if director.launched > launch_times.size():
			launch_times.append(game.sea_time)
			launch_heights.append(game.ocean.wave_field.waves.back().height)
		if director.phase == director.Phase.RECOVERY:
			reached_recovery = true
			break
	check(reached_recovery and director.launched == 10, "open-water regional sequence launches exactly ten crests then drains")
	check(max_active == 4 and game.ocean.wave_field.waves.is_empty(), "overlap stays bounded and recovery begins with no remaining crests")
	check(launch_times.size() == 10 and launch_times.back() - launch_times.front() < 21.0, "dense rampage launches ten waves within twenty-one seconds")
	check(launch_heights == Array(director.CREST_HEIGHTS, TYPE_FLOAT, &"", null), "spawned rampage crests preserve every distinct scheduled height")
	var saved_count: int = director.total_launched
	for frame in range(1100):
		game.sea_time += 1.0 / 60.0
		director.update(game, 1.0 / 60.0)
	check(director.total_launched == saved_count and director.phase == director.Phase.RECOVERY, "protected calm cannot be interrupted by ambient or regional waves")
	check(0 in director.completed, "region completion persists independently of leaving its area")
	director.warning_until = game.sea_time + 3.0
	director.warning_direction = Vector2.DOWN
	check(director.warning(game.sea_time, 0) == "Wave from ahead" and director.warning(game.sea_time, PI) == "Wave from astern",
		"incoming direction cue follows the bow when the player turns around")
	var ids: Array[int] = []
	var valid_zones := true
	var triggered_zones := true
	var terrain = game.archipelago.get_node("Terrain")
	for zone: Vector4 in director.REGIONS:
		var id := int(zone.w)
		valid_zones = valid_zones and id not in ids and terrain.terrain_height_at(Vector3(zone.x, 0, zone.y)) < -3.0
		ids.append(id)
		director.reset(60)
		game.ocean.wave_field.clear()
		game.boat.position = Vector3(zone.x, 0, zone.y)
		# The relocated departure's 75m quiet circle covers this zone's centre.
		# Its eastern water remains inside the same zone and outside that refuge.
		if id == 5:
			game.boat.position.x += 20.0
		valid_zones = valid_zones and Vector2(game.boat.position.x-zone.x,game.boat.position.z-zone.y).length()<zone.z and terrain.terrain_height_at(game.boat.position)<-3.0
		game.sea_time = 0
		director.update(game, 0)
		triggered_zones = triggered_zones and director.phase == director.Phase.WARNING and director.region_id == id
		print("ZONE %d %s depth=%.2f triggered=%d" % [id, director.REGION_NAMES[id], terrain.terrain_height_at(game.boat.position), director.region_id])
	check(valid_zones and ids.size() == 14, "fourteen independently identified rampage zones lie in open water")
	check(triggered_zones, "every zone activates without requiring a particular discovery stage")
	director.reset(60)
	game.boat.position = game.archipelago.get_node("SpawnPoints/Departure").position
	director.update(game, 0)
	check(director.phase == director.Phase.CALM, "departure remains quiet despite additional zones")
	director.begin_region(0, Vector2.UP, 0)
	director.phase = director.Phase.CALM
	game.boat.position = Vector3(-130, 0, 58)
	director.update(game, 0)
	check(director.phase == director.Phase.CALM, "re-entering an already visited wave zone does not restart it")
	game.boat.position = Vector3(-195, 0, -65)
	director.update(game, 0)
	check(director.phase == director.Phase.WARNING and director.region_id == 1, "a second zone can start within the same discovery stage")
	for h: float in [0.65, 1.1, 1.85]:
		var height_field := Field.new()
		height_field.add_wave(Vector2(-24, 0), Vector2.RIGHT, h, 4.8, 26, 8, 0, 8)
		check(absf(height_field.sample(Vector2.ZERO, 3).x - h) < 0.0001, "crest reaches its configured %.2f m height above calm water" % h)
	game.archipelago.debug_wave_zone()
	check(game.wave_encounters.phase == director.Phase.WARNING and game.wave_encounters.region_id == 10 and game.hull == game.hull_capacity,
		"development shortcut starts a fresh open-water zone test")
	for frame in range(900):
		game.advance_sailing(1.0 / 60.0, 0.0)
		if frame % 30 == 0:
			await process_frame
	check(game.state == game.State.SAILING and game.hull == game.hull_capacity and game.wave_encounters.launched > 0,
		"first zone shortcut has room to meet real waves for fifteen seconds without steering into shore")
	director.stop(game.ocean.wave_field)
	game.ocean.focus_xz = Vector2(900, 900)
	game.ocean.wave_field.add_wave(Vector2(-404, -350), Vector2.RIGHT, 1, 4, 24, 8, 0, 8)
	var far_value: Vector3 = game.ocean.wave_field.sample(Vector2(-380, -350), 3)
	game.ocean.focus_xz = Vector2(-380, -350)
	check(far_value.is_equal_approx(game.ocean.wave_field.sample(Vector2(-380, -350), 3)), "event field never follows the player or changes strength with mesh focus")
	game.ocean.wave_time = 3
	var water: Dictionary = game.ocean.water_hit(Vector3(-384, 0.3, -350), Vector3(-376, 0.3, -350), 0)
	check(not water.is_empty() and water.position.x < -380, "fast horizontal projectile intersects visible crest before crossing it")
	game.restart()
	check(game.ocean.wave_field.waves.is_empty() and director.completed.is_empty() and game.wave_sailing.drift == Vector2.ZERO and game.sea_time == 0,
		"retry resets wave events, regions, momentum and clock")
	game.state = game.State.SAILING
	game.ocean.wave_field.add_wave(Vector2.ZERO, Vector2.RIGHT, 1, 4, 24, 8, 0, 8)
	game.take_damage(game.hull_capacity, "fixture")
	check(game.ocean.wave_field.waves.is_empty() and not director.busy(), "loss clears encounter forces and scheduling")
	game.queue_free()
	await process_frame
	print("WAVE ENCOUNTERS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

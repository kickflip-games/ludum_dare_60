extends SceneTree
## Summoned zones must produce real, avoidable, countersteerable forces.
var game
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ")+label)
func trial(counter: bool, enabled: bool, hz: int) -> Dictionary:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = enabled
	game.wind_regions.enabled = false
	game.boat.position = Vector3(-380,0,-350)
	game.heading = 0
	game.target = Vector3(-380,0,-650)
	var max_yaw := 0.0
	var max_waves := 0
	var max_end := 0.0
	for frame in range(hz*12):
		var steering: float = clampf(-game.heading*3.0-(game.boat.position.x+380)*0.12-game.wave_sailing.drift.x*0.22,-1,1) if counter else 0.0
		if steering < 0: Input.action_press("steer_port",-steering)
		else: Input.action_release("steer_port")
		if steering > 0: Input.action_press("steer_starboard",steering)
		else: Input.action_release("steer_starboard")
		game._physics_process(1.0/hz)
		max_yaw = maxf(max_yaw,absf(game.heading))
		max_waves = maxi(max_waves,game.ocean.wave_field.waves.size())
		for w: Dictionary in game.ocean.wave_field.waves: max_end = maxf(max_end,w.start+w.lifetime)
	Input.action_release("steer_port")
	Input.action_release("steer_starboard")
	return {"x":game.boat.position.x+380,"heading":game.heading,"peak_yaw":max_yaw,"max_waves":max_waves,"end":max_end,"zones":game.wave_encounters.star_history.duplicate(true)}
func run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	var calm := trial(false,false,60)
	var wave := trial(false,true,60)
	var counter := trial(true,true,60)
	print("SUMMONED FORCES calm=%s wave=%s counter=%s" % [calm,wave,counter])
	check(absf(calm.x) < 0.01 and calm.peak_yaw < 0.001,"no summoned zone means no hidden drift or yaw")
	check(wave.peak_yaw > deg_to_rad(5) and absf(wave.x) > 1,"aligned star produces actual wave-driven heading change and displacement")
	check(absf(counter.x) < absf(wave.x)*0.5,"advertised steering materially reduces summoned-zone course error")
	check(wave.zones.size() == 1 and wave.zones[0].launched >= 2 and wave.max_waves <= 4,"one aligned star creates a bounded finite physical set")
	check(wave.end <= wave.zones[0].end+0.0001 and game.ocean.wave_field.waves.is_empty(),"every crest lifetime finishes inside the 70 percent window")
	var slow := trial(true,true,30)
	var fast := trial(true,true,120)
	check(absf(slow.x-fast.x) < 0.2 and absf(slow.heading-fast.heading) < 0.02,"summoned-zone counterplay is consistent at 30 and 120 Hz")
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = true
	game.boat.position = Vector3(-380,0,-350)
	game.heading = 0
	game.target = Vector3(-380,0,-650)
	for frame in range(30): game._physics_process(1.0/60)
	var fixed: Vector2 = game.wave_encounters.star_zones[0].center
	game.boat.position += Vector3(150,0,0)
	game.wave_encounters.update(game,0.0)
	check(game.wave_encounters.star_zones[0].center == fixed,"leaving the lane cannot drag the summoned turbulence toward the player")
	game.damage_immunity = 0
	game.take_damage(game.hull,"zone lifecycle")
	check(game.wave_encounters.star_zones.is_empty() and game.ocean.wave_field.waves.is_empty(),"defeat immediately cancels summoned zones and crests")
	game.free()
	print("STAR TURBULENCE CHECKS %d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

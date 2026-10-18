extends SceneTree
## Real movement/input route, alignment, wind and lifecycle regressions.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ")+label)

func action(name: String, value: float) -> void:
	if value > 0: Input.action_press(name,value)
	else: Input.action_release(name)

func step(seconds: float, hz: int = 60) -> void:
	for frame in range(roundi(seconds*hz)):
		game._physics_process(1.0/hz)
		game.cannon.advance(1.0/hz)
	game.hud._process(0.0)

func fresh() -> void:
	for name: String in ["steer_port","steer_starboard","watch_starboard","fire_starboard","astrolabe","restart_crossing"]:
		action(name,0)
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.boat.position = Vector3(400,0,320)
	game.heading = 0.0
	game._update_view(0.1)
	game.hud._process(0.0)

func run_route(with_wind: bool) -> void:
	fresh()
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = true
	game.enemy_encounters.enabled = true
	game.wind_regions.enabled = with_wind
	var max_waves := 0
	var max_speed := 0.0
	var legs: Array[int] = [0]
	var spawned_forward := true
	var fixed_centers: Dictionary = {}
	var shore_hits := 0
	var old_hits := 0
	for frame in range(60*240):
		# The pilot knows only the visible star's direction; no hidden safe-route points.
		var turn: float = game.destination_turn()
		var steer: float = clampf(turn*3.0-game.wave_sailing.yaw_rate*0.7,-1,1)
		action("steer_port",maxf(0,-steer))
		action("steer_starboard",maxf(0,steer))
		game._physics_process(1.0/60)
		game.cannon.advance(1.0/60)
		if game.hits_taken > old_hits:
			print("ROUTE HIT at=%s reason=%s" % [game.boat.position,game.hit_message])
			if game.hit_message.begins_with("HULL STRUCK"): shore_hits += 1
			old_hits = game.hits_taken
		max_waves = maxi(max_waves,game.ocean.wave_field.waves.size())
		max_speed = maxf(max_speed,game.wind_regions.speed)
		if legs.back() != game.voyage.leg: legs.append(game.voyage.leg)
		for z: Dictionary in game.wave_encounters.star_zones:
			spawned_forward = spawned_forward and (z.center-z.origin).dot(z.forward) > 40
			if fixed_centers.has(z.leg):
				spawned_forward = spawned_forward and fixed_centers[z.leg] == z.center
			else: fixed_centers[z.leg] = z.center
		if frame%30 == 0: await process_frame
		if game.state != game.State.SAILING: break
	print("JOURNEY wind=%s state=%s seconds=%.2f hits=%d hull=%d zones=%d waves=%d max_waves=%d legs=%s position=%s" % [with_wind,game.state,game.elapsed,game.hits_taken,game.hull,game.wave_encounters.star_history.size(),game.wave_encounters.total_launched,max_waves,legs,game.boat.position])
	print("LEG TIMINGS %s" % str(game.voyage.history))
	var harbour = game.archipelago.get_node("NavigationRegions/Lighthouse")
	check(game.state == game.State.ARRIVED and game.boat.position.distance_to(harbour.position) <= harbour.radius+0.01,"input-driven star following physically reaches Lighthouse Harbour; wind=%s" % with_wind)
	check(legs.size() == game.voyage.POINTS.size()+1 and game.voyage.history.size() == game.voyage.POINTS.size(),"all eleven stars advance exactly once and in order")
	check(shore_hits == 0,"star-following route avoids actual terrain/obstacle impacts")
	check(game.wave_encounters.star_history.size() == game.voyage.POINTS.size() and spawned_forward,"every newly aligned star summons one fixed zone ahead")
	check(max_waves <= 4 and game.wave_encounters.total_launched > 20,"route exercises bounded real crests")
	check(game.elapsed < 170,"full journey completes below 2m50s with real waves and pirates")
	check(max_speed <= 12.5 and (max_speed > 12 if with_wind else max_speed == 9.5),"optional wind changes cruise without stacking speed")
	check(game.ocean.wave_field.waves.is_empty() and game.wave_encounters.star_zones.is_empty() and game.wind_regions.speed == 9.5,"arrival clears waves, summoned regions and boost")

func run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	fresh()
	check(game.hud.instrument.visible and game.hud.instrument.get_rect().end.x < game.hud.size.x*0.5,"permanent sextant occupies the lower-left corner")
	check(InputMap.action_get_events("astrolabe").is_empty(),"Space has no sighting binding")
	var old_color: Color = game.guiding_star_color()
	game.heading = game.destination_bearing()
	game._update_view(0.0)
	check(game.hud.star_guidance().get("visible",false),"aligned star is visible from the ordinary deck camera")
	check(game.camera_mode == game.CameraMode.SAILING and game.guiding_star_direction().y < 0.25,"low star needs no look-up camera")
	check(game.hud.sextant_reading().contains("aligned"),"sextant reads zero at alignment")
	game.heading = game.destination_bearing()+deg_to_rad(35)
	check(game.hud.sextant_reading().contains("left"),"sextant shows the signed turn from the actual bow")
	var before_leg: int = game.voyage.leg
	step(16)
	check(game.voyage.leg == before_leg and game.wave_encounters.star_zones.is_empty(),"time passing off course cannot advance a star or create turbulence")
	fresh()
	game.boat.position = game.archipelago.get_node("NavigationRegions/Lighthouse").position
	game.voyage.update_progress(game)
	check(game.state == game.State.SAILING and game.voyage.leg == 0,"early harbour entry cannot skip the ordered stars")
	# Test a high-speed sweep through a point without a frame landing inside it.
	game.boat.position = game.target+Vector3(30,0,0)
	game.voyage.update_progress(game,game.target-Vector3(30,0,0))
	check(game.voyage.leg == 1 and game.guiding_star_color() != old_color,"swept point entry changes star and color once")
	# The alignment hold itself must not depend on frame rate.
	for hz in [30,60,120]:
		fresh()
		game.wave_encounters.enabled = true
		game.heading = game.destination_bearing()
		step(0.2,hz)
		check(game.wave_encounters.star_zones.is_empty(),"%d Hz brief alignment is not enough" % hz)
		step(0.2,hz)
		check(game.wave_encounters.star_zones.size() == 1,"%d Hz held star alignment summons turbulence" % hz)
		var z: Dictionary = game.wave_encounters.star_zones[0].duplicate()
		check(is_equal_approx(z.end-z.start,10.5),"turbulence window is exactly 70 percent of 15 seconds")
		game.boat.position = Vector3(400,0,320)
		game.heading += PI
		game.sea_time = z.end+0.001
		game.wave_encounters.update(game,0.0)
		game.ocean.wave_time = game.sea_time
		game.ocean.update_turbulence(game.wave_encounters,0.0)
		check(game.wave_encounters.star_zones.is_empty() and game.ocean.wave_field.waves.is_empty() and game.ocean.turbulence_intensity == 0,"70 percent endpoint clears crests and visible zone completely")
		game.heading = game.destination_bearing()
		step(1,hz)
		check(game.wave_encounters.star_history.size() == 1 and game.wave_encounters.star_zones.is_empty(),"realigning the same star cannot summon it again")
	# Wind entry/miss/exit with actual game movement and smooth capped response.
	fresh()
	game.wind_regions.enabled = true
	check(game.wind_regions.advance(Vector3(0,0,0),1) == 9.5,"missing wind leaves ordinary cruise unchanged")
	var lane: Vector4 = game.wind_regions.LANES[0]
	check(game.wind_regions.advance(Vector3(lane.x,0,lane.y),0.5) > 9.5 and game.wind_regions.speed < 12.5,"wind entry eases speed up")
	for i in range(20): game.wind_regions.advance(Vector3(lane.x,0,lane.y),0.1)
	check(game.wind_regions.speed == 12.5,"remaining/re-entering wind cannot exceed its cap")
	game.wind_regions.advance(Vector3.ZERO,0.5)
	check(game.wind_regions.speed < 12.5 and game.wind_regions.speed > 9.5,"wind exit eases down")
	game.wind_regions.advance(Vector3.ZERO,2)
	check(game.wind_regions.speed == 9.5,"wind exit restores cruise")
	game.wind_regions.advance(Vector3(lane.x,0,lane.y),1)
	game.restart()
	check(game.wind_regions.speed == 9.5 and game.voyage.leg == 0 and not game.voyage.aligned and game.wave_encounters.star_history.is_empty(),"retry clears boost, alignment latch, zones and route")
	check(game.voyage.leg_started == 0.0,"retry starts first-leg timing from the new voyage clock")
	await run_route(false)
	await run_route(true)
	game.free()
	print("JOURNEY CHECKS %d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

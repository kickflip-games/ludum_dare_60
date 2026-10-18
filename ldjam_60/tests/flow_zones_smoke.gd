extends SceneTree
## Real movement/input, once-per-zone rewards and stronger-force regression.
const Flow = preload("res://game/flow_zones.gd")
const Field = preload("res://game/ocean/wave_field.gd")
const Sailing = preload("res://game/ocean/wave_sailing.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func action(name: String, pressed: bool) -> void:
	Input.action_press(name) if pressed else Input.action_release(name)

func stage(offset: Vector2, bearing: float = 0.0) -> void:
	game.restart()
	game.state = game.State.SAILING
	game.wave_encounters.enabled = false
	game.enemy_encounters.enabled = false
	game.flow_zones.enabled = true
	game.boat.position = game.arena_center() + Vector3(offset.x, 0, offset.y)
	game.heading = bearing
	game.boat.rotation.y = -bearing

func sail(seconds: float, hz: int = 60) -> void:
	for frame in roundi(seconds * hz):
		game._physics_process(1.0 / hz)
		game.cannon.advance(1.0 / hz)

func wave_trial(speed: float, hz: int, counter: bool) -> Dictionary:
	var field := Field.new()
	var model := Sailing.new()
	var d := Vector2(1, -0.5).normalized()
	field.add_wave(Vector2(0, -speed * 3.0) - d * 24, d, 1.0, 4.0, 26, 8, 0, 8)
	var point := Vector2.ZERO
	var heading := 0.0
	for frame in hz * 8:
		var rudder := clampf(-heading * 3.0 - point.x * 0.12 - model.drift.x * 0.22, -1, 1) if counter else 0.0
		heading = model.step(field, point, heading, rudder, float(frame + 1) / hz, 1.0 / hz, speed)
		point += model.displacement
	return {"x": point.x, "heading": heading}

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	check(game.sailing_speed == 7.5 and game.flow_zones.zones.size() == 3, "7.5 m/s base and three authored flow zones")
	check(is_equal_approx(game.ocean_settings.height_multiplier,0.22*4.0),"rolling surface uses the requested 4x modulation")
	var flow = game.flow_zones
	var original: Array[Dictionary] = flow.zones.duplicate(true)
	# Verify every part of each ribbon, not only its marker, against terrain and
	# actual obstacle collision; also keep clear of spawn and return initiation.
	var safe := true
	var spawn: Vector2 = Vector2(game.boat.position.x, game.boat.position.z)
	for zone: Dictionary in flow.zones:
		for x in range(-32, 33, 3):
			for z in range(-32, 33, 3):
				var point: Vector2 = zone.center + Vector2(x, z)
				if Flow.distance_to_zone(point, zone) <= 0:
					var world := Vector3(point.x, 0, point.y)
					safe = safe and world.distance_to(game.arena_center()) < 125 and point.distance_to(spawn) > 8
					safe = safe and game.archipelago.water_clear(world, 4.0)
	check(safe, "complete flow footprints have hull clearance and remain inside 125 m, away from spawn")
	# Membership boundaries, rotated rounded caps, and no repeated/ordered grants.
	var isolated := Flow.new()
	isolated.zones = original.duplicate(true)
	for order in [[0,1,2],[2,0,1]]:
		isolated.reset()
		for i: int in order:
			check(isolated.collect_at(original[i].center) == 1, "new zone %d rewards once in order %s" % [i, order])
			check(isolated.collect_at(original[i].center) == 0, "standing/revisiting zone %d never repeats" % i)
		check(is_equal_approx(isolated.multiplier(), pow(1.25,3)), "zone order leaves the same compounded multiplier")
	isolated.reset()
	isolated.zones[1].center = isolated.zones[0].center
	check(isolated.collect_at(isolated.zones[0].center) == 2 and isolated.collect_at(isolated.zones[0].center) == 0,
		"two fresh overlapping IDs reward twice total, never per frame")
	for zone: Dictionary in original:
		var forward := Vector2(sin(zone.heading), -cos(zone.heading))
		check(Flow.distance_to_zone(zone.center + forward * (zone.length * 0.5 + 0.2), zone) > 0,
			"outside rounded end does not collect %s" % zone.id)
	# Enter every real authored ribbon through actual sailing, rather than
	# assigning reward IDs. Retain each reward when staging the next approach.
	for hz in [30,60,120]:
		stage(Vector2(70,-30))
		await physics_frame
		var at: Vector3 = game.boat.position
		sail(2, hz)
		check(absf(game.boat.position.distance_to(at) - 15) < 0.02 and flow.collected.is_empty(),
			"%d Hz no-zone control travels 15 m without granting speed" % hz)
		var target := 7.5
		for zone: Dictionary in original:
			var forward := Vector2(sin(zone.heading), -cos(zone.heading))
			var start: Vector2 = zone.center - forward * (zone.length * 0.5 + 3)
			game.boat.position = Vector3(start.x, 0, start.y)
			game.heading = zone.heading
			game.boat.rotation.y = -game.heading
			game.wave_sailing.reset()
			game.arena_return.reset()
			await physics_frame
			sail(1.4, hz)
			target *= 1.25
			check(is_equal_approx(game.propulsion_speed(), target) and game.hits_taken == 0,
				"%d Hz real entry into %s grants persistent %.6f m/s" % [hz, zone.id, target])
		# Leave all zones into clear water; measured movement and held E must keep
		# the entire reward. The same displacement is required at all frame rates.
		game.boat.position = game.arena_center() + Vector3(70,0,-30)
		game.heading = 0
		game.boat.rotation.y = 0
		game.wave_sailing.reset()
		game.arena_return.reset()
		await physics_frame
		at = game.boat.position
		action("watch_starboard", true)
		sail(1, hz)
		action("watch_starboard", false)
		check(absf(game.boat.position.distance_to(at) - target) < 0.025 and flow.collected.size() == 3,
			"%d Hz exit and unbound E retain measured full three-zone speed" % hz)
		game.damage_immunity = 0
		game.take_damage(1,"flow regression")
		check(is_equal_approx(game.propulsion_speed(), target), "nonfatal damage preserves all flow rewards")
		game.take_damage(1,"immune hit")
		check(flow.collected.size() == 3, "immunity does not consume flow rewards")
		game.damage_immunity = 0
		game.take_damage(3,"flow sinking")
		check(game.state == game.State.LOST and flow.collected.is_empty(), "sinking clears flow rewards")
		game.restart()
		check(flow.collected.is_empty() and game.propulsion_speed() == 7.5, "retry resets speed and all distinct zone eligibility")
	# Player action remains necessary; a real steering turn occurs at full speed.
	stage(Vector2(70,-30))
	for zone: Dictionary in original: flow.collect_at(zone.center)
	await physics_frame
	action("steer_starboard", true)
	sail(0.7)
	action("steer_starboard", false)
	check(game.heading > 0.3 and game.hits_taken == 0, "A/D input still turns the fully boosted boat")
	action("restart_crossing",true)
	sail(0.65)
	action("restart_crossing",false)
	check(flow.collected.is_empty() and game.propulsion_speed()==7.5 and game.state==game.State.CASTING_OFF,
		"held R resets collected rewards and speed through the real input path")
	# All reward levels cross the advisory storm line, including a long frame.
	# Real collisions remain enabled; no health protection.
	for hz in [30,60,120]:
		for level in [0,1,2,3]:
			stage(Vector2(161,0), PI/2)
			for i in level: flow.collect_at(original[i].center)
			await physics_frame
			var max_radius := 0.0
			for frame in hz * 2:
				game.advance_sailing(1.0/hz,0)
				max_radius = maxf(max_radius,game.boat.position.distance_to(game.arena_center()))
			check(max_radius > 175 and game.hits_taken == 0 and game.state == game.State.SAILING,
				"%d Hz level %d: earned speed crosses storm line without obstacle hits" % [hz,level])
	stage(Vector2(161,0), PI/2)
	for zone: Dictionary in original: flow.collect_at(zone.center)
	game.wave_sailing.drift = Vector2(3.8,0)
	game.wave_sailing.yaw_rate = 0.56
	game.advance_sailing(0.75,0)
	check(game.boat.position.distance_to(game.arena_center()) > 170.01, "long frame plus strong drift crosses storm line freely")
	# Exact 50% force gain, including the former saturation case. This calculates
	# the old vector independently, then compares the production force at contact.
	for count in [1,4]:
		var field := Field.new()
		for i in count: field.add_wave(Vector2(-24,0),Vector2.RIGHT,2,4,26,8,0,8)
		var old_force := Vector2.ZERO
		for wave: Dictionary in field.waves:
			old_force += wave.direction * maxf(0.0,field.sample_one(wave,Vector2.ZERO,3).x) * (4.0/wave.width) * 6.5
		old_force = old_force.limit_length(8.0)
		check(field.push_at(Vector2.ZERO,0,3).is_equal_approx(old_force*1.5), "force is exactly 150%% of former force with %d event(s)" % count)
		check(field.push_at(Vector2(200,200),0,3) == Vector2.ZERO, "no contact means no hidden 50% force")
	for speed in [7.5,7.5*pow(1.25,3)]:
		var unattended := wave_trial(speed,60,false)
		var corrected := wave_trial(speed,60,true)
		print("STRONG WAVE speed=%f unattended=%s corrected=%s" % [speed,unattended,corrected])
		check(absf(unattended.x)>1 and absf(corrected.x)<absf(unattended.x)*0.5,
			"%.3f m/s: player countersteering reduces stronger-wave error" % speed)
		var slow := wave_trial(speed,30,false)
		var fast := wave_trial(speed,120,false)
		check(absf(slow.x-fast.x)<0.2 and absf(slow.heading-fast.heading)<0.012,
			"%.3f m/s stronger-wave response agrees at 30/120 Hz" % speed)
	# Physical obstacle collision remains live at full speed.
	stage(Vector2(85,15), PI)
	for zone: Dictionary in original: flow.collect_at(zone.center)
	await physics_frame
	sail(2.5)
	check(game.hits_taken > 0 and game.boat.position.z < game.arena_center().z + 48,
		"full-speed approach hits visible wreck rather than tunnelling through")
	# Real production-water negative case: at the trough, the low barrel line
	# meets an advancing ambient swell before a target 28 m away.
	stage(Vector2(0,100))
	await physics_frame
	action("watch_starboard",true)
	game._physics_process(1.0/60)
	var muzzle: Vector3 = game.cannon.shot_origin()
	var water_contact: Dictionary = game.ocean.water_hit(muzzle,muzzle+game.cannon.aimed_direction()*28,0)
	check(not water_contact.is_empty(),"visible rolling swell can intercept a low cannon line before a distant target")
	action("watch_starboard",false)
	# Lifecycle victory path is exercised through the production scheduler.
	stage(Vector2(70,-30))
	for zone: Dictionary in original: flow.collect_at(zone.center)
	var enemies = game.enemy_encounters
	enemies.enabled = true
	enemies.phase = enemies.Phase.ACTIVE
	enemies.wave_number = 5
	enemies.spawn_queue.clear()
	enemies.records.clear()
	enemies.update_encounters(1.0/60)
	check(game.state == game.State.ARRIVED and flow.collected.is_empty(), "scheduler victory clears speed and collection state")
	game.queue_free()
	await process_frame
	print("FLOW ZONES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

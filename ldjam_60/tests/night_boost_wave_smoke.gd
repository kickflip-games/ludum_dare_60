extends SceneTree
## Actual Shift input, finite arena scheduling, lifecycle and unrestricted storm-line crossing.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func shift(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fresh() -> void:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.boat.position = game.arena_center() + Vector3(110,0,35)
	game.heading = 0
	game.boat.rotation.y = 0
	game.weather_enabled = false

func step(seconds: float, hz: int = 60) -> void:
	for frame in roundi(seconds*hz): game._physics_process(1.0/hz)

func _run() -> void:
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	for hz in [30,60,120]:
		fresh()
		var start: Vector3 = game.boat.position
		step(0.5,hz)
		check(is_equal_approx(start.distance_to(game.boat.position),3.75), "%d Hz no Shift keeps 7.5 m/s" % hz)
		check(not game.boost_wind.visible and game.boost_wind.active_streams==0, "%d Hz no boost has no tailwind indicator" % hz)
		start = game.boat.position
		shift(true)
		step(0.5,hz)
		check(is_equal_approx(game.propulsion_speed(),11.25) and absf(start.distance_to(game.boat.position)-5.625)<0.002, "%d Hz real Shift gives exactly 50 percent movement" % hz)
		check(game.boost_wind.visible and game.boost_wind.strength>0.99 and game.boost_wind.active_streams==8, "%d Hz held Shift shows bounded wind ribbons" % hz)
		shift(true,true)
		step(0.2,hz)
		check(is_equal_approx(game.propulsion_speed(),11.25), "%d Hz key echo and holding never stack boost" % hz)
		shift(false)
		step(0.1,hz)
		check(not game.boosting and is_equal_approx(game.actual_speed,7.5), "%d Hz release immediately restores cruise" % hz)
		step(0.1,hz)
		check(not game.boost_wind.visible, "%d Hz released wind indicator fades completely" % hz)
	fresh()
	for zone: Dictionary in game.flow_zones.zones: game.flow_zones.collect_at(zone.center)
	shift(true)
	step(0.1)
	check(is_equal_approx(game.propulsion_speed(),21.97265625), "Shift multiplies all three earned flow rewards by 1.5")
	shift(false)
	step(0.1)
	check(is_equal_approx(game.propulsion_speed(),14.6484375) and game.flow_zones.collected.size()==3, "release preserves permanent rewards")
	step(0.1)
	check(not game.boost_wind.visible, "permanent flow rewards alone never show the Shift indicator")
	shift(true)
	step(0.1)
	game.take_damage(1,"boost regression")
	check(game.boosting and is_equal_approx(game.propulsion_speed(),21.97265625), "nonfatal damage preserves held boost and earned speed")
	game.damage_immunity = 0
	game.take_damage(game.hull,"boost sinking regression")
	check(game.state==game.State.LOST and not game.boosting and not Input.is_action_pressed("boost_sailing"), "real sinking clears the boost and input latch")
	fresh()
	Input.action_press("steer_starboard")
	shift(true)
	step(0.3)
	check(game.heading>0.05 and is_equal_approx(game.propulsion_speed(),11.25), "steering remains available during Shift boost")
	game.motion_setting = 1
	step(0.1)
	check(game.boost_wind.visible and game.boost_wind.active_streams==4 and is_equal_approx(game.propulsion_speed(),11.25), "Reduced motion preserves the boost with fewer wind streaks")
	game.motion_setting = 0
	Input.action_press("watch_starboard")
	step(0.4)
	var held_heading: float = game.heading
	step(0.2)
	check(not game.cannon.aiming and is_equal_approx(game.propulsion_speed(),11.25) and game.heading-held_heading>0.05, "unbound E preserves boost and independent arena steering")
	check(game.cannon.shots_fired==0, "boost and unbound E do not fire without Space or click")
	var fire := InputEventKey.new()
	fire.physical_keycode = KEY_SPACE
	fire.pressed = true
	Input.parse_input_event(fire)
	Input.flush_buffered_events()
	var turning_heading: float = game.heading
	step(0.1)
	check(game.cannon.shots_fired==1 and game.heading>turning_heading and game.boosting,
		"physical Space fires the cone while Shift and steering remain held")
	fire.pressed = false
	Input.parse_input_event(fire)
	Input.flush_buffered_events()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(0.1)
	check(not game.boosting and not Input.is_action_pressed("boost_sailing") and not Input.is_action_pressed("fire_starboard") and not game.cannon._fire_held and game.turn_input==0, "focus loss clears Shift, firing and steering")
	check(not game.boost_wind.visible and game.boost_wind.strength==0, "focus loss immediately clears wind ribbons")
	shift(true)
	step(0.1)
	game.restart()
	check(not game.boosting and not Input.is_action_pressed("boost_sailing"), "retry clears boost and held key")
	game.state = game.State.LOST
	shift(true)
	step(0.1)
	check(not game.boosting and is_equal_approx(game.propulsion_speed(),7.5), "ending cannot activate speed boost")
	# Real arena director clock, with an actual living enemy and held cannon aim.
	fresh()
	game.enemy_encounters.enabled = true
	game.enemy_encounters.next_wave_in = 0.0
	game.enemy_encounters.update_encounters(1.0/60)
	Input.action_press("watch_starboard")
	game._physics_process(1.0/60)
	game.wave_encounters.enabled = true
	var director = game.wave_encounters
	var first_time := -1.0
	var maximum := 0
	var recoveries := 0
	var recovery_valid := true
	var warning_valid := true
	var count := 0
	for frame in 3600:
		game.sea_time += 1.0/60
		var previous: int = director.total_launched
		var phase: int = director.phase
		director.update(game,1.0/60)
		maximum = maxi(maximum,game.ocean.wave_field.waves.size())
		if director.total_launched>previous:
			if first_time<0: first_time=game.sea_time
			warning_valid = warning_valid and is_equal_approx(director.warning_until-game.sea_time,3.0)
			count += 1
		if director.phase==director.Phase.RECOVERY:
			recovery_valid = recovery_valid and game.ocean.wave_field.waves.is_empty()
			if phase!=director.Phase.RECOVERY:
				recoveries += 1
				recovery_valid = recovery_valid and director.phase_until-game.sea_time>=3.99 and director.phase_until-game.sea_time<=6.01
	print("ARENA CADENCE first=%.3f launches=%d max=%d recovery=%d" % [first_time,count,maximum,recoveries])
	check(game.enemy_encounters.battle_active() and not game.cannon.aiming, "cadence fixture includes real active combat with current arcade controls")
	check(first_time>=6 and first_time<=8.1, "first arena wave launches after 6-8 seconds of sailing")
	check(count>=6 and maximum>=2 and maximum<=4, "recurring wave pairs spawn often during combat and aiming; four-event cap holds")
	check(recoveries>=2 and recovery_valid, "finite wave pairs drain fully then provide 4-6 seconds of calm")
	check(warning_valid, "every launched crest has three seconds of directional warning")
	fresh()
	game.wave_encounters.enabled = true
	game.boat.position = game.arena_center()+Vector3(0,0,30)
	for frame in 900:
		game.sea_time += 1.0/60
		director.update(game,1.0/60)
	check(director.total_launched==0, "island shelter does not launch waves through the central shoreline")
	game.boat.position = game.arena_center()+Vector3(110,0,35)
	game.state = game.State.READY
	for frame in 600:
		game.sea_time += 1.0/60
		director.update(game,1.0/60)
	check(director.total_launched==0, "title and ended sessions cannot schedule new arena waves")
	fresh()
	step(10)
	check(director.total_launched==0 and game.wave_sailing.drift.length()<0.001, "disabled wave trigger has no hidden current or wave launches")
	# Let normal sailing, scheduling and contact run together on a clear eastern lane.
	fresh()
	game.wave_encounters.enabled = true
	game.flow_zones.enabled = false
	game.boat.position = game.arena_center()+Vector3(115,0,75)
	var push := 0.0
	var yaw := 0.0
	for frame in 900:
		game._physics_process(1.0/60)
		push = maxf(push,game.wave_sailing.drift.length())
		yaw = maxf(yaw,absf(game.wave_sailing.yaw_rate))
	print("SCHEDULED CONTACT launches=%d drift=%.4f yaw=%.4f hits=%d" % [director.total_launched,push,yaw,game.hits_taken])
	check(director.total_launched>=2 and push>0.1 and yaw>0.02, "automatically scheduled visible waves measurably push and turn the moving boat")
	check(game.hits_taken==0 and game.state==game.State.SAILING, "normal clear-water encounter does not require a collision or damage")
	fresh()
	game.flow_zones.enabled = true
	for zone: Dictionary in game.flow_zones.zones: game.flow_zones.collect_at(zone.center)
	game.boat.position = game.arena_center()+Vector3(130,0,15)
	game.heading = PI/2
	game.boat.rotation.y = -game.heading
	shift(true)
	var radius := 0.0
	for frame in 720:
		game._physics_process(1.0/60)
		radius = maxf(radius,game.boat.position.distance_to(game.arena_center()))
	check(radius>game.arena_radius+100 and game.state==game.State.SAILING, "full flow plus Shift crosses storm line without automatic return")
	check(game.boosting and is_equal_approx(game.propulsion_speed(),21.97265625) and game.boost_wind.visible, "continuous twelve-second hold retains full boost and wind without timeout or cooldown")
	game.restart()
	check(director.total_launched==0 and game.ocean.wave_field.waves.is_empty() and director.history.is_empty(), "retry clears wave clock, finite events, history and boost")
	game.queue_free()
	await process_frame
	print("NIGHT BOOST WAVES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

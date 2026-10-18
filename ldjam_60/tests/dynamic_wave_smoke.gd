extends SceneTree
## Integrated visible-height / pressure / hull response, rather than a second water model.
const Field = preload("res://game/ocean/wave_field.gd")
var game
var checks := 0
var failures := 0
var results: Dictionary = {}
const ORIGIN := Vector3(-300,0,-330)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func trial(height: float, hz: int, preset_path: String = "res://game/ocean/presets/calm.tres", ambient_multiplier: float = 0.095) -> Dictionary:
	game.restart()
	game.state = game.State.SAILING
	game.enemy_encounters.enabled = false
	game.wave_encounters.enabled = false
	game.weather_enabled = false
	game.ocean_settings = load(preset_path).duplicate(true)
	# Isolate finite-crest lift/roll ratios from background swells. The production
	# four-times-larger rolling composite is exercised separately below.
	game.ocean_settings.height_multiplier = ambient_multiplier
	game.boat.position = ORIGIN
	game.heading = 0.0
	game.boat.rotation = Vector3.ZERO
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	game.sea_time = 0.0
	game._update_view(0.0)
	await physics_frame
	var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
	if height > 0.0:
		game.ocean.wave_field.add_wave(Vector2(center.x-24,center.z-game.SPEED*3),Vector2.RIGHT,height,4.8,26,8,0,8)
	var maximum_error := 0.0
	var squared_error := 0.0
	var maximum_heave := 0.0
	var maximum_roll := 0.0
	var roll_area := 0.0
	var first_visible := -1.0
	var first_push := -1.0
	var clock_ok := true
	var camera_ok := true
	var limits_ok := true
	var final_error := 0.0
	var dt := 1.0/hz
	for frame in range(hz*9):
		game.advance_sailing(dt,0.0)
		game._update_view(dt)
		center = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
		var forward: Vector3 = -game.boat.global_basis.z
		var right: Vector3 = game.boat.global_basis.x
		var mean := 0.0
		var visible_height := 0.0
		var highest_edge := -INF
		var index := 0
		for at: Vector3 in [center,center+forward*2.1,center-forward*2.1,center+right*1.05,center-right*1.05]:
			var p := Vector2(at.x,at.z)
			mean += game.ocean.height_at(p)*(0.5 if index==0 else 0.125)
			if index > 0: highest_edge = maxf(highest_edge,game.ocean.height_at(p))
			visible_height = maxf(visible_height,game.ocean.wave_field.sample(p,game.sea_time).x)
			index += 1
		var equilibrium: float = game.ocean_settings.sea_level+(mean-game.ocean_settings.sea_level)*game.ocean_settings.bob_strength
		# The intended flotation target includes bounded visual edge support,
		# rather than treating that support as a tracking error from the mean.
		equilibrium = maxf(equilibrium,minf(equilibrium+0.50,highest_edge-0.50))
		final_error = absf(game.boat_motion.heave-equilibrium)
		maximum_error = maxf(maximum_error,final_error)
		squared_error += final_error*final_error
		maximum_heave = maxf(maximum_heave,game.boat_motion.heave-game.ocean_settings.sea_level)
		maximum_roll = maxf(maximum_roll,absf(game.boat_motion.roll))
		roll_area += absf(game.boat_motion.roll)*dt
		if first_visible < 0 and visible_height > 0.001:
			first_visible = game.sea_time
		if first_push < 0 and game.wave_sailing.drift.length() > 0.005:
			first_push = game.sea_time
		clock_ok = clock_ok and is_equal_approx(game.ocean.wave_time,game.sea_time)
		camera_ok = camera_ok and absf(game.camera.rotation.z)<0.15 and game.camera.position.y>=game.ocean.height_at(Vector2(game.camera.position.x,game.camera.position.z))+1.19
		limits_ok = limits_ok and absf(game.boat_motion.pitch)<=deg_to_rad(game.ocean_settings.pitch_limit_degrees)+0.0001 and absf(game.boat_motion.roll)<=deg_to_rad(game.ocean_settings.roll_limit_degrees)+0.0001
		if frame%12==0:
			await process_frame
	return {"height":height,"hz":hz,"max_equilibrium_error_m":maximum_error,
		"rms_equilibrium_error_m":sqrt(squared_error/(hz*9)),"settled_error_m":final_error,
		"max_heave_m":maximum_heave,"max_roll_degrees":rad_to_deg(maximum_roll),"roll_integral":roll_area,
		"visible_at":first_visible,"push_at":first_push,"heading":game.heading,"x":game.boat.position.x,
		"z":game.boat.position.z,"drift":game.wave_sailing.drift.length(),"clock_ok":clock_ok,
		"camera_ok":camera_ok,"limits_ok":limits_ok}

func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	await physics_frame
	var field := Field.new()
	field.add_wave(Vector2(-24,0),Vector2.RIGHT,1.85,4.8,26,8,0,8)
	check(absf(field.sample(Vector2.ZERO,3).x-1.85)<0.0001 and absf(field.sample(Vector2(2,0),3.25).x-1.85)<0.0001,
		"crest travels exactly two metres in its assigned direction over a quarter second")
	var smooth_edges := true
	for t: float in [-0.01,0.0,0.01,7.99,8.0,8.01]:
		smooth_edges = smooth_edges and absf(field.sample(Vector2(-24+8*t,0),t).x)<0.002
	check(smooth_edges,"moving crest height enters and leaves continuously at its lifetime boundaries")
	check(field.push_at(Vector2(20,0),0,3)==Vector2.ZERO and field.sample(Vector2(20,0),3)==Vector3.ZERO,
		"no displacement or pressure exists outside the visible ridge footprint")
	field.clear()
	for i in range(4):
		field.add_wave(Vector2(-24,0),Vector2.RIGHT,2,4.8,26,8,0,8)
	check(field.add_wave(Vector2.ZERO,Vector2.LEFT,2,4.8,26,8,0)==-1 and absf(field.sample(Vector2.ZERO,3).x-8)<0.0001,
		"four overlapping maximum crests remain additive and a fifth is refused")
	game.ocean.wave_field = field
	game.ocean._sync_settings()
	check(game.ocean.near_mesh.custom_aabb.end.y > 8.0+game.ocean_settings.maximum_displacement(),
		"GPU displacement bounds cover four maximum crests plus the ambient surface")
	game.ocean.wave_field = Field.new()
	for preset in ["calm","choppy","stormy"]:
		var quiet := await trial(0.0,60,"res://game/ocean/presets/"+preset+".tres")
		check(absf(quiet.x-ORIGIN.x)<0.00001 and absf(quiet.heading)<0.00001 and quiet.drift<0.00001,
			"%s ambient waves cannot add a second horizontal shove or yaw" % preset)
		check(quiet.camera_ok and quiet.limits_ok,"%s preset keeps the horizon stable and hull inside comfort limits" % preset)
	var small := await trial(0.65,60)
	var large := await trial(1.85,60)
	var slow := await trial(1.85,30)
	var fast := await trial(1.85,120)
	check(large.max_heave_m>small.max_heave_m*1.8 and large.roll_integral>small.roll_integral,
		"larger visible crests lift the hull further and sustain more roll")
	check(large.push_at>=large.visible_at and large.push_at-large.visible_at<0.2 and large.clock_ok,
		"horizontal pressure begins only after the crest reaches the sampled hull on the shared clock")
	check(large.max_equilibrium_error_m<0.45 and large.settled_error_m<0.02,
		"the hull follows the actual five-point surface and settles after the crest expires")
	check(absf(slow.max_heave_m-fast.max_heave_m)<0.08 and absf(slow.x-fast.x)<0.15 and absf(slow.heading-fast.heading)<0.01,
		"moving hull response and wave pressure agree at 30, 60 and 120 Hz")
	check(large.camera_ok and slow.camera_ok and fast.camera_ok and large.limits_ok,
		"large encounters keep a bounded, clear deck camera and preserve the 8/12-degree hull limits")
	check(game.boat.position.y==0 and game.boat.rotation.x==0 and game.boat.rotation.z==0,
		"wave motion never rotates or lifts the planar collision root")
	var rolling := await trial(1.85,60,"res://game/ocean/presets/calm.tres",0.88)
	check(rolling.camera_ok and rolling.limits_ok and rolling.clock_ok and rolling.settled_error_m<0.02,
		"production 4x rolls plus a large crest preserve camera clearance, hull limits and shared time")
	results["production_rolling"] = rolling
	var baseline_path := ProjectSettings.globalize_path("res://../artifacts/water_review/dynamic_toon/baseline/source/ldjam_60/game/ocean/presets/calm.tres")
	if FileAccess.file_exists(baseline_path):
		var baseline := await trial(1.85,60,baseline_path)
		# World positions are float32. Compare below a millimetre, rather than below
		# one representable world-position increment at this test's 300 m coordinates.
		check(absf(baseline.x-large.x)<0.001 and absf(baseline.heading-large.heading)<0.0001,
			"horizontal response is unchanged from the preserved working-tree baseline")
		results["baseline"] = baseline
	results.merge({"small":small,"large":large,"30hz":slow,"120hz":fast,"checks":checks,"failures":failures})
	var dir := ProjectSettings.globalize_path("res://../artifacts/water_review/dynamic_toon")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("motion-check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("DYNAMIC WATER RESPONSE "+JSON.stringify(results))
	print("DYNAMIC WAVE CHECK: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

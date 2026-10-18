extends "res://tests/dynamic_water_previews.gd"
## Intentionally camera-only: the advertised sensation must not depend on effects.
var checks := 0
var failures := 0
var measurements: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func trial(direction: Vector2, hz: int, reduced: bool = false, count: int = 1) -> Dictionary:
	place()
	game.motion_setting = 1 if reduced else 0
	game.ocean_settings.height_multiplier = 0.0
	game.actual_speed = 0.0
	game.boat.velocity = Vector3.ZERO
	game.boat_motion.reset()
	game._sailing_camera_initialized = false
	game._update_view(0.0)
	var center: Vector3 = game.boat.to_global(game.BoatWaveMotion.HULL_CENTER)
	for i in range(count):
		var d := direction.rotated(i*PI/2.0)
		game.ocean.wave_field.add_wave(Vector2(center.x,center.z)-d*24.0,d,1.85,4.8,30,8,0,8)
	var min_y := INF
	var max_y := -INF
	var peak_roll := 0.0
	var peak_pitch := 0.0
	var incoming_roll := 0.0
	var clear := true
	var max_lag := 0.0
	var max_step := 0.0
	var previous: Vector3 = game.camera.position
	var max_contacts := 0
	for frame in range(hz*10):
		game.sea_time = float(frame+1)/hz
		game.ocean.wave_field.advance(game.sea_time)
		game._update_view(1.0/hz)
		var r: float = game.camera.rotation.z
		peak_roll = maxf(peak_roll,absf(r))
		peak_pitch = maxf(peak_pitch,absf(game.camera.rotation.x+deg_to_rad(7)))
		# Centre leading face enters at t=2.61; sample its developed slope, before crest t=3.
		if game.sea_time > 2.75 and game.sea_time < 2.85: incoming_roll = r
		min_y = minf(min_y,game.camera.position.y)
		max_y = maxf(max_y,game.camera.position.y)
		max_lag = maxf(max_lag,game.camera.position.distance_to(game.helm_anchor.global_position))
		max_step = maxf(max_step,previous.distance_to(game.camera.position))
		previous = game.camera.position
		clear = clear and game.camera.transform.is_finite() and game.camera.position.y >= game.ocean.height_at(Vector2(previous.x,previous.z))+1.19
		max_contacts = maxi(max_contacts,game.deck_response.contacts.size())
		if frame % hz == 0: await process_frame
	var result := {"heave":max_y-min_y,"roll":peak_roll,"pitch":peak_pitch,"incoming_roll":incoming_roll,
		"contacts":game.deck_response.impact_count,"max_contacts":max_contacts,"clear":clear,
		"lag":max_lag,"step":max_step,"settled":game.deck_response.impact.length()+game.deck_response.kick.length(),
		"final_roll":absf(game.camera.rotation.z),"final_pitch":absf(game.camera.rotation.x+deg_to_rad(7))}
	return result

func _run() -> void:
	game = load("res://tests/legacy_voyage.tscn").instantiate()
	# This suite measures the retained opt-in deck rig, not the default chase view.
	game.sailing_camera_rig = game.SailingCameraRig.DECK
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	game.hud.set_process(false)
	await physics_frame
	var front := await trial(Vector2.DOWN,60)
	var port := await trial(Vector2.RIGHT,60)
	var starboard := await trial(Vector2.LEFT,60)
	var oblique := await trial(Vector2(1,1).normalized(),60)
	var four := await trial(Vector2.DOWN,60,false,4)
	var reduced := await trial(Vector2.RIGHT,60,true)
	var slow := await trial(Vector2.RIGHT,30)
	var fast := await trial(Vector2.RIGHT,120)
	measurements = {"front":front,"port":port,"starboard":starboard,"oblique":oblique,"four":four,"reduced":reduced,"30hz":slow,"120hz":fast}
	check(front.heave > 0.6 and front.pitch > deg_to_rad(2),"frontal crest visibly lifts and pitches the camera with effects absent")
	check(port.incoming_roll < -0.025 and starboard.incoming_roll > 0.025,"port and starboard advancing faces bank the horizon in opposite correct directions")
	check(port.roll > deg_to_rad(3) and port.roll < deg_to_rad(8),"ordinary strong side crossing inherits substantial bounded roll")
	check(oblique.pitch > 0.025 and oblique.roll > 0.025,"oblique crest combines pitch and roll")
	for key: String in measurements:
		var r: Dictionary = measurements[key]
		check(r.clear and r.max_contacts <= 4,"finite output, water guard and four-event history: "+key)
		check(r.contacts == (4 if key == "four" else 1),"one descending compression per actual crest: "+key)
		check(r.settled < 0.0001 and r.final_roll < 0.002 and r.final_pitch < 0.002,"calm recovery clears impulse and attitude: "+key)
	check(absf(slow.heave-fast.heave)<0.16 and absf(slow.roll-fast.roll)<deg_to_rad(1.2),"30/60/120 Hz crossings have comparable lift and roll extrema")
	check(reduced.roll < port.roll*0.40 and reduced.heave > 0.5,"Reduced scales angular motion while retaining strong deck attachment")
	check(game.boat.position.y==0 and game.boat.rotation.x==0 and game.boat.rotation.z==0,"camera never changes planar collision motion")
	var physics_results: Array[Vector3] = []
	for setting in [0,1]:
		place()
		# Reset the complete basis: Euler assignment preserves scale accumulated
		# by earlier staged turns, which would make these initial conditions differ.
		game.boat.transform = Transform3D(Basis.IDENTITY,OPEN)
		await physics_frame
		await process_frame
		game.motion_setting = setting
		crest(Vector2.RIGHT,1.85)
		for frame in range(480):
			game.advance_sailing(DT,-0.15)
			game._update_view(DT)
		physics_results.append(Vector3(game.boat.position.x,game.heading,game.boat.position.z))
	check(physics_results[0].distance_to(physics_results[1])<0.00001,"Full and Reduced produce identical physical movement under the same wave and steering input")
	place()
	game.boat.transform = Transform3D(Basis.IDENTITY,OPEN)
	await physics_frame
	crest(Vector2.RIGHT,1.85)
	for frame in range(168):
		game.advance_sailing(DT,0.0)
		game._update_view(DT)
	var rail: Vector3 = game.boat_visual.to_global(Vector3(-1.45,0.98,-2.0))
	check(rail.y-game.ocean.height_at(Vector2(rail.x,rail.z))>0.02,"bounded edge support keeps the visible port gunwale above a strong incoming crest")
	# A long browser pause snaps history rather than integrating stale derivatives.
	game.deck_response.impact_velocity = Vector3(2,-2,0)
	game.sea_time += 5.0
	game._update_view(5.0)
	check(game.deck_response.events.is_empty() and game.deck_response.impact_velocity==Vector3.ZERO and game.camera.transform.is_finite(),"long frame gap discards stale contact and impulse history")
	game.boat.position += Vector3(80,0,0)
	game._update_view(1.0/60)
	check(game.camera.position.distance_to(game.helm_anchor.global_position)<0.2 and game.deck_response.contacts.is_empty(),"teleport snaps the eye and clears wave contacts")
	for i in range(2):
		game.restart()
		check(game.deck_response.impact_count==0 and game.deck_response.contacts.is_empty() and game.deck_response.impact==Vector3.ZERO,"retry %d clears response and event state" % (i+1))
	print("TURBULENCE MEASUREMENTS "+JSON.stringify(measurements))
	print("TURBULENCE CAMERA: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

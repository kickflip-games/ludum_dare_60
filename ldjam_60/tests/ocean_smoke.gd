extends SceneTree
## Godot --headless --path ldjam_60 --script res://tests/ocean_smoke.gd

const Motion = preload("res://game/ocean/boat_wave_motion.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func _run() -> void:
	var game = load("res://tests/legacy_voyage.tscn").instantiate()
	game.weather_enabled = false
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	var original = game.ocean_settings
	var settings = original.duplicate(true)
	game.ocean_settings = settings
	var ocean = game.ocean
	ocean.update_surface(Vector3.ZERO, 2.7, 0.0, 0.0, 0.0)
	check(ocean.near_mesh.mesh.size == Vector2(120, 120) and ocean.cells == 192,
		"default water resolves approaching crests across a 120 m patch")
	var vertices: PackedVector3Array = ocean.distant_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edge_ok: bool = true
	for i in range(ocean.cells + 1):
		var expected := Vector3(-60.0 + 120.0 * i / ocean.cells, 0.0, -60.0)
		edge_ok = edge_ok and vertices[i].is_equal_approx(expected)
	check(edge_ok, "skirt inner edge exactly matches the detailed patch grid")
	check(vertices.size() < 7000, "horizon uses a small fixed perimeter mesh")
	var max_derivative_error: float = 0.0
	for i in range(20):
		var p := Vector2(-17.3 + i * 3.71, 8.2 + i * 0.93)
		var v: Vector3 = ocean.sample_surface(p, 2.7)
		var epsilon: float = 0.002
		var dx: float = (ocean.height_at(p + Vector2(epsilon, 0), 2.7) - ocean.height_at(p - Vector2(epsilon, 0), 2.7)) / (2.0 * epsilon)
		var dz: float = (ocean.height_at(p + Vector2(0, epsilon), 2.7) - ocean.height_at(p - Vector2(0, epsilon), 2.7)) / (2.0 * epsilon)
		max_derivative_error = maxf(max_derivative_error, maxf(absf(dx - v.y), absf(dz - v.z)))
	check(max_derivative_error < 0.002, "analytic wave/LOD derivatives agree with finite differences")
	var p := Vector2(8.4, -9.2)
	var before: float = ocean.height_at(p, 3.2)
	var near_id: int = ocean.near_mesh.mesh.get_instance_id()
	var skirt_id: int = ocean.distant_mesh.mesh.get_instance_id()
	for i in range(60):
		ocean.update_surface(Vector3(i * 0.01, 100.0, i * -0.004), 3.2, 1.0 / 60.0, 0.0, 0.0)
	check(absf(before - ocean.height_at(p, 3.2)) < 0.00001,
		"recentring does not change world-space wave phase near the boat")
	check(ocean.global_position.y == 0.0, "recentring never moves the vertical water origin")
	check(ocean.near_mesh.mesh.get_instance_id() == near_id and ocean.distant_mesh.mesh.get_instance_id() == skirt_id,
		"updates reuse both meshes without CPU mesh regeneration")
	check(not _has_collision(ocean), "ocean and wake contain no raycast or collision bodies")
	check(ocean.near_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and ocean.distant_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"water shadows are disabled")
	var base_sample: float = settings.sample_wave(p, 3.2).x
	settings.height_multiplier *= 0.5
	check(absf(settings.sample_wave(p, 3.2).x - base_sample * 0.5) < 0.00001,
		"amplitude editing affects the authoritative sampler")
	check(absf(float(ocean.material.get_shader_parameter("height_multiplier")) - settings.height_multiplier) < 0.0001,
		"Inspector resource edits immediately synchronize GPU uniforms")
	settings.height_multiplier = 0.0
	check(absf(ocean.height_at(p, 20.0) - settings.sea_level) < 0.00001,
		"zero amplitude produces a flat sea at the configured level")
	settings.height_multiplier = original.height_multiplier
	settings.speed_multiplier = 0.0
	check(settings.sample_wave(p, 0.0).is_equal_approx(settings.sample_wave(p, 20.0)),
		"zero speed freezes the same three-wave field")
	game.ocean_settings = original
	var heights: Array[float] = []
	for preset: String in ["calm", "choppy", "stormy"]:
		var resource = load("res://game/ocean/presets/" + preset + ".tres")
		heights.append(resource.maximum_displacement())
	check(heights[0] < heights[1] and heights[1] < heights[2], "Calm, Choppy, and Stormy share progressively larger wave settings")
	var min_heave: float = INF
	var max_heave: float = -INF
	var motion_ok: bool = true
	for frame in range(240):
		game.sea_time = frame / 60.0
		game._update_view(1.0 / 60.0)
		min_heave = minf(min_heave, game.boat_motion.heave)
		max_heave = maxf(max_heave, game.boat_motion.heave)
		motion_ok = motion_ok and absf(game.boat_motion.pitch) <= deg_to_rad(original.pitch_limit_degrees) + 0.001
		motion_ok = motion_ok and absf(game.boat_motion.roll) <= deg_to_rad(original.roll_limit_degrees) + 0.001
	check(max_heave - min_heave > 0.005 and max_heave - min_heave < 0.10, "calm baseline has gentle, bounded heave")
	check(motion_ok, "wave pitch and roll remain within the configured comfort limits")
	check(game.boat.position.y == 0.0 and absf(game.boat.rotation.x) < 0.00001 and absf(game.boat.rotation.z) < 0.00001,
		"buoyancy leaves movement-root height and collision orientation unchanged")
	var origin: Vector3 = game.cannon.shot_origin()
	for time in [4.0, 4.5, 5.0]:
		game.sea_time = time
		game._update_view(0.5)
	check(not game.cannon.shot_origin().is_equal_approx(origin) and game.cannon.shot_origin().is_equal_approx(game.cannon.muzzle.global_position), "rocking cannon shot origin follows the visible muzzle exactly")
	var slow = Motion.new()
	var fast = Motion.new()
	ocean.update_surface(game.boat.position, 1.0, 0.0, 0.0, game.heading)
	slow.update_motion(ocean, game.boat, game.boat_visual, 0.0, true)
	fast.update_motion(ocean, game.boat, game.boat_visual, 0.0, true)
	ocean.update_surface(game.boat.position, 3.0, 0.0, 0.0, game.heading)
	for i in range(30):
		slow.update_motion(ocean, game.boat, game.boat_visual, 1.0 / 30.0)
	for i in range(60):
		fast.update_motion(ocean, game.boat, game.boat_visual, 1.0 / 60.0)
	check(absf(slow.heave - fast.heave) < 0.0001 and absf(slow.pitch - fast.pitch) < 0.0001,
		"exponential response gives equivalent 30/60 Hz damping")
	# Isolate sailing attitude from waves, then exercise actual view integration.
	var flat = original.duplicate(true)
	flat.height_multiplier = 0.0
	game.ocean_settings = flat
	var trim = Motion.new()
	trim.update_motion(ocean, game.boat, game.boat_visual, 0.0, true, 0.0, 0.72)
	check(is_zero_approx(trim.pitch) and is_zero_approx(trim.roll), "stationary hull does not bank from steering alone")
	trim.update_motion(ocean, game.boat, game.boat_visual, 0.0, true, 1.0, 0.0)
	check(trim.pitch > 0.0 and trim.roll < 0.0 and absf(trim.roll) < deg_to_rad(3.0),
		"straight sailing adds restrained bow trim and sail heel")
	trim.update_motion(ocean, game.boat, game.boat_visual, 0.0, true, 1.0, 0.72)
	check(trim.roll < -deg_to_rad(10.0), "starboard turn banks the mast toward starboard")
	trim.update_motion(ocean, game.boat, game.boat_visual, 0.0, true, 1.0, -0.72)
	check(trim.roll > deg_to_rad(7.0), "port turn banks the mast toward port")
	for hz: int in [30, 60, 120]:
		trim.reset()
		trim.update_motion(ocean, game.boat, game.boat_visual, 0.0, true)
		trim.update_motion(ocean, game.boat, game.boat_visual, 1.0 / hz, false, 1.0, 0.72)
		check(absf(trim.roll) < deg_to_rad(1.0), "turn entry is eased at %d Hz" % hz)
		for i in range(hz * 3):
			trim.update_motion(ocean, game.boat, game.boat_visual, 1.0 / hz, false, 1.0, 0.72)
		check(absf(rad_to_deg(trim.roll) + 11.8) < 0.02, "turn attitude converges consistently at %d Hz" % hz)
		for i in range(hz * 3):
			trim.update_motion(ocean, game.boat, game.boat_visual, 1.0 / hz)
		check(absf(trim.roll) < deg_to_rad(0.02) and absf(trim.pitch) < deg_to_rad(0.02),
			"blocked or stopped boat settles at %d Hz" % hz)
	game.state = game.State.SAILING
	game.actual_speed = game.SPEED
	game.wave_sailing.rudder_rate = 0.72
	game.boat_motion.reset()
	game._update_view(0.0)
	check(game.boat_motion.roll < -deg_to_rad(10.0) and absf(game.camera.rotation.z) < deg_to_rad(2.0),
		"game view uses measured speed and turn without amplifying artificial turn heel")
	check(game.cannon.shot_origin().is_equal_approx(game.cannon.muzzle.global_position),
		"banked cannon still launches at its visible muzzle")
	game.cannon.set_aim_held(true)
	game.cannon.update_aim(0.0)
	for i in range(180):
		game._update_view(1.0 / 60.0)
	check(absf(game.boat_motion.roll) < deg_to_rad(0.02) and absf(game.boat_motion.pitch) < deg_to_rad(0.02),
		"gun view smoothly settles added sailing trim on a flat sea")
	game.restart()
	check(is_zero_approx(game.boat_motion.sailing_roll) and is_zero_approx(game.boat_motion.sailing_pitch),
		"retry clears the previous sailing attitude")
	game.ocean_settings = original
	# A speed request alone cannot paint a wake against an unmoving/blocked hull.
	for i in range(60):
		ocean.update_surface(game.boat.position+Vector3(0,0,-6.3*i/60.0),3.0+i/60.0,1.0/60,1.0,game.heading)
	check(ocean.wake_strength > 0.9, "subtle V wake strengthens with sailing speed")
	ocean.update_surface(game.boat.position+Vector3(0,0,-6.3*59/60.0),6.0,2.0,0.0,game.heading)
	check(ocean.wake_strength < 0.001 and ocean.wake_root.get_child_count() == 2,
		"two reusable wake meshes stop emitting at rest")
	ocean.set_quality(0)
	check(ocean.cells == 160, "Low quality reduces the fixed grid resolution")
	ocean.set_quality(1)
	game.restart()
	check(game.ocean.wake_strength < 0.001 and game.boat_motion.initialized,
		"retry resets wake and seats the visual hull on the current wave field")
	print("OCEAN CHECKS: derivative error=%.6f, heave range=%.3f m" % [max_derivative_error, max_heave - min_heave])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _has_collision(child):
			return true
	return false

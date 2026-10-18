extends SceneTree
## Complete native rendered voyage using real input, collisions, cameras and encounters.
const Pilot = preload("res://tests/archipelago_pilot.gd")
var game
var output := ProjectSettings.globalize_path("res://../artifacts/archipelago/voyage")
var captured: Dictionary = {}
var alternate := false
var guidance_checks := 0
var guidance_failures := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--alternate":
			alternate = true
	_run.call_deferred()
func capture(label: String) -> void:
	if captured.has(label):
		return
	captured[label] = true
	RenderingServer.force_draw(true, 1.0 / 60.0)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://game/crossing.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cannon.set_physics_process(false)
	for i in range(30):
		await process_frame
	await capture("00-title")
	game.start_crossing()
	while game.state == game.State.CASTING_OFF:
		game._physics_process(1.0 / 60.0)
		await process_frame
	var pilot := Pilot.new()
	pilot.alternate = alternate
	game.wind_regions.enabled = not alternate
	var cadence: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var stages: Array[int] = [0]
	for frame in range(26000):
		var steering: float = pilot.steering(game)
		Input.action_release("steer_port")
		Input.action_release("steer_starboard")
		if absf(steering) > 0.01:
			Input.action_press("steer_port" if steering < 0 else "steer_starboard", absf(steering))
		game._physics_process(1.0 / 60.0)
		game.cannon.advance(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		if game.state == game.State.SAILING:
			guidance_checks += 1
			var ray: Vector3 = game.sky_material.get_shader_parameter("guiding_star")
			var toward: Vector3 = (game.target - game.boat.global_position).normalized()
			if Vector3(ray.x, 0, ray.z).normalized().dot(toward) < 0.9999 or game.hud.star_guidance().is_empty():
				guidance_failures += 1
		await process_frame
		var now := Time.get_ticks_usec()
		cadence.append((now - previous) / 1000.0)
		previous = now
		if game.elapsed > 5 and game.elapsed < 6:
			await capture("01-departure")
		if game.state == game.State.SAILING:
			await capture("star-leg-%02d" % game.voyage.leg)
		if stages.back() != game.voyage.stage:
			stages.append(game.voyage.stage)
			await capture("discovery-%d" % game.voyage.stage)
		var ship = game.enemy_encounters.ship
		if ship.visible and game.camera_mode == game.CameraMode.COMBAT:
			await capture("pirate-%d" % game.enemy_encounters.encounter_index)
		if game.beacon_seen and game.voyage.stage == 2 and not game.reading:
			await capture("final-approach")
		if game.camera_mode == game.CameraMode.SAILING and game.read_blend < 0.01 and game.aim_camera_blend < 0.01 and game.combat_camera_blend < 0.01 and game.boat.position.distance_to(game.target) < 95.0:
			await capture("sailing-approach-%d"%game.voyage.stage)
		if frame % 1800 == 0:
			print("VOYAGE t=%.1f stage=%d hull=%d position=%s" % [game.elapsed,game.voyage.stage,game.hull,game.boat.position])
		if game.state != game.State.SAILING:
			break
	for action: String in ["steer_port", "steer_starboard", "astrolabe"]:
		Input.action_release(action)
	for i in range(100):
		game._physics_process(1.0 / 60.0)
		game.hud._process(1.0 / 60.0)
		await process_frame
	await capture("safe-harbour" if game.state == game.State.ARRIVED else "failed")
	cadence.sort()
	var result := {"arrived":game.state == game.State.ARRIVED,"alternate":alternate,"seconds":game.elapsed,"hull":game.hull,"hits":game.hits_taken,"stages":stages,"encounters":game.enemy_encounters.encounter_index,"guidance_checks":guidance_checks,"guidance_failures":guidance_failures,"median_frame_ms":cadence[cadence.size()/2],"p95_frame_ms":cadence[int(cadence.size()*0.95)],"captures":captured.keys()}
	var report := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"\t"))
	report.close()
	print("NATIVE VOYAGE " + JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if result.arrived and stages == [0, 1, 2, 3] and guidance_failures == 0 and guidance_checks > 0 else 1)

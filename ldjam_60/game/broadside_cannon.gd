extends Node3D
## One sweeping starboard cannon. Sailing and gun view share the existing weapon.

const PIRATE_CANNON = preload("res://assets/pirate_kit/cannon.glb")
const SPLASH_SHADER = preload("res://game/ocean/splash.gdshader")
var _splash_ring_mesh: TorusMesh
var _splash_spray_mesh: SphereMesh
const RELOAD_SECONDS: float = 1.5
const SHOT_SPEED: float = 55.0
signal aiming_started
signal aiming_ended
signal fired(direction: Vector3)

@export_group("Automatic broadside sweep")
@export_range(1.0, 45.0, 1.0) var max_aim_degrees: float = 30.0
@export_range(1.5, 6.0, 0.1) var sweep_period: float = 3.0
## 1 is sinusoidal; higher values linger longer at each end, with continuous velocity.
@export_range(1.0, 2.5, 0.1) var sweep_easing: float = 1.0
@export_enum("Toward bow", "Toward stern") var initial_sweep_direction: int = 0
@export_group("Firing feedback")
@export_range(0.0, 0.5, 0.01) var recoil_strength: float = 0.3
@export_range(0.0, 0.15, 0.005) var camera_shake_strength: float = 0.055

var aiming: bool = false
var aim_degrees: float = 0.0
var sweep_elapsed: float = 0.0
var mode_seconds: float = 0.0
var entries: int = 0
var indicator_alpha: float = 0.0
var _fire_held: bool = false
var _recoil_left: float = 0.0
var _fire_pending: bool = false
var _aim_held: bool = false
var yaw_pivot: Node3D
var game: Node3D
var cooldown: float = 0.0
var feedback: String = ""
var feedback_time: float = 0.0
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var muzzle: Marker3D
var barrel: Node3D
var flash: MeshInstance3D
var flash_light: OmniLight3D
var flash_time: float = 0.0
var _shot_audio: AudioStreamPlayer
var _impact_audio: AudioStreamPlayer
var _water_audio: AudioStreamPlayer
var _ship_audio: AudioStreamPlayer
var shots_fired: int = 0
var targets_hit: int = 0


func _ready() -> void:
	position = Vector3(0.8, 1.17, -2.6)
	_fire_held = Input.is_action_pressed("fire_starboard")
	yaw_pivot = Node3D.new()
	yaw_pivot.name = "AimYaw"
	add_child(yaw_pivot)
	barrel = Node3D.new()
	yaw_pivot.add_child(barrel)
	var cannon_model: Node3D = PIRATE_CANNON.instantiate()
	cannon_model.name = "PirateKitStarboardCannon"
	cannon_model.rotation.y = PI / 2.0
	cannon_model.scale = Vector3.ONE * 1.1
	cannon_model.position = Vector3(0.25, -0.63, 0.0)
	barrel.add_child(cannon_model)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(1.22, 0.0, 0.0)
	barrel.add_child(muzzle)
	var spark := SphereMesh.new()
	spark.radius = 0.26
	spark.height = 0.52
	spark.radial_segments = 8
	spark.rings = 4
	flash = game._mesh(muzzle, spark, Vector3.ZERO, game._material(Color("ffe3a2"), 2.0))
	flash.scale = Vector3(2.0, 0.8, 0.8)
	flash.visible = false
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("ffc078")
	flash_light.light_energy = 4.0
	flash_light.omni_range = 9.0
	flash_light.visible = false
	muzzle.add_child(flash_light)
	if DisplayServer.get_name() != "headless":
		_shot_audio = _audio(68.0, 0.8, -13.0)
		_impact_audio = _audio(135.0, 0.9, -17.0)
		_water_audio = _audio(380.0, 0.8, -22.0)
		_ship_audio = _audio(78.0, 0.35, -14.0)


func starboard_direction() -> Vector3:
	return Vector3(cos(game.heading), 0.0, sin(game.heading))


func aimed_direction() -> Vector3:
	# The same world-space barrel axis drives visuals, sight and projectile physics,
	# including hull yaw, wave pitch/roll and heave. Camera transforms never enter it.
	return yaw_pivot.global_basis.x.normalized()


func shot_origin() -> Vector3:
	return muzzle.global_position


func set_aim_held(pressed: bool) -> void:
	_aim_held = pressed
	if not pressed:
		cancel_aim()


func set_fire_held(pressed: bool) -> void:
	# Resolve fresh edges on the next physics tick so E + F works in either order.
	# Reload/Space presses are discarded at receipt, never deferred until ready.
	if pressed and not _fire_held and cooldown <= 0.0 and game.state == game.State.SAILING and not game.reading and not (not game.arena_mode and Input.is_action_pressed("astrolabe")):
		_fire_pending = true
	_fire_held = pressed


func cancel_aim() -> void:
	_fire_pending = false
	_update_target_highlights(false)
	if not aiming:
		return
	aiming = false
	# Retain the last barrel angle during camera return; entry resets to centre.
	aiming_ended.emit()


func update_aim(delta: float) -> void:
	var fire_pressed := _fire_pending
	_fire_pending = false
	if not _aim_held or game.reading or (not game.arena_mode and Input.is_action_pressed("astrolabe")) or game.state != game.State.SAILING:
		cancel_aim()
	else:
		if not aiming:
			aiming = true
			entries += 1
			mode_seconds = 0.0
			sweep_elapsed = 0.0
			aim_degrees = 0.0
			yaw_pivot.rotation.y = 0.0
			aiming_started.emit()
		# Fire along the currently visible barrel before advancing its sweep.
		if fire_pressed:
			fire()
		mode_seconds += delta
		sweep_elapsed = fposmod(sweep_elapsed + delta, sweep_period)
		var wave: float = sin(sweep_elapsed * TAU / sweep_period)
		var eased: float = signf(wave) * (1.0 - pow(1.0 - absf(wave), sweep_easing))
		aim_degrees = max_aim_degrees * eased * (1.0 if initial_sweep_direction == 0 else -1.0)
		yaw_pivot.rotation.y = deg_to_rad(aim_degrees)
	indicator_alpha = move_toward(indicator_alpha, 1.0 if aiming else 0.0, delta * (10.0 if aiming else 5.0))
	_update_target_highlights(aiming)


func visible_in_firing_sector(body: Node3D) -> bool:
	if not aiming or game.state != game.State.SAILING or not body.is_visible_in_tree() or body.get_meta("destroyed", true):
		return false
	var offset := body.global_position - shot_origin()
	var flat := Vector3(offset.x, 0, offset.z)
	if flat.length() < 3.0 or flat.length() > 90.0 or flat.normalized().dot(starboard_direction()) < cos(deg_to_rad(max_aim_degrees + 10.0)):
		return false
	var size: float = body.get_meta("target_radius", 4.2) / 4.2
	for height in [1.3, 4.3]:
		var point := body.to_global(Vector3(0, height, -1.8) * size)
		if not game.camera.is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(game.camera.global_position, point, 5)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider == body:
			return true
	return false


func _update_target_highlights(enabled: bool) -> void:
	for body: Node3D in get_tree().get_nodes_in_group("cannon_targets"):
		if body.has_method("set_aim_highlight"):
			body.set_aim_highlight(enabled and visible_in_firing_sector(body))


func fire() -> bool:
	if not aiming or not _aim_held or game.state != game.State.SAILING or cooldown > 0.0 or game.reading or (not game.arena_mode and Input.is_action_pressed("astrolabe")):
		return false
	shots_fired += 1
	game.shake(camera_shake_strength)
	cooldown = RELOAD_SECONDS
	_recoil_left = 0.24
	flash_time = 0.14
	flash.visible = true
	flash_light.visible = true
	var shape := SphereMesh.new()
	shape.radius = 0.32
	shape.height = 0.64
	shape.radial_segments = 8
	shape.rings = 4
	var ball = game._mesh(game, shape, muzzle.global_position, game._material(Color("e8c286"), 1.0))
	projectiles.append({"node": ball, "velocity": aimed_direction() * SHOT_SPEED + Vector3.UP * 0.35, "ttl": 1.8,
		"physics_position": shot_origin(), "trail_clock": 0.0})
	# Existing effect lifetime system also owns the short muzzle smoke burst.
	for i in range(5):
		var smoke_shape := SphereMesh.new()
		smoke_shape.radius = 0.22 + i * 0.07
		smoke_shape.height = smoke_shape.radius * 2.0
		var smoke = game._mesh(game, smoke_shape, muzzle.global_position + aimed_direction() * i * 0.3, game._material(Color("aab7b2")))
		effects.append({"node": smoke, "ttl": 0.6 + i * 0.04, "velocity": aimed_direction() * (1.5 + i * 0.3) + Vector3.UP * 1.4, "smoke": true})
	fired.emit(aimed_direction())
	feedback = "STARBOARD SHOT"
	feedback_time = 0.9
	if is_instance_valid(_shot_audio) and game._sound_enabled:
		_shot_audio.play()
	return true


func _physics_process(delta: float) -> void:
	if game.state != game.State.SAILING:
		return
	advance(delta)


func advance(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	flash_time = maxf(0.0, flash_time - delta)
	flash.visible = flash_time > 0.0
	flash_light.visible = flash_time > 0.0
	_recoil_left = maxf(0.0, _recoil_left - delta)
	barrel.position.x = -recoil_strength * sin(PI * clampf(_recoil_left / 0.24, 0.0, 1.0))
	feedback_time = maxf(0.0, feedback_time - delta)
	if feedback_time <= 0.0:
		feedback = ""
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var ball: MeshInstance3D = shot.node
		var from: Vector3 = shot.physics_position
		var to: Vector3 = from + shot.velocity * delta
		var ray := PhysicsRayQueryParameters3D.create(from, to, 5)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var water: Dictionary = game.ocean.water_hit(from, to, delta)
		if not water.is_empty() and not hit.is_empty() and from.distance_squared_to(water.position) < from.distance_squared_to(hit.position):
			hit = {}
		shot.ttl -= delta
		shot.velocity.y -= 0.9 * delta
		if not hit.is_empty():
			_impact(hit.collider, hit.position)
			ball.queue_free()
			projectiles.remove_at(i)
		elif shot.ttl <= 0.0 or not water.is_empty():
			water_splash(water.position if not water.is_empty() else to)
			feedback = "SPLASH  ·  SHOT WIDE"
			feedback_time = 0.9
			ball.queue_free()
			projectiles.remove_at(i)
		else:
			shot.physics_position = to
			ball.global_position = to
			shot.trail_clock += delta
			if shot.trail_clock >= 0.055:
				shot.trail_clock = 0.0
				var trail = game._box(game, Vector3(0.10, 0.10, 0.10), ball.global_position, game._material(Color("f3dcb0"), 1.0))
				effects.append({"node": trail, "ttl": 0.18, "velocity": Vector3.ZERO, "ring": false})
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.ttl -= delta
		if effect.ttl <= 0.0:
			effect.node.queue_free()
			effects.remove_at(i)
		else:
			if effect.get("ring", false):
				var remaining: float = effect.ttl/effect.lifetime
				var growth: float = 1.0 + (1.0 - remaining) * 3.4
				effect.node.scale = Vector3(growth, 0.15, growth)
				effect.node.position.y = game.ocean.height_at(Vector2(effect.node.position.x,effect.node.position.z))+0.045
				effect.node.material_override.set_shader_parameter("opacity",pow(remaining,1.4))
			else:
				effect.node.position += effect.velocity * delta
				if effect.get("water_spray",false):
					effect.velocity.y -= delta*7.0
					var remaining: float = effect.ttl/effect.lifetime
					effect.node.scale = effect.spray_scale*(0.55+remaining*0.45)
					effect.node.material_override.set_shader_parameter("opacity",remaining*remaining)
				elif effect.get("smoke", false):
					effect.node.scale += Vector3.ONE * delta * 1.5
				elif effect.get("impact_smoke", false):
					var remaining: float = effect.ttl / effect.lifetime
					effect.node.scale += Vector3.ONE * delta * 0.8
					effect.node.material_override.albedo_color.a = remaining * 0.45
				else:
					effect.velocity.y -= delta * 2.0
					effect.node.scale = Vector3.ONE * minf(1.0, effect.ttl * 3.0)


func _impact(body: Object, at: Vector3) -> void:
	var ship: bool = body.get_meta("target_kind", "") == "ship"
	var destructible: bool = body.get_meta("destructible", false)
	if (ship or destructible) and body.get_meta("destroyed", false):
		return
	if ship:
		targets_hit += 1
		body.take_hit()
		feedback = "%s SUNK" % body.display_name().to_upper() if body.hull <= 0 else "HULL HIT  ·  %d MORE" % body.hull
		if body.hull <= 0:
			_sinking_burst(at)
	elif destructible:
		targets_hit += 1
		body.visible = false
		body.collision_layer = 0
		body.set_meta("destroyed", true)
		feedback = "TIMBER SHATTERED"
	else:
		feedback = "SOLID REEF  ·  STEER AROUND"
	feedback_time = 2.0
	_splinters(at, destructible or ship)
	water_splash(at, false)
	game.shake(0.04 if ship else 0.025)
	var audio: AudioStreamPlayer = _ship_audio if ship else _impact_audio
	if is_instance_valid(audio) and game._sound_enabled:
		audio.play()


func _sinking_burst(at: Vector3) -> void:
	_splinters(at + Vector3.UP, true)
	for puff_index in 3:
		var material = game._material(Color("c6bda6"))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.45
		var shape := SphereMesh.new()
		shape.radius = 0.7
		shape.height = 1.4
		shape.radial_segments = 8
		shape.rings = 4
		var smoke = game._mesh(game, shape, at + Vector3(0, puff_index * 0.5, 0), material)
		effects.append({"node": smoke, "ttl": 1.2, "lifetime": 1.2,
			"velocity": Vector3(0.3, 1.4 + puff_index * 0.4, 0.2), "impact_smoke": true})


func aim_target() -> Dictionary:
	var selected: Dictionary = {}
	var best_score: float = INF
	var forward := aimed_direction().rotated(Vector3.UP, PI / 2.0)
	for body: Node3D in get_tree().get_nodes_in_group("cannon_targets"):
		if body.get_meta("destroyed", false):
			continue
		var aim_point: Vector3 = body.global_position
		var ship: bool = body.get_meta("target_kind", "") == "ship"
		if ship:
			aim_point = body.to_global(Vector3(0, 1.0, -1.8))
			aim_point += body.velocity * (aim_point.distance_to(shot_origin()) / SHOT_SPEED)
		var offset: Vector3 = aim_point - shot_origin()
		var right: float = offset.dot(aimed_direction())
		var ahead: float = offset.dot(forward)
		var distance: float = Vector2(right, ahead).length()
		if right < 2.0 or distance > 75.0:
			continue
		var radius: float = body.get_meta("target_radius", 3.0)
		var aligned: bool = absf(ahead) < maxf(0.5, radius - 0.6)
		var score: float = distance + absf(ahead) * 2.0 - (80.0 if aligned else 0.0)
		if score < best_score:
			best_score = score
			selected = {"body": body, "distance": distance, "aligned": aligned,
				"bearing": rad_to_deg(atan2(right, ahead)),
				"aim_point": aim_point, "kind": "HOSTILE CUTTER" if ship else "FLOATING TIMBER"}
	return selected


func water_splash(at: Vector3, sound: bool = true) -> void:
	var point := Vector3(at.x, game.ocean.height_at(Vector2(at.x, at.z)) + 0.1, at.z)
	if _splash_ring_mesh == null:
		_splash_ring_mesh = TorusMesh.new()
		_splash_ring_mesh.inner_radius = 0.45
		_splash_ring_mesh.outer_radius = 0.75
		_splash_ring_mesh.rings = 16
		_splash_ring_mesh.ring_segments = 4
		_splash_spray_mesh = SphereMesh.new()
		_splash_spray_mesh.radius = 0.16
		_splash_spray_mesh.height = 0.70
		_splash_spray_mesh.radial_segments = 7
		_splash_spray_mesh.rings = 3
	var material := ShaderMaterial.new()
	material.shader = SPLASH_SHADER
	var ring = game._mesh(game, _splash_ring_mesh, point, material)
	ring.scale.y = 0.15
	effects.append({"node": ring, "ttl": 0.85, "lifetime":0.85, "velocity": Vector3.ZERO, "ring": true})
	for i in range(5):
		var spray_material := ShaderMaterial.new()
		spray_material.shader = SPLASH_SHADER
		var spray = game._mesh(game,_splash_spray_mesh,point+Vector3.UP*0.35,spray_material)
		var direction := Vector3(sin(i*2.4),0,cos(i*2.4))*2.0 if i>0 else Vector3.ZERO
		spray.rotation.z = 0.55*sin(i*2.4)
		var life := 0.52 if i==0 else 0.42+i*0.025
		var spray_scale := Vector3(1.2,1.8,1.2) if i==0 else Vector3(0.8,0.8,0.8)
		spray.scale = spray_scale
		effects.append({"node":spray,"ttl":life,"lifetime":life,"spray_scale":spray_scale,"water_spray":true,"velocity":direction+Vector3.UP*(2.0 if i==0 else 1.1)})
	if sound and is_instance_valid(_water_audio) and game._sound_enabled:
		_water_audio.play()


func _splinters(at: Vector3, timber: bool) -> void:
	var mat = game._material(Color("b08c58") if timber else Color("a1c3c3"), 0.5)
	for i in range(7):
		var chip = game._box(game, Vector3(0.15, 0.15, 0.65 if timber else 0.15), at, mat)
		chip.rotation = Vector3(i * 0.7, i * 1.4, i * 0.3)
		effects.append({"node": chip, "ttl": 0.8,
			"velocity": Vector3(sin(i * 2.4) * 3.0, 1.5 + i * 0.12, cos(i * 2.4) * 3.0)})


func reset() -> void:
	set_aim_held(false)
	_fire_held = Input.is_action_pressed("fire_starboard")
	aim_degrees = 0.0
	sweep_elapsed = 0.0
	mode_seconds = 0.0
	entries = 0
	indicator_alpha = 0.0
	yaw_pivot.rotation.y = 0.0
	_recoil_left = 0.0
	barrel.position = Vector3.ZERO
	for shot: Dictionary in projectiles:
		shot.node.queue_free()
	for effect: Dictionary in effects:
		effect.node.queue_free()
	projectiles.clear()
	effects.clear()
	shots_fired = 0
	targets_hit = 0
	cooldown = 0.0
	flash_time = 0.0
	feedback = ""
	feedback_time = 0.0
	flash.visible = false
	flash_light.visible = false


func _audio(frequency: float, noise_level: float, volume: float) -> AudioStreamPlayer:
	var data := PackedByteArray()
	var count: int = 8820
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	for i in range(count):
		var time := float(i) / 22050.0
		var envelope := exp(-time * 14.0) * minf(time * 300.0, 1.0)
		var sample := (sin(time * TAU * frequency) * 0.6 + rng.randf_range(-1.0, 1.0) * noise_level) * envelope
		data.encode_s16(i * 2, clampi(int(sample * 20000.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

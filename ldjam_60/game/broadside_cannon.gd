extends Node3D
## One fixed starboard cannon. Projectiles sweep against the same hazard bodies as the boat.

const PIRATE_CANNON = preload("res://assets/pirate_kit/cannon.glb")
const RELOAD_SECONDS: float = 1.5
const SHOT_SPEED: float = 55.0
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
	barrel = Node3D.new()
	add_child(barrel)
	var cannon_model: Node3D = PIRATE_CANNON.instantiate()
	cannon_model.name = "PirateKitStarboardCannon"
	cannon_model.rotation.y = PI / 2.0
	cannon_model.scale = Vector3.ONE * 1.1
	cannon_model.position = Vector3(0.25, -0.63, 0.0)
	barrel.add_child(cannon_model)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(1.22, 0.0, 0.0)
	add_child(muzzle)
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


func shot_origin() -> Vector3:
	# Cosmetic pitch/heave must not change the established planar firing rules.
	return game.boat.to_global(Vector3(2.02, 1.17, -2.6))


func fire() -> bool:
	if game.state != game.State.SAILING or cooldown > 0.0 or game.reading:
		return false
	shots_fired += 1
	game.shake(0.055)
	cooldown = RELOAD_SECONDS
	flash_time = 0.14
	flash.visible = true
	flash_light.visible = true
	var shape := SphereMesh.new()
	shape.radius = 0.32
	shape.height = 0.64
	shape.radial_segments = 8
	shape.rings = 4
	var ball = game._mesh(game, shape, muzzle.global_position, game._material(Color("e8c286"), 1.0))
	projectiles.append({"node": ball, "velocity": _launch_direction() * SHOT_SPEED + Vector3.UP * 0.35, "ttl": 1.8,
		"physics_position": shot_origin(), "visual_offset": muzzle.global_position - shot_origin(), "trail_clock": 0.0})
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
	barrel.position.x = -0.24 * clampf((cooldown - RELOAD_SECONDS + 0.22) / 0.22, 0.0, 1.0)
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
		shot.ttl -= delta
		shot.velocity.y -= 0.9 * delta
		if not hit.is_empty():
			_impact(hit.collider, hit.position)
			ball.queue_free()
			projectiles.remove_at(i)
		elif shot.ttl <= 0.0 or to.y < -0.05:
			water_splash(to)
			feedback = "SPLASH  ·  SHOT WIDE"
			feedback_time = 0.9
			ball.queue_free()
			projectiles.remove_at(i)
		else:
			shot.physics_position = to
			ball.global_position = to + shot.visual_offset
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
				var growth: float = 1.0 + (1.0 - effect.ttl) * 5.0
				effect.node.scale = Vector3(growth, 0.15, growth)
			else:
				effect.node.position += effect.velocity * delta
				effect.velocity.y -= delta * 2.0
				effect.node.scale = Vector3.ONE * minf(1.0, effect.ttl * 3.0)


func _impact(body: Object, at: Vector3) -> void:
	var ship: bool = body.get_meta("target_kind", "") == "ship"
	var destructible: bool = body.get_meta("destructible", false)
	if ship:
		targets_hit += 1
		body.take_hit()
		feedback = "CUTTER SUNK" if body.hull <= 0 else "HULL HIT  ·  %d MORE" % body.hull
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


func _launch_direction() -> Vector3:
	var exact := starboard_direction()
	var target: Dictionary = aim_target()
	if not target.is_empty() and target.body.get_meta("target_kind", "") == "ship" and target.aligned:
		var offset: Vector3 = target.aim_point - shot_origin()
		offset.y = 0
		# Forgive at most 8 degrees, at launch only. The ball never tracks after firing.
		if exact.dot(offset.normalized()) > cos(deg_to_rad(8.0)):
			return offset.normalized()
	return exact


func aim_target() -> Dictionary:
	var selected: Dictionary = {}
	var best_score: float = INF
	var forward := Vector3(sin(game.heading), 0.0, -cos(game.heading))
	for body: Node3D in get_tree().get_nodes_in_group("cannon_targets"):
		if body.get_meta("destroyed", false):
			continue
		var aim_point: Vector3 = body.global_position
		var ship: bool = body.get_meta("target_kind", "") == "ship"
		if ship:
			aim_point = body.to_global(Vector3(0, 1.0, -1.8))
			aim_point += body.velocity * (aim_point.distance_to(shot_origin()) / SHOT_SPEED)
		var offset: Vector3 = aim_point - shot_origin()
		var right: float = offset.dot(starboard_direction())
		var ahead: float = offset.dot(forward)
		var distance: float = Vector2(right, ahead).length()
		if right < 2.0 or distance > 75.0:
			continue
		var radius: float = body.get_meta("target_radius", 3.0)
		var aligned: bool = absf(ahead) < maxf(0.5, radius - 0.6) or (ship and absf(atan2(ahead, right)) < deg_to_rad(8.0))
		var score: float = distance + absf(ahead) * 2.0 - (80.0 if aligned else 0.0)
		if score < best_score:
			best_score = score
			selected = {"body": body, "distance": distance, "aligned": aligned,
				"bearing": rad_to_deg(atan2(right, ahead)),
				"aim_point": aim_point, "kind": "HOSTILE CUTTER" if ship else "FLOATING TIMBER"}
	return selected


func water_splash(at: Vector3, sound: bool = true) -> void:
	var point := Vector3(at.x, game.ocean.height_at(Vector2(at.x, at.z)) + 0.1, at.z)
	var shape := TorusMesh.new()
	shape.inner_radius = 0.6
	shape.outer_radius = 0.85
	shape.rings = 16
	shape.ring_segments = 4
	var ring = game._mesh(game, shape, point, game._material(Color("c4efde"), 0.8))
	ring.scale.y = 0.15
	effects.append({"node": ring, "ttl": 1.0, "velocity": Vector3.ZERO, "ring": true})
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

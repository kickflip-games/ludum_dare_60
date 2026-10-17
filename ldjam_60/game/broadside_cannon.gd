extends Node3D
## One fixed starboard cannon. Projectiles sweep against the same hazard bodies as the boat.

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


func _ready() -> void:
	position = Vector3(0.8, 1.17, -2.6)
	var iron = game._material(Color("25343a"))
	var brass = game._material(Color("b79a62"))
	var wood = game._material(Color("69503b"))
	game._box(self, Vector3(1.35, 0.25, 0.7), Vector3(-0.12, -0.24, 0.0), wood)
	for side in [-1.0, 1.0]:
		var wheel = game._cylinder(self, 0.22, 0.22, 0.12, Vector3(-0.4, -0.35, side * 0.4), iron)
		wheel.rotation.x = PI / 2.0
	barrel = Node3D.new()
	add_child(barrel)
	var tube = game._cylinder(barrel, 0.25, 0.19, 1.65, Vector3(0.25, 0.0, 0.0), iron)
	tube.rotation.z = -PI / 2.0
	for x in [-0.3, 0.65]:
		var band = game._cylinder(barrel, 0.265, 0.265, 0.09, Vector3(x, 0.0, 0.0), brass)
		band.rotation.z = -PI / 2.0
	var bore = game._cylinder(barrel, 0.15, 0.15, 0.02, Vector3(1.08, 0.0, 0.0), game._material(Color("080e11")))
	bore.rotation.z = -PI / 2.0
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
		_impact_audio = _audio(135.0, 0.9, -19.0)


func starboard_direction() -> Vector3:
	return Vector3(cos(game.heading), 0.0, sin(game.heading))


func fire() -> bool:
	if game.state != game.State.SAILING or cooldown > 0.0 or game.reading:
		return false
	cooldown = RELOAD_SECONDS
	flash_time = 0.14
	flash.visible = true
	flash_light.visible = true
	var shape := SphereMesh.new()
	shape.radius = 0.22
	shape.height = 0.44
	shape.radial_segments = 8
	shape.rings = 4
	var ball = game._mesh(game, shape, muzzle.global_position, game._material(Color("e8c286"), 1.0))
	projectiles.append({"node": ball, "velocity": starboard_direction() * SHOT_SPEED, "ttl": 1.8})
	feedback = "STARBOARD SHOT"
	feedback_time = 0.9
	if is_instance_valid(_shot_audio) and game._sound_enabled:
		_shot_audio.play()
	return true


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	flash_time = maxf(0.0, flash_time - delta)
	flash.visible = flash_time > 0.0
	flash_light.visible = flash_time > 0.0
	barrel.position.x = -0.14 * sin(clampf(cooldown / RELOAD_SECONDS, 0.0, 1.0) * PI)
	feedback_time = maxf(0.0, feedback_time - delta)
	if feedback_time <= 0.0:
		feedback = ""
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var ball: MeshInstance3D = shot.node
		var from: Vector3 = ball.global_position
		var to: Vector3 = from + shot.velocity * delta
		var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		shot.ttl -= delta
		shot.velocity.y -= 0.9 * delta
		if not hit.is_empty():
			_impact(hit.collider, hit.position)
			ball.queue_free()
			projectiles.remove_at(i)
		elif shot.ttl <= 0.0 or to.y < -0.05:
			_splinters(to, false)
			ball.queue_free()
			projectiles.remove_at(i)
		else:
			ball.global_position = to
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.ttl -= delta
		if effect.ttl <= 0.0:
			effect.node.queue_free()
			effects.remove_at(i)
		else:
			effect.node.position += effect.velocity * delta
			effect.velocity.y -= delta * 2.0
			effect.node.scale = Vector3.ONE * minf(1.0, effect.ttl * 3.0)


func _impact(body: Object, at: Vector3) -> void:
	var destructible: bool = body.get_meta("destructible", false)
	if destructible:
		body.visible = false
		body.collision_layer = 0
		body.set_meta("destroyed", true)
		feedback = "TIMBER SHATTERED  /  PASSAGE CLEAR"
	else:
		feedback = "SOLID WRECK / ROCK  /  STEER AROUND"
	feedback_time = 2.5
	_splinters(at, destructible)
	if is_instance_valid(_impact_audio) and game._sound_enabled:
		_impact_audio.play()


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

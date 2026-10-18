extends Node3D
## Per-hull surface history and a bounded spray pool; no gameplay authority.
const Wake = preload("res://game/ocean/wake_trail.gd")
const ARRIVAL_SECONDS := 0.9
const CAPACITY := 16
var ship: CharacterBody3D
var wake: Node3D
var spray: MultiMeshInstance3D
var pool: MultiMesh
var drops: Array[Dictionary] = []
var fade_materials: Array[StandardMaterial3D] = []
var arrival_age := ARRIVAL_SECONDS
var opacity := 1.0
var cursor := 0
var spray_credit := 0.0
var clock := 0.0
var emitted := 0
var active_drops := 0
var previous := Vector3.ZERO
var initialized := false

func setup(owner_ship: CharacterBody3D) -> void:
	ship = owner_ship
	wake = Wake.new()
	wake.name = "EnemyWake"
	add_child(wake)
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/ocean/wake.gdshader")
	wake.setup(material)
	pool = MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_custom_data = true
	var droplet := SphereMesh.new()
	droplet.radius = 1.0
	droplet.height = 2.0
	droplet.radial_segments = 6
	droplet.rings = 3
	pool.mesh = droplet
	pool.instance_count = CAPACITY
	spray = MultiMeshInstance3D.new()
	spray.name = "EnemySternSpray"
	spray.multimesh = pool
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spray_material := ShaderMaterial.new()
	spray_material.shader = preload("res://game/ocean/turbulence_spray.gdshader")
	spray.material_override = spray_material
	add_child(spray)
	for i in CAPACITY:
		drops.append({"age": 1.0, "life": 0.6, "origin": Vector3.ZERO, "velocity": Vector3.ZERO, "radius": 0.0})
	refresh_materials()
	reset()

func refresh_materials() -> void:
	_restore_materials()
	fade_materials.clear()
	_collect_materials(ship.presentation)

func _collect_materials(node: Node) -> void:
	if node.is_queued_for_deletion(): return
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if not material is StandardMaterial3D: continue
			# Hull feedback already owns private overrides. Guns/flashes still use
			# shared imported resources, so give only those private fade materials.
			if material not in ship.model_materials:
				material = material.duplicate()
				node.set_surface_override_material(surface, material)
			if material not in fade_materials: fade_materials.append(material)
	for child in node.get_children(): _collect_materials(child)

func _restore_materials() -> void:
	for material in fade_materials:
		material.albedo_color.a = 1.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

func reset() -> void:
	arrival_age = ARRIVAL_SECONDS
	opacity = 1.0
	_restore_materials()
	wake.clear_path()
	wake.visible = false
	spray.visible = false
	initialized = false
	spray_credit = 0.0
	clock = 0.0
	cursor = 0
	emitted = 0
	active_drops = 0
	for i in CAPACITY:
		drops[i].age = 1.0
		pool.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.00001), Vector3.ZERO))
		pool.set_instance_custom_data(i, Color(1, 1, 1, 0))

func begin() -> void:
	arrival_age = 0.0
	opacity = 0.0
	apply_arrival()
	# A small water cue precedes the full silhouette. Origins stay in the sea.
	var amount := 6 if ship.game.ocean_quality == 0 else 12
	for i in amount:
		var angle := i * TAU / amount
		var radial := Vector3(sin(angle), 0, cos(angle))
		_emit(ship.position + ship.forward() * 1.8 + radial * 2.3,
			radial * 2.2 + Vector3.UP * 2.4, 0.13)
	previous = ship.position
	initialized = true
	update_trail(0.0, false)

func advance_arrival(delta: float) -> void:
	arrival_age = minf(ARRIVAL_SECONDS, arrival_age + delta)
	opacity = smoothstep(0.0, ARRIVAL_SECONDS, arrival_age)

func apply_arrival() -> void:
	for material in fade_materials:
		material.albedo_color.a = opacity
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if opacity < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED

func update_trail(delta: float, underway: bool) -> void:
	clock += delta
	var movement: float = Vector2(ship.position.x - previous.x, ship.position.z - previous.z).length()
	var snapped := not initialized or movement > 24.0
	var speed := 0.0 if snapped or not underway else movement / maxf(delta, 0.001)
	previous = ship.position
	initialized = true
	if snapped:
		wake.clear_path()
		for drop in drops: drop.age = 1.0
		spray_credit = 0.0
	# Ordinary stern is at local +0.8 m; the flagship uses the same hull centre
	# with a longer stern. Deposit behind it, never through the moving deck.
	var stern_offset := 5.0 if ship.mine_layer == null else 1.5
	var stern: Vector3 = ship.position - ship.forward() * stern_offset
	wake.advance_path(stern, clock, delta, speed / 7.5, ship.heading)
	wake.visible = wake.count > 1
	sync_surface()
	if speed > 1.0 and ship.game.development_spray:
		spray_credit += delta * (5.0 if ship.game.ocean_quality == 0 else 12.0)
		if spray_credit >= 1.0:
			spray_credit = fmod(spray_credit, 1.0)
			var side: float = -1.0 if emitted % 2 == 0 else 1.0
			_emit(stern + ship.port_direction() * side * 0.75,
				-ship.forward() * 1.5 + ship.port_direction() * side * 1.6 + Vector3.UP * 1.7,
				0.09 + minf(speed, 16.0) * 0.004)
	spray.global_transform = Transform3D.IDENTITY
	active_drops = 0
	for i in CAPACITY:
		var drop := drops[i]
		drop.age += delta
		var alive: bool = drop.age < drop.life
		var at: Vector3 = drop.origin + drop.velocity * drop.age + Vector3.DOWN * 3.8 * drop.age * drop.age
		var alpha := (1.0 - smoothstep(0.25, drop.life, drop.age)) * 0.7 if alive else 0.0
		if ship.game.motion_setting == 1: alpha *= 0.65
		pool.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(0.00001, drop.radius if alive else 0.0)), at))
		pool.set_instance_custom_data(i, Color(1, 1, 1, alpha))
		if alpha > 0.01: active_drops += 1
	spray.visible = active_drops > 0 and ship.game.development_spray

func sync_surface() -> void:
	var ocean = ship.game.ocean
	for material in wake.materials:
		ocean.settings.apply_waves(material)
		ocean.settings.apply_palette(material)
		ocean.wave_field.apply_to(material)
		material.set_shader_parameter("wave_time", ocean.wave_time)
		material.set_shader_parameter("focus_xz", ocean.focus_xz)
		material.set_shader_parameter("fade_start", ocean.fade_start)
		material.set_shader_parameter("fade_end", ocean.fade_end)

func _emit(at: Vector3, velocity: Vector3, radius: float) -> void:
	at.y = ship.game.ocean.height_at(Vector2(at.x, at.z)) + 0.12
	drops[cursor] = {"age": 0.0, "life": 0.6, "origin": at, "velocity": velocity, "radius": radius}
	cursor = (cursor + 1) % CAPACITY
	emitted += 1

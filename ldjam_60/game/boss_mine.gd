extends StaticBody3D
## Stationary planar hazard. The ring samples the same ocean as the visible mine.
const MODEL = preload("res://assets/optimized/spike_mine.glb")
const RING = preload("res://game/boss_mine_ring.gdshader")
@export var trigger_radius := 7.0
@export var arming_delay := 0.8
static var _rings: Dictionary = {}
var pooled := false
var game: Node3D
var age := 0.0
var spent := false
var model: Node3D
var _model_basis: Basis
var ring: MeshInstance3D
var material: ShaderMaterial
var collision_shape: CollisionShape3D
var _settings: Resource
var _settings_dirty := true

func _ready() -> void:
	collision_layer = 8 # Player cannon only; boats and enemy shells pass through.
	collision_mask = 0
	set_meta("target_kind", "mine")
	set_meta("destroyed", false)
	set_meta("target_radius", 1.8)
	add_to_group("cannon_targets")
	collision_shape = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.8
	collision_shape.shape = shape
	add_child(collision_shape)
	model = MODEL.instantiate()
	model.scale = Vector3.ONE * 16.0
	add_child(model)
	_model_basis = model.global_basis
	if not _rings.has(trigger_radius):
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 129:
			var angle := i * TAU / 128.0
			for edge in [-0.07, 0.07]:
				mesh.surface_add_vertex(Vector3(cos(angle), 0, sin(angle)) * (trigger_radius + edge))
		mesh.surface_end()
		_rings[trigger_radius] = mesh
	material = ShaderMaterial.new()
	material.shader = RING
	set_meta("ring_radius", trigger_radius)
	ring = MeshInstance3D.new()
	ring.mesh = _rings[trigger_radius]
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.extra_cull_margin = 4.0
	add_child(ring)
	if pooled: expire()
	else: update_visuals()

func activate(at: Vector3) -> void:
	position = at
	age = 0.0
	spent = false
	set_meta("destroyed", false)
	collision_layer = 8
	visible = true
	set_process(true)
	update_visuals()

func armed() -> bool:
	return not spent and age >= arming_delay

func _process(_delta: float) -> void:
	# Present after the ocean's physics update, including the current LOD focus.
	update_visuals()

func update_mine(delta: float) -> void:
	if spent:
		return
	if game.state != game.State.SAILING:
		expire()
		return
	age += delta
	var offset: Vector3 = game.boat.global_position - global_position
	offset.y = 0.0
	if armed() and offset.length_squared() <= trigger_radius * trigger_radius:
		spent = true # Before damage/effects: a contact is consumed even during immunity.
		game.take_damage(1, "Proximity mine hit")
		game.combat_particles.damage(model.global_position, false)
		game.cannon.water_splash(model.global_position)
		expire()
	update_visuals()

func update_visuals() -> void:
	if spent:
		return
	var water: float = game.ocean.height_at(Vector2(global_position.x, global_position.z))
	model.global_position.y = water + 0.65
	model.global_basis = game.ocean.floating_basis(global_position, _model_basis)
	collision_shape.global_position = model.global_position
	ring.global_position.y = water + 0.10
	material.set_shader_parameter("clock", age)
	material.set_shader_parameter("strength", 1.0 if armed() else 0.25)
	material.set_shader_parameter("wave_time", game.ocean.wave_time)
	# Follow the real surface around the full circumference, including travelling crests.
	if _settings != game.ocean.settings:
		if _settings != null and _settings.changed.is_connected(_invalidate_settings):
			_settings.changed.disconnect(_invalidate_settings)
		_settings = game.ocean.settings
		_settings.changed.connect(_invalidate_settings)
		_settings_dirty = true
	if _settings_dirty:
		_settings.apply_waves(material)
		_settings_dirty = false
	game.ocean.wave_field.apply_to(material)
	material.set_shader_parameter("focus_xz", game.ocean.focus_xz)
	material.set_shader_parameter("fade_start", game.ocean.fade_start)
	material.set_shader_parameter("fade_end", game.ocean.fade_end)

func take_hit() -> void:
	if spent: return
	var at := model.global_position
	expire()
	game.combat_particles.impact(at, true, true)
	game.cannon.water_splash(at)

func expire() -> void:
	spent = true
	set_meta("destroyed", true)
	collision_layer = 0
	visible = false
	set_process(false)
	if not pooled: queue_free()

func _invalidate_settings() -> void:
	_settings_dirty = true

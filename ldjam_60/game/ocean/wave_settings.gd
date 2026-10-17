@tool
extends Resource
## One authoritative CPU/GPU wave and cosmetic-response configuration.

@export_group("Ocean")
@export_range(0.0, 1.5, 0.01) var height_multiplier: float = 0.70:
	set(value):
		height_multiplier = value
		emit_changed()
@export_range(0.0, 2.0, 0.01) var speed_multiplier: float = 1.0:
	set(value):
		speed_multiplier = value
		emit_changed()
@export var sea_level: float = -0.12:
	set(value):
		sea_level = value
		emit_changed()

@export_group("Wave 1")
@export var direction_1: Vector2 = Vector2(1.0, 0.3):
	set(value):
		direction_1 = value
		emit_changed()
@export_range(0.05, 3.0, 0.01) var frequency_1: float = 0.28:
	set(value):
		frequency_1 = value
		emit_changed()
@export_range(0.0, 5.0, 0.01) var speed_1: float = 1.2:
	set(value):
		speed_1 = value
		emit_changed()
@export_range(0.0, 3.0, 0.01) var amplitude_1: float = 1.10:
	set(value):
		amplitude_1 = value
		emit_changed()

@export_group("Wave 2")
@export var direction_2: Vector2 = Vector2(-0.4, 1.0):
	set(value):
		direction_2 = value
		emit_changed()
@export_range(0.05, 3.0, 0.01) var frequency_2: float = 0.76:
	set(value):
		frequency_2 = value
		emit_changed()
@export_range(0.0, 5.0, 0.01) var speed_2: float = 1.8:
	set(value):
		speed_2 = value
		emit_changed()
@export_range(0.0, 3.0, 0.01) var amplitude_2: float = 0.52:
	set(value):
		amplitude_2 = value
		emit_changed()

@export_group("Wave 3")
@export var direction_3: Vector2 = Vector2(0.8, -0.6):
	set(value):
		direction_3 = value
		emit_changed()
@export_range(0.05, 3.0, 0.01) var frequency_3: float = 1.30:
	set(value):
		frequency_3 = value
		emit_changed()
@export_range(0.0, 5.0, 0.01) var speed_3: float = 2.5:
	set(value):
		speed_3 = value
		emit_changed()
@export_range(0.0, 3.0, 0.01) var amplitude_3: float = 0.16:
	set(value):
		amplitude_3 = value
		emit_changed()

@export_group("Toon palette")
@export var trough_color: Color = Color("112c46"):
	set(value):
		trough_color = value
		emit_changed()
@export var main_color: Color = Color("17556b"):
	set(value):
		main_color = value
		emit_changed()
@export var slope_color: Color = Color("238a98"):
	set(value):
		slope_color = value
		emit_changed()
@export var crest_color: Color = Color("3796a5"):
	set(value):
		crest_color = value
		emit_changed()
@export var sun_direction: Vector3 = Vector3(-0.6, 0.7, -0.4):
	set(value):
		sun_direction = value
		emit_changed()
@export_range(0.005, 0.15, 0.005) var band_softness: float = 0.035:
	set(value):
		band_softness = value
		emit_changed()

@export_group("Crest foam")
@export_range(0.0, 1.0, 0.01) var foam_threshold: float = 0.55:
	set(value):
		foam_threshold = value
		emit_changed()
@export_range(0.02, 0.4, 0.01) var foam_softness: float = 0.10:
	set(value):
		foam_softness = value
		emit_changed()
@export var foam_color: Color = Color("a1d7db"):
	set(value):
		foam_color = value
		emit_changed()
@export_range(0.0, 1.5, 0.01) var foam_intensity: float = 0.82:
	set(value):
		foam_intensity = value
		emit_changed()
## Independent of ambient foam, so calm water still shows approaching encounter caps.
@export_range(0.0, 1.5, 0.05) var encounter_foam: float = 1.0:
	set(value):
		encounter_foam = value
		emit_changed()
@export_range(0.0, 2.0, 0.05) var pattern_density: float = 0.8:
	set(value):
		pattern_density = value
		emit_changed()

@export_group("Boat visual response")
@export_range(0.0, 1.0, 0.01) var bob_strength: float = 1.0:
	set(value):
		bob_strength = value
		emit_changed()
@export_range(0.0, 1.5, 0.01) var pitch_strength: float = 0.90:
	set(value):
		pitch_strength = value
		emit_changed()
@export_range(0.0, 1.5, 0.01) var roll_strength: float = 0.85:
	set(value):
		roll_strength = value
		emit_changed()
@export_range(0.5, 20.0, 0.1) var motion_damping: float = 7.0:
	set(value):
		motion_damping = value
		emit_changed()
@export_range(0.0, 15.0, 0.5) var pitch_limit_degrees: float = 8.0:
	set(value):
		pitch_limit_degrees = value
		emit_changed()
@export_range(0.0, 20.0, 0.5) var roll_limit_degrees: float = 12.0:
	set(value):
		roll_limit_degrees = value
		emit_changed()
@export_range(-0.5, 0.3, 0.01) var hull_draft_offset: float = -0.18:
	set(value):
		hull_draft_offset = value
		emit_changed()
@export_range(0.0, 0.5, 0.01) var camera_bob_strength: float = 0.20:
	set(value):
		camera_bob_strength = value
		emit_changed()


func sample_wave(world_xz: Vector2, wave_time: float) -> Vector3:
	# Return (height, dh/dx, dh/dz). Identical to waves.gdshaderinc.
	return _one(world_xz, wave_time, direction_1, frequency_1, speed_1, amplitude_1) \
		+ _one(world_xz, wave_time, direction_2, frequency_2, speed_2, amplitude_2) \
		+ _one(world_xz, wave_time, direction_3, frequency_3, speed_3, amplitude_3)


func _one(p: Vector2, time: float, direction: Vector2, frequency: float, speed: float, amplitude: float) -> Vector3:
	var d := direction.normalized()
	var phase := p.dot(d) * frequency - time * speed * speed_multiplier
	var s := 0.5 + 0.5 * sin(phase)
	var a := amplitude * height_multiplier
	var height := a * (s * s * s - 0.3125)
	var derivative := a * 1.5 * s * s * cos(phase) * frequency
	return Vector3(height, derivative * d.x, derivative * d.y)


func maximum_displacement() -> float:
	return (amplitude_1 + amplitude_2 + amplitude_3) * height_multiplier * 0.6875


func apply_waves(material: ShaderMaterial) -> void:
	var d1 := direction_1.normalized()
	var d2 := direction_2.normalized()
	var d3 := direction_3.normalized()
	material.set_shader_parameter("wave_1", Vector4(d1.x, d1.y, frequency_1, speed_1))
	material.set_shader_parameter("wave_2", Vector4(d2.x, d2.y, frequency_2, speed_2))
	material.set_shader_parameter("wave_3", Vector4(d3.x, d3.y, frequency_3, speed_3))
	material.set_shader_parameter("wave_amplitudes", Vector3(amplitude_1, amplitude_2, amplitude_3))
	material.set_shader_parameter("height_multiplier", height_multiplier)
	material.set_shader_parameter("speed_multiplier", speed_multiplier)
	material.set_shader_parameter("sea_level", sea_level)
	material.set_shader_parameter("foam_color", foam_color)


func apply_palette(material: ShaderMaterial) -> void:
	material.set_shader_parameter("trough_color", trough_color)
	material.set_shader_parameter("main_color", main_color)
	material.set_shader_parameter("slope_color", slope_color)
	material.set_shader_parameter("crest_color", crest_color)
	material.set_shader_parameter("sun_direction", sun_direction.normalized())
	material.set_shader_parameter("band_softness", band_softness)
	material.set_shader_parameter("foam_threshold", foam_threshold)
	material.set_shader_parameter("foam_softness", foam_softness)
	material.set_shader_parameter("foam_intensity", foam_intensity)
	material.set_shader_parameter("encounter_foam", encounter_foam)
	material.set_shader_parameter("pattern_density", pattern_density)
	material.set_shader_parameter("crest_scale", maxf(0.5, maximum_displacement()))

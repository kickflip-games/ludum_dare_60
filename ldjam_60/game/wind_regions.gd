extends Node3D
## Optional authored wind lanes; region overlap cannot stack bonuses.
const CRUISE := preload("res://game/ocean/wave_sailing.gd").CRUISE_SPEED
const BOOST_SPEED := 12.5
const LANES := [Vector4(-158,7,-0.65,62),Vector4(-65,-205,PI/2,66),Vector4(350,-40,2.97,62)]
var enabled := true
var speed := CRUISE
var inside := false
var visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/wind_lane.gdshader")
	for lane: Vector4 in LANES:
		var patch := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(22,lane.w)
		patch.mesh = plane
		patch.material_override = material
		patch.position = Vector3(lane.x,0.22,lane.y)
		patch.rotation.y = -lane.z
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
		visuals.append(patch)

func contains(point: Vector3) -> bool:
	for lane: Vector4 in LANES:
		var offset := Vector2(point.x-lane.x,point.z-lane.y)
		var forward := Vector2(sin(lane.z),-cos(lane.z))
		var right := Vector2(-forward.y,forward.x)
		if absf(offset.dot(forward)) < lane.w*0.5 and absf(offset.dot(right)) < 11:
			return true
	return false

func advance(point: Vector3, delta: float) -> float:
	inside = enabled and contains(point)
	speed = move_toward(speed,BOOST_SPEED if inside else CRUISE,delta*(3.0 if inside else 1.5))
	return speed

func reset() -> void:
	speed = CRUISE
	inside = false

func present(active: bool, time: float) -> void:
	visible = enabled and active
	if not visuals.is_empty():
		visuals[0].material_override.set_shader_parameter("visual_time",time)

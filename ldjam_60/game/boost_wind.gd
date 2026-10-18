extends MeshInstance3D
## Bounded cosmetic slipstream around the sail/hull, driven only by held boost.
const STREAMS := 8
const SEGMENTS := 10
var strength := 0.0
var active_streams := 0
var ribbons := ImmediateMesh.new()

func _ready() -> void:
	mesh = ribbons
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	reset()

func reset() -> void:
	strength = 0.0
	active_streams = 0
	visible = false
	ribbons.clear_surfaces()

func update_wind(held: bool, time: float, delta: float, camera: Camera3D, reduced: bool, aiming: bool) -> void:
	strength = move_toward(strength,1.0 if held else 0.0,maxf(delta,0.0)*7.0)
	visible = strength>0.001
	active_streams = 0
	ribbons.clear_surfaces()
	if not visible: return
	active_streams = 4 if reduced else STREAMS
	var eye := to_local(camera.global_position)
	ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for stream in active_streams:
		var phase := fposmod(time*(0.7 if reduced else 1.15)+float(stream)*0.381,1.0)
		var side := -1.0 if stream%2==0 else 1.0
		var x := side*(1.9+float(stream/2)*0.38)
		var y := 1.6+float(stream%4)*0.72
		var start := -5.0+phase*9.0
		var length := 2.4+float(stream%3)*0.45
		var opacity := sin(phase*PI)*strength*(0.40 if aiming else 0.72)
		for segment in SEGMENTS:
			var t0 := float(segment)/SEGMENTS
			var t1 := float(segment+1)/SEGMENTS
			var a := Vector3(x+side*sin(t0*PI)*0.22,y+sin(t0*TAU+float(stream))*0.18,start+t0*length)
			var b := Vector3(x+side*sin(t1*PI)*0.22,y+sin(t1*TAU+float(stream))*0.18,start+t1*length)
			var across := (b-a).cross(eye-(a+b)*0.5).normalized()*0.055
			var color_a := Color(0.72,0.87,1.0,opacity*sin(t0*PI))
			var color_b := Color(0.72,0.87,1.0,opacity*sin(t1*PI))
			for vertex in [a-across,a+across,b+across,a-across,b+across,b-across]:
				ribbons.surface_set_color(color_a if vertex==a-across or vertex==a+across else color_b)
				ribbons.surface_add_vertex(vertex)
	ribbons.surface_end()

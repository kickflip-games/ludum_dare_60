extends MeshInstance3D
## Straight boat-local slipstream, travelling from bow to stern during boost.
const STREAMS := 6
const SEGMENTS := 4
var ribbons := ImmediateMesh.new()
var active_streams := 0

func _ready() -> void:
	mesh = ribbons
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.vertex_color_use_as_albedo = true
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = ink
	reset()

func reset() -> void:
	visible = false
	active_streams = 0
	ribbons.clear_surfaces()

func update_trails(strength: float, time: float, camera: Camera3D, reduced: bool, aiming: bool) -> void:
	if strength <= 0.001:
		if visible: reset()
		return
	visible = true
	active_streams = 4 if reduced else STREAMS
	ribbons.clear_surfaces()
	ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var eye := to_local(camera.global_position)
	for stream in active_streams:
		var phase := fposmod(time * 1.35 + float(stream) * 0.381, 1.0)
		var side := -1.0 if stream % 2 == 0 else 1.0
		var lane := stream / 2
		var start := Vector3(side * (1.75 + lane * 0.35), 1.0 + lane * 1.1, -3.5 + phase * 5.0)
		var finish := start + Vector3.BACK * (4.2 + lane * 0.65)
		var across := Vector3.BACK.cross(eye - (start + finish) * 0.5).normalized() * (0.10 + lane * 0.02)
		var opacity := sin(phase * PI) * strength * (0.4 if aiming else 0.85)
		for segment in SEGMENTS:
			var t0 := float(segment) / SEGMENTS
			var t1 := float(segment + 1) / SEGMENTS
			var a := start.lerp(finish, t0)
			var b := start.lerp(finish, t1)
			var wa := across * sin(t0 * PI)
			var wb := across * sin(t1 * PI)
			var ca := Color(0.80, 0.91, 1.0, opacity * sin(t0 * PI))
			var cb := Color(0.80, 0.91, 1.0, opacity * sin(t1 * PI))
			var vertices := [a - wa, a + wa, b + wb, a - wa, b + wb, b - wb]
			for index in vertices.size():
				ribbons.surface_set_color(ca if index in [0, 1, 3] else cb)
				ribbons.surface_add_vertex(vertices[index])
	ribbons.surface_end()

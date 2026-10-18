extends RefCounted
## Cosmetic scratches on the existing hull; health and hit timing belong to crossing.
var light_marks: MeshInstance3D
var heavy_marks: MeshInstance3D
var wood: Array[StandardMaterial3D] = []
var severity := 0
var flash_strength := 0.0


func configure(pivot: Node3D, ship: Node3D) -> void:
	# Duplicate only the player's wood materials; the imported mesh stays shared.
	var hull := ship.get_node("RootNode/Boat") as MeshInstance3D
	for surface in [0, 1]:
		var material := hull.get_active_material(surface).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color("d68b67")
		material.emission_energy_multiplier = 0.0
		hull.set_surface_override_material(surface, material)
		wood.append(material)
	# Two small splintered cuts on the transom, visible from the normal helm.
	light_marks = _marks(pivot, "HullScratches", [
		PackedVector3Array([Vector3(-0.82, 0.94, 0.94), Vector3(-0.57, 0.83, 0.94), Vector3(-0.67, 0.76, 0.94), Vector3(-0.39, 0.60, 0.94)]),
		PackedVector3Array([Vector3(0.23, 0.94, 0.94), Vector3(0.46, 0.85, 0.94), Vector3(0.37, 0.77, 0.94), Vector3(0.69, 0.62, 0.94)]),
	], Vector3.BACK)
	# More splintering across the top of both gunwales at critical health.
	heavy_marks = _marks(pivot, "HeavyHullScratches", [
		PackedVector3Array([Vector3(-1.27, 0.978, -0.65), Vector3(-1.10, 0.978, -0.52), Vector3(-1.23, 0.978, -0.39), Vector3(-1.04, 0.978, -0.22)]),
		PackedVector3Array([Vector3(1.20, 0.978, -0.12), Vector3(1.02, 0.978, 0.02), Vector3(1.14, 0.978, 0.15), Vector3(0.94, 0.978, 0.34)]),
	], Vector3.UP)
	update(1, 1, 0.0)


func update(hull: int, capacity: int, hit_flash: float) -> void:
	var fraction := clampf(float(hull) / maxf(1.0, capacity), 0.0, 1.0)
	# Exact thirds put the default three-point hull into three distinct conditions.
	severity = 0 if fraction > 2.0 / 3.0 else 1 if fraction > 1.0 / 3.0 else 2
	light_marks.visible = severity >= 1
	heavy_marks.visible = severity == 2
	# First 0.18 seconds of the existing 0.8-second impact state; no new timer.
	flash_strength = clampf((hit_flash - 0.62) / 0.18, 0.0, 1.0)
	for material in wood:
		material.emission_energy_multiplier = flash_strength * 0.35


func _marks(parent: Node3D, node_name: String, cuts: Array, normal: Vector3) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	# Muted fresh-timber edges make the dark cuts readable against dark wood at night.
	for layer in range(2):
		var vertices := PackedVector3Array()
		for cut: PackedVector3Array in cuts:
			for i in range(cut.size() - 1):
				var side := (cut[i + 1] - cut[i]).cross(normal).normalized() * (0.048 if layer == 0 else 0.032)
				var lift := normal * (0.002 * layer)
				var a := cut[i] + lift
				var b := cut[i + 1] + lift
				vertices.append_array(PackedVector3Array([a - side, a + side, b + side, a - side, b + side, b - side]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color("987556") if layer == 0 else Color("211c1b")
		mesh.surface_set_material(layer, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

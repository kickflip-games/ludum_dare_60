extends RefCounted
## Keep the supplied atlas intact; per-instance overrides own damage/highlighting.

static func prepare(node: Node, night_fill := 0.04) -> Array[StandardMaterial3D]:
	var materials: Array[StandardMaterial3D] = []
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface).duplicate() as StandardMaterial3D
			material.metallic = 0.0
			material.roughness = 1.0
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.emission_enabled = true
			material.emission_texture = material.albedo_texture
			material.emission = Color.WHITE
			material.emission_energy_multiplier = night_fill
			node.set_surface_override_material(surface, material)
			materials.append(material)
	for child in node.get_children():
		materials.append_array(prepare(child, night_fill))
	return materials

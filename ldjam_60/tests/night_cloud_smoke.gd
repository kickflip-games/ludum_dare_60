extends SceneTree
## Layout invariants that prevent camera-dependent clouds and invalid cards.
const Clouds = preload("res://game/night_clouds.gd")
const SkyShader = preload("res://game/night_sky.gdshader")
var failures := 0
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	var layout := Clouds.new()
	var material := ShaderMaterial.new()
	material.shader = SkyShader
	layout.configure(material, 60, Vector2(0.85, 1.15))
	var original: PackedVector4Array = material.get_shader_parameter("cloud_centers")
	var rights: PackedVector4Array = material.get_shader_parameter("cloud_rights")
	var ups: PackedVector4Array = material.get_shader_parameter("cloud_ups")
	check(original.size() == 40, "layout stays bounded to 40 cards in a single sky pass")
	var families: Dictionary = {}
	for i in original.size():
		var center := Vector3(original[i].x, original[i].y, original[i].z)
		var right := Vector3(rights[i].x, rights[i].y, rights[i].z)
		var up := Vector3(ups[i].x, ups[i].y, ups[i].z)
		check(is_equal_approx(center.length(), 1.0), "cloud %d has a unit world direction" % i)
		check(absf(center.dot(right)) < 0.0001 and absf(center.dot(up)) < 0.0001, "cloud %d uses an orthogonal fixed tangent plane" % i)
		check(right.is_finite() and up.is_finite(), "cloud %d has finite angular bounds" % i)
		families[int(rights[i].w)] = true
	check(families.size() == 8, "all eight authored silhouettes occur")
	layout.configure(material, 60, Vector2(0.85, 1.15))
	check(original == material.get_shader_parameter("cloud_centers"), "same seed preserves layout")
	layout.configure(material, 61, Vector2(0.85, 1.15))
	check(original != material.get_shader_parameter("cloud_centers"), "another seed changes placement")
	layout.configure(material, 60, Vector2(0.85, 1.15))
	check(original == material.get_shader_parameter("cloud_centers"), "returning to seed restores exact layout")
	layout.configure(material, 60, Vector2(-2.0, 0.0))
	var clamped: PackedVector4Array = material.get_shader_parameter("cloud_rights")
	check(Vector3(clamped[0].x, clamped[0].y, clamped[0].z).is_finite(), "invalid Inspector sizes clamp safely")
	check(Clouds.ATLAS.get_size() == Vector2(2048, 512), "atlas has its expected eight padded tiles")
	# The old cards are a reversible fallback. The active field only needs a seed offset.
	layout.configure_procedural(material, 60)
	var offset: Vector3 = material.get_shader_parameter("cloud_offset")
	check(offset.is_finite(), "procedural seed offset is finite")
	layout.configure_procedural(material, 60)
	check(offset == material.get_shader_parameter("cloud_offset"), "same procedural seed is stable")
	layout.configure_procedural(material, 61)
	check(offset != material.get_shader_parameter("cloud_offset"), "procedural seed changes the field")
	layout.configure_procedural(material, 60)
	check(offset == material.get_shader_parameter("cloud_offset"), "returning to seed restores the procedural field")
	print("NIGHT CLOUD CHECK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

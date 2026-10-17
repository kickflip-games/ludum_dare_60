extends RefCounted
## Fixed tangent cards composited inside the existing sky pass. No scene nodes,
## transparent sorting, per-frame images, or camera-facing billboard transforms.
const ATLAS = preload("res://assets/sky/night_clouds.png")
const COUNT := 40
# Height follows each painting's intended proportions. A wisp must not inherit
# the flattened distant-bank scale (the old source of needle-like silhouettes).
const HEIGHT_RATIOS := [0.54, 0.62, 0.74, 0.76, 0.57, 0.78, 0.60, 0.68]
const NEAR_FAMILIES := [0, 3, 1, 6, 7, 0, 3, 4, 1, 6, 2, 5, 4, 5, 6, 2, 4, 3, 7, 0, 1, 1, 7, 6]
var _seed_value: int = -9223372036854775807
var _size_range := Vector2(INF, INF)
var _procedural_seed: int = -9223372036854775807


func configure_procedural(material: ShaderMaterial, seed_value: int) -> void:
	if seed_value == _procedural_seed:
		return
	_procedural_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	material.set_shader_parameter("cloud_offset", Vector3(rng.randf_range(8, 72), rng.randf_range(8, 72), rng.randf_range(8, 72)))


func configure(material: ShaderMaterial, seed_value: int, size_range: Vector2) -> void:
	if seed_value == _seed_value and size_range == _size_range:
		return
	_seed_value = seed_value
	_size_range = size_range
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var centers := PackedVector4Array()
	var rights := PackedVector4Array()
	var ups := PackedVector4Array()
	# Authored loose groups, isolated banks, and a sparse zenith. Azimuth is
	# measured from world north. The second layer sits low on the horizon.
	var positions := [
		Vector2(-164, 42), Vector2(-113, 31), Vector2(-73, 53), Vector2(-28, 33),
		Vector2(16, 74), Vector2(58, 38), Vector2(101, 51), Vector2(148, 29),
		Vector2(-137, 73), Vector2(-51, 77), Vector2(84, 75), Vector2(171, 68),
		Vector2(-170, 20), Vector2(-99, 18), Vector2(-45, 22), Vector2(27, 24),
		Vector2(78, 18), Vector2(126, 21), Vector2(-124, 46), Vector2(139, 49),
		Vector2(-18, 48), Vector2(42, 54), Vector2(-82, 64), Vector2(114, 64),
		Vector2(-175, 8), Vector2(-151, 13), Vector2(-123, 7), Vector2(-102, 11),
		Vector2(-76, 8), Vector2(-52, 14), Vector2(-25, 7), Vector2(-3, 12),
		Vector2(20, 8), Vector2(44, 13), Vector2(67, 7), Vector2(91, 11),
		Vector2(117, 8), Vector2(142, 13), Vector2(162, 6), Vector2(179, 15),
	]
	for i in COUNT:
		var distant := i >= 24
		var azimuth := deg_to_rad(positions[i].x + rng.randf_range(-7, 7))
		var elevation := deg_to_rad(positions[i].y + rng.randf_range(-3, 3))
		var center := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
		var right := Vector3(cos(azimuth), 0, sin(azimuth))
		# Higher formations follow a common world wind rather than radiating
		# around the zenith. Low banks stay level against the ocean horizon.
		var wind_direction := Vector3.RIGHT
		var wind := (wind_direction - center * center.dot(wind_direction)).normalized()
		if wind.dot(right) < 0.0:
			wind = -wind
		right = right.lerp(wind, smoothstep(0.65, 1.15, elevation)).normalized()
		var up := right.cross(center)
		var roll := rng.randf_range(-0.065, 0.065)
		var rotated_right := right * cos(roll) + up * sin(roll)
		up = up * cos(roll) - right * sin(roll)
		var scale_value := rng.randf_range(clampf(minf(size_range.x, size_range.y), 0.25, 1.7), clampf(maxf(size_range.x, size_range.y), 0.25, 1.7))
		# Smaller overhead formations leave clear sky and limit wide-angle
		# perspective deformation. Broad low banks still frame the horizon.
		var width := deg_to_rad(rng.randf_range(20, 32) if distant else rng.randf_range(28, 38)) * scale_value
		width *= lerpf(1.0, 0.83, smoothstep(0.8, 1.3, elevation))
		var family: int = NEAR_FAMILIES[i % 24]
		if (i / 8) % 2 == 1:
			rotated_right = -rotated_right
		if distant:
			family = [4, 0, 5, 1][i % 4]
		var height: float = width * HEIGHT_RATIOS[family] * rng.randf_range(0.94, 1.08)
		if distant:
			height *= 0.72
		var rank := rng.randf_range(0.10, 0.88) if i < 12 else rng.randf_range(0.28, 1.05)
		# Retain a feather and a layered bank in the default overhead composition,
		# rather than leaving only the rounded families after density selection.
		if i == 10 or i == 11:
			rank = minf(rank, 0.48)
		centers.append(Vector4(center.x, center.y, center.z, rank))
		rights.append(Vector4(rotated_right.x / tan(width * 0.5), rotated_right.y / tan(width * 0.5), rotated_right.z / tan(width * 0.5), family))
		ups.append(Vector4(up.x / tan(height * 0.5), up.y / tan(height * 0.5), up.z / tan(height * 0.5), rng.randf()))
	material.set_shader_parameter("cloud_atlas", ATLAS)
	material.set_shader_parameter("cloud_centers", centers)
	material.set_shader_parameter("cloud_rights", rights)
	material.set_shader_parameter("cloud_ups", ups)

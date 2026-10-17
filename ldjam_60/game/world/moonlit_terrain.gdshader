shader_type spatial;
render_mode cull_back;

// World-space paint keeps the same scale on the heightmap, boulders and lintel.
group_uniforms Palette;
uniform vec4 stone : source_color = vec4(0.28, 0.34, 0.41, 1.0);
uniform vec4 stone_light : source_color = vec4(0.43, 0.46, 0.50, 1.0);
uniform vec4 crevice : source_color = vec4(0.15, 0.20, 0.27, 1.0);
uniform vec4 shore : source_color = vec4(0.63, 0.57, 0.44, 1.0);
uniform vec4 moss : source_color = vec4(0.31, 0.40, 0.34, 1.0);
uniform vec4 lichen : source_color = vec4(0.53, 0.56, 0.41, 1.0);
uniform vec4 wet_stone : source_color = vec4(0.13, 0.23, 0.26, 1.0);
group_uniforms Surface;
uniform sampler2D paint_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D joint_texture : filter_linear_mipmap, repeat_enable;
uniform float paint_scale : hint_range(12.0, 96.0) = 64.0;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.50;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.68;
uniform float sea_level = 0.0;
// Kept for compatibility with the installed LiteTerrain material API.
uniform float lod_grass_enabled = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float triplanar_paint(vec3 p, vec3 weights) {
	return texture(paint_texture, p.yz).r * weights.x
		+ texture(paint_texture, p.xz + vec2(0.31, 0.17)).r * weights.y
		+ texture(paint_texture, p.xy + vec2(0.73, 0.41)).r * weights.z;
}

float triplanar_joints(vec3 p, vec3 weights) {
	return texture(joint_texture, p.zy * vec2(1.0, 1.6)).r * weights.x
		+ texture(joint_texture, p.xz).r * weights.y
		+ texture(joint_texture, p.xy * vec2(1.0, 1.6)).r * weights.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_position;
	float wash = triplanar_paint(p / paint_scale, weights);
	float grain = triplanar_paint(p / 16.0, weights);
	float broad = texture(paint_texture, p.xz / 125.0 + vec2(0.2, 0.6)).r;
	float height = p.y - sea_level;
	float gentle = smoothstep(0.58, 0.91, n.y);
	float plates = triplanar_joints(p / 86.0, weights);
	float joints = 1.0 - smoothstep(0.018, 0.11, plates);
	// Warped, tilted beds break up the former continuous horizontal stripes.
	float beds = sin((height + p.x * 0.065 - p.z * 0.045 + wash * 0.9) * 0.62);
	float seams = smoothstep(0.72, 0.98, beds) * (1.0 - gentle * 0.65);
	float chips = smoothstep(0.64, 0.82, grain);
	vec3 rock = mix(stone.rgb, stone_light.rgb, 0.18 + wash * 0.28 + smoothstep(0.25, 0.55, plates) * 0.18);
	rock = mix(rock, crevice.rgb, (seams * 0.14 + chips * 0.07 + joints * 0.62 * (1.0 - gentle * 0.75)) * texture_strength);
	rock *= mix(1.0, 0.95 + grain * 0.10, texture_strength);
	// Broad patches on upward slopes, with sparse pale lichen on rock faces.
	float greenery = gentle * smoothstep(3.0, 11.0, height)
		* smoothstep(0.35, 0.63, broad + wash * 0.10) * moss_amount;
	vec3 color = mix(rock, moss.rgb * (0.86 + wash * 0.30), greenery);
	float lichens = smoothstep(0.68, 0.84, wash) * smoothstep(4.0, 14.0, height) * 0.18;
	color = mix(color, lichen.rgb, lichens);
	float sand = (1.0 - smoothstep(3.0, 8.0, height + wash * 2.5)) * (0.38 + gentle * 0.62);
	color = mix(color, shore.rgb * (0.92 + grain * 0.12), sand);
	float wet = 1.0 - smoothstep(0.7, 2.6, height + (grain - 0.5) * 0.7);
	color = mix(color, wet_stone.rgb * (0.78 + wash * 0.40), wet * 0.76);
	// A broken salt edge catches moonlight just above the moving water.
	float salt = smoothstep(1.2, 1.5, height) * (1.0 - smoothstep(1.6, 2.1, height));
	salt *= smoothstep(0.46, 0.67, grain) * 0.20;
	color = mix(color, vec3(0.59, 0.69, 0.66), salt);
	ALBEDO = color;
	ROUGHNESS = mix(0.96, 0.36, wet);
	SPECULAR = mix(0.22, 0.48, wet);
}

shader_type spatial;
render_mode cull_back;
uniform vec4 stone : source_color = vec4(0.23, 0.30, 0.38, 1.0);
uniform vec4 shore : source_color = vec4(0.46, 0.45, 0.37, 1.0);
uniform vec4 summit : source_color = vec4(0.27, 0.34, 0.36, 1.0);
uniform float lod_grass_enabled = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float sand = (1.0 - smoothstep(2.0, 6.5, world_position.y)) * smoothstep(0.35, 0.75, world_normal.y);
	float top = smoothstep(11.0, 27.0, world_position.y) * smoothstep(0.6, 0.95, world_normal.y);
	vec3 color = mix(stone.rgb, summit.rgb, top);
	color = mix(color, shore.rgb, sand);
	float bands = floor(world_position.y * 0.32 + sin(world_position.x * 0.045) * 1.8);
	color *= 0.95 + 0.05 * sin(bands * 2.0);
	ALBEDO = color;
	ROUGHNESS = 0.95;
}

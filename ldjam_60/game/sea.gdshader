shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.018, 0.075, 0.10, 1.0);
uniform vec4 crest_color : source_color = vec4(0.10, 0.25, 0.27, 1.0);
uniform float visual_time = 0.0;
varying vec3 sea_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float swell = sin(dot(p, vec2(0.65, 0.76)) * 0.14 - visual_time * 0.85);
	float cross_wave = sin(dot(p, vec2(-0.91, 0.41)) * 0.22 - visual_time * 1.12);
	VERTEX.y += swell * 0.19 + cross_wave * 0.09;
	sea_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = sea_world.xz;
	float t = visual_time;
	vec2 a = vec2(0.65, 0.76);
	vec2 b = vec2(-0.91, 0.41);
	vec2 c = vec2(0.28, 0.96);
	float phase_a = dot(p, a) * 0.14 - t * 0.85;
	float phase_b = dot(p, b) * 0.22 - t * 1.12;
	float phase_c = dot(p, c) * 1.05 - t * 2.0;
	float wave_a = sin(phase_a);
	float wave_b = sin(phase_b);
	// Fine surface detail fades with distance, avoiding horizon sparkle.
	float distance_to_eye = distance(sea_world, CAMERA_POSITION_WORLD);
	float close_detail = 1.0 - smoothstep(35.0, 160.0, distance_to_eye);
	vec2 gradient = a * cos(phase_a) * 0.19 * 0.14
		+ b * cos(phase_b) * 0.09 * 0.22
		+ c * cos(phase_c) * 0.055 * close_detail;
	vec3 world_normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float patches = noise(p * 0.23 + vec2(t * 0.07, -t * 0.10));
	float crest = smoothstep(0.70, 0.98, wave_a * 0.65 + wave_b * 0.35);
	float foam = crest * smoothstep(0.48, 0.75, patches) * close_detail;
	float threads = smoothstep(0.88, 0.99, sin(phase_c + patches * 3.0))
		* smoothstep(0.66, 0.88, patches) * close_detail * 0.13;
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - sea_world);
	float fresnel = pow(1.0 - max(dot(world_normal, view_direction), 0.0), 4.0);
	float shade = 0.35 + wave_a * 0.16 + wave_b * 0.12;
	vec3 water = mix(deep_color.rgb, crest_color.rgb, shade);
	// A restrained cool horizon reflection; no screen-space/depth dependencies.
	water = mix(water, vec3(0.18, 0.29, 0.32), fresnel * 0.35);
	ALBEDO = mix(water, vec3(0.40, 0.57, 0.56), clamp(foam * 0.6 + threads, 0.0, 0.65));
	ROUGHNESS = mix(0.43, 0.78, foam);
	SPECULAR = 0.28;
}

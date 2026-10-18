shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.65;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.65;
uniform float visual_time = 0.0;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float rain(vec2 uv, vec2 cells, float speed, float seed) {
	// Slanted, sparse dashes in two depth layers. All sizes use viewport height.
	vec2 p = vec2(uv.x + uv.y * 0.24, uv.y) * cells;
	p.y -= visual_time * speed;
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float random = hash(cell + seed);
	float center = 0.15 + hash(cell + seed + 19.0) * 0.7;
	float width = max(fwidth(p.x), 0.025);
	float line = 1.0 - smoothstep(0.015, 0.015 + width, abs(local.x - center));
	float dash = smoothstep(0.1, 0.24, local.y) * (1.0 - smoothstep(0.64, 0.9, local.y));
	return line * dash * step(0.80, random);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	// Retain warm lanterns and red weapon warnings; cool mainly the shadows.
	vec3 graded = mix(color, vec3(luma), 0.18 * strength);
	graded *= mix(vec3(1.0), vec3(0.86, 0.96, 1.04), strength * (1.0 - smoothstep(0.2, 0.75, luma)));
	vec2 edge = (uv - 0.5) * 2.0;
	float vignette = smoothstep(0.22, 1.65, dot(edge, edge));
	graded *= 1.0 - vignette * 0.18 * strength;
	vec2 rain_uv = uv * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float streaks = rain(rain_uv, vec2(100.0, 20.0), 23.0, 7.0) * 0.11;
	streaks += rain(rain_uv, vec2(53.0, 12.0), 19.0, 43.0) * 0.18;
	// No refraction or distortion: targets and the horizon stay stable.
	graded += vec3(0.59, 0.72, 0.81) * streaks * rain_amount * strength;
	COLOR = vec4(graded, 1.0);
}

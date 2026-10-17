shader_type sky;
render_mode disable_fog;

uniform float visual_time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	return noise(p) * 0.56 + noise(p * 2.03 + 7.1) * 0.28
		+ noise(p * 4.07 - 3.4) * 0.16;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float height = max(d.y, 0.0);
	vec3 night = mix(vec3(0.075, 0.13, 0.17), vec3(0.012, 0.025, 0.052),
		smoothstep(0.0, 0.8, height));
	if (AT_CUBEMAP_PASS) {
		// Ambient lighting stays cheap even though the visible clouds drift.
		COLOR = night;
	} else {
		vec2 p = d.xz / (height + 0.24) * 3.1;
		vec2 drift = vec2(visual_time * 0.012, visual_time * -0.005);
		float mass = cloud_noise(p + drift);
		float wisps = cloud_noise(p * 1.7 - drift * 0.7 + 11.0);
		float cover = smoothstep(0.43, 0.68, mass + (wisps - 0.5) * 0.18);
		cover *= smoothstep(0.015, 0.14, d.y);
		// A broad clear patch around the fixed navigation star prevents obstruction.
		vec3 navigation_star = vec3(0.0, 0.8290376, -0.5591929);
		cover *= 1.0 - smoothstep(0.90, 0.985, dot(d, navigation_star));
		float lining = smoothstep(0.44, 0.59, mass) - smoothstep(0.60, 0.76, mass);
		vec3 cloud = mix(vec3(0.065, 0.095, 0.13), vec3(0.20, 0.26, 0.30), lining * 0.55 + wisps * 0.25);
		COLOR = mix(night, cloud, cover * 0.82);
	}
}

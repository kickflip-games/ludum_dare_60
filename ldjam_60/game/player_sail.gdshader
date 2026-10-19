shader_type spatial;

uniform vec4 canvas_color : source_color;
uniform float damage_glow = 0.0;
uniform float roughness = 0.95;
uniform float specular = 0.5;
uniform float sway_angle = 0.0;
uniform float foot_height;
uniform float foot_blend;
uniform float mast_radius;
uniform vec4 canvas_bounds;
uniform int damage_stage = 0;
varying vec2 cloth_uv;

float tear_distance(vec2 p, vec2 centre, vec2 radius) {
	vec2 q = (p - centre) / radius;
	// Fixed angular fraying stays attached to the cloth, without a noise texture.
	float fray = abs(fract(p.x * 31.0 + p.y * 23.0) * 2.0 - 1.0) * 0.20;
	return length(q) + fray - 1.0;
}

void vertex() {
	cloth_uv = (VERTEX.yz - canvas_bounds.xy) * canvas_bounds.zw;
	// Pin the cloth beside the mast and along the fixed boom. The original
	// low-poly vertices suffice; no subdivision, textures or extra draw pass.
	float span = sign(VERTEX.y) * max(abs(VERTEX.y) - mast_radius, 0.0);
	float free_cloth = smoothstep(foot_height, foot_height + foot_blend, VERTEX.z);
	VERTEX.x += sin(sway_angle) * span * free_cloth;
}

void fragment() {
	float scorch = 0.0;
	if (damage_stage > 0) {
		bool critical = damage_stage > 1;
		float tear = tear_distance(cloth_uv, vec2(0.81, 0.53), critical ? vec2(0.10, 0.21) : vec2(0.065, 0.14));
		if (critical) {
			tear = min(tear, tear_distance(cloth_uv, vec2(0.34, 0.25), vec2(0.09, 0.12)));
			tear = min(tear, tear_distance(cloth_uv, vec2(0.78, 0.86), vec2(0.055, 0.085)));
		}
		float teeth = 1.0 - abs(fract(cloth_uv.x * 8.0 + 0.2) * 2.0 - 1.0);
		float foot = cloth_uv.y - teeth * (critical ? 0.14 : 0.05);
		float edge_teeth = 1.0 - abs(fract(cloth_uv.y * 6.0) * 2.0 - 1.0);
		float edge = 1.0 - edge_teeth * (critical ? 0.075 : 0.025) - cloth_uv.x;
		if (tear < 0.0 || (cloth_uv.x < 0.58 && foot < 0.0) || edge < 0.0) {
			discard;
		}
		scorch = (1.0 - smoothstep(0.0, 0.28, tear)) * 0.88;
		if (cloth_uv.x < 0.58) {
			scorch = max(scorch, (1.0 - smoothstep(0.0, 0.045, foot)) * 0.6);
		}
	}
	ALBEDO = mix(canvas_color.rgb, vec3(0.16, 0.12, 0.09), scorch);
	EMISSION = vec3(1.0, 0.015, 0.005) * damage_glow;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

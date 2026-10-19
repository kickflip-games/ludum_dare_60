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

float edge_rip(float p, float tip, vec2 widths) {
	// Unequal sides give the cloth a few authored tears instead of repeated teeth.
	return max(0.0, min((p - tip + widths.x) / widths.x, (tip + widths.y - p) / widths.y));
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
		float foot_depth = (critical ? 0.34 : 0.10) * edge_rip(cloth_uv.x, 0.16, vec2(0.13, 0.07));
		foot_depth = max(foot_depth, (critical ? 0.24 : 0.07) * edge_rip(cloth_uv.x, 0.43, vec2(0.06, 0.09)));
		float foot = cloth_uv.y - foot_depth;
		float edge_depth = (critical ? 0.33 : 0.13) * edge_rip(cloth_uv.y, 0.50, vec2(0.20, 0.15));
		edge_depth = max(edge_depth, (critical ? 0.21 : 0.07) * edge_rip(cloth_uv.y, 0.83, vec2(0.10, 0.08)));
		float edge = 1.015 - edge_depth - cloth_uv.x;
		float corner = cloth_uv.x - (critical ? 0.16 : 0.0);
		// Every missing section opens onto an existing edge; no isolated punctures.
		// Lose the critical outer tip completely so it cannot become a floating scrap.
		if ((cloth_uv.x < 0.58 && foot < 0.0) || edge < 0.0 || corner < 0.0) {
			discard;
		}
		scorch = (1.0 - smoothstep(0.0, 0.035, edge)) * 0.55;
		if (cloth_uv.x < 0.58 && foot_depth > 0.001) {
			scorch = max(scorch, (1.0 - smoothstep(0.0, 0.035, foot)) * 0.55);
		}
	}
	ALBEDO = mix(canvas_color.rgb, vec3(0.16, 0.12, 0.09), scorch);
	EMISSION = vec3(1.0, 0.015, 0.005) * damage_glow;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

shader_type spatial;

uniform vec4 canvas_color : source_color;
uniform float damage_glow = 0.0;
uniform float roughness = 0.95;
uniform float specular = 0.5;
uniform float sway_angle = 0.0;
uniform float foot_height;
uniform float foot_blend;
uniform float mast_radius;

void vertex() {
	// Pin the cloth beside the mast and along the fixed boom. The original
	// low-poly vertices suffice; no subdivision, textures or extra draw pass.
	float span = sign(VERTEX.y) * max(abs(VERTEX.y) - mast_radius, 0.0);
	float free_cloth = smoothstep(foot_height, foot_height + foot_blend, VERTEX.z);
	VERTEX.x += sin(sway_angle) * span * free_cloth;
}

void fragment() {
	ALBEDO = canvas_color.rgb;
	EMISSION = vec3(1.0, 0.015, 0.005) * damage_glow;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

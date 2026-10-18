shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform float effect_time = 0.0;
varying vec3 particle_color;

void vertex() {
	float age = effect_time - (abs(INSTANCE_CUSTOM.w) - 1.0);
	float life = COLOR.a * 1.25;
	float progress = clamp(age / max(life, 0.001), 0.0, 1.0);
	bool smoke = INSTANCE_CUSTOM.w < 0.0;
	float alive = life > 0.0 && age >= 0.0 && age < life ? 1.0 : 0.0;
	// Opaque geometry shrinks away: no alpha sorting, soft-particle depth reads or overdraw layers.
	float size = (smoke ? (0.65 + progress * 1.2) : 1.0) * (1.0 - smoothstep(0.55, 1.0, progress)) * alive;
	float angle = age * (smoke ? 0.4 : 2.5);
	mat3 spin = mat3(vec3(cos(angle), 0, -sin(angle)), vec3(0, 1, 0), vec3(sin(angle), 0, cos(angle)));
	vec3 world = (MODEL_MATRIX * vec4(spin * VERTEX * size, 1.0)).xyz;
	world += INSTANCE_CUSTOM.xyz * age;
	world.y += (smoke ? 0.3 : -3.8) * age * age;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	// A restrained face tint keeps the unlit blocks legible against the night sea.
	particle_color = COLOR.rgb * (0.72 + 0.28 * max(NORMAL.y, 0.0));
}

void fragment() {
	ALBEDO = particle_color;
}

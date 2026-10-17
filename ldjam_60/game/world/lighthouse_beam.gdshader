shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float strength : hint_range(0.0, 0.4) = 0.12;

void fragment() {
	float along = UV.y;
	float fade = smoothstep(0.0, 0.045, along) * (1.0 - smoothstep(0.12, 1.0, along));
	// An open low-poly cone suggests airborne light. No volumetric buffer,
	// spotlight shadow map, screen sampling or fragment loops.
	float side = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.6);
	ALBEDO = vec3(0.86, 0.76, 0.52);
	ALPHA = fade * strength * mix(0.12, 1.0, side);
}

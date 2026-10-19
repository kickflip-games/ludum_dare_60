shader_type sky;
render_mode disable_fog;
// A/B only. Same gradient, moon direction and exposure; no lighting changes.
uniform vec3 moon_direction = vec3(0.43, 0.105, 0.897);
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 night = mix(vec3(0.085, 0.15, 0.20), vec3(0.018, 0.032, 0.075), smoothstep(0.0, 0.9, max(d.y, 0.0)));
	if (!AT_CUBEMAP_PASS) {
		float separation = length(d - normalize(moon_direction));
		float edge = max(fwidth(separation), 0.00035);
		night += vec3(0.91, 0.89, 0.79) * (1.0 - smoothstep(0.014 - edge, 0.014 + edge, separation)) * 1.35;
		night += vec3(0.52, 0.63, 0.75) * exp(-separation * separation / 0.0018) * 0.16 * smoothstep(0.0, 0.08, d.y);
	}
	COLOR = night;
}

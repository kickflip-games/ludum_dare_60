shader_type spatial;
render_mode cull_disabled;

uniform vec4 shadow_color : source_color = vec4(0.10, 0.20, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.34, 0.45, 0.39, 1.0);
uniform float wind_strength = 0.12;
uniform float plant_height = 6.5;
varying float tip;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tip = clamp(VERTEX.y / plant_height, 0.0, 1.0);
	float wind = sin(TIME * 0.75 + world.x * 0.095 + world.z * 0.065);
	VERTEX.x += wind * tip * tip * wind_strength;
	VERTEX.z += cos(TIME * 0.56 + world.z * 0.08) * tip * tip * wind_strength * 0.45;
}

void fragment() {
	ALBEDO = mix(shadow_color.rgb, tip_color.rgb, smoothstep(0.15, 1.0, tip)) * COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}

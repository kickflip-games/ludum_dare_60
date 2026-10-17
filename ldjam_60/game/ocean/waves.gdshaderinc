// The CPU equivalent lives in wave_settings.gd and OceanController.sample_surface.
uniform vec4 wave_1;
uniform vec4 wave_2;
uniform vec4 wave_3;
uniform vec3 wave_amplitudes;
uniform float height_multiplier;
uniform float speed_multiplier;
uniform float wave_time;
uniform float sea_level;
uniform vec2 focus_xz;
uniform float fade_start = 32.0;
uniform float fade_end = 92.0;
uniform vec4 foam_color : source_color;

vec3 one_wave(vec2 p, vec4 wave, float amplitude) {
	float phase = dot(p, wave.xy) * wave.z - wave_time * wave.w * speed_multiplier;
	float s = 0.5 + 0.5 * sin(phase);
	float a = amplitude * height_multiplier;
	float h = a * (s * s * s - 0.3125);
	float derivative = a * 1.5 * s * s * cos(phase) * wave.z;
	return vec3(h, derivative * wave.xy);
}

vec3 raw_waves(vec2 p) {
	return one_wave(p, wave_1, wave_amplitudes.x)
		+ one_wave(p, wave_2, wave_amplitudes.y)
		+ one_wave(p, wave_3, wave_amplitudes.z);
}

vec3 surface_sample(vec2 p) {
	vec3 sample_value = raw_waves(p);
	vec2 offset = p - focus_xz;
	float distance_value = length(offset);
	float u = clamp((distance_value - fade_start) / (fade_end - fade_start), 0.0, 1.0);
	float envelope = 1.0 - u * u * (3.0 - 2.0 * u);
	float derivative = -6.0 * u * (1.0 - u) / (fade_end - fade_start);
	vec2 envelope_gradient = offset / max(distance_value, 0.0001) * derivative;
	return vec3(sample_value.x * envelope,
		sample_value.yz * envelope + sample_value.x * envelope_gradient);
}

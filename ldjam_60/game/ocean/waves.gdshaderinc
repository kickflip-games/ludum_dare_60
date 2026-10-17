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
uniform int event_count = 0;
uniform vec4 event_origins[4]; // origin xz, propagation direction xz
uniform vec4 event_shapes[4]; // height, width, half span, speed
uniform vec4 event_timings[4]; // start, lifetime

vec2 ridge_lobe(float s, float width) {
	float q = s / width;
	if (abs(q) >= 1.0) { return vec2(0.0); }
	return vec2(0.5 + 0.5 * cos(3.14159265359 * q), -0.5 * 3.14159265359 / width * sin(3.14159265359 * q));
}

vec3 event_sample(vec2 p, int i) {
	vec4 origin = event_origins[i];
	vec4 shape = event_shapes[i];
	float age = wave_time - event_timings[i].x;
	float life = event_timings[i].y;
	float fade = smoothstep(0.0, 0.8, age) * (1.0 - smoothstep(life - 1.5, life, age));
	vec2 d = origin.zw;
	vec2 side = vec2(-d.y, d.x);
	vec2 offset = p - origin.xy - d * shape.w * age;
	float lateral = dot(offset, side);
	float s = dot(offset, d) + 1.4 * (cos(lateral * 0.055) - 1.0);
	float bend_slope = -0.077 * sin(lateral * 0.055);
	float u = clamp((abs(lateral) / shape.z - 0.7) / 0.3, 0.0, 1.0);
	float taper = 1.0 - u * u * (3.0 - 2.0 * u);
	float taper_slope = -6.0 * u * (1.0 - u) * sign(lateral) / (shape.z * 0.3);
	vec2 ridge = ridge_lobe(s, shape.y * (s >= 0.0 ? 0.65 : 1.35));
	vec2 trough = ridge_lobe(s + shape.y * 1.5, shape.y * 0.9);
	vec2 profile = ridge - trough * 0.16;
	float a = shape.x * fade;
	return vec3(a * profile.x * taper, a * (d * profile.y * taper + side * (profile.x * taper_slope + profile.y * taper * bend_slope)));
}

vec3 event_waves(vec2 p) {
	vec3 value = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		if (i >= event_count) { break; }
		value += event_sample(p, i);
	}
	return value;
}

float event_foam(vec2 p) {
	float foam = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= event_count) { break; }
		vec3 wave = event_sample(p, i);
		// A continuous slender cap along the ridge, never round spots over the sea.
		vec2 side = vec2(-event_origins[i].w, event_origins[i].z);
		float along = dot(p - event_origins[i].xy, side);
		float edge = 0.83 + 0.035 * sin(along * 2.3 + wave_time * 1.4);
		foam = max(foam, smoothstep(edge, 0.98, wave.x / max(event_shapes[i].x, 0.001)));
	}
	return foam;
}

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
	return event_waves(p) + vec3(sample_value.x * envelope,
		sample_value.yz * envelope + sample_value.x * envelope_gradient);
}

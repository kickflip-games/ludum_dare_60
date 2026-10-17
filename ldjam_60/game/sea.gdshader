shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/ocean/waves.gdshaderinc"

uniform vec4 trough_color : source_color;
uniform vec4 main_color : source_color;
uniform vec4 slope_color : source_color;
uniform vec3 sun_direction;
uniform float band_softness = 0.035;
uniform float foam_threshold = 0.42;
uniform float foam_softness = 0.12;
uniform float foam_intensity = 0.88;
uniform float crest_scale = 1.0;
// Same linear horizon color as the existing night-sky shader, without extra fog.
uniform vec3 horizon_color = vec3(0.075, 0.13, 0.17);

varying vec3 surface_world;
varying vec3 surface_normal;
varying float crest_fraction;
varying float cap_foam;

void vertex() {
	vec2 p = VERTEX.xz;
	vec3 wave = surface_sample(p);
	VERTEX.y = sea_level + wave.x;
	surface_world = VERTEX;
	surface_normal = normalize(vec3(-wave.y, 1.0, -wave.z));
	NORMAL = surface_normal;
	crest_fraction = wave.x / crest_scale;
	// Two incommensurate travelling variations break caps, entirely per vertex.
	float breakup = 0.5 + 0.25 * sin(dot(p, vec2(0.37, 0.53)) + wave_time * 0.35)
		+ 0.25 * sin(dot(p, vec2(-0.83, 0.27)) - wave_time * 0.21);
	float cap = smoothstep(foam_threshold, foam_threshold + foam_softness, crest_fraction);
	cap_foam = cap * smoothstep(0.52, 0.82, breakup);
}

void fragment() {
	vec3 n = normalize(surface_normal);
	float illumination = dot(n, normalize(sun_direction));
	float main_band = smoothstep(0.43 - band_softness, 0.43 + band_softness, illumination);
	float bright_band = smoothstep(0.76 - band_softness, 0.76 + band_softness, illumination);
	vec3 water = mix(trough_color.rgb, main_color.rgb, main_band);
	water = mix(water, slope_color.rgb, bright_band);
	float valley = (1.0 - smoothstep(-0.10, 0.18, crest_fraction)) * 0.32;
	water = mix(water, trough_color.rgb, valley);
	water = mix(water, foam_color.rgb, clamp(cap_foam * foam_intensity, 0.0, 1.0));
	float distance_to_eye = distance(surface_world, CAMERA_POSITION_WORLD);
	float haze = smoothstep(48.0, 180.0, distance_to_eye);
	ALBEDO = mix(water, horizon_color, haze);
}

shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/ocean/waves.gdshaderinc"

uniform vec4 trough_color : source_color;
uniform vec4 main_color : source_color;
uniform vec4 slope_color : source_color;
uniform vec4 crest_color : source_color;
uniform vec3 sun_direction;
uniform float band_softness = 0.035;
uniform float foam_threshold = 0.42;
uniform float foam_softness = 0.12;
uniform float foam_intensity = 0.88;
uniform float encounter_foam = 1.0;
uniform float pattern_density = 0.8;
uniform float crest_scale = 1.0;
uniform sampler2D coastal_foam_mask : filter_linear, repeat_disable;
uniform float coastal_foam_strength = 0.38;
// Presentation only: never enters the shared displacement/sampling functions.
uniform float storm_shading : hint_range(0.0, 1.0) = 0.0;
// Same linear horizon color as the existing night-sky shader, without extra fog.
uniform vec3 horizon_color = vec3(0.075, 0.13, 0.17);
// World-anchored, presentation-only footprint: centre XZ, radius, envelope.
uniform vec4 turbulence_area = vec4(0.0);
// Exactly the world-space rounded ribbons used by flow_zones.gd.
uniform int flow_count = 0;
uniform vec4 flow_frames[3]; // centre XZ, sin heading, cos heading (precomputed)
uniform vec4 flow_shapes[3]; // width, bend, collected, length

varying vec3 surface_world;
varying vec3 surface_normal;
varying float crest_fraction;
varying float cap_foam;
varying float ripple_fraction;
varying vec2 encounter_face;
varying float turbulence;
varying vec3 flow_style;

void vertex() {
	vec2 p = VERTEX.xz;
	vec3 ambient = ambient_surface(p);
	vec3 event_style;
	vec3 wave = ambient + styled_event_waves(p, event_style);
	VERTEX.y = sea_level + wave.x;
	surface_world = VERTEX;
	surface_normal = normalize(vec3(-wave.y, 1.0, -wave.z));
	NORMAL = surface_normal;
	crest_fraction = wave.x / crest_scale;
	ripple_fraction = ambient.x/max(0.025,dot(wave_amplitudes,vec3(1.0))*height_multiplier*0.6875);
	encounter_face = event_style.xy;
	turbulence = (1.0-smoothstep(turbulence_area.z*0.45,max(0.01,turbulence_area.z),distance(p,turbulence_area.xy)))*turbulence_area.w;
	// Two incommensurate travelling variations break caps, entirely per vertex.
	float breakup = 0.5 + 0.25 * sin(dot(p, vec2(0.37, 0.53)) + wave_time * 0.35)
		+ 0.25 * sin(dot(p, vec2(-0.83, 0.27)) - wave_time * 0.21);
	float cap = smoothstep(foam_threshold, foam_threshold + foam_softness, ripple_fraction);
	cap_foam = max(cap * smoothstep(0.52, 0.82, breakup) * foam_intensity, event_style.z * encounter_foam);
	flow_style = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		if (i >= flow_count) { break; }
		vec4 frame = flow_frames[i];
		vec4 shape = flow_shapes[i];
		vec2 offset = p - frame.xy;
		vec2 forward = vec2(frame.z, -frame.w);
		vec2 right = vec2(frame.w, frame.z);
		float y = dot(offset, forward);
		float local_x = dot(offset, right);
		if (abs(y) > shape.w * 0.5 || abs(local_x) > shape.x * 0.5 + abs(shape.y)) { continue; }
		float half_straight = max(0.01, (shape.w - shape.x) * 0.5);
		float clamped_y = clamp(y, -half_straight, half_straight);
		float bend = shape.y * (1.0 - pow(clamped_y / half_straight, 2.0));
		float x = local_x - bend;
		float dist = length(vec2(x, y - clamped_y)) - shape.x * 0.5;
		float mask = 1.0 - smoothstep(-1.4, 0.0, dist);
		float eligible = mix(1.0, 0.18, shape.z);
		float ribbons = smoothstep(0.45, 0.95, sin(y * 0.85 - wave_time * 3.0 + x * 0.2));
		float edge = smoothstep(-2.4, -0.6, dist) * mask;
		flow_style = max(flow_style, vec3(mask, mask * ribbons, edge) * eligible);
	}
}

void fragment() {
	vec3 n = normalize(surface_normal);
	vec2 p = surface_world.xz;
	vec3 view = normalize(CAMERA_POSITION_WORLD-surface_world);
	// Few broad bands: actual swell height, signed travelling face and moon slope.
	// No fragment event/noise loops, refraction or second displacement model.
	float swell = smoothstep(-0.22-band_softness,0.56+band_softness,ripple_fraction);
	float leading = smoothstep(0.02,0.48,encounter_face.y);
	float trailing = smoothstep(0.02,0.34,-encounter_face.y);
	float elevated = smoothstep(0.12,1.75,encounter_face.x);
	float moon_slope = smoothstep(0.48-band_softness,0.88+band_softness,dot(n,normalize(sun_direction)));
	vec3 water = mix(trough_color.rgb,main_color.rgb,0.25+swell*0.65);
	water = mix(water,slope_color.rgb,swell*0.48+moon_slope*0.07);
	water = mix(water,slope_color.rgb,leading*0.46);
	water = mix(water,crest_color.rgb,elevated*(0.15+leading*0.40));
	water = mix(water,trough_color.rgb,trailing*0.52);
	water = mix(water,main_color.rgb,turbulence*0.12);
	water = mix(water,slope_color.rgb,leading*turbulence*0.45);
	water = mix(water,crest_color.rgb,elevated*turbulence*0.20);
	float rim = 1.0-clamp(dot(n,view),0.0,1.0);
	water = mix(water,slope_color.rgb,rim*rim*rim*0.055);
	float streak = sin(dot(p,wave_1.xy)*pattern_density*0.8-wave_time*0.26
		+sin(dot(p,vec2(-0.42,0.63))*pattern_density*0.36)*1.2);
	float filament = smoothstep(0.86,0.99,streak)*swell*swell*0.085*step(0.001,pattern_density);
	water = mix(water,crest_color.rgb,filament);
	float foam_grain = 0.86+0.14*sin(dot(p,vec2(1.3,0.8))-wave_time*0.7);
	vec2 coast_uv = (p+vec2(512.5))/1025.0;
	float within_map = step(0.0,coast_uv.x)*step(coast_uv.x,1.0)*step(0.0,coast_uv.y)*step(coast_uv.y,1.0);
	float coast = texture(coastal_foam_mask,coast_uv).r*within_map;
	float wash_pulse = 0.62+0.22*sin(wave_time*0.8+dot(p,vec2(0.19,0.12)))+0.16*sin(dot(p,vec2(0.65,-0.42))-wave_time*0.5);
	coast *= wash_pulse*coastal_foam_strength*(1.0-smoothstep(0.45,1.4,crest_fraction));
	coast *= 0.55+0.45*smoothstep(-0.4,0.6,sin(dot(p,vec2(0.45,0.31))+wave_time*0.35));
	vec3 cap_color = foam_color.rgb;
	water = mix(water,cap_color,max(cap_foam*foam_grain*0.88,coast));
	water = mix(water,crest_color.rgb,flow_style.x * 0.25);
	water = mix(water,foam_color.rgb,flow_style.y * 0.34 + flow_style.z * 0.24);
	float distance_to_eye = distance(surface_world, CAMERA_POSITION_WORLD);
	float haze = smoothstep(48.0, 180.0, distance_to_eye);
	ALBEDO = mix(water * mix(1.0, 0.76, storm_shading), horizon_color, haze);
}

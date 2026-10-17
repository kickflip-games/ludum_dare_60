shader_type canvas_item;
render_mode unshaded;
#include "res://game/ocean/waves.gdshaderinc"
uniform vec2 probe_origin;
uniform vec2 probe_step;
uniform float probe_range = 4.0;
uniform float probe_rows = 3.0;
uniform bool probe_styled = false;

void fragment() {
	float index = floor(UV.x * 16.0);
	vec2 p = probe_origin + probe_step * index;
	vec3 value = surface_sample(p);
	if (probe_styled) {
		vec3 style;
		value = ambient_surface(p) + styled_event_waves(p, style);
	}
	vec3 n = normalize(vec3(-value.y, 1.0, -value.z));
	float row = floor(UV.y * probe_rows);
	float component = row < 0.5 ? value.x + sea_level : (row < 1.5 ? n.x : (probe_rows > 3.5 && row < 2.5 ? n.y : n.z));
	float packed_value = floor(clamp((component + probe_range) / (probe_range * 2.0), 0.0, 1.0) * 65535.0 + 0.5);
	COLOR = vec4(floor(packed_value / 256.0) / 255.0, mod(packed_value, 256.0) / 255.0, 0.0, 1.0);
}

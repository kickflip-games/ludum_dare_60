shader_type canvas_item;
render_mode unshaded;
#include "res://game/ocean/waves.gdshaderinc"
uniform vec2 probe_origin;
uniform vec2 probe_step;

void fragment() {
	float index = floor(UV.x * 16.0);
	vec2 p = probe_origin + probe_step * index;
	vec3 value = surface_sample(p);
	vec3 n = normalize(vec3(-value.y, 1.0, -value.z));
	float row = floor(UV.y * 3.0);
	float component = row < 0.5 ? value.x + sea_level : (row < 1.5 ? n.x : n.z);
	float packed_value = floor(clamp((component + 4.0) / 8.0, 0.0, 1.0) * 65535.0 + 0.5);
	COLOR = vec4(floor(packed_value / 256.0) / 255.0, mod(packed_value, 256.0) / 255.0, 0.0, 1.0);
}

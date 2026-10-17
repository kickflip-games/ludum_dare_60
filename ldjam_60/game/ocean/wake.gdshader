shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://game/ocean/waves.gdshaderinc"

uniform float strength = 0.0;

void vertex() {
	vec3 wave = surface_sample(VERTEX.xz);
	VERTEX.y = sea_level + wave.x + 0.045;
}

void fragment() {
	float across = smoothstep(0.0, 0.22, UV.x) * (1.0 - smoothstep(0.78, 1.0, UV.x));
	float along = sin(UV.y * PI);
	float fray = 0.7 + 0.3 * sin(UV.y * 29.0 + wave_time * 1.1);
	ALBEDO = foam_color.rgb;
	ALPHA = across * along * fray * strength * 0.32;
}

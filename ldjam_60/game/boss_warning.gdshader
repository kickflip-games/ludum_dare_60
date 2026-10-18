shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
#include "res://game/ocean/waves.gdshaderinc"
uniform vec4 tell_color : source_color = vec4(0.86, 0.62, 0.40, 1.0);
uniform float opacity = 0.65;
void vertex() {
	VERTEX.y = sea_level + surface_sample(VERTEX.xz).x + 0.16;
}
void fragment() {
	ALBEDO = tell_color.rgb;
	ALPHA = opacity;
}

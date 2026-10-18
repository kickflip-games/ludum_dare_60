shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
#include "res://game/ocean/waves.gdshaderinc"
uniform float clock = 0.0;
uniform float strength = 1.0;
void vertex() {
	VERTEX.y = sea_level + ambient_surface(VERTEX.xz).x + event_waves(VERTEX.xz).x + 0.12;
}
void fragment() {
	ALBEDO = vec3(0.88, 0.30, 0.27);
	ALPHA = strength * (0.62 + 0.18 * sin(clock * 3.5));
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
#include "res://game/ocean/waves.gdshaderinc"
uniform vec4 tell_color : source_color = vec4(0.86, 0.62, 0.40, 1.0);
uniform float opacity = 0.65;
void vertex() {
	VERTEX.y = sea_level + surface_sample(VERTEX.xz).x + 0.16;
}
void fragment() {
	// Solid translucent danger area with a brighter rim; no individual aim lines.
	float rim = max(smoothstep(0.93, 0.99, abs(UV.x * 2.0 - 1.0)), smoothstep(0.97, 0.995, UV.y));
	ALBEDO = tell_color.rgb;
	ALPHA = mix(opacity, min(0.7, opacity * 2.5), rim);
}

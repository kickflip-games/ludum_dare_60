shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled, shadows_disabled;

#include "res://game/ocean/waves.gdshaderinc"

void vertex() {
	// The sea/wake sampler; local Y contains only the edge ribbon's 1 cm lift.
	VERTEX.y = sea_level + surface_sample(VERTEX.xz).x + 0.16 + VERTEX.y;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	ROUGHNESS = 1.0;
}

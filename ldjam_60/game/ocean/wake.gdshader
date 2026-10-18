shader_type spatial;
render_mode unshaded, world_vertex_coords, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://game/ocean/waves.gdshaderinc"

uniform float strength = 0.0;
uniform int wake_kind = 0;
varying vec2 world_xz;

void vertex() {
	vec3 wave = surface_sample(VERTEX.xz);
	VERTEX.y = sea_level + wave.x + 0.045;
	world_xz = VERTEX.xz;
}

void fragment() {
	float fray = 0.5+0.3*sin(dot(world_xz,vec2(0.73,1.31))-wave_time*0.2)
		+0.2*sin(UV.y*2.7+world_xz.x*1.8-world_xz.y*0.31);
	float edge = 0.1+0.18*(1.0-fray);
	float across = smoothstep(edge,0.45,UV.x)*(1.0-smoothstep(0.55,1.0-edge,UV.x));
	float body = smoothstep(0.25,0.76,fray);
	ALBEDO = foam_color.rgb * (wake_kind==0 ? 0.94 : 0.87);
	float boost = clamp(strength - 1.0, 0.0, 1.0);
	ALPHA = across*COLOR.a*body*(wake_kind==0 ? 0.42 : 0.50)*(1.0 + boost*0.35);
}

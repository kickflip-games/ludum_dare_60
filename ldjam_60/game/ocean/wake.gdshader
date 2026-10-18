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
	// Two scales of water-fixed foam cells, with a slow churn instead of stripes.
	vec2 p = world_xz;
	float cells = sin(p.x*3.1+sin(p.y*2.3)+wave_time*0.42)
		* sin(p.y*3.7+sin(p.x*1.9)-wave_time*0.31);
	float patches = 0.5+0.25*sin(dot(p,vec2(1.17,0.71))+wave_time*0.18)
		+0.25*sin(dot(p,vec2(-0.63,1.93))-wave_time*0.22);
	float ragged = abs(UV.x-0.5)*2.0 + cells*0.18;
	float edge = 1.0-smoothstep(0.40,0.98,ragged);
	float core = 1.0-smoothstep(0.12,0.65,ragged);
	float age = COLOR.b;
	float gaps = smoothstep(0.20+age*0.23,0.62,patches);
	float froth = smoothstep(-0.42,0.62,cells);
	float foam = mix(gaps*(0.38+froth*0.62),0.48+froth*0.52,core*(1.0-age)*0.65);
	if (wake_kind==1) {
		foam = mix(gaps,0.32+froth*0.68,0.68);
	}
	ALBEDO = mix(foam_color.rgb*0.69,foam_color.rgb, froth*0.65+core*0.25);
	ALPHA = edge*COLOR.a*foam*(wake_kind==0 ? 0.73 : 0.80);
}

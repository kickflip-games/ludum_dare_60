shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float visual_time = 0.0;
void fragment() {
	float column = floor(UV.x*15.0);
	float thin = 1.0-smoothstep(0.025,0.095,abs(fract(UV.x*15.0)-0.5));
	float travel = fract(UV.y*5.0+visual_time*1.4+sin(column*4.7)*0.4);
	float streak = smoothstep(0.0,0.2,travel)*(1.0-smoothstep(0.25,0.6,travel));
	float edge = smoothstep(0.0,0.14,UV.x)*(1.0-smoothstep(0.86,1.0,UV.x));
	edge *= smoothstep(0.0,0.1,UV.y)*(1.0-smoothstep(0.9,1.0,UV.y));
	ALBEDO = vec3(0.95,0.84,0.55);
	ALPHA = thin*streak*edge*0.45;
}

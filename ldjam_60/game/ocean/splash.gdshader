shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 splash_color : source_color = vec4(0.63,0.84,0.86,1.0);
uniform float opacity = 1.0;
void fragment() {
	ALBEDO = splash_color.rgb;
	ALPHA = opacity*0.78;
}

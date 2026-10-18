shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 splash_color : source_color = vec4(0.63,0.84,0.86,1.0);
uniform float opacity = 1.0;
uniform bool foam_ring = false;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float angle = atan(local_point.z, local_point.x);
	float broken_edge = smoothstep(-0.55, 0.2, sin(angle * 9.0 + sin(angle * 5.0) * 1.7));
	float foam = foam_ring ? mix(0.12, 1.0, broken_edge) : 1.0;
	ALBEDO = mix(splash_color.rgb, vec3(0.67, 0.79, 0.84), 0.38);
	ALPHA = opacity * 0.78 * foam;
}

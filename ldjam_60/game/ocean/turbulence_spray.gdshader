shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec4 tint;
void vertex() { tint = INSTANCE_CUSTOM; }
void fragment() {
	ALBEDO = vec3(0.72,0.91,0.93);
	ALPHA = tint.a;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec4 tint;
void vertex() { tint = INSTANCE_CUSTOM; }
void fragment() {
	ALBEDO = mix(vec3(0.43,0.66,0.80),vec3(0.83,0.94,0.98),smoothstep(-0.2,0.8,NORMAL.y));
	ALPHA = tint.a;
}

shader_type spatial;
render_mode cull_disabled;
uniform float visual_time = 0.0;
uniform vec4 cloth_color : source_color = vec4(0.43, 0.51, 0.52, 1.0);

void vertex() {
	float loose = UV.y * UV.y;
	VERTEX.z += sin(visual_time * 0.8 + VERTEX.x * 1.4) * loose * 0.14;
}

void fragment() {
	float wash = 0.94 + 0.06 * sin(UV.x * 6.0 + UV.y * 3.0);
	ALBEDO = cloth_color.rgb * wash;
	ROUGHNESS = 1.0;
}

shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float board = floor(UV.x * 11.0);
	float seam = smoothstep(0.025,0.065,min(fract(UV.x*11.0),1.0-fract(UV.x*11.0)));
	float grain = sin(UV.y*160.0 + sin(UV.x*49.0)*2.0)*0.025;
	float end_seam = smoothstep(0.006,0.018,abs(fract(UV.y*3.0+board*0.31)-0.5));
	vec3 wood = mix(vec3(0.16,0.074,0.033),vec3(0.34,0.19,0.084),0.5+0.22*sin(board*4.1)+grain);
	ALBEDO = wood * mix(0.37,1.0,seam*end_seam);
	ROUGHNESS = 0.86;
}

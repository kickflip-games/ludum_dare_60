shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.0;
uniform float clock = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.7778,1.0);
	float r = length(p);
	float angle = atan(p.y,p.x);
	float line = pow(max(0.0,sin(angle*43.0+sin(angle*11.0)*2.0)),30.0);
	float dash = smoothstep(0.25,0.85,sin(r*36.0-clock*18.0+angle*7.0));
	float edge = smoothstep(0.38,0.85,r);
	COLOR = vec4(0.76,0.9,0.94,line*dash*edge*strength*0.17);
}

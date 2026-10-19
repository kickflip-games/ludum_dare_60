shader_type canvas_item;
#include "res://game/ribbon_cloth.gdshaderinc"
// Map Kenney's red cloth and cream trim separately, retaining shade and alpha.
uniform vec3 body_color : source_color = vec3(0.14117647, 0.21568627, 0.27450980); // #243746
uniform vec3 trim_color : source_color = vec3(0.72549020, 0.60784314, 0.39607843); // #B99B65

uniform float cloth_time = 0.0;
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;
varying vec4 ribbon_tint;

void vertex() {
    ribbon_tint = COLOR;
}

void fragment() {
    // Source base colours: cloth #E2665B, trim #FFF1D2. Solve their palette weights.
    float pin_x = sin(UV.x * 3.14159265);
    float phase = UV.x * 8.1681409 - cloth_time * 2.4;
    vec2 cloth_uv = ribbon_cloth_uv(UV, cloth_time, motion_amount);
    vec4 original = texture(TEXTURE, cloth_uv);
    float cloth_ratio = 102.0 / 226.0;
    float trim_weight = clamp((original.g - original.r * cloth_ratio) / (241.0 / 255.0 - cloth_ratio), 0.0, 1.0);
    float cloth_weight = max(0.0, (original.r - trim_weight) / (226.0 / 255.0));
    float light = 1.0 + cos(phase) * pin_x * motion_amount * 0.045;
    COLOR = vec4((body_color * cloth_weight + trim_color * trim_weight) * light, original.a) * ribbon_tint;
}

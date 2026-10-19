shader_type canvas_item;
#include "res://game/ribbon_cloth.gdshaderinc"

uniform float cloth_time = 0.0;
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 ribbon_size = vec2(256.0, 64.0);

void vertex() {
    // Invert the texture's sampling displacement so ink follows the cloth.
    vec2 source_uv = VERTEX / ribbon_size;
    vec2 destination_uv = source_uv;
    for (int i = 0; i < 3; i++) {
        destination_uv -= ribbon_cloth_uv(destination_uv, cloth_time, motion_amount) - source_uv;
    }
    VERTEX = destination_uv * ribbon_size;
}

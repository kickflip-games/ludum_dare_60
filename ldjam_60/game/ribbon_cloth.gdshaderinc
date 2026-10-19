// Shared displacement field for the cloth texture and its printed lettering.
vec2 ribbon_cloth_uv(vec2 uv, float cloth_time, float motion_amount) {
    float pin_x = sin(uv.x * 3.14159265);
    float envelope = pin_x * sin(uv.y * 3.14159265);
    float phase = uv.x * 8.1681409 - cloth_time * 2.4;
    float ripple = sin(phase) * 0.04 + sin(uv.x * 17.592919 - cloth_time * 3.5) * 0.012;
    return uv + vec2(0.0, ripple * envelope * motion_amount);
}

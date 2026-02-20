shader_type canvas_item;

uniform vec2 light_pos = vec2(0.5, 0.5); // in coordinate schermo [0..1]
uniform float radius = 0.25;              // raggio del cerchio
uniform float softness = 0.05;            // bordo sfumato

void fragment() {
    // coordinate normalizzate sullo schermo
    vec2 uv = SCREEN_UV;

    float dist = distance(uv, light_pos);

    // alpha 0 vicino alla luce, 1 nel buio
    float a = smoothstep(radius, radius - softness, dist);

    COLOR = vec4(0.0, 0.0, 0.0, a);
}

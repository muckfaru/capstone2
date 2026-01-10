shader_type canvas_item;

uniform vec4 shield_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float hex_scale : hint_range(5.0, 50.0) = 20.0;
uniform float energy_flow_speed : hint_range(0.0, 5.0) = 1.5;

vec2 hex_to_cell(vec2 p) {
    vec2 h = vec2(sqrt(3.0), 1.5);
    vec2 a = mod(p, h) - h * 0.5;
    vec2 b = mod(p - h * 0.5, h) - h * 0.5;
    return length(a) < length(b) ? a : b;
}

float hex_pattern(vec2 uv, float scale) {
    vec2 grid = uv * scale;
    vec2 cell = hex_to_cell(grid);
    return length(cell);
}

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(TEXTURE, uv);

    // Hexagonal grid
    float hex = hex_pattern(uv, hex_scale);
    hex = smoothstep(0.1, 0.15, hex);

    // Animated pulse through hexagons
    float pulse = sin(TIME * pulse_speed + uv.x * 3.0 + uv.y * 3.0) * 0.5 + 0.5;

    // Energy flow
    float flow = fract(hex * 2.0 - TIME * energy_flow_speed);
    flow = smoothstep(0.0, 0.3, flow) * smoothstep(1.0, 0.7, flow);

    // Combine effects
    vec4 shield = shield_color * (hex * 0.3 + pulse * 0.4 + flow * 0.5);
    shield *= tex.a; // Only show on visible parts

    COLOR = tex + shield * 0.6;
    COLOR.a = tex.a;
}
shader_type canvas_item;

uniform vec4 holo_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float scan_speed : hint_range(0.0, 10.0) = 3.0;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float depth_layers : hint_range(1.0, 5.0) = 3.0;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;

    // Glitch displacement
    float glitch_line = floor(uv.y * 100.0);
    float glitch_trigger = step(0.98, random(vec2(glitch_line, floor(TIME * 10.0))));
    float displacement = (random(vec2(glitch_line, TIME)) - 0.5) * glitch_intensity * 0.1;
    uv.x += displacement * glitch_trigger;

    // Multi-layer depth effect
    vec4 color = vec4(0.0);
    for (float i = 0.0; i < depth_layers; i += 1.0) {
        float layer_offset = i * 0.002;
        vec2 layer_uv = uv + vec2(sin(TIME + i) * layer_offset, 0.0);
        vec4 layer = texture(TEXTURE, layer_uv);

        // Color shift per layer
        float hue_shift = i / depth_layers;
        vec4 layer_color = mix(layer, holo_color, hue_shift * 0.3);

        color += layer_color * (1.0 - i / depth_layers);
    }
    color /= depth_layers;

    // Horizontal scan line
    float scan = fract(uv.y * 5.0 - TIME * scan_speed);
    float scan_glow = smoothstep(0.0, 0.1, scan) * smoothstep(1.0, 0.9, scan);
    color.rgb += holo_color.rgb * scan_glow * 0.3;

    // RGB split
    float split = 0.005 * glitch_trigger;
    float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
    float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
    color.r = mix(color.r, r, 0.5);
    color.b = mix(color.b, b, 0.5);

    // Flickering
    float flicker = sin(TIME * 30.0 + random(vec2(TIME, 0.0)) * 10.0) * 0.1 + 0.9;
    color.rgb *= flicker;

    // Edge detection glow
    vec2 pixel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
    float edge = 0.0;
    edge += texture(TEXTURE, uv + vec2(pixel_size.x, 0.0)).a;
    edge += texture(TEXTURE, uv - vec2(pixel_size.x, 0.0)).a;
    edge += texture(TEXTURE, uv + vec2(0.0, pixel_size.y)).a;
    edge += texture(TEXTURE, uv - vec2(0.0, pixel_size.y)).a;
    edge = abs(edge - 4.0 * texture(TEXTURE, uv).a);
    color.rgb += holo_color.rgb * edge * 2.0;

    COLOR = color;
}

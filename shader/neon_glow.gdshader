shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(1.0, 0.2, 0.5, 1.0);
uniform float glow_size : hint_range(0.0, 0.1) = 0.03;
uniform float bloom_intensity : hint_range(0.0, 5.0) = 3.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 10.0;
uniform float flicker_amount : hint_range(0.0, 0.3) = 0.15;

float random(float t) {
    return fract(sin(t * 12.9898) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(TEXTURE, uv);

    // Multi-sample bloom
    vec4 bloom = vec4(0.0);
    int samples = 16;
    float sample_step = 6.28318 / float(samples);

    for (int i = 0; i < samples; i++) {
        float angle = float(i) * sample_step;
        for (float dist = glow_size * 0.3; dist <= glow_size; dist += glow_size * 0.2) {
            vec2 offset = vec2(cos(angle), sin(angle)) * dist;
            bloom += texture(TEXTURE, uv + offset);
        }
    }
    bloom /= float(samples * 4);

    // Apply neon color to bloom
    bloom.rgb = neon_color.rgb * bloom.a * bloom_intensity;

    // Flickering effect
    float flicker = 1.0 - random(floor(TIME * flicker_speed)) * flicker_amount;

    // Pulse
    float pulse = sin(TIME * 3.0) * 0.1 + 0.9;

    // Combine
    vec4 color = tex + bloom * flicker * pulse;

    // Core glow
    color.rgb += neon_color.rgb * tex.a * 0.5;

    COLOR = color;
}
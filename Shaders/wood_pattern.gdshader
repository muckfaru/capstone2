shader_type spatial;

uniform vec3 wood_color_dark : source_color = vec3(0.3, 0.2, 0.1);
uniform vec3 wood_color_light : source_color = vec3(0.6, 0.4, 0.2);
uniform float grain_scale : hint_range(0.1, 10.0) = 2.0;
uniform float ring_scale : hint_range(0.1, 10.0) = 5.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

// Simple noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    // Get UV coordinates
    vec2 uv = UV * grain_scale;

    // Create wood rings
    float dist = length(uv);
    float rings = sin(dist * ring_scale + noise(uv * 2.0) * 2.0) * 0.5 + 0.5;

    // Add grain texture
    float grain = noise(uv * 10.0) * 0.3;

    // Mix colors
    vec3 wood_color = mix(wood_color_dark, wood_color_light, rings + grain);

    ALBEDO = wood_color;
    ROUGHNESS = roughness;
    METALLIC = 0.0;
}
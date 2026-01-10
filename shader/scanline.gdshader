shader_type canvas_item;

uniform float scanline_count : hint_range(100.0, 500.0) = 300.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scan_speed : hint_range(0.0, 5.0) = 2.0;
uniform float distortion_amount : hint_range(0.0, 0.1) = 0.015;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.003;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.05;
uniform vec4 tint_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;

    // CRT barrel distortion
    vec2 center = uv - 0.5;
    float dist_from_center = length(center);
    vec2 distortion = center * dist_from_center * distortion_amount;
    uv += distortion;

    // Vertical wave distortion
    uv.x += sin(uv.y * 30.0 + TIME * 3.0) * 0.003;

    // Chromatic aberration (RGB split)
    float r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
    float a = texture(TEXTURE, uv).a;
    vec4 color = vec4(r, g, b, a);

    // Horizontal scanlines
    float scanline = sin((uv.y + TIME * scan_speed * 0.1) * scanline_count);
    scanline = pow(abs(scanline), 2.0);
    color.rgb *= 1.0 - scanline * scanline_intensity;

    // Vertical scanlines (thinner)
    float vertical_scan = sin(uv.x * scanline_count * 0.5);
    vertical_scan = pow(abs(vertical_scan), 4.0);
    color.rgb *= 1.0 - vertical_scan * scanline_intensity * 0.3;

    // Moving scan line (like old CRT refresh)
    float moving_scan = fract(TIME * 0.3);
    float scan_dist = abs(uv.y - moving_scan);
    if (scan_dist < 0.01) {
        float scan_bright = 1.0 - scan_dist / 0.01;
        color.rgb += vec3(scan_bright * 0.1);
    }

    // Screen flicker
    float flicker = random(vec2(TIME * 10.0, 0.0)) * flicker_intensity;
    color.rgb *= 1.0 - flicker;

    // Vignette effect
    float vignette = length(center) * vignette_strength;
    color.rgb *= 1.0 - vignette;

    // Subtle cyan tint (cyberpunk aesthetic)
    color.rgb = mix(color.rgb, tint_color.rgb, 0.1);

    // Noise grain
    float grain = random(uv + TIME * 0.5) * 0.05;
    color.rgb += grain;

    COLOR = color;
}

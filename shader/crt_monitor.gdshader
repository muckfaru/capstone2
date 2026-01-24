shader_type canvas_item;

// CRT Monitor Effect - Gives cyberpunk terminal aesthetic
uniform float scanline_count = 180.0;
uniform float curvature = 0.05;
uniform float vignette_strength = 0.3;
uniform float scanline_alpha = 0.1;
uniform vec3 phosphor_tint : source_color = vec3(0.0, 1.0, 0.3);
uniform float flicker_speed = 0.1;

float random(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Screen curvature (like old CRT monitors)
    uv = uv * 2.0 - 1.0;
    vec2 offset = uv.yx / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    uv = (uv + 1.0) * 0.5;

    // Check if UV is out of bounds
    if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
        // Get base texture
        vec4 tex = texture(TEXTURE, uv);

        // Scanlines
        float scanline = sin(uv.y * scanline_count) * scanline_alpha;

        // Vignette effect
        vec2 vign_uv = uv * 2.0 - 1.0;
        float vignette = 1.0 - (pow(abs(vign_uv.x), 2.0) + pow(abs(vign_uv.y), 2.0)) * vignette_strength;
        vignette = clamp(vignette, 0.0, 1.0);

        // Subtle flicker
        float flicker = 1.0 - (random(vec2(TIME * flicker_speed, 0.0)) * 0.02);

        // Phosphor glow (green tint)
        vec3 phosphor = tex.rgb * phosphor_tint * 1.1;

        // Combine effects
        COLOR.rgb = mix(tex.rgb, phosphor, 0.2); // Subtle green tint
        COLOR.rgb *= (1.0 - scanline) * vignette * flicker;
        COLOR.a = tex.a;
    } else {
        // Out of bounds - black
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
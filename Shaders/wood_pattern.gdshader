shader_type spatial;

// === Color uniforms ===
uniform vec3 wood_color_dark   : source_color = vec3(0.25, 0.15, 0.07);
uniform vec3 wood_color_mid    : source_color = vec3(0.50, 0.30, 0.13);
uniform vec3 wood_color_light  : source_color = vec3(0.75, 0.52, 0.28);

// === Structure uniforms ===
uniform float grain_scale      : hint_range(0.1, 20.0) = 3.0;
uniform float ring_frequency   : hint_range(1.0, 30.0) = 12.0;
uniform float ring_distortion  : hint_range(0.0, 5.0)  = 2.5;
uniform float grain_angle      : hint_range(0.0, 6.28) = 0.0; // radians
uniform float grain_stretch    : hint_range(0.5, 8.0)  = 4.0; // elongate along grain
uniform float plank_width      : hint_range(0.05, 1.0) = 0.3;
uniform float plank_softness   : hint_range(0.001, 0.05) = 0.01;

// === Knot uniforms ===
uniform float knot_count       : hint_range(0.0, 5.0)  = 2.0;
uniform float knot_size        : hint_range(0.01, 0.3) = 0.08;
uniform float knot_strength    : hint_range(0.0, 1.0)  = 0.7;

// === Surface uniforms ===
uniform float roughness_base   : hint_range(0.0, 1.0)  = 0.75;
uniform float roughness_vary   : hint_range(0.0, 0.5)  = 0.2;
uniform float normal_strength  : hint_range(0.0, 3.0)  = 1.2;
uniform float ao_strength      : hint_range(0.0, 1.0)  = 0.35;

// =====================================================
//  Noise helpers
// =====================================================
float hash1(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 17.31);
    return fract(p.x * p.y);
}

float hash1(float n) { return fract(sin(n) * 43758.5453); }

// Smooth value noise
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintic smoothstep
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = hash1(i);
    float b = hash1(i + vec2(1.0, 0.0));
    float c = hash1(i + vec2(0.0, 1.0));
    float d = hash1(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion — 6 octaves
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;
mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));    for (int i = 0; i < 6; i++) {
        v   += amp * vnoise(p * freq);
        amp  *= 0.5;
        freq *= 2.0;
        p     = rot * p;
    }
    return v;
}

// =====================================================
//  Wood ring function
// =====================================================
float wood_rings(vec2 uv) {
    // Rotate UV to align grain direction
    float s = sin(grain_angle);
    float c = cos(grain_angle);
    vec2 ruv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
    // Stretch along grain axis
    ruv.y *= grain_stretch;

    // Distance from center of "log" + fbm distortion
    float dist = length(ruv);
    float distorted = dist + ring_distortion * fbm(uv * 2.0 + 1.5);

    // Rings via sine — remap to [0,1]
    return smoothstep(-0.05, 0.05,
        sin(distorted * ring_frequency * TAU) * 0.5 + 0.5
    );
}

// =====================================================
//  Knot mask
// =====================================================
float knot_mask(vec2 uv) {
    float mask = 0.0;
    for (int i = 0; i < 5; i++) {
        if (float(i) >= knot_count) break;
        // Pseudo-random knot positions per tile
        vec2 kpos = vec2(
            hash1(float(i) * 3.7),
            hash1(float(i) * 7.3 + 1.1)
        );
        float d = length(fract(uv) - kpos);
        float k = 1.0 - smoothstep(0.0, knot_size, d);
        mask = max(mask, k);
    }
    return mask;
}

// =====================================================
//  Plank edge darkening (AO at board edges)
// =====================================================
float plank_ao(vec2 uv) {
    float tx = fract(uv.x / plank_width);
    float edge = min(tx, 1.0 - tx); // 0 at seam, 0.5 at center
    return smoothstep(0.0, plank_softness * 4.0, edge);
}

// =====================================================
//  Compute approximate surface normal from FBM
// =====================================================
vec3 wood_normal(vec2 uv, float eps) {
    float h  = fbm(uv);
    float hx = fbm(uv + vec2(eps, 0.0));
    float hy = fbm(uv + vec2(0.0, eps));
    vec3 n = normalize(vec3(h - hx, h - hy, 1.0 / normal_strength));
    return n * 0.5 + 0.5; // encode for NORMAL_MAP
}

// =====================================================
//  Fragment
// =====================================================
void fragment() {
    vec2 uv = UV * grain_scale;

    // --- Wood rings ---
    float rings = wood_rings(uv);

    // --- Fine surface grain (high-freq FBM) ---
    float fine_grain = fbm(uv * 6.0 + 3.0) * 0.4;

    // --- Knots ---
    float knots   = knot_mask(UV); // use raw UV so knots don't tile weirdly
    float knot_ao = knots * 0.5;   // knots darken locally

    // --- Plank lines ---
    float plank   = plank_ao(UV);

    // --- Combine rings + grain ---
    float wood_val = clamp(rings + fine_grain * 0.3, 0.0, 1.0);

    // --- 3-stop color ramp ---
    vec3 color;
    if (wood_val < 0.5) {
        color = mix(wood_color_dark, wood_color_mid, wood_val * 2.0);
    } else {
        color = mix(wood_color_mid, wood_color_light, (wood_val - 0.5) * 2.0);
    }

    // --- Ambient occlusion: darken ring valleys ---
    float ring_ao = 1.0 - ao_strength * (1.0 - rings) * 0.6;
    color *= ring_ao;

    // --- Apply plank edge AO ---
    color *= mix(1.0 - ao_strength * 0.5, 1.0, plank);

    // --- Apply knot darkening ---
    color = mix(color, wood_color_dark * 0.6, knots * knot_strength);

    // --- Normal map from surface grain ---
    vec3 nmap = wood_normal(uv * 2.0, 0.01);
    // Mix in knot bump (concentric, compressed normals at knot)
    vec3 knot_normal = vec3(0.5, 0.5, 1.0); // flat
    nmap = mix(nmap, knot_normal, knots * knot_strength * 0.7);

    // --- Roughness: higher in dark grain valleys, smoother on highlights ---
    float roughness = roughness_base
        + roughness_vary * (1.0 - rings)
        + 0.1 * fine_grain
        - 0.1 * knots; // knots slightly smoother/shinier

    // --- Output ---
    ALBEDO    = color;
    NORMAL_MAP = nmap;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp(roughness, 0.0, 1.0);
    METALLIC  = 0.0;
    AO        = mix(1.0, plank * (1.0 - knot_ao), ao_strength);
}
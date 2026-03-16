shader_type spatial;

// === Color uniforms ===
uniform vec3 rock_color_dark   : source_color = vec3(0.18, 0.18, 0.20);
uniform vec3 rock_color_mid    : source_color = vec3(0.35, 0.33, 0.30);
uniform vec3 rock_color_light  : source_color = vec3(0.52, 0.50, 0.46);
uniform vec3 crack_color       : source_color = vec3(0.08, 0.08, 0.09);
uniform vec3 moss_color        : source_color = vec3(0.18, 0.28, 0.10);
uniform vec3 wet_color_tint    : source_color = vec3(0.10, 0.10, 0.12);

// === Structure uniforms ===
uniform float rock_scale       : hint_range(0.1, 20.0) = 3.0;
uniform float crack_scale      : hint_range(1.0, 20.0) = 6.0;
uniform float crack_width      : hint_range(0.0, 1.0)  = 0.25;
uniform float crack_depth      : hint_range(0.0, 1.0)  = 0.6;

// === Moss uniforms ===
uniform float moss_amount      : hint_range(0.0, 1.0)  = 0.3;
uniform float moss_fuzziness   : hint_range(0.01, 0.5) = 0.15;

// === Surface uniforms ===
uniform float roughness_base   : hint_range(0.0, 1.0)  = 0.92;
uniform float roughness_vary   : hint_range(0.0, 0.5)  = 0.18;
uniform float normal_strength  : hint_range(0.0, 4.0)  = 1.8;
uniform float wetness          : hint_range(0.0, 1.0)  = 0.0;
uniform float ao_strength      : hint_range(0.0, 1.0)  = 0.5;
uniform float micro_detail     : hint_range(0.0, 1.0)  = 0.5;

// =====================================================
//  Noise helpers
// =====================================================
float hash1(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 17.31);
    return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
    return vec2(
        hash1(p),
        hash1(p + vec2(31.41, 59.26))
    );
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic
    float a = hash1(i);
    float b = hash1(i + vec2(1.0, 0.0));
    float c = hash1(i + vec2(0.0, 1.0));
    float d = hash1(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v   = 0.0;
    float amp = 0.5;
    mat2 rot  = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
    for (int i = 0; i < 6; i++) {
        v   += amp * vnoise(p);
        amp *= 0.5;
        p    = rot * p * 2.0;
    }
    return v;
}

// =====================================================
//  Voronoi — returns (min_dist, second_min_dist, cell_id)
//  Edge = F2 - F1, useful for sharp crack lines
// =====================================================
vec3 voronoi_f1f2(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);

    float f1 = 8.0, f2 = 8.0;
    float cell_id = 0.0;

    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g   = vec2(float(i), float(j));
            vec2 rnd = hash2(n + g);
            // Animate cell centers slightly with noise for organic feel
            vec2 o   = rnd + 0.5 * sin(rnd * 6.28);
            float d  = length(g + o - f);
            if (d < f1) { f2 = f1; f1 = d; cell_id = hash1(n + g); }
            else if (d < f2) { f2 = d; }
        }
    }
    return vec3(f1, f2, cell_id);
}

// =====================================================
//  Normal from height field (finite difference)
// =====================================================
vec3 height_normal(vec2 uv, float scale, float eps) {
    float h0 = fbm(uv * scale);
    float hx = fbm((uv + vec2(eps, 0.0)) * scale);
    float hy = fbm((uv + vec2(0.0, eps)) * scale);
    vec3 n   = normalize(vec3((h0 - hx) * normal_strength,
                               (h0 - hy) * normal_strength,
                               eps));
    return n * 0.5 + 0.5;
}

// =====================================================
//  Fragment
// =====================================================
void fragment() {
    vec2 uv = UV * rock_scale;

    // --- Base rock structure ---
    float rock_macro = fbm(uv * 1.0);           // large stone variation
    float rock_mid   = fbm(uv * 3.0 + 5.3);    // medium surface texture
    float rock_micro = vnoise(uv * 18.0);        // fine grit detail

    float rock_val = rock_macro * 0.55
                   + rock_mid   * 0.30
                   + rock_micro * 0.15;

    // --- Voronoi cracks (two scales for layered look) ---
    vec3 v1 = voronoi_f1f2(uv * crack_scale);
    vec3 v2 = voronoi_f1f2(uv * crack_scale * 2.3 + 3.7); // offset 2nd layer

    // F2-F1 gives the sharpest edge (crack boundary)
    float crack1 = v1.y - v1.x;
    float crack2 = v2.y - v2.x;

    // Combine: primary deep cracks + finer hairline cracks
    float cracks = min(
        smoothstep(0.0, crack_width * 0.15, crack1),
        smoothstep(0.0, crack_width * 0.08, crack2)
    );

    // --- Per-stone color variation (cell_id drives tint) ---
    float stone_tint = v1.z * 0.15 - 0.075; // small ± per cell

    // --- 3-stop color ramp ---
    vec3 base_color;
    if (rock_val < 0.5) {
        base_color = mix(rock_color_dark, rock_color_mid, rock_val * 2.0);
    } else {
        base_color = mix(rock_color_mid, rock_color_light, (rock_val - 0.5) * 2.0);
    }
    base_color += stone_tint; // per-stone nudge

    // --- Micro surface detail overlay ---
    base_color *= 0.88 + micro_detail * 0.24 * rock_micro;

    // --- Crack AO: darken into crack edges ---
    float crack_ao = mix(1.0 - ao_strength * crack_depth, 1.0, cracks);
    base_color *= crack_ao;

    // --- Apply crack color ---
    vec3 color = mix(crack_color, base_color, cracks);

    // --- Moss in crevices ---
    // Moss lives in low-height + crack-adjacent regions
    float moss_mask = (1.0 - rock_val) * (1.0 - cracks);
    moss_mask = smoothstep(1.0 - moss_amount - moss_fuzziness,
                            1.0 - moss_amount + moss_fuzziness,
                            moss_mask + fbm(uv * 4.0) * 0.3);
    // Add moss FBM for texture variation
    float moss_detail = fbm(uv * 8.0 + 2.0);
    vec3 moss_c = moss_color * (0.7 + 0.6 * moss_detail);
    color = mix(color, moss_c, moss_mask * 0.85);

    // --- Wetness ---
    // Wet areas: darker, smoother, slight tint
    float wet_mask = wetness * (0.6 + 0.4 * (1.0 - rock_val));
    color = mix(color, color * (1.0 - 0.35 * wetness) + wet_color_tint * 0.1, wet_mask);

    // --- Normal map ---
    vec3 nmap = height_normal(UV, rock_scale * 2.5, 0.004);
    // Flatten normals inside deep crack zones (cracks are geometry valleys)
    vec3 crack_norm = vec3(0.5, 0.5, 1.0);
    nmap = mix(crack_norm, nmap, cracks * 0.85 + 0.15);

    // --- Roughness ---
    float rough = roughness_base
                - roughness_vary * rock_val       // lighter areas slightly smoother
                + 0.08 * (1.0 - cracks)           // cracks rougher
                - 0.25 * moss_mask                // moss is rougher (inverted below)
                - 0.35 * wet_mask;                // wet = much smoother
    rough = clamp(rough + 0.25 * moss_mask, 0.0, 1.0);

    // --- Specular response ---
    // Wet rock gets a subtle specular; moss kills it
    float spec = mix(0.04, 0.18, wet_mask) * (1.0 - moss_mask);

    // --- Output ---
    ALBEDO        = color;
    NORMAL_MAP    = nmap;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS     = clamp(rough, 0.0, 1.0);
    METALLIC      = 0.0;
    SPECULAR      = spec;
    AO            = crack_ao * (1.0 - moss_mask * 0.2);
}
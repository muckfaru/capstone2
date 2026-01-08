shader_type canvas_item;

// Parameters we can animate
uniform float break_progress : hint_range(0.0, 1.0) = 0.0;
uniform float crack_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec2 impact_point = vec2(0.5, 0.5); // Center of break
uniform float piece_count : hint_range(4.0, 20.0) = 8.0;
uniform float explosion_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec3 edge_glow_color : source_color = vec3(0.0, 0.8, 1.0);
uniform float edge_glow_intensity : hint_range(0.0, 2.0) = 0.8;

// Advanced voronoi function for organic crack patterns
vec2 voronoi_point(vec2 grid, float seed) {
    return 0.5 + 0.5 * sin(seed + 6.2831 * grid + vec2(1.0, 5.7));
}

float voronoi(vec2 uv, float seed) {
    vec2 grid = floor(uv);
    vec2 fract_uv = fract(uv);

    float min_dist = 2.0;
    vec2 min_point = vec2(0.0);

    // Check 3x3 grid of neighbors
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = voronoi_point(grid + neighbor, seed);

            float dist = length(neighbor + point - fract_uv);
            if(dist < min_dist) {
                min_dist = dist;
                min_point = grid + neighbor + point;
            }
        }
    }

    return min_dist;
}

// Get second-closest distance for crack lines
float voronoi_cracks(vec2 uv, float seed) {
    vec2 grid = floor(uv);
    vec2 fract_uv = fract(uv);

    float min_dist1 = 10.0;
    float min_dist2 = 10.0;

    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = voronoi_point(grid + neighbor, seed);

            float dist = length(neighbor + point - fract_uv);

            if(dist < min_dist1) {
                min_dist2 = min_dist1;
                min_dist1 = dist;
            } else if(dist < min_dist2) {
                min_dist2 = dist;
            }
        }
    }

    return min_dist2 - min_dist1;
}

// Noise function for additional randomness
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Distance from impact point
    float dist_from_impact = distance(uv, impact_point);

    // Create shatter cells using voronoi
    float cells = voronoi(uv * piece_count, 1.0);
    float cell_id = noise(floor(uv * piece_count));

    // Create crack lines
    float crack_lines = voronoi_cracks(uv * piece_count * 1.5, 2.0);
    crack_lines = smoothstep(0.08, 0.0, crack_lines);

    // Calculate which pieces should disappear
    // Pieces closer to impact break first, with some randomness
    float break_threshold = dist_from_impact * 0.6 + cell_id * 0.4;
    float break_wave = break_progress * 1.8 - 0.4; // Wave moves outward

    // Smooth transition for each piece
    float piece_alpha = smoothstep(break_threshold - 0.15, break_threshold + 0.05, break_wave);
    piece_alpha = 1.0 - piece_alpha;

    // Calculate displacement for pieces flying apart
    vec2 cell_center = uv;
    float displacement_amount = 0.0;

    if(break_progress > 0.0 && piece_alpha > 0.0) {
        // Find cell center
        vec2 to_impact = uv - impact_point;
        float angle = atan(to_impact.y, to_impact.x);

        // Add spiral/rotation effect
        angle += cell_id * 6.28 * 0.3;

        // Calculate displacement
        displacement_amount = break_progress * explosion_strength * (0.5 + cell_id * 0.5);
        displacement_amount *= smoothstep(1.0, 0.3, piece_alpha); // Accelerate as it fades

        vec2 displacement = vec2(cos(angle), sin(angle)) * displacement_amount;
        cell_center = uv - displacement * 0.3;
    }

    // Sample texture with displacement
    vec4 color = texture(TEXTURE, cell_center);

    // Add crack darkening
    float crack_darkness = crack_lines * crack_intensity * smoothstep(0.0, 0.4, break_progress);
    color.rgb = mix(color.rgb, vec3(0.0), crack_darkness * 0.6);

    // Add crack glow (cyan tint)
    float crack_glow = crack_lines * smoothstep(0.1, 0.5, break_progress);
    color.rgb += edge_glow_color * crack_glow * 0.3 * crack_intensity;

    // Apply break alpha
    color.a *= piece_alpha;

    // Add edge glow to pieces that are currently breaking
    float edge_threshold = 0.1;
    if(piece_alpha > edge_threshold && piece_alpha < 1.0 - edge_threshold) {
        // Calculate edge glow based on how close to disappearing
        float edge_factor = smoothstep(0.3, 0.8, 1.0 - piece_alpha);
        color.rgb += edge_glow_color * edge_factor * edge_glow_intensity;

        // Add slight brightness increase
        color.rgb *= 1.0 + edge_factor * 0.3;
    }

    // Add subtle rotation to pieces (visual only, affects sampling)
    if(displacement_amount > 0.1) {
        float rotation = cell_id * 3.14 * break_progress * 2.0;
        vec2 rotated_uv = uv - impact_point;
        float cos_r = cos(rotation);
        float sin_r = sin(rotation);
        rotated_uv = vec2(
            rotated_uv.x * cos_r - rotated_uv.y * sin_r,
            rotated_uv.x * sin_r + rotated_uv.y * cos_r
        );
        rotated_uv += impact_point;

        // Blend between normal and rotated based on break progress
        float rotation_blend = smoothstep(0.3, 0.8, break_progress);
        vec2 final_uv = mix(cell_center, rotated_uv, rotation_blend * 0.5);

        if(piece_alpha > 0.1) {
            color = texture(TEXTURE, final_uv);
            color.a *= piece_alpha;
        }
    }

    COLOR = color;
}
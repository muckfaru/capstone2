shader_type canvas_item;

uniform vec4 base_glow_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float glow_width : hint_range(0.0, 0.1) = 0.04;
uniform float glow_intensity : hint_range(0.0, 3.0) = 2.0;
uniform bool rainbow_mode = true;
uniform float particle_speed : hint_range(0.0, 5.0) = 2.0;
uniform int particle_count : hint_range(5, 50) = 20;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec3 hsv_to_rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(TEXTURE, uv);
    
    // Multi-layered pulse with different frequencies
    float pulse1 = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float pulse2 = sin(TIME * pulse_speed * 1.5 + 1.0) * 0.5 + 0.5;
    float pulse3 = sin(TIME * pulse_speed * 0.7 + 2.0) * 0.5 + 0.5;
    float combined_pulse = (pulse1 + pulse2 * 0.5 + pulse3 * 0.3) / 1.8;
    combined_pulse = pow(combined_pulse, 1.5);
    
    // Distance from all edges
    float dist_left = uv.x;
    float dist_right = 1.0 - uv.x;
    float dist_top = uv.y;
    float dist_bottom = 1.0 - uv.y;
    float dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
    
    vec4 glow_color = base_glow_color;
    
    // Rainbow color shift for edges
    if (rainbow_mode) {
        float hue = fract(TIME * 0.1 + uv.x * 0.5 + uv.y * 0.5);
        glow_color.rgb = hsv_to_rgb(vec3(hue, 0.8, 1.0));
    }
    
    // Multi-layer glow effect
    vec4 final_glow = vec4(0.0);
    
    if (dist < glow_width) {
        float edge_factor = 1.0 - (dist / glow_width);
        edge_factor = pow(edge_factor, 1.5);
        
        // Inner bright glow
        float inner_glow = pow(edge_factor, 3.0);
        final_glow += glow_color * inner_glow * combined_pulse * glow_intensity;
        
        // Outer soft glow
        float outer_glow = edge_factor * 0.5;
        final_glow += glow_color * outer_glow * glow_intensity * 0.6;
        
        // Particle trail effect along edges
        float perimeter = 0.0;
        if (dist == dist_left) perimeter = uv.y;
        else if (dist == dist_right) perimeter = 1.0 + (1.0 - uv.y);
        else if (dist == dist_top) perimeter = 2.0 + uv.x;
        else if (dist == dist_bottom) perimeter = 3.0 + (1.0 - uv.x);
        
        // Animated particles
        for (int i = 0; i < particle_count; i++) {
            float particle_offset = float(i) / float(particle_count);
            float particle_pos = fract(perimeter - TIME * particle_speed * 0.1 + particle_offset);
            float dist_to_particle = abs(perimeter - particle_pos);
            
            if (dist_to_particle < 0.05) {
                float particle_glow = (1.0 - dist_to_particle / 0.05) * edge_factor;
                particle_glow = pow(particle_glow, 2.0);
                final_glow += vec4(1.0, 1.0, 1.0, 1.0) * particle_glow * 0.5;
            }
        }
    }
    
    // Corner accent lights
    vec2 corner_dist = min(vec2(uv.x, uv.y), vec2(1.0 - uv.x, 1.0 - uv.y));
    float corner_glow = length(corner_dist);
    if (corner_glow < 0.1) {
        float corner_factor = 1.0 - corner_glow / 0.1;
        corner_factor = pow(corner_factor, 3.0);
        final_glow += glow_color * corner_factor * combined_pulse * 0.3;
    }
    
    COLOR = tex + final_glow;
    COLOR.a = tex.a;
}
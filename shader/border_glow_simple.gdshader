shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.5;
uniform bool rainbow_mode = true;
uniform float particle_speed : hint_range(0.0, 5.0) = 2.0;

vec3 hsv_to_rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV;
    
    // Multi-layered pulse
    float pulse1 = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float pulse2 = sin(TIME * pulse_speed * 1.5 + 1.0) * 0.5 + 0.5;
    float combined_pulse = (pulse1 * 0.7 + pulse2 * 0.3);
    combined_pulse = pow(combined_pulse, 1.2);
    
    vec4 final_color = glow_color;
    
    // Rainbow mode - cycle through colors
    if (rainbow_mode) {
        float hue = fract(TIME * 0.15 + uv.x * 0.3 + uv.y * 0.3);
        final_color.rgb = hsv_to_rgb(vec3(hue, 0.9, 1.0));
    }
    
    // Animated particle/wave effect along the border
    float wave = sin(uv.x * 10.0 + TIME * particle_speed) * 0.5 + 0.5;
    wave += sin(uv.y * 10.0 + TIME * particle_speed * 1.3) * 0.5 + 0.5;
    wave *= 0.3;
    
    // Apply pulse and wave
    float brightness = (combined_pulse + wave) * glow_intensity;
    final_color.rgb *= brightness;
    
    // Keep full opacity
    final_color.a = 1.0;
    
    COLOR = final_color;
}

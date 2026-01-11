shader_type canvas_item;

// Shader to make both white AND black pixels transparent
// Works with images that have solid color backgrounds

uniform float white_threshold : hint_range(0.5, 1.0) = 0.75;
uniform float black_threshold : hint_range(0.0, 0.3) = 0.15;
uniform float smoothness : hint_range(0.0, 0.3) = 0.1;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // Calculate brightness (average of RGB)
    float brightness = (tex.r + tex.g + tex.b) / 3.0;
    
    // Check color variance (how "gray" the pixel is)
    float color_variance = max(max(abs(tex.r - tex.g), abs(tex.g - tex.b)), abs(tex.r - tex.b));
    
    // Detect white-ish pixels (bright and low variance)
    float is_white = step(white_threshold, brightness) * step(color_variance, 0.2);
    float white_fade = smoothstep(white_threshold - smoothness, white_threshold + smoothness, brightness) * is_white;
    
    // Detect black-ish pixels (dark and low variance)
    float is_black = step(brightness, black_threshold) * step(color_variance, 0.15);
    float black_fade = smoothstep(black_threshold + smoothness, black_threshold - smoothness, brightness) * is_black;
    
    // Combine - make both white and black transparent
    float alpha_mult = 1.0 - max(white_fade, black_fade);
    
    tex.a *= alpha_mult;
    COLOR = tex;
}

shader_type canvas_item;

// Matrix-style falling code background
uniform float rain_speed = 1.0;
uniform vec3 rain_color : source_color = vec3(0.0, 1.0, 0.3);
uniform float column_count = 40.0;
uniform float char_height = 30.0;
uniform float brightness_variation = 0.5;

float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Create columns
    uv.x *= column_count;
    float col = floor(uv.x);

    // Vertical movement
    float offset = TIME * rain_speed;
    float cell_y = floor((uv.y * char_height) - offset);

    // Random character generation
    float char_rand = random(vec2(col, cell_y));

    // Only show some characters (sparse effect)
    float show = step(0.85, char_rand);

    // Fade based on position in column
    float fade_y = fract((uv.y * char_height) - offset);
    float alpha = smoothstep(1.0, 0.0, fade_y) * show;

    // Brightness variation per column
    float brightness = random(vec2(col, 0.0)) * brightness_variation + (1.0 - brightness_variation);

    // Leading bright character
    float lead = step(0.95, fade_y) * 2.0;

    vec3 color = rain_color * (brightness + lead);

    COLOR = vec4(color, alpha * 0.5);
}
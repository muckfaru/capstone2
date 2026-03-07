shader_type canvas_item;

uniform vec4 grid_color : source_color = vec4(0.0, 0.8, 1.0, 0.08);
uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform float grid_size : hint_range(10.0, 200.0) = 60.0;
uniform float line_width : hint_range(0.5, 3.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.5;
uniform float scan_speed : hint_range(0.0, 5.0) = 0.3;

void fragment() {
	vec2 uv = UV;
	vec2 pixel = uv * vec2(1280.0, 2400.0);

	// Base background
	vec4 color = bg_color;

	// Grid lines
	vec2 grid = mod(pixel, grid_size);
	float grid_line = step(grid.x, line_width) + step(grid.y, line_width);
	grid_line = clamp(grid_line, 0.0, 1.0);

	// Pulse effect on grid
	float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;
	color = mix(color, grid_color, grid_line * pulse);

	// Horizontal scan line
	float scan_y = mod(TIME * scan_speed * 500.0, 2400.0);
	float scan_dist = abs(pixel.y - scan_y);
	float scan = smoothstep(80.0, 0.0, scan_dist) * 0.15;
	color.rgb += vec3(0.0, scan * 0.8, scan);

	// Slight vignette
	float vignette = 1.0 - length(uv - 0.5) * 0.4;
	color.rgb *= vignette;

	COLOR = color;
}

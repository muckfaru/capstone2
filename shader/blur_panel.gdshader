shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 1.5;
uniform vec4 tint_color : source_color = vec4(0.0, 0.05, 0.18, 0.5);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.05;

// SDF for a rounded rectangle
// uv: 0..1 coords, r: corner radius in UV space
float rounded_rect(vec2 uv, float r) {
	vec2 d = abs(uv - 0.5) - (0.5 - r);
	return length(max(d, 0.0)) - r;
}

void fragment() {
	// Rounded corner mask — discard pixels outside the rounded shape
	float dist = rounded_rect(UV, corner_radius);
	if (dist > 0.0) {
		discard;
	}

	// Soft anti-aliased edge
	float alpha = 1.0 - smoothstep(-0.005, 0.0, dist);

	// Sample the screen behind this rect with mipmap blur
	vec3 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount).rgb;

	// Blend in the tint so UI text stays readable
	vec3 result = mix(blurred, tint_color.rgb, tint_color.a);

	COLOR = vec4(result, alpha);
}
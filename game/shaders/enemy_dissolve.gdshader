shader_type canvas_item;
render_mode unshaded;

uniform float dissolve_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_width : hint_range(0.01, 0.25, 0.01) = 0.09;
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.08, 0.95);
uniform float noise_density : hint_range(0.01, 0.2, 0.005) = 0.065;

varying vec2 dissolve_position;


float random_value(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);

	float bottom_left = random_value(cell);
	float bottom_right = random_value(cell + vec2(1.0, 0.0));
	float top_left = random_value(cell + vec2(0.0, 1.0));
	float top_right = random_value(cell + vec2(1.0, 1.0));
	return mix(
		mix(bottom_left, bottom_right, fraction.x),
		mix(top_left, top_right, fraction.x),
		fraction.y
	);
}


void vertex() {
	dissolve_position = VERTEX;
}


void fragment() {
	vec4 texel = texture(TEXTURE, UV) * COLOR;
	float coarse_noise = value_noise(dissolve_position * noise_density);
	float fine_noise = value_noise(
		dissolve_position * noise_density * 2.13 + vec2(19.7, 7.3)
	);
	float noise_value = mix(coarse_noise, fine_noise, 0.28);
	float threshold = mix(
		-edge_width,
		1.0 + edge_width,
		dissolve_amount
	);
	float visibility = smoothstep(
		threshold - 0.018,
		threshold + 0.018,
		noise_value
	);
	float glowing_edge = visibility * (
		1.0 - smoothstep(
			threshold + edge_width * 0.25,
			threshold + edge_width,
			noise_value
		)
	);

	texel.rgb = mix(
		texel.rgb,
		edge_color.rgb,
		glowing_edge * edge_color.a
	);
	texel.a *= visibility;
	COLOR = texel;
}

shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.33, 0.85, 1.0, 1.0);
uniform float outline_width : hint_range(1.0, 32.0, 1.0) = 9.0;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;

void fragment() {
	vec4 sampled_color = texture(TEXTURE, UV);
	if (sampled_color.a <= alpha_threshold) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(offset.x, 0.0)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(0.0, offset.y)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(0.0, -offset.y)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(offset.x, offset.y)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a
		);
		neighbor_alpha = max(
			neighbor_alpha,
			texture(TEXTURE, UV + vec2(-offset.x, -offset.y)).a
		);

		if (neighbor_alpha > alpha_threshold) {
			COLOR = vec4(
				outline_color.rgb,
				outline_color.a * neighbor_alpha
			);
		}
	}
}

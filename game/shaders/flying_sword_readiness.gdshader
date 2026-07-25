shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform float outline_width : hint_range(1.0, 32.0, 1.0) = 22.0;
uniform vec4 glow_color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform float glow_width : hint_range(16.0, 128.0, 1.0) = 68.0;
uniform float glow_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float readiness_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float warning_energy : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sword_brighten : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;

float max_surrounding_alpha(
	float right_alpha,
	float left_alpha,
	float down_alpha,
	float up_alpha,
	float down_right_alpha,
	float down_left_alpha,
	float up_right_alpha,
	float up_left_alpha
) {
	return max(
		max(
			max(right_alpha, left_alpha),
			max(down_alpha, up_alpha)
		),
		max(
			max(down_right_alpha, down_left_alpha),
			max(up_right_alpha, up_left_alpha)
		)
	);
}

void fragment() {
	vec4 sampled_color = texture(TEXTURE, UV) * COLOR;
	if (sampled_color.a > alpha_threshold) {
		float brighten_amount = sword_brighten * warning_energy;
		sampled_color.rgb = mix(
			sampled_color.rgb,
			vec3(1.0),
			brighten_amount
		);
		COLOR = sampled_color;
	} else {
		vec2 outline_offset = TEXTURE_PIXEL_SIZE * outline_width;
		vec2 inner_glow_offset = TEXTURE_PIXEL_SIZE * glow_width * 0.55;
		vec2 outer_glow_offset = TEXTURE_PIXEL_SIZE * glow_width;
		float outline_alpha = max_surrounding_alpha(
			texture(TEXTURE, UV + vec2(outline_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(-outline_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(0.0, outline_offset.y)).a,
			texture(TEXTURE, UV + vec2(0.0, -outline_offset.y)).a,
			texture(TEXTURE, UV + outline_offset).a,
			texture(
				TEXTURE,
				UV + vec2(-outline_offset.x, outline_offset.y)
			).a,
			texture(
				TEXTURE,
				UV + vec2(outline_offset.x, -outline_offset.y)
			).a,
			texture(TEXTURE, UV - outline_offset).a
		);
		float inner_glow_alpha = max_surrounding_alpha(
			texture(TEXTURE, UV + vec2(inner_glow_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(-inner_glow_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(0.0, inner_glow_offset.y)).a,
			texture(TEXTURE, UV + vec2(0.0, -inner_glow_offset.y)).a,
			texture(TEXTURE, UV + inner_glow_offset).a,
			texture(
				TEXTURE,
				UV + vec2(-inner_glow_offset.x, inner_glow_offset.y)
			).a,
			texture(
				TEXTURE,
				UV + vec2(inner_glow_offset.x, -inner_glow_offset.y)
			).a,
			texture(TEXTURE, UV - inner_glow_offset).a
		);
		float outer_glow_alpha = max_surrounding_alpha(
			texture(TEXTURE, UV + vec2(outer_glow_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(-outer_glow_offset.x, 0.0)).a,
			texture(TEXTURE, UV + vec2(0.0, outer_glow_offset.y)).a,
			texture(TEXTURE, UV + vec2(0.0, -outer_glow_offset.y)).a,
			texture(TEXTURE, UV + outer_glow_offset).a,
			texture(
				TEXTURE,
				UV + vec2(-outer_glow_offset.x, outer_glow_offset.y)
			).a,
			texture(
				TEXTURE,
				UV + vec2(outer_glow_offset.x, -outer_glow_offset.y)
			).a,
			texture(TEXTURE, UV - outer_glow_offset).a
		);
		float glow_alpha = max(inner_glow_alpha, outer_glow_alpha);
		glow_alpha *= glow_strength * warning_energy;
		float edge_alpha = outline_alpha * readiness_strength;
		float final_alpha = max(glow_alpha, edge_alpha);
		if (final_alpha <= 0.0) {
			discard;
		}
		vec3 final_color = mix(
			glow_color.rgb,
			outline_color.rgb,
			clamp(edge_alpha / max(final_alpha, 0.001), 0.0, 1.0)
		);
		COLOR = vec4(final_color, final_alpha);
	}
}

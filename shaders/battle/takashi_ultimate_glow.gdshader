shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float glow_radius = 7.0;
uniform float glow_strength = 1.4;
uniform float core_alpha = 0.16;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 near_offset = TEXTURE_PIXEL_SIZE * glow_radius;
	vec2 mid_offset = near_offset * 2.2;
	vec2 far_offset = near_offset * 3.8;

	float near_ring = (
		texture(TEXTURE, UV + vec2(near_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(-near_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(0.0, near_offset.y)).a +
		texture(TEXTURE, UV + vec2(0.0, -near_offset.y)).a +
		texture(TEXTURE, UV + near_offset).a +
		texture(TEXTURE, UV + vec2(-near_offset.x, near_offset.y)).a +
		texture(TEXTURE, UV + vec2(near_offset.x, -near_offset.y)).a +
		texture(TEXTURE, UV - near_offset).a
	) / 8.0;
	float mid_ring = (
		texture(TEXTURE, UV + vec2(mid_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(-mid_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(0.0, mid_offset.y)).a +
		texture(TEXTURE, UV + vec2(0.0, -mid_offset.y)).a +
		texture(TEXTURE, UV + mid_offset).a +
		texture(TEXTURE, UV + vec2(-mid_offset.x, mid_offset.y)).a +
		texture(TEXTURE, UV + vec2(mid_offset.x, -mid_offset.y)).a +
		texture(TEXTURE, UV - mid_offset).a
	) / 8.0;
	float far_ring = (
		texture(TEXTURE, UV + vec2(far_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(-far_offset.x, 0.0)).a +
		texture(TEXTURE, UV + vec2(0.0, far_offset.y)).a +
		texture(TEXTURE, UV + vec2(0.0, -far_offset.y)).a +
		texture(TEXTURE, UV + far_offset).a +
		texture(TEXTURE, UV + vec2(-far_offset.x, far_offset.y)).a +
		texture(TEXTURE, UV + vec2(far_offset.x, -far_offset.y)).a +
		texture(TEXTURE, UV - far_offset).a
	) / 8.0;
	float outer = (near_ring * 0.5) + (mid_ring * 0.32) + (far_ring * 0.18);

	float raw_aura = (outer * glow_strength) + (source.a * core_alpha);
	float aura = 1.0 - exp(-raw_aura * 1.6);
	COLOR = vec4(glow_color.rgb, aura * glow_color.a);
}

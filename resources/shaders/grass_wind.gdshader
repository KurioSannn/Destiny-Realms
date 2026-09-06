shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

// Stylized Zelda/Genshin grass shader:
// - Uses COLOR.r (baked vertex height gradient: 0.0 at root, 1.0 at tip)
//   to pin roots firmly in place while tips sway with wind.
// - Blends base_color (root) to tip_color (tip) so grass has rich lush depth
//   instead of being pitch-black or bleached pale.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.30, 0.48, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.58, 0.82, 0.28, 1.0);

uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.6;
uniform vec2 wind_direction = vec2(1.0, 0.3);

void vertex() {
	// COLOR.r is 0 at the root and 1 at the tip
	float wind_factor = COLOR.r;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(world_pos.xz, normalize(wind_direction)) * 0.5;
	float sway = sin(TIME * wind_speed + phase) * wind_strength * wind_factor;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	// Stylized upward-biased normal so grass blades catch sunlight evenly
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	// Lush vertical gradient: deeper ground green at root, bright sunny green at tip
	vec3 blade_color = mix(base_color.rgb, tip_color.rgb, COLOR.r);
	ALBEDO = tex_color.rgb * blade_color * albedo_color.rgb;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = tex_color.a * albedo_color.a;
	// Translucent backlight so sun creates bright foliage glow instead of dark silhouettes
	BACKLIGHT = vec3(0.2, 0.32, 0.12);
	ROUGHNESS = 0.85;
}

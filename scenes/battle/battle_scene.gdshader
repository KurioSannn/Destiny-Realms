shader_type canvas_item;

uniform sampler2D profile_mask;

void fragment() {
    vec4 fade = texture(TEXTURE, UV);
    vec4 mask = texture(profile_mask, UV);

    COLOR = vec4(fade.rgb, fade.a * mask.a);
}
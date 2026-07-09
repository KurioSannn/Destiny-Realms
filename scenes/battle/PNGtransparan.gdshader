shader_type canvas_item;

uniform float fade_start : hint_range(0.0, 1.0) = 0.65;
uniform float fade_end : hint_range(0.0, 1.0) = 0.95;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float fade = 1.0 - smoothstep(fade_start, fade_end, UV.y);

    COLOR = vec4(tex.rgb, tex.a * fade);
}
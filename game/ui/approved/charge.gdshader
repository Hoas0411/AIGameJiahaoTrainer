shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tone = UV.y >= 1.0 - progress ? vec3(1.0) : vec3(0.45,0.49,0.51);
	COLOR = vec4(tone, tex.a);
}

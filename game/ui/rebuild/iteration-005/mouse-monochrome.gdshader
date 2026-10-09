shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.025, 0.025, 0.03, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.92, 0.87, 1.0);
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 poster = mix(ink.rgb, paper.rgb, smoothstep(0.31, 0.62, l));
    COLOR = vec4(poster, c.a);
}

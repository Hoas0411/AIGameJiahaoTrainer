shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec4 tint : source_color = vec4(1.0,0.52,0.16,1.0);
uniform float opacity = 0.18;
void fragment() {
    float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))), 4.0);
    ALBEDO=tint.rgb;
    EMISSION=tint.rgb*1.5;
    ALPHA=rim*opacity;
}

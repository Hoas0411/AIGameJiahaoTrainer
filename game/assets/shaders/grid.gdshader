shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.25,0.32,0.35,1.0);
uniform vec4 line_color : source_color = vec4(0.4,0.5,0.52,1.0);
uniform float grid_size = 2.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 coordinate = world.xz / grid_size;
    vec2 width = max(fwidth(coordinate), vec2(0.0001));
    vec2 distance_to_line = abs(fract(coordinate - 0.5) - 0.5) / width;
    float line = 1.0 - min(min(distance_to_line.x, distance_to_line.y), 1.0);
    ALBEDO = mix(base_color.rgb, line_color.rgb, line * 0.42);
    ROUGHNESS = 0.82;
}

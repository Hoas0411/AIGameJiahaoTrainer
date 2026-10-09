shader_type spatial;
uniform sampler2D grid_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_m = 4.0;
uniform bool object_grid = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 if(object_grid) { world_position = VERTEX; world_normal = NORMAL; }
}
void fragment() {
 vec3 n = abs(normalize(world_normal));
 vec2 uv = world_position.xz;
 if(n.x > n.y && n.x > n.z) uv = world_position.zy;
 else if(n.z > n.y) uv = world_position.xy;
 ALBEDO = texture(grid_texture, uv/tile_m).rgb * tint.rgb;
 ROUGHNESS = 0.9;
}

shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.29,0.31,0.32,1.0);
uniform float square_size = 0.5;
varying vec3 world_position;
void vertex(){ world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
    vec3 p = floor((world_position+vec3(0.002))/square_size);
    float check = mod(p.x+p.y+p.z,2.0);
    ALBEDO = base_color.rgb * mix(0.9,1.1,check);
    ROUGHNESS = 0.9;
}

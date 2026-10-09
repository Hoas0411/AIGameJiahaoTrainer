shader_type spatial;
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 b=texture(base_tex,UV).rgb;
 float lane=1.0-smoothstep(0.033,0.043,abs(abs(world_pos.x)-3.4));
 // Reduce baked white sparkle while retaining the original manufactured panel texture.
 vec3 steel=mix(vec3(0.065,0.078,0.09),b,0.035);
 ALBEDO=mix(steel,vec3(.82),lane);
 ROUGHNESS=mix(.43,.55,lane);METALLIC=mix(.24,.0,lane);
 NORMAL_MAP=texture(normal_tex,UV).rgb;NORMAL_MAP_DEPTH=.008;
}



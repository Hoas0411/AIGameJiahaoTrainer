shader_type spatial;
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec4 b=texture(base_tex,UV);vec4 orm=texture(orm_tex,UV);float lane=1.0-smoothstep(0.033,0.043,abs(abs(world_pos.x)-3.4));ALBEDO=mix(b.rgb,vec3(0.88),lane);ROUGHNESS=mix(clamp(orm.g*0.8,0.4,0.58),0.48,lane);METALLIC=orm.b*0.12;NORMAL_MAP=texture(normal_tex,UV).rgb;NORMAL_MAP_DEPTH=0.08;}

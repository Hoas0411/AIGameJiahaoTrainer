shader_type canvas_item;
uniform bool head_hit = false;
float line_segment(vec2 p, vec2 a, vec2 b) {
    vec2 v=b-a;
    float t=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
    return 1.0-smoothstep(.62,1.12,length(p-a-v*t));
}
void fragment() {
    vec2 p=abs((UV-vec2(.5))*44.0);
    float mark=line_segment(p,vec2(6.0,6.0),vec2(15.0,15.0));
    if(head_hit) {
        mark=max(mark,line_segment(p,vec2(6.0,10.0),vec2(12.0,16.0)));
    }
    COLOR=vec4(vec3(.80,.49,.17),mark*COLOR.a);
}

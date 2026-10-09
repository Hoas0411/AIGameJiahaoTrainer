shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float emission_power = 0.0;
uniform float breakup = 0.3;
uniform bool fire_tint = false;
varying float particle_seed;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
    particle_seed = float(INSTANCE_ID) * 17.31;
    // Billboard sprites are VFX carriers, not replacement 3D models.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
    MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,length(MODEL_MATRIX[2].xyz),0),vec4(0,0,0,1));
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    vec2 flow=vec2(particle_seed,-particle_seed)+vec2(0.0,-TIME*0.7);
    float n=noise(UV*5.0+flow)*0.65+noise(UV*11.0+flow)*0.35;
    // Close the mask before the quad edge even at maximum breakup.
    float radial=pow(max(0.0,1.0-dot(p,p)),1.8);
    float soft=radial*mix(1.0,smoothstep(0.15,0.8,n),breakup);
    vec3 tint=COLOR.rgb;
    if (fire_tint) tint*=mix(vec3(1.0,0.22,0.035),vec3(1.0),radial);
    ALBEDO=tint;
    EMISSION=tint*emission_power;
    ALPHA=soft*COLOR.a;
}

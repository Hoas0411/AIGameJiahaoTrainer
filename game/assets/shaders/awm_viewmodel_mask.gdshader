shader_type canvas_item;
uniform vec2 aperture_center = vec2(0.5);
uniform vec2 aperture_radius = vec2(0.16,0.28);
uniform float scope_blend = 0.0;
uniform bool reticle_only = false;
float stroke(float distance_, float width_, float aa) {
    return 1.0-smoothstep(width_-aa,width_+aa,distance_);
}
void fragment() {
    vec2 p = (UV-aperture_center) / max(aperture_radius,vec2(0.001));
    float r=length(p);
    float feather=max(fwidth(r),0.002);
    float opening=1.0-smoothstep(1.0-feather,1.0+feather,r);
    if (reticle_only) {
        vec2 pixel=SCREEN_PIXEL_SIZE/max(aperture_radius,vec2(0.001));
        float px=(pixel.x+pixel.y)*.5;
        float ink=max(stroke(abs(p.x),px*.5,px*.35),stroke(abs(p.y),px*.5,px*.35))*step(r,.89);
        float tx=abs(mod(p.x+.02185,.0437)-.02185);
        float ty=abs(mod(p.y+.02185,.0437)-.02185);
        float majorx=1.0-step(.003,abs(mod(p.x+.0437,.0874)-.0437));
        float majory=1.0-step(.003,abs(mod(p.y+.0437,.0874)-.0437));
        float ht=stroke(tx,px*.5,px*.3)*stroke(abs(p.y),mix(.007,.016,majorx),px*.3)*step(.065,abs(p.x))*step(abs(p.x),.54);
        float vt=stroke(ty,px*.5,px*.3)*stroke(abs(p.x),mix(.007,.016,majory),px*.3)*step(.065,abs(p.y))*step(abs(p.y),.54);
        float hp=stroke(abs(p.y),px*3.5,px*.4)*step(.61,abs(p.x))*step(abs(p.x),.89);
        float vp=stroke(abs(p.x),px*3.5,px*.4)*step(.61,abs(p.y))*step(abs(p.y),.89);
        ink=max(ink,max(max(ht,vt),max(hp,vp)));
        for (int i=0;i<4;i++) {
            float row=.18+float(i)*.085;
            float spread=.145+float(i)*.075;
            float yline=stroke(abs(p.y-row),px*.45,px*.3);
            float dots=stroke(abs(mod(p.x+.075,.15)-.075),px*.65,px*.3);
            float grid=yline*dots*step(abs(p.x),spread);
            float endcross=max(stroke(abs(abs(p.x)-spread),px*.45,px*.3)*stroke(abs(p.y-row),px*3.0,px*.3),yline*stroke(abs(abs(p.x)-spread),px*3.0,px*.3));
            ink=max(ink,max(grid,endcross));
        }
        float vignette=(.035+.52*smoothstep(.56,1.0,r))*opening;
        COLOR=vec4(vec3(.006,.009,.011),max(ink*.96,vignette)*opening*scope_blend);
    } else {
        vec4 model=texture(TEXTURE,UV);
        model.a*=1.0-opening*scope_blend;
        COLOR=model;
    }
}

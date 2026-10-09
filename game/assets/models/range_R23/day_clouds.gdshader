shader_type sky;
void sky(){float up=max(EYEDIR.y,0.0);COLOR=mix(vec3(0.65,0.77,0.88),vec3(0.16,0.4,0.72),pow(up,0.55));if(EYEDIR.y<0.0)COLOR=vec3(0.3,0.32,0.35);}
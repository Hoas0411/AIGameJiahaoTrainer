shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 1.6;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float strands = pow(max(0.0, sin(angle * 61.0 + sin(angle * 11.0))), 20.0);
	float pulses = smoothstep(0.2, 0.8, sin(r * 26.0 - TIME * 35.0));
	float edge = smoothstep(0.20, 0.65, r);
	COLOR = vec4(0.35, 0.83, 1.0, edge * (0.10 + strands * pulses * 0.8)) * COLOR;
}

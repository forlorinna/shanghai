shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float night;
void fragment() {
	vec2 p = UV - vec2(.5,0.0);
	float envelope = smoothstep(.01,.1,p.y) * (1.0 - p.y);
	float border = abs(abs(p.x) - (.17+p.y*.23));
	float crest = exp(-border*(31.0-13.0*p.y));
	float ripples = .44 + .56*pow(abs(sin(p.y*34.0 - TIME*2.2)), 1.9);
	float body = exp(-abs(p.x)*13.0) * .24;
	ALBEDO = mix(vec3(.57,.67,.63),vec3(.27,.38,.43),night);
	ALPHA = (crest*ripples*.57+body)*envelope;
}

shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;
uniform float strength = .34;
void fragment() {
	vec2 p = (UV-.5)*2.0;
	ALBEDO = vec3(.012,.017,.019);
	ALPHA = pow(max(0.0,1.0-dot(p,p)),1.7) * strength;
}

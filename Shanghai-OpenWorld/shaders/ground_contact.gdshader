shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
global uniform float night;
void fragment() {
	float falloff = pow(max(0.0,1.0-UV.x),2.1);
	ALBEDO = vec3(.033,.037,.038);
	ALPHA = falloff * (.29 - .13*night);
}

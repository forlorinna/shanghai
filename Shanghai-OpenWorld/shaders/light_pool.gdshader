shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float night;
global uniform float wetness;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float dist = length(UV * 2.0 - 1.0);
	float light = pow(max(0.0, 1.0 - dist*dist), 2.6);
	float texture_rhythm = .75 + .25 * sin(world.x*1.9 + sin(world.z*.62) * 1.1);
	ALBEDO = COLOR.rgb;
	ALPHA = light * night * (.11 + wetness*.12) * texture_rhythm;
}

shader_type spatial;
render_mode cull_disabled;
uniform sampler2D PlaneLeaf : source_color, filter_linear_mipmap_anisotropic;
global uniform float wetness;
varying float shade;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float tip = smoothstep(0.03, 2.4, VERTEX.y + 1.0);
	VERTEX.x += sin(TIME*1.6 + p.x*.12 + p.z*.07)*tip*.16;
	VERTEX.z += sin(TIME*1.8 + p.z*.09)*tip*.095;
	shade = mix(.54,1.0,smoothstep(-1.5,1.3,VERTEX.y));
}
void fragment() {
	vec4 leaf = texture(PlaneLeaf, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ALBEDO = leaf.rgb * shade * (1.0-wetness*.10);
	ROUGHNESS = .81-wetness*.17;
	SPECULAR = .22;
	AO = .68+.31*shade;
	BACKLIGHT = leaf.rgb*.12;
}

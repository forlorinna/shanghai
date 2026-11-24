shader_type spatial;
render_mode cull_disabled;
global uniform float wetness;
global uniform float surface_detail;
uniform vec3 paint : source_color = vec3(.18,.34,.37);
uniform int finish = 0;
uniform float damage = 0.0;
varying vec3 local;
float rand_cell(vec2 p) {
	p=fract(p*vec2(.1031,.1030));
	p+=dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}
void vertex() { local = VERTEX; }
void fragment() {
	vec2 uv = UV;
	float range = -(VERTEX.z);
	float grain = rand_cell(floor(uv*vec2(610.0,420.0)));
	float close = 1.0-smoothstep(3.0,17.0,range);
	float dirt = exp(-max(local.y-.16,0.0)*4.72) * (grain*.24+.16);
	float angle = pow(1.0-max(0.0,dot(normalize(NORMAL),normalize(VIEW))),3.0);
	ALBEDO = mix(paint*(.96+grain*.15*close),vec3(.16,.13,.1),dirt*(.46+damage*.62));
	METALLIC = .62;
	ROUGHNESS = mix(.32,.17,wetness) + dirt*.26 + damage*.14;
	CLEARCOAT = .71;
	CLEARCOAT_ROUGHNESS = .22-wetness*.08;
	SPECULAR = .55;
	ALBEDO *= 1.0-angle*.15;
	float beads = 0.0;
	if (wetness > .06 && close > .02) {
		vec2 f = fract(uv*vec2(95.0,59.0))-.5;
		float pulse = rand_cell(floor(uv*vec2(95.0,59.0)));
		float lens = max(0.0, .22-length(f*vec2(1.0,.71)));
		beads = lens * step(.58,pulse) * wetness * close * surface_detail;
		NORMAL = normalize(NORMAL + vec3(f,0.0)*beads*.90);
		ROUGHNESS *= 1.0-beads*.38;
	}
	if (finish == 1) {
		ALBEDO = paint * (.72 + .28*angle) + beads*.035;
		METALLIC = .56;
		ROUGHNESS = .23 + beads*.18;
		SPECULAR = .72;
	}
}

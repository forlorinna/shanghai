shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wetness;
global uniform float surface_detail;
uniform vec3 finish : source_color = vec3(.65);
uniform int material_kind = 0;
uniform float metal = 0.0;
uniform float rough = .8;
uniform sampler2D color_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap, repeat_enable;
varying vec3 world;
varying vec3 nm;

float noise(vec2 p) {
	p=fract(p*vec2(.1031,.1030));
	p+=dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}
void vertex() {
	world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	nm=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	float dist = length(world-CAMERA_POSITION_WORLD);
	vec2 coord = abs(nm.y) > .65 ? world.xz : vec2(dot(world.xz,vec2(nm.z,-nm.x)),world.y);
	ALBEDO = finish;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = .34;
	if (material_kind <= 1) {
		vec2 tex = coord / (material_kind == 0 ? 2.0 : 1.0);
		ALBEDO *= .62 + texture(color_tex,tex).rgb*.50;
		vec3 rma = texture(rough_tex,tex).rgb;
		ROUGHNESS = mix(rough, rma.r, .35);
		AO = .72 + rma.g*.28;
		if (material_kind == 0 && abs(nm.y)<.6 && dist < 92.0) {
			vec2 grid = coord / vec2(1.65, .52);
			grid.x += floor(grid.y)*.5;
			vec2 f = fract(grid);
			float edge = min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
			ALBEDO *= .89 + noise(floor(grid))*.15;
			ALBEDO *= mix(.69,1.0,smoothstep(0.008,0.038+max(fwidth(grid.x), fwidth(grid.y))*.42,edge));
			EMISSION += finish * vec3(.91,.39,.13) * night * .14 * exp(-max(world.y,0.0)*.031);
		}
	}
	if (material_kind == 2) {
		vec2 cells = coord / vec2(1.73,3.48);
		vec2 f = fract(cells);
		float cadence = min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
		float blend = 1.0-smoothstep(170.0,620.0,dist);
		float frame = blend * (1.0-smoothstep(.018,.045+max(fwidth(cells.x), fwidth(cells.y))*.46,cadence));
		float room = noise(floor(cells));
		ALBEDO *= mix(.69,1.24,room);
		ALBEDO = mix(ALBEDO,vec3(.16,.19,.20),frame*.62);
		ROUGHNESS = mix(rough + room*.13,.55,frame);
		EMISSION = mix(vec3(.44,.24,.074),vec3(.24,.40,.51),room) * step(.87,room) * night * blend * (1.0-frame)*.73;
	}
	if (material_kind >= 3) {
		float pulse = material_kind == 4 ? (.72+.28*sin(TIME*.73 + world.y*.026)) : 1.0;
		EMISSION = finish * night * pulse * (material_kind == 5 ? 2.2 : 3.6);
		ALBEDO = mix(finish*.27,finish,night);
	}
}

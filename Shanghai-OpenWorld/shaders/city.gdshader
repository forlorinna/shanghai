shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wetness;
global uniform float surface_detail;
global uniform vec3 city_sky_tint;
uniform int surface_type = 0;
uniform sampler2D color_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_tex : filter_linear_mipmap, repeat_enable;
varying vec3 world;
varying vec3 normal_world;
varying float finish;
varying vec2 elevation_uv;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float box_mask(vec2 p, vec2 lo, vec2 hi, float e) {
	vec2 v = min(p-lo, hi-p);
	return smoothstep(-e, e, min(v.x, v.y));
}
vec3 mapped_normal(vec2 coord, vec3 n, float strength) {
	vec3 map = texture(normal_tex, coord).rgb * 2.0 - 1.0;
	vec3 du = dFdx(world);
	vec3 dv = dFdy(world);
	vec2 tu = dFdx(coord);
	vec2 tv = dFdy(coord);
	float sign_det = sign(tu.x * tv.y - tu.y * tv.x);
	vec3 tangent = du * tv.y - dv * tu.y;
	vec3 across = dv * tu.x - du * tv.x;
	tangent = normalize(tangent - n * dot(n, tangent)) * sign_det;
	across = normalize(across - n * dot(n, across)) * sign_det;
	return normalize(n + strength * (map.x * tangent + map.y * across));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	finish = UV2.x;
	elevation_uv = UV;
}

void fragment() {
	float dist = distance(CAMERA_POSITION_WORLD, world);
	vec2 coords = world.xz / 2.7;
	vec3 n = normalize(normal_world);
	bool vertical = abs(n.y) < 0.40;
	if (vertical) {
		coords = vec2(dot(world.xz, normalize(vec2(n.z, -n.x))), world.y) / 2.6;
	}
	if (surface_type == 5) { coords = world.xz / 1.4; }
	if (surface_type == 6) { coords = world.xz / 3.8; }
	float close_detail = 1.0 - smoothstep(45.0, 210.0, dist);
	vec3 tex_color = texture(color_tex, coords).rgb;
	vec3 rma = texture(material_tex, coords).rgb;
	float broad = noise(world.xz * 0.075);
	ALBEDO = COLOR.rgb * mix(vec3(0.62), tex_color * 1.28, 0.62);
	ROUGHNESS = mix(0.68, 0.98, rma.r);
	AO = mix(0.72, 1.0, rma.g);
	SPECULAR = 0.31;
	if (close_detail > 0.004 && !vertical && surface_type != 3 && surface_type != 7) {
		vec3 normal_sample = mapped_normal(coords, n, 0.28 * close_detail * surface_detail);
		NORMAL = normalize(mat3(VIEW_MATRIX) * normal_sample);
	}
	if (surface_type == 0 && vertical) {
		bool heritage = finish >= 4.5;
		bool glazing = finish < 2.0 || finish == 4.0;
		float u = elevation_uv.x;
		float floor_h = mix(3.25, 4.1, float(heritage));
		float bay = heritage ? 2.65 : (glazing ? 1.56 : 2.95);
		vec2 grid = vec2(u / bay, (world.y - 0.18) / floor_h);
		vec2 f = fract(grid);
		float antialias = min(0.115, max(fwidth(grid.x), fwidth(grid.y)) * 0.58 + 0.005);
		float activity = hash(floor(grid) + vec2(finish * 13.1, floor(elevation_uv.y)));
		vec2 low = glazing ? vec2(.055, .13) : vec2(.21, .25);
		vec2 high = glazing ? vec2(.945, .91) : vec2(.79, .81);
		if (world.y < 4.3) {
			low = vec2(.085, .03);
			high = vec2(.925, .89);
		}
		float surround = box_mask(f, low - vec2(.033, .035), high + vec2(.033, .035), antialias);
		float aperture = box_mask(f, low, high, antialias);
		if (heritage) {
			float arch = smoothstep(-antialias, antialias, .80 - f.y - pow((f.x - .5) * 1.32, 2.0) * 1.8);
			aperture *= mix(1.0, arch, step(.57, f.y));
		}
		float pane = aperture * (1.0 - 0.86 * box_mask(f, vec2(.485,.0), vec2(.515,1.0), antialias) * float(!glazing));
		float visible_grid = 1.0 - smoothstep(220.0, 620.0, dist);
		vec3 glass = mix(vec3(.044,.070,.088), vec3(.17,.22,.245), activity);
		glass *= mix(.77, 1.0, smoothstep(.02, .45, f.y));
		vec3 wall = COLOR.rgb * (0.60 + tex_color * 0.19);
		wall *= (0.81 + .19 * smoothstep(0.0, 5.0, world.y));
		wall *= 0.93 + hash(vec2(floor(u / bay * .47), floor(grid.y))) * .14;
		float masonry_joint = 1.0 - smoothstep(.0, .026 + antialias, min(f.y, 1.0 - f.y));
		wall *= 1.0 - masonry_joint * .13;
		wall *= 0.90 + 0.1 * noise(vec2(u*.037, world.y*.028));
		ALBEDO = mix(wall, mix(wall * (heritage ? .68 : .45), glass, pane), surround * visible_grid);
		float exterior = pane * visible_grid;
		ROUGHNESS = mix(heritage ? .83 : .70, .24 + activity * .17, exterior);
		METALLIC = mix(0.0, 0.53, exterior);
		SPECULAR = mix(.26, .53, exterior);
		AO *= 1.0 - surround * (1.0 - exterior) * .18;
		float inside = smoothstep(.69, .77, activity) * exterior;
		vec3 light_color = mix(vec3(.96,.54,.24), vec3(.59,.73,.88), smoothstep(.73,.98,activity));
		float blinds = smoothstep(.07, .18, fract(f.y * (6.0 + activity * 4.0)));
		EMISSION = light_color * inside * night * (0.40 + 0.34 * blinds);
		if (world.y < 5.0 && heritage) {
			EMISSION += COLOR.rgb * vec3(.57,.25,.065) * night * (1.0 - exterior)
				* smoothstep(0.68,.98,noise(vec2(u*.19, world.y*.07)));
		}
	}
	if (surface_type == 1 || surface_type == 5) {
		float seal = noise(world.xz * .23 + 41.0);
		float repair = smoothstep(.62, .66, seal * .73 + broad * .27);
		float spill = smoothstep(.55,.81,noise(world.xz * .19) * .75 + broad * .30 + (rma.b-.5)*.13);
		float puddle = spill * smoothstep(.35,.91,wetness);
		float film = wetness * (0.75 + 0.25 * seal);
		ALBEDO = mix(vec3(dot(tex_color,vec3(.2126,.7152,.0722))),tex_color,surface_type == 1 ? .42 : .78) * mix(vec3(.86), COLOR.rgb*1.36, .48) * mix(1.08, 0.71, film) * (1.0 - repair * .16);
		ROUGHNESS = mix(0.73 + 0.22*rma.r, .31 - .19*puddle, film);
		SPECULAR = mix(.28, .71, film);
		if (wetness > .32 && dist < 80.0) {
			vec2 cell = world.xz*1.45;
			vec2 f = fract(cell) - vec2(.28,.4);
			float hit = hash(floor(cell));
			float ring = sin(length(f)*36.0 - TIME*(9.0 + hit*6.0));
			NORMAL = normalize(NORMAL + vec3(f.x,f.y,.0) * ring * puddle * .14 * close_detail);
		}
	}
	if (surface_type == 6) {
		ALBEDO = tex_color * (0.51 + broad * .27);
		ROUGHNESS = .91;
	}
	if (surface_type == 7) {
		float chip = smoothstep(.27,.59, texture(material_tex, world.xz*1.85).b);
		ALBEDO = COLOR.rgb * mix(.47,.94, chip) * (1.0 - wetness*.21);
		ROUGHNESS = .70 - wetness*.25;
	}
	if (surface_type == 10) {
		vec2 cells = vec2(elevation_uv.x / 2.7, world.y / 3.55);
		float grid = box_mask(fract(cells),vec2(.19,.24),vec2(.81,.88),min(.18,max(fwidth(cells.x),fwidth(cells.y))*.38));
		float row = hash(floor(cells) + elevation_uv.y);
		ALBEDO = COLOR.rgb * mix(.38,.62,float(finish>=5.0));
		ALBEDO = mix(ALBEDO,vec3(.071,.097,.116)+row*.042,grid*.66*float(vertical));
		EMISSION = mix(vec3(.52,.23,.085),vec3(.22,.38,.52),row)*grid*night*step(.71,row)*.69*float(vertical);
		ROUGHNESS = .68;
	}
	if (surface_type == 3) {
		ALBEDO = COLOR.rgb * .38;
		EMISSION = COLOR.rgb * night * 2.1;
	}
}

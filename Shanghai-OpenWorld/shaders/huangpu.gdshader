shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wetness;
global uniform float water_detail;
global uniform vec3 city_sky_tint;
global uniform sampler2D river_reflection : filter_linear, repeat_disable;
global uniform bool river_reflect_on;
global uniform vec3 river_eye;
global uniform vec3 river_right;
global uniform vec3 river_up;
global uniform vec3 river_back;
global uniform vec2 river_projection;
varying vec3 world;
varying float bank_distance;

float hash(vec2 p) {
	p = fract(p * vec2(.1031,.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x+p.y)*p.x);
}
vec2 component(vec2 p, vec2 direction, float frequency, float speed) {
	float crest = dot(p, direction) * frequency + TIME * speed;
	return direction * cos(crest);
}
float reflection_ray(vec2 v, vec2 light, float spread, vec2 cam) {
	vec2 ray = light - cam;
	float t = dot(world.xz - cam, ray) / max(1.0, dot(ray,ray));
	float cross_axis = length((cam + ray*t) - world.xz);
	return exp(-cross_axis/(spread + t*19.0)) * smoothstep(.015,.15,t) * (1.0-smoothstep(.74,1.04,t))
		* (.28 + .72*pow(abs(v.x), 1.6));
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bank_distance = UV.x;
}
void fragment() {
	float dist = distance(world, CAMERA_POSITION_WORLD);
	float near_level = 1.0 - smoothstep(22.0, 280.0, dist);
	vec2 p = world.xz;
	vec2 waves = component(p, vec2(.91,.39), .21, 1.14) * .037;
	waves += component(p, vec2(-.31,.95), .47, 1.72) * .034;
	waves += component(p, vec2(.53,-.84), 1.38, 2.3) * (.038 + near_level*.026);
	waves += component(p, vec2(-.87,-.49), 3.84, 3.75) * near_level * .043 * water_detail;
	float shore = exp(-bank_distance / 8.5);
	waves += component(p, vec2(.80,.60), 1.81, 1.8) * shore*.035;
	if (wetness > .12 && near_level > .05) {
		vec2 field = p * 1.66;
		vec2 local = fract(field) - .5;
		float seed = hash(floor(field));
		float birth = fract(TIME * (1.8 + seed*.7) + seed);
		float radius = length(local);
		float ring = exp(-abs(radius - birth * .60) * 53.0);
		waves += normalize(local + vec2(.002)) * ring * (1.0-birth) * wetness * near_level * .115;
	}
	vec3 wave_normal = normalize(vec3(waves.x, 1.0, waves.y));
	NORMAL = normalize(mat3(VIEW_MATRIX) * wave_normal);
	float grazing = pow(1.0 - clamp(dot(normalize(CAMERA_POSITION_WORLD-world),wave_normal),0.0,1.0), 4.2);
	vec3 silt = mix(vec3(.090,.117,.092), vec3(.015,.024,.025), night);
	ALBEDO = mix(silt, silt*.62 + city_sky_tint*.18, grazing);
	SPECULAR = .61;
	METALLIC = .23 + grazing*.23;
	ROUGHNESS = .14 + wetness*.12 + (1.0-water_detail*.7)*.14;
	vec2 flicker = component(p, vec2(.19,.98), 1.48, 2.28) + waves*2.5;
	vec3 banks = vec3(.72,.30,.10) * reflection_ray(flicker,vec2(-1240,-360),22.0, CAMERA_POSITION_WORLD.xz);
	banks += vec3(.64,.25,.09) * reflection_ray(flicker,vec2(-1270,-552),24.0, CAMERA_POSITION_WORLD.xz);
	banks += vec3(.75,.12,.15) * reflection_ray(flicker,vec2(-265,-661),13.0, CAMERA_POSITION_WORLD.xz);
	banks += vec3(.14,.43,.68) * reflection_ray(flicker,vec2(291,52),20.0, CAMERA_POSITION_WORLD.xz);
	banks += vec3(.24,.45,.51) * reflection_ray(flicker,vec2(471,-81),13.0, CAMERA_POSITION_WORLD.xz);
	EMISSION = banks * night * water_detail * (.58 + .66*grazing);
	if (river_reflect_on) {
		vec3 from_mirror = world - river_eye;
		float depth = -dot(from_mirror,river_back);
		if (depth > .25) {
			vec2 image = vec2(dot(from_mirror,river_right),-dot(from_mirror,river_up)) / (depth*river_projection)*.5+.5;
			image += vec2(waves.x*.078,waves.y*.18) * (0.52+wetness*.26);
			vec2 edges = min(image,1.0-image);
			float frame = smoothstep(.0,.075,min(edges.x,edges.y));
			vec3 reflect_city = texture(river_reflection,image).rgb;
			float clarity = frame*clamp(.24+grazing*.68,.0,1.0)*water_detail;
			EMISSION += reflect_city*clarity*(.33 + night*.49);
			ALBEDO *= 1.0-clarity*.37;
			SPECULAR *= 1.0-clarity*.46;
		}
	}
	EMISSION += vec3(.018,.023,.020) * shore * (0.27 + .22 * sin(bank_distance * 3.4 - TIME * 1.8));
}

shader_type sky;
uniform sampler2D sky_hdr : filter_linear_mipmap, repeat_enable;
uniform vec3 zenith : source_color = vec3(0.21, 0.38, 0.59);
uniform vec3 horizon : source_color = vec3(0.65, 0.74, 0.79);
uniform vec3 dusk_tint : source_color = vec3(1.0, 0.62, 0.34);
uniform float sun_strength = 0.8;
uniform float coverage = 0.35;
uniform float daylight = 0.75;
uniform float phase = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(.1031, .1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
float noise(vec2 p) {
	vec2 t = fract(p);
	vec2 i = floor(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash(i), hash(i + vec2(1,0)), t.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), t.x), t.y);
}
void sky() {
	vec3 dir = EYEDIR;
	float height = max(0.0, dir.y);
	vec3 grad = mix(horizon, zenith, pow(height, 0.64));
	vec3 reflected = textureLod(sky_hdr, vec2(SKY_COORDS.x + 0.26, SKY_COORDS.y), 2.2).rgb;
	grad += clamp(reflected, vec3(0.0), vec3(2.8)) * (0.085 * daylight * smoothstep(0.02, 0.52, height));
	float s = max(0.0, dot(normalize(LIGHT0_DIRECTION), dir));
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (0.19 + height) * 2.8 + vec2(phase, -phase * 0.3);
		float structure = 0.56 * noise(uv) + 0.28 * noise(uv * 2.08) + 0.12 * noise(uv * 4.16);
		float cloud = smoothstep(0.63 - coverage * 0.50, 0.84 - coverage * 0.35, structure);
		float sun_cloud = pow(s, 8.0) * 0.18;
		vec3 clouds = mix(vec3(0.048, 0.062, 0.087), vec3(0.47, 0.53, 0.60), daylight) + sun_cloud * dusk_tint;
		grad = mix(grad, clouds, cloud * smoothstep(0.02, 0.21, height));
		grad += dusk_tint * sun_strength * (pow(s, 72.0) * .35 + pow(s, 22000.0) * 10.0) * (1.0 - 0.82 * cloud);
	}
	COLOR = grad;
}

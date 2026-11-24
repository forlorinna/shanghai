extends Node3D

const WEATHER_ZH := ["晴天", "多云", "阴天", "小雨", "暴雨", "雾天", "雷电"]
const WEATHER_EN := ["Clear", "Partly cloudy", "Overcast", "Light rain", "Downpour", "Fog", "Thunderstorm"]
var hour := 16.25
var weather := 0
var night := 0.0
var wetness := 0.0
var flash := 0.0
var thunder_timer := 9.0
var weather_timer := 0.0
var sun: DirectionalLight3D
var environment: Environment
const SKY = preload("res://shaders/shanghai_sky.gdshader")
const HDR = preload("res://assets/textures/pbr/industrial_sunset_02.exr")
var sky: ShaderMaterial
var sky_key := Vector2i(-1, -1)
var light_probe: ReflectionProbe
var probe_area := -1
var probe_cooldown := 0.0
var lamp_clock := 0.0
var lamps: Array[SpotLight3D] = []
var rain: GPUParticles3D
var update_clock := 0.0

func start() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	sun.shadow_bias = .10
	sun.shadow_normal_bias = 1.15
	sun.shadow_blur = 1.28
	add_child(sun)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	sky = ShaderMaterial.new()
	sky.shader = SKY
	sky.set_shader_parameter("sky_hdr", HDR)
	environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 4.0
	environment.tonemap_exposure = .94
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.90
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	light_probe = ReflectionProbe.new()
	light_probe.size = Vector3(82, 38, 82)
	light_probe.origin_offset = Vector3(0, -5, 0)
	light_probe.box_projection = true
	light_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	light_probe.max_distance = 115.0
	light_probe.enable_shadows = false
	light_probe.visible = false
	add_child(light_probe)
	for i in 8:
		var streetlamp := SpotLight3D.new()
		streetlamp.light_color = Color("#ffd9a6")
		streetlamp.light_energy = 4.6
		streetlamp.spot_angle = 54
		streetlamp.spot_range = 15.8
		streetlamp.spot_attenuation = 0.79
		streetlamp.shadow_enabled = false
		streetlamp.hide()
		add_child(streetlamp)
		lamps.append(streetlamp)
	rain = GPUParticles3D.new()
	rain.amount = 1900
	rain.lifetime = 0.82
	rain.visibility_aabb = AABB(Vector3(-18, -18, -18), Vector3(36, 36, 36))
	rain.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13, 1.2, 13)
	process.direction = Vector3(0.1, -1, 0.055)
	process.spread = 5
	process.initial_velocity_min = 16
	process.initial_velocity_max = 20
	process.gravity = Vector3(0, -3.2, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.33, 0.012)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.54, 0.62, 0.67, 0.38)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = material
	rain.draw_pass_1 = drop
	add_child(rain)

func tick(game, dt: float, at: Vector3) -> void:
	if game.is_playing():
		hour = fposmod(hour + dt * 0.028, 24.0)
		weather_timer += dt
		if weather_timer > 245.0 and not game.sandbox:
			weather = (weather + randi_range(1, 3)) % WEATHER_ZH.size()
			weather_timer = 0.0
	var hour_angle := (hour - 12.0) * TAU / 24.0
	var elevation := asin(clampf(cos(deg_to_rad(31.23)) * cos(hour_angle), -1.0, 1.0))
	var daylight := smoothstep(-0.12, 0.49, elevation)
	wetness = lerpf(wetness, [0.0, 0.0, 0.06, 0.43, 1.0, 0.24, 0.93][weather], 1.0 - exp(-dt * 0.63))
	night = 1.0 - smoothstep(0.03, 0.51, daylight)
	flash = maxf(0, flash - dt * 3.8)
	if weather == 6 and game.is_playing():
		thunder_timer -= dt
		if thunder_timer < 0:
			thunder_timer = randf_range(12, 27)
			flash = 1.0
			game.feedback("thunder", at)
	rain.position = game.camera.position + Vector3.UP * 9.0 if game.still_photo else at + Vector3.UP * 8
	rain.emitting = wetness > 0.30 and not game.in_tunnel and not game.on_ferry
	rain.amount_ratio = (0.17 + wetness * 0.71) * (0.38 + game.quality * 0.20)
	update_clock += dt
	if update_clock < 0.09:
		return
	update_clock = 0
	var cloud: float = [0.18, 0.36, 0.70, 0.70, 0.85, 0.65, 0.91][weather]
	var golden := (1.0 - smoothstep(0.12, 0.56, absf(elevation))) * (1.0 - cloud * 0.72)
	var top := Color("#4b5773").lerp(Color("#638fc0"), daylight)
	var horizon := Color("#626b80").lerp(Color("#b7ccd9"), daylight)
	horizon = horizon.lerp(Color("#ebb988"), golden * smoothstep(-0.16, 0.12, elevation) * 0.50)
	var current_sky := Vector2i(floori(hour * 8.0), weather)
	if sky_key != current_sky:
		sky_key = current_sky
		sky.set_shader_parameter("zenith", top)
		sky.set_shader_parameter("horizon", horizon)
		sky.set_shader_parameter("coverage", cloud)
		sky.set_shader_parameter("daylight", daylight)
		sky.set_shader_parameter("sun_strength", daylight * (1.0 - cloud * 0.82))
		sky.set_shader_parameter("phase", floorf(hour * 8.0) * 0.025)
	var solar_azimuth := atan2(sin(hour_angle), sin(deg_to_rad(31.23)) * cos(hour_angle))
	sun.rotation = Vector3(-elevation, -solar_azimuth, 0.0)
	sun.light_color = Color("#fff5e8").lerp(Color("#ffbc83"), golden * 0.77)
	sun.light_energy = daylight * (2.16 - cloud * 1.38) + flash * 2.75
	environment.ambient_light_color = Color("#9eaac1").lerp(Color("#bfcedf"), daylight)
	environment.ambient_light_energy = (0.46 + daylight * 0.23 + cloud * 0.24 + flash * 0.65) if not game.inside else 0.48
	environment.fog_enabled = game.settings.fog_enabled
	environment.fog_light_color = horizon.darkened(0.26) if not game.in_tunnel else Color("#3a423f")
	environment.fog_density = (0.0046 if weather == 5 else 0.00028 + cloud * 0.00045) if not game.in_tunnel else 0.0022
	environment.fog_sky_affect = 0.12
	var shadow_distance: float = game.rendering.SHADOW_DISTANCE[game.quality] * float(game.settings.shadow_detail)
	sun.shadow_enabled = shadow_distance > 0.0 and daylight > 0.14 and not game.in_tunnel
	sun.directional_shadow_max_distance = maxf(16, shadow_distance)
	RenderingServer.global_shader_parameter_set("night", night)
	RenderingServer.global_shader_parameter_set("wetness", wetness)
	RenderingServer.global_shader_parameter_set("water_detail", clampf((0.30 + game.quality * 0.15) * game.settings.water_detail, 0.0, 1.25))
	RenderingServer.global_shader_parameter_set("surface_detail", clampf((0.60 + game.quality * 0.13) * game.settings.texture_detail, 0.35, 1.15))
	var tint := horizon.srgb_to_linear()
	RenderingServer.global_shader_parameter_set("city_sky_tint", Vector3(tint.r, tint.g, tint.b))
	game.world.skywalk.update_lighting(night)
	game.world.landmarks.update_lod(game.camera.position, game.quality, game.settings.building_detail, 0.09)
	var view_origin: Vector3 = game.camera.position
	_update_probe(game, view_origin, 0.09)
	_update_lamps(game, view_origin)
	game.audio.mix(wetness, night, game.on_ferry or game.world.is_water(at), game.wanted)

func _update_probe(game, at: Vector3, delta: float) -> void:
	if game.rendering.method == &"gl_compatibility" or game.quality < 2 or game.settings.reflection_detail < 0.5 or game.in_tunnel or game.inside or DisplayServer.get_name() == "headless":
		light_probe.hide()
		probe_area = -1
		return
	probe_cooldown -= delta
	if probe_cooldown > 0.0:
		return
	probe_cooldown = 0.18
	var anchors := [Vector3(-245, 13, -500), Vector3(-1180, 13, -430), Vector3(290, 13, -20)]
	var closest := -1
	var best := 115.0 * 115.0
	for index in anchors.size():
		var score: float = anchors[index].distance_squared_to(at)
		if score < best:
			best = score
			closest = index
	if probe_area == closest:
		return
	probe_area = closest
	if closest < 0:
		light_probe.hide()
	else:
		light_probe.position = anchors[closest]
		light_probe.intensity = 0.72 * game.settings.reflection_detail
		light_probe.show()

func _update_lamps(game, at: Vector3) -> void:
	lamp_clock += .09
	if lamp_clock < .36:
		return
	lamp_clock = 0.0
	if night < .30 or game.in_tunnel or game.inside or DisplayServer.get_name() == "headless":
		for item in lamps:
			item.hide()
		return
	var budget: int = [2,4,6,8,8][game.quality]
	var positions: Array = game.world.near_lamps(at, budget)
	for index in lamps.size():
		var item := lamps[index]
		if index < positions.size():
			var anchor: Vector3 = positions[index]
			item.look_at_from_position(anchor, anchor + Vector3(.23,-5.0,.49),Vector3.UP)
			item.light_energy = (2.0 + night * 3.4) * (1.0-wetness*.16)
			item.show()
		else:
			item.hide()

extends RefCounted

const SCALE := [0.64, 0.82, 0.94, 1.0, 1.0]
const STREAM_RADIUS := [1, 2, 2, 3, 4]
const SHADOW_DISTANCE := [0.0, 68.0, 100.0, 140.0, 230.0]
const PREFERENCES := {
	"render_ratio": 0.0, "texture_detail": 1.0, "shadow_detail": 1.0,
	"reflection_detail": 1.0, "water_detail": 1.0, "building_detail": 1.0,
	"vegetation": 1.0, "traffic_density": 1.0, "fog_enabled": true, "aa": 1,
}
var method: StringName
var viewport: Viewport
var preset := 1
var scale := 1.0
var ceiling := 1.0
var clock := 0.0
var frame_sum := 0.0
var samples := 0
var pressure_ticks := 0
var tuning: Dictionary
var exposure := CameraAttributesPractical.new()

func start(game) -> void:
	method = RenderingServer.get_current_rendering_method()
	viewport = game.get_viewport()
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	game.camera.attributes = exposure
	if method != &"gl_compatibility":
		viewport.use_hdr_2d = true

func apply(game, is_photo := false) -> void:
	tuning = game.settings
	preset = 4 if is_photo else clampi(int(tuning.quality), 0, 4)
	apply_preset(game)
	Engine.max_fps = 30 if tuning.power and not is_photo else int(tuning.fps)
	exposure.exposure_multiplier = 1.0
	exposure.dof_blur_far_enabled = false
	exposure.dof_blur_near_enabled = false

func apply_preset(game) -> void:
	game.quality = preset
	var override: float = tuning.render_ratio
	ceiling = 1.0 if game.still_photo else (clampf(override, 0.55, 1.0) if override > 0.5 else SCALE[preset])
	scale = ceiling
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	viewport.mesh_lod_threshold = [3.8, 2.0, 1.15, 0.72, 0.45][preset] / maxf(0.55, float(tuning.building_detail))
	viewport.msaa_3d = Viewport.MSAA_2X if tuning.aa > 0 and preset > 0 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if method == &"forward_plus" and tuning.aa == 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	game.world.map_radius = STREAM_RADIUS[preset]
	game.camera.far = [1600.0, 2350.0, 3100.0, 4100.0, 5000.0][preset]
	game.world.vegetation = clampf(float(tuning.vegetation) * [0.60, 0.82, 1.0, 1.0, 1.0][preset], 0.0, 1.0)
	game.world.update_quality(preset, float(tuning.building_detail))
	var env: Environment = game.climate.environment
	# Screen-space passes below are intentionally gated to the desktop renderer.
	env.ssao_enabled = method == &"forward_plus" and preset >= 2
	env.ssao_radius = 2.4
	env.ssao_intensity = 1.25
	env.ssr_enabled = method == &"forward_plus" and preset == 4 and float(tuning.reflection_detail) > 0.8
	env.ssr_max_steps = 24
	env.glow_enabled = method != &"gl_compatibility" and preset >= 3
	env.glow_intensity = 0.20
	env.glow_bloom = 0.025
	env.glow_hdr_threshold = 1.65

func tick(game, delta: float) -> void:
	if not tuning.auto or game.still_photo or DisplayServer.get_name() == "headless":
		return
	clock += delta
	frame_sum += delta
	samples += 1
	if clock < 3.0:
		return
	var budget := 1.0 / (30.0 if tuning.power else float(maxi(30, mini(60, int(tuning.fps)))))
	var average := frame_sum / maxi(1, samples)
	clock = 0.0
	frame_sum = 0.0
	samples = 0
	if average > budget * 1.21:
		scale = maxf(0.55, scale - 0.07)
		pressure_ticks += 1
	elif average < budget * 0.94:
		scale = minf(ceiling, scale + 0.035)
		pressure_ticks = maxi(0, pressure_ticks - 1)
	else:
		pressure_ticks = 0
	if (pressure_ticks >= 3 and scale < 0.65 or Performance.get_monitor(Performance.MEMORY_STATIC) > 550_000_000) and preset > 0:
		preset -= 1
		apply_preset(game)
		scale = minf(scale, 0.72)
		pressure_ticks = 0
	viewport.scaling_3d_scale = scale

func frame_times() -> Vector2:
	var rid := viewport.get_viewport_rid()
	return Vector2(RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid))

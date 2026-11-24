extends RefCounted

var active := false
var entry: Dictionary
var look := Vector2.ZERO
var flight_height := 0.0
var taking := false
var resolution := 1920

func enter(game) -> void:
	if active:
		return
	entry = {
		"camera":game.camera.global_transform, "fov":game.camera.fov,
		"hour":game.climate.hour, "weather":game.climate.weather, "wet":game.climate.wetness,
		"night":game.climate.night, "sat":game.climate.environment.adjustment_saturation,
		"contrast":game.climate.environment.adjustment_contrast,
		"brightness":game.climate.environment.adjustment_brightness,
	}
	look = Vector2(game.camera.rotation.y, game.camera.rotation.x)
	flight_height = 0.0
	active = true
	game.still_photo = true
	game.apply_settings()

func leave(game) -> void:
	if not active:
		return
	active = false
	game.still_photo = false
	game.camera.global_transform = entry.camera
	game.camera.fov = entry.fov
	game.climate.hour = entry.hour
	game.climate.weather = entry.weather
	game.climate.wetness = entry.wet
	game.climate.night = entry.night
	game.climate.environment.adjustment_saturation = entry.sat
	game.climate.environment.adjustment_contrast = entry.contrast
	game.climate.environment.adjustment_brightness = entry.brightness
	game.apply_settings()

func rotate(game, delta: Vector2) -> void:
	look.x -= delta.x*.0038
	look.y = clampf(look.y - delta.y*.0038, -1.49,1.48)
	game.camera.rotation = Vector3(look.y,look.x,0)

func navigate(game, delta: float) -> void:
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	var rise := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var amount := 35.0 if game.flag("sprint") else 7.0
	pan(game,movement * amount * delta)
	game.camera.position.y = clampf(game.camera.position.y + (rise*amount + flight_height)*delta, -24.0, 730.0)

func pan(game, offset: Vector2) -> void:
	var flat := Basis(Vector3.UP, look.x)
	var candidate: Vector3 = game.camera.position + flat * Vector3(offset.x,0,offset.y)
	if game.world.in_bounds(candidate):
		game.camera.position = candidate

func lift(game, meters: float) -> void:
	game.camera.position.y = clampf(game.camera.position.y+meters, -24.0, 730.0)

func filter(game, index: int) -> void:
	var env: Environment = game.climate.environment
	env.adjustment_saturation = [0.90, 0.76, 0.10, 1.0][index]
	env.adjustment_contrast = [1.0, 1.10, 1.18, 0.95][index]
	env.adjustment_brightness = [1.0,0.95,0.97,1.04][index]

func save(game) -> void:
	if not active or taking or DisplayServer.get_name() == "headless":
		return
	taking = true
	var viewport := SubViewport.new()
	var width := mini(resolution,1920) if OS.has_feature("mobile") or OS.has_feature("web") else resolution
	viewport.size = Vector2i(width,roundi(width*9.0/16.0))
	viewport.world_3d = game.get_world_3d()
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.global_transform = game.camera.global_transform
	camera.fov = game.camera.fov
	camera.near = game.camera.near
	camera.far = game.camera.far
	camera.attributes = game.camera.attributes
	camera.environment = game.camera.environment
	camera.current = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	DirAccess.make_dir_recursive_absolute("user://photos")
	var tag := str(int(Time.get_unix_time_from_system())) + "-" + str(Time.get_ticks_msec() % 10000)
	var ok := image != null and image.save_png("user://photos/Shanghai-Photo-%s.png" % tag) == OK
	game.notice(game.bi("已保存高清照片", "High-resolution photo saved") if ok else game.bi("照片保存失败", "Could not save photo"))
	taking = false

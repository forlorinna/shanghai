extends SceneTree

const Scene = preload("res://game/main.tscn")
var game
var output := "res://builds"
var only := ""
var records: Array[Dictionary] = []
var disable_shadows := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg == "--no-shadows":
			disable_shadows = true
	call_deferred("_run")

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _shot(label: String, eye: Vector3, subject: Vector3, hour: float, weather: int,
		actor := Vector3.INF, motion := false, tunnel := false, field := 62.0) -> void:
	if not only.is_empty() and label not in only.split(","):
		return
	if "rendering" in game:
		game.settings.quality = 3 if label in ["06-huangpu-reflections","10-lujiazui-aerial"] else 2
		game.apply_settings()
	if game.driving != null:
		game.leave_vehicle(true)
	game.in_tunnel = tunnel
	var actor_point := actor if actor.is_finite() else subject
	if not game.world.in_bounds(actor_point):
		actor_point = game.start_position()
	if not tunnel:
		actor_point.y = .06
	game.teleport(actor_point)
	if label == "10-lujiazui-aerial":
		for anchor in [Vector3(-930,0,-500),Vector3(-302,0,-890),Vector3(300,0,-210),Vector3(790,0,350),Vector3(0,0,470)]:
			game.world.warm(anchor)
	game.player.hero.visible = actor.is_finite() and not motion
	game.player.hero.rotation.y = atan2(eye.x-subject.x, eye.z-subject.z)
	game.climate.hour = hour
	game.climate.weather = weather
	game.climate.wetness = 0.96 if weather >= 3 else 0.0
	game.camera.fov = field
	game.camera.position = eye
	game.camera.look_at(subject)
	var speed := 0.0
	if motion:
		var road: Dictionary = game.streets.spawn_space(actor_point) if not tunnel else {"pos":actor_point, "yaw":atan2(eye.x-subject.x,eye.z-subject.z)}
		var car = game.spawn_car(2,road.pos,road.yaw,Color("#4b5863") if weather >= 3 else Color("#43646b"))
		game.enter_vehicle(car)
		game.free_camera = true
		game.free_position = eye
		game.ui.open("game")
		game.ui.hide()
		car.speed = 11.5
		Input.action_press("move_up")
		for step in 10:
			await physics_frame
		Input.action_release("move_up")
		speed = car.speed * 3.6
		var offset: Vector3 = subject - actor_point
		var view: Vector3 = car.global_position + (eye - actor_point)
		game.ui.open("pause")
		game.camera.position = view
		game.camera.look_at(car.global_position + offset)
		game.free_camera = false
		game.player.hero.visible = false
	await _frames(10)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var result := img.save_png(output.path_join(label + ".png"))
	assert(result == OK)
	var row := {"shot":label, "width":img.get_width(), "height":img.get_height(),
		"renderer":str(RenderingServer.get_current_rendering_method()),"driving_kmh":speed,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),
		"renderer_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		"renderer_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
		"rendered_fps":Engine.get_frames_per_second()}
	records.append(row)
	print("SHOT ", JSON.stringify(row))

func _run() -> void:
	seed(314159)
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	game.settings.auto = false
	game.settings.quality = 2
	if disable_shadows and game.settings.has("shadow_detail"):
		game.settings.shadow_detail = 0.0
	game.begin("new")
	game.ui.open("pause")
	game.ui.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _frames(8)
	await _shot("01-pearl-street", Vector3(-381,2.6,-581), Vector3(-267,45,-663),12.2,0,Vector3(-375,0,-585),false,false,72)
	await _shot("02-shanghai-tower", Vector3(206,5.8,-21),Vector3(291,180,52),14.1,1,Vector3(214,0,-15),false,false,76)
	await _shot("03-lujiazui-driving",Vector3(-131,4,-461),Vector3(-196,4,-559),17.35,1,Vector3(-136,0,-470),true)
	await _shot("04-bund-night",Vector3(-1080,3.2,-337),Vector3(-1191,13,-502),21.6,1,Vector3(-1100,0,-412),false,false,62)
	await _shot("05-bund-rain-drive",Vector3(-1101,2.66,-473),Vector3(-1106,2.0,-519),21.6,4,Vector3(-1105,0,-480),true,false,66)
	await _shot("06-huangpu-reflections",Vector3(-918,4,-497),Vector3(-35,89,-375),20.5,2,Vector3(-1064,0,-451),false,false,74)
	var car_slot: Dictionary = game.streets.spawn_space(Vector3(138,0,-405))
	var car = game.spawn_car(0,car_slot.pos,car_slot.yaw,Color("#723545"))
	var car_eye: Vector3 = car.position + car.basis*Vector3(3.25,1.30,-4.8)
	await _shot("07-car-close",car_eye,car.position+Vector3.UP*.63,15.8,1,car.position+Vector3(4.8,0,3.9),false,false,46)
	await _shot("08-third-person",Vector3(-190,2.7,-552),Vector3(-263,8,-624),13.4,0,Vector3(-195,0,-558),false,false,59)
	var point: Vector3 = game.world.tunnel[3].lerp(game.world.tunnel[4],.5)
	var toward: Vector3 = point.direction_to(game.world.tunnel[4])
	await _shot("09-tunnel",point-toward*4.5 + Vector3.UP*2.3,point+toward*32+Vector3.UP*1.3,19.1,0,point,true,true,65)
	await _shot("10-lujiazui-aerial",Vector3(-770,373,-839),Vector3(175,25,-121),16.4,1,Vector3(-223,0,-530),false,false,57)
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	quit()

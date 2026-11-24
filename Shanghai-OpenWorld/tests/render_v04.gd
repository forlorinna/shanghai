extends SceneTree

const Game = preload("res://game/main.tscn")
const STREET := Vector3(-247, .08, -495)
const SHOTS := [
	["01-car", Vector3(3.6, 1.64, -4.9), Vector3(0, .70, 0), 14.0, 0, 40.0],
	["02-character", Vector3(-245.1, 1.51, -497.55), Vector3(-247, 1.34, -495), 14.0, 0, 32.0],
	["03-pearl", Vector3(-223, 4.2, -568), Vector3(-265, 35, -658), 13.3, 0, 63.0],
	["04-skywalk", Vector3(-259, 4.0, -434), Vector3(-186, 10.5, -466), 14.0, 0, 60.0],
	["05-street", Vector3(-255, 2.4, -516), Vector3(-182, 6, -472), 14.0, 0, 59.0],
	["06-third-person", Vector3(-248.55, 2.96, -489.94), Vector3(-246.61, 1.31, -496.27), 14.0, 0, 59.0],
	["07-night", Vector3(-257, 3.7, -436), Vector3(-184, 9, -466), 21.4, 1, 61.0],
	["08-rain", Vector3(-255, 2.4, -516), Vector3(-182, 6, -472), 17.5, 4, 59.0],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() else "res://builds/v0.4/screenshots"
	var selected := args[1].split(",") if args.size() > 1 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(output)
	seed(7074)
	var game = Game.instantiate()
	root.add_child(game)
	game.settings.auto = false
	game.settings.quality = 2
	game.begin("new")
	game.ui.open("pause")
	game.ui.hide()
	game.teleport(STREET)
	game.player.hero.rotation.y = PI - .32
	var slot: Dictionary = game.streets.spawn_space(Vector3(-245, 0, -528))
	var car = game.spawn_car(0, slot.pos, slot.yaw, Color("#4e5662"))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var rows: Array[Dictionary] = []
	for shot in SHOTS:
		if not selected.is_empty() and shot[0] not in selected:
			continue
		var eye: Vector3 = shot[1]
		var center: Vector3 = shot[2]
		if shot[0] == "01-car":
			eye = car.to_global(eye)
			center = car.to_global(center)
		game.player.hero.visible = shot[0] in ["02-character", "06-third-person"]
		game.player.hero.rotation.y = .32 if shot[0] == "06-third-person" else PI - .32
		game.camera.global_position = eye
		game.camera.look_at(center)
		game.camera.fov = shot[5]
		game.climate.hour = shot[3]
		game.climate.weather = shot[4]
		game.climate.wetness = .98 if shot[4] == 4 else 0.0
		game.still_photo = true
		game.climate.tick(game, .12, STREET)
		game.world.landmarks.update_lod(eye, 2, 1.0, .5)
		for frame in (6 if Engine.get_frames_per_second() < 12.0 else 12):
			await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var status := picture.save_png(output.path_join(shot[0] + ".png"))
		if status != OK:
			push_error("Capture failed %s" % shot[0])
			quit(1)
			return
		var record := {"shot":shot[0], "renderer":str(RenderingServer.get_current_rendering_method()),
			"width":picture.get_width(), "height":picture.get_height(),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
			"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
			"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())}
		rows.append(record)
		print("SHOT ", JSON.stringify(record))
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()

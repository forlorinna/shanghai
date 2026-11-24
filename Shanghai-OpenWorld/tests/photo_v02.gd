extends SceneTree

const Game = preload("res://game/main.tscn")
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Game.instantiate()
	root.add_child(game)
	game.settings.auto = false
	game.begin("new")
	game.ui.open("photo")
	game.photography.resolution = 1920
	assert(not game.is_playing() and game.quality == 4)
	await process_frame
	await game.photography.save(game)
	var photos := DirAccess.get_files_at("user://photos")
	assert(photos.size() == 1)
	var shot := Image.load_from_file("user://photos/" + photos[0])
	assert(shot.get_size() == Vector2i(1920,1080))
	assert(shot.get_pixel(960,540).a > .9)
	game.ui.open("game")
	assert(game.quality == 1 and game.is_playing())
	print("PHOTO_PASS ", RenderingServer.get_current_rendering_method(), " ", shot.get_size())
	game.queue_free()
	for tick in 5:
		await process_frame
	quit()

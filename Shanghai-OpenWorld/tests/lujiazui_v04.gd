extends SceneTree

const Scene = preload("res://game/main.tscn")
const Car = preload("res://assets/vehicles/vehicle.gd")
var game
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(passed: bool, label: String) -> void:
	print("PASS " + label if passed else "FAIL " + label)
	if not passed:
		failures += 1

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame

func _ray(point: Vector3) -> Dictionary:
	var body := game.get_world_3d() as World3D
	var params := PhysicsRayQueryParameters3D.create(point + Vector3.UP*2, point-Vector3.UP*2, 1)
	return body.direct_space_state.intersect_ray(params)

func _run() -> void:
	seed(7074)
	game = Scene.instantiate()
	root.add_child(game)
	game.begin("new")
	game.settings.auto = false
	game.settings.traffic = false
	game.settings.crowds = 0.0
	await _ticks(15)
	for model in [0,1,2,3,4]:
		for traffic in [false,true]:
			var car := Car.new()
			car.create(game, model, Color("#576373"), traffic, traffic)
			var body := car.shell.get_node_or_null("ImportedBody")
			_check(car.imported and body != null and car.wheels.size() == 4,
				"Imported vehicle model %d / traffic %s / four wheel hubs" % [model, traffic])
			car.free()
	var character = game.player.hero
	_check(character.skeleton.get_bone_count() >= 60, "Textured protagonist skin uses imported skeleton")
	character.animate(0.016, 1.7, "ground")
	_check(character.animations.current_animation == "Walk", "Walk animation selected")
	character.animate(0.016, 4.7, "ground")
	_check(character.animations.current_animation == "Run", "Run animation selected")
	character.animate(0.016, 0, "jump")
	_check(character.animations.current_animation == "Jump", "Jump animation selected")

	var skywalk = game.world.skywalk
	var access: Dictionary
	for route: Dictionary in skywalk.bridges.access:
		if route.id == "166125936":
			access = route
	var bottom: Vector3 = skywalk.to_global(Vector3(access.points[-1][0],access.points[-1][1],access.points[-1][2]))
	var top: Vector3 = skywalk.to_global(Vector3(access.points[0][0],access.points[0][1],access.points[0][2]))
	var bearing := Vector3(top.x-bottom.x, 0, top.z-bottom.z).normalized()
	var level: Array = access.points[1]
	var level_world: Vector3 = skywalk.to_global(Vector3(level[0],level[1],level[2]))
	var halfway := bottom.lerp(level_world, .5)
	var landing := _ray(halfway)
	_check(not landing.is_empty() and absf(landing.position.y-halfway.y)<.13, "Ramped stair collision follows the mapped climb")
	game.teleport(bottom - bearing * 1.1 + Vector3.UP*.10)
	game.yaw = atan2(-bearing.x,-bearing.z)
	await _ticks(15)
	Input.action_press("move_up")
	for step in 570:
		await physics_frame
		if game.player.position.y > 8.10 and game.player.is_on_floor():
			break
	await _ticks(22)
	Input.action_release("move_up")
	await _ticks(8)
	print("BRIDGE player=", game.player.position, " approach_top=", top)
	_check(game.player.position.y > 8.07 and game.player.is_on_floor(), "Walk from street to bridge under normal player input")
	quit(1 if failures else 0)

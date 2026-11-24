extends Node

const LEVEL := -0.62
const DISPLAY_WIDTH := 416
const DISPLAY_HEIGHT := 236
var surface: SubViewport
var mirror: Camera3D
var cooldown := 0.0
var active := false

func start(world: World3D) -> void:
	surface = SubViewport.new()
	surface.name = "HuangpuReflection"
	surface.size = Vector2i(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	surface.world_3d = world
	surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(surface)
	mirror = Camera3D.new()
	mirror.cull_mask = 1
	mirror.near = .17
	mirror.far = 1750.0
	surface.add_child(mirror)
	mirror.current = true
	RenderingServer.global_shader_parameter_set("river_reflection", surface.get_texture())

func update_view(game, delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	cooldown = .13 if game.still_photo else .24
	var camera: Camera3D = game.camera
	var eye := camera.global_position
	var direction := -camera.global_basis.z
	var wants: bool = game.quality >= 3 and float(game.settings.water_detail) >= .76 and float(game.settings.reflection_detail) >= .7
	# Excluding terrain/water from the auxiliary view avoids recursion and looking through land.
	var sees_water: bool = wants and eye.y > LEVEL+1.2 and eye.y < 105 and not game.in_tunnel and not game.inside
	if sees_water:
		sees_water = game.world.is_water(eye) or game.world.is_water(eye+direction*32) or game.world.is_water(eye+direction*108)
	if not sees_water:
		if active:
			RenderingServer.global_shader_parameter_set("river_reflect_on", false)
		active = false
		return
	var flip := Vector3(1,-1,1)
	var basis := camera.global_basis.orthonormalized()
	var reflected := Basis(-basis.x*flip, basis.y*flip, basis.z*flip)
	var position := Vector3(eye.x,2.0*LEVEL-eye.y,eye.z)
	mirror.global_transform = Transform3D(reflected, position)
	var vertical_half_tangent := tan(deg_to_rad(camera.fov) * .5)
	# The texture retains the camera's vertical FOV. X projection uses the reflection viewport aspect.
	mirror.fov = camera.fov
	RenderingServer.global_shader_parameter_set("river_eye", position)
	RenderingServer.global_shader_parameter_set("river_right", reflected.x)
	RenderingServer.global_shader_parameter_set("river_up", reflected.y)
	RenderingServer.global_shader_parameter_set("river_back", reflected.z)
	RenderingServer.global_shader_parameter_set("river_projection", Vector2(vertical_half_tangent*DISPLAY_WIDTH/DISPLAY_HEIGHT,vertical_half_tangent))
	RenderingServer.global_shader_parameter_set("river_reflect_on", true)
	surface.render_target_update_mode = SubViewport.UPDATE_ONCE
	active = true

func _exit_tree() -> void:
	if surface != null:
		RenderingServer.global_shader_parameter_set("river_reflect_on", false)
		RenderingServer.global_shader_parameter_set("river_reflection", preload("res://assets/textures/pbr/metal_albedo.jpg"))

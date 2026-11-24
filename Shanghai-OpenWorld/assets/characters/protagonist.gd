extends Node3D

const MODEL = preload("res://assets/characters/models/lujiazui_protagonist.glb")
const CROWD_MODEL := "res://assets/characters/models/pedestrian.glb"
const COLORS := [Color.WHITE, Color("#b9b7a0"), Color("#a5b7d3"), Color("#bbadaf")]
var skeleton: Skeleton3D
var animations: AnimationPlayer
var clip := &""
var previous_heading := 0.0

func build(style: int, pedestrian := false) -> void:
	var packed := load(CROWD_MODEL) as PackedScene if pedestrian else MODEL
	var human := packed.instantiate() as Node3D
	human.scale = Vector3.ONE * 1.025
	add_child(human)
	skeleton = human.find_children("*", "Skeleton3D", true, false)[0]
	animations = human.find_children("*", "AnimationPlayer", true, false)[0]
	for mesh: MeshInstance3D in human.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if original and original.resource_name.to_lower() == "outfit":
				var clothes := original.duplicate() as BaseMaterial3D
				clothes.albedo_color *= COLORS[posmod(style, COLORS.size())]
				mesh.set_surface_override_material(i, clothes)
	for name in [&"Idle", &"Walk", &"Run", &"Crouch idle", &"Crouch walk (aiming)", &"Paddle canoe"]:
		if animations.has_animation(name):
			animations.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	animate(0, 0, "ground")
	animations.advance(0)

func animate(delta: float, speed: float, state: String) -> void:
	var next := &"Idle"
	var pace := 1.0
	var heading_change := angle_difference(previous_heading, rotation.y)
	previous_heading = rotation.y
	match state:
		"jump", "climb":
			next = &"Jump"
		"down":
			next = &"Fall"
		"enter":
			next = &"Sit (passenger)"
		"exit":
			next = &"Idle"
		"swim":
			next = &"Paddle canoe"
		"crouch":
			next = &"Crouch walk (aiming)" if speed > .3 else &"Crouch idle"
		_:
			if speed > 3.6:
				next = &"Run"
				pace = clampf(speed/4.6, .85, 1.73)
			elif speed > .24:
				next = &"Walk"
				pace = clampf(speed/1.8, .55, 1.8)
			elif delta > 0 and absf(heading_change) > .18:
				next = &"Turn left 45°" if heading_change > 0 else &"Turn right 45°"
	if not animations.has_animation(next):
		next = &"Idle"
	animations.speed_scale = pace
	if next != clip:
		animations.play(next, .14)
		clip = next

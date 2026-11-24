extends Node3D

const MODEL = preload("res://assets/landmarks/models/lujiazui_skywalk.glb")
const PAVING = preload("res://assets/textures/lujiazui/precast_stone_paving_diff_1k.jpg")
const PAVING_NORMAL = preload("res://assets/textures/lujiazui/precast_stone_paving_nor_gl_1k.jpg")
const A = preload("res://scripts/art.gd")
const DATA := "res://assets/landmarks/models/lujiazui_skywalk.json"
var tread_light: StandardMaterial3D
var bridges: Dictionary

func build() -> void:
	bridges = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	position = _point(bridges.origin)
	var asset := MODEL.instantiate()
	add_child(asset)
	var paving := (asset.get_node("deck") as MeshInstance3D)
	var stone := paving.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	stone.albedo_color = Color("#caced0")
	stone.albedo_texture = PAVING
	stone.normal_enabled = true
	stone.normal_texture = PAVING_NORMAL
	stone.normal_scale = .5
	paving.material_override = stone
	var light_mesh := asset.get_node("light") as MeshInstance3D
	tread_light = light_mesh.mesh.surface_get_material(0).duplicate()
	tread_light.emission_enabled = true
	tread_light.emission = Color("#ffbd78")
	tread_light.emission_energy_multiplier = 0.0
	light_mesh.material_override = tread_light
	var ring := _points(bridges.ring)
	var accesses: Array[Vector3] = []
	for access: Dictionary in bridges.access:
		var points := _points(access.points)
		accesses.append(points[0].lerp(points[2], .22))
		_surface(points, access.width, false, [])
	_surface(ring, bridges.width, true, accesses)
	for index in range(0, ring.size(), 11):
		var point := ring[index]
		var near_access := false
		for entrance in accesses:
			if Vector2(point.x,point.z).distance_to(Vector2(entrance.x,entrance.z)) < 7.0:
				near_access = true
				break
		if not near_access:
			A.collider(self, Vector3(point.x, 3.5, point.z), Vector3(1.35, 7.0, 1.35))

func update_lighting(level: float) -> void:
	tread_light.emission_energy_multiplier = 2.9 * smoothstep(.25, .82, level)

func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _points(rows: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for row: Array in rows:
		points.append(_point(row))
	return points

func _surface(points: PackedVector3Array, width: float, loop: bool, openings: Array) -> void:
	var outside := PackedVector3Array()
	var inside := PackedVector3Array()
	for index in points.size():
		var previous := points[posmod(index-1, points.size())] if index > 0 or loop else points[index]
		var following := points[(index+1) % points.size()] if index < points.size()-1 or loop else points[index]
		var offset := Vector3.UP.cross(following-previous).normalized() * width * .5
		outside.append(points[index] + offset)
		inside.append(points[index] - offset)
	var faces := PackedVector3Array()
	var limit := points.size() if loop else points.size()-1
	var deck_left := inside.duplicate()
	var deck_right := outside.duplicate()
	if loop:
		for i in points.size():
			for access: Vector3 in openings:
				var direction := Vector3(access.x-points[i].x,0,access.z-points[i].z)
				if direction.length_squared() > 50.0:
					continue
				if direction.dot(outside[i]-points[i]) > .5:
					deck_right[i] = points[i].lerp(outside[i], .09)
				elif direction.dot(inside[i]-points[i]) > .5:
					deck_left[i] = points[i].lerp(inside[i], .09)
	for i in limit:
		var j := (i+1) % points.size()
		faces.append_array([deck_left[i], deck_right[i], deck_right[j], deck_left[i], deck_right[j], deck_left[j]])
	if loop:
		_attach_collision(faces, false)
	else:
		# Use a continuous convex stair ramp per mapped flight. Triangle seams
		# on inclines can trap the character capsule under Godot Physics.
		for i in points.size()-1:
			var from := points[i]
			var to := points[i+1]
			var axes := Basis.looking_at(from.direction_to(to), Vector3.UP)
			var ramp := A.collider(self, from.lerp(to,.5)-axes.y*.12,
				Vector3(width, .24, from.distance_to(to)+.07))
			ramp.basis = axes
	faces = PackedVector3Array()
	for i in range(0, limit, 2):
		var j := (i+2) % points.size() if loop else mini(i+2, points.size()-1)
		for edge in [outside, inside]:
			var a: Vector3 = edge[i]
			var b: Vector3 = edge[j]
			var midpoint := a.lerp(b, .5)
			var open := false
			for opening: Vector3 in openings:
				if Vector2(midpoint.x, midpoint.z).distance_to(Vector2(opening.x, opening.z)) < 6.15:
					open = true
					break
			if not open:
				faces.append_array([a, b, b+Vector3.UP*1.10, a, b+Vector3.UP*1.10, a+Vector3.UP*1.10])
	_attach_collision(faces, true)

func _attach_collision(faces: PackedVector3Array, double_sided: bool) -> void:
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = double_sided
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

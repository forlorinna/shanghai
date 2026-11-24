extends SceneTree

const CITY_SHADER = preload("res://shaders/city.gdshader")
const TREE_SHADER = preload("res://shaders/tree.gdshader")
const CONTACT_SHADER = preload("res://shaders/ground_contact.gdshader")
const POOL_SHADER = preload("res://shaders/light_pool.gdshader")
const WATER_SHADER = preload("res://shaders/huangpu.gdshader")
const BUILDING_COLORS := [
	Color("#8098a3"), Color("#879695"), Color("#8e8c82"), Color("#a1a29a"), Color("#566f82"),
	Color("#c6ab89"), Color("#aaa092"), Color("#bdad94"), Color("#8e8376"), Color("#b6a898"),
]
const ROAD_COLORS := [Color("#858686"), Color("#39404a"), Color("#313946"), Color("#2b3440"), Color("#6b7174")]
var surfaces: Dictionary
var origin := Vector3.ZERO
var solid := PackedVector3Array()
var materials: Array[Material] = []
var wall_u := Vector3.ZERO
var wall_origin := Vector3.ZERO
var style := 0.0
var wall_seed := 0.0
var shoreline: Array[PackedVector2Array] = []
var foliage: ArrayMesh
var leaf_material: ShaderMaterial
var prop_center: Vector3
var prop_yaw := 0.0
var uv_hint := Vector2.INF
var street_center := false
var contact_range := 0.0
var wall_normal := Vector3.ZERO

func _initialize() -> void:
	for i in range(8):
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER if i == 4 else CITY_SHADER
		if i != 4:
			mat.set_shader_parameter("surface_type", i)
			var surface: String = ["concrete", "asphalt", "concrete", "concrete", "", "paving", "grass", "asphalt"][i]
			for row in [["color_tex","albedo.jpg"], ["normal_tex","normal.png"], ["material_tex","rma.png"]]:
				mat.set_shader_parameter(row[0], load("res://assets/textures/pbr/%s_%s" % [surface, row[1]]))
		materials.append(mat)
	var pool := ShaderMaterial.new()
	pool.shader = POOL_SHADER
	materials.append(pool)
	var contact := ShaderMaterial.new()
	contact.shader = CONTACT_SHADER
	materials.append(contact)
	var distance_mat := ShaderMaterial.new()
	distance_mat.shader = CITY_SHADER
	distance_mat.set_shader_parameter("surface_type", 10)
	materials.append(distance_mat)
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = TREE_SHADER
	leaf_material.set_shader_parameter("PlaneLeaf", load("res://assets/textures/pbr/foliage.png"))
	foliage = _make_foliage()
	var city: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/city.json"))
	for polygon in city.water:
		for ring in polygon:
			var edge := PackedVector2Array()
			for point in ring:
				edge.append(Vector2(point[0], point[1]))
			shoreline.append(edge)
	var skyline := Node3D.new()
	skyline.name = "Skyline"
	for tile in city.tiles:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/source/chunks/%s.json" % tile))
		if data.get("skyline", []).is_empty():
			continue
		surfaces = {}
		origin = _center(tile)
		var group := Node3D.new()
		group.name = "Distant_" + tile.replace("-", "N")
		group.position = origin
		skyline.add_child(group)
		group.owner = skyline
		_attach_distant(group, data.skyline)
		group.get_child(0).owner = skyline
	_bake_background(skyline, city.tiles)
	_save(skyline, "res://maps/chunks/skyline.scn")
	for tile in city.tiles:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/source/chunks/%s.json" % tile))
		_bake(tile, data)
	print("Map bake complete, ", city.tiles.size(), " chunk scenes plus skyline")
	quit()

func _bake_background(skyline: Node3D, ids: Array) -> void:
	# One low, continuous georeferenced land-and-water mesh under the streamed tiles.
	# Keep it off the reflection camera and below the detailed height to avoid seams.
	surfaces = {}
	origin = Vector3.ZERO
	for tile in ids:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/source/chunks/%s.json" % tile))
		_flat(data.get("ground",[]),-.18,"BackingLand",Color("#555952"))
		_flat(data.get("water",[]),-.83,"BackingWater",Color("#404947"))
	for label in ["BackingLand", "BackingWater"]:
		_attach(skyline,label,2)
		var item := skyline.get_node_or_null(label) as MeshInstance3D
		if item == null:
			continue
		item.layers = 2


func _center(key: String) -> Vector3:
	var pair := key.split("_")
	return Vector3((float(pair[0]) + 0.5) * 256.0, 0, (float(pair[1]) + 0.5) * 256.0)

func _attach_distant(root: Node3D, buildings: Array) -> void:
	for building in buildings:
		_building(building, "HLOD", false)
	_attach(root, "HLOD", 10, 405.0)

func _surface(key: String) -> SurfaceTool:
	if not surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[key] = st
	return surfaces[key]

func _point(a: Array, index: int, height: float) -> Vector3:
	return Vector3(float(a[index]), height, float(a[index + 1]))

func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3, collision := false) -> void:
	if (b - a).cross(c - a).length_squared() < 0.000001:
		return
	var st := _surface(key)
	for point in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		var uv := Vector2((point - wall_origin).dot(wall_u), wall_seed)
		if uv_hint.is_finite():
			var local: Vector3 = (point - prop_center).rotated(Vector3.UP, -prop_yaw)
			uv = Vector2(local.x / uv_hint.x, local.z / uv_hint.y) + Vector2.ONE * 0.5
		if key == "Contact":
			uv = Vector2((point-wall_origin).dot(wall_normal) / contact_range, 0)
		elif key == "water":
			uv.x = _shore_distance(Vector2(point.x, point.z))
		st.set_uv(uv)
		st.set_uv2(Vector2(style, 0.0))
		st.add_vertex(point - origin)
		if collision:
			solid.append(point - origin)

func _shore_distance(p: Vector2) -> float:
	var value := 38.0 * 38.0
	for ring in shoreline:
		for i in range(1, ring.size()):
			var from := ring[i - 1]
			var end := ring[i]
			if p.x < minf(from.x, end.x) - 38 or p.x > maxf(from.x, end.x) + 38 or p.y < minf(from.y, end.y) - 38 or p.y > maxf(from.y, end.y) + 38:
				continue
			value = minf(value, p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, from, end)))
	return sqrt(value)

func _flat(data: Array, height: float, key: String, color: Color, collision := false) -> void:
	for index in range(0, data.size(), 6):
		var a := _point(data, index, height)
		var b := _point(data, index + 2, height)
		var c := _point(data, index + 4, height)
		if (b - a).cross(c - a).y > 0:
			_tri(key, a, c, b, color, Vector3.UP, collision)
		else:
			_tri(key, a, b, c, color, Vector3.UP, collision)

func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3, collision := false) -> void:
	_tri(key, a, b, c, color, normal, collision)
	_tri(key, a, c, d, color, normal, collision)

func _make_foliage() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var randomizer := RandomNumberGenerator.new()
	randomizer.seed = 14778
	for i in 15:
		var a := i * 2.39996
		var height := randomizer.randf_range(-0.96, 1.43)
		var reach := 0.85 if i > 5 else 0.34
		var pivot := Vector3(cos(a) * reach, height, sin(a) * reach)
		var size := randomizer.randf_range(1.35, 2.22)
		var basis := Basis.from_euler(Vector3(randomizer.randf_range(-0.77, 0.77), a, randomizer.randf_range(-0.45, 0.45)))
		var entries := [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)]
		for uv in entries:
			surface.set_uv(uv)
			surface.set_normal((basis.z + Vector3.UP * 0.32).normalized())
			surface.add_vertex(pivot + basis * Vector3((uv.x - 0.5) * size, (0.5 - uv.y) * size, 0))
	return surface.commit()

func _box_surface(key: String, center: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var half := size * 0.5
	var corners := [
		Vector3(-half.x,-half.y,-half.z), Vector3(half.x,-half.y,-half.z),
		Vector3(half.x,-half.y,half.z), Vector3(-half.x,-half.y,half.z),
		Vector3(-half.x,half.y,-half.z), Vector3(half.x,half.y,-half.z),
		Vector3(half.x,half.y,half.z), Vector3(-half.x,half.y,half.z),
	]
	for i in corners.size():
		corners[i] = center + corners[i].rotated(Vector3.UP, yaw)
	for face in [[0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7], [4,5,6,7], [3,2,1,0]]:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		_quad(key, a, b, c, d, color, (c-a).cross(b-a).normalized())

func _fixture(row: Array) -> void:
	var p := _point(row, 0, 0)
	var yaw: float = row[2]
	var direction := Basis(Vector3.UP, yaw)
	var variant := int(row[3])
	var grey := Color("#63706e")
	var warm := Color("#8b684a")
	var concrete := Color("#a7a198")
	var black := Color("#3f4748")
	match variant:
		0:
			_box_surface("StreetDetail", p + Vector3.UP * .49, Vector3(.36,.98,.35), yaw, grey)
			_box_surface("StreetDetail", p + Vector3.UP * .99, Vector3(.40,.08,.39), yaw, black)
		1:
			for offset in [-.62,.62]:
				_box_surface("StreetDetail", p + direction.z * offset + Vector3.UP * .21, Vector3(.45,.42,.10), yaw, grey)
			for offset in [-.17,-.05,.07,.19]:
				_box_surface("StreetDetail", p + direction.x * offset + Vector3.UP * .47, Vector3(.085,.07,1.56), yaw, warm)
			_box_surface("StreetDetail", p + direction.x * .23 + Vector3.UP * .72, Vector3(.07,.28,1.53), yaw, warm)
		2:
			_box_surface("StreetDetail", p + Vector3.UP * .37, Vector3(.23,.74,.23), yaw, Color("#9e372e"))
			_box_surface("StreetDetail", p + Vector3.UP * .70, Vector3(.32,.13,.30), yaw, Color("#ad4a36"))
			_box_surface("StreetDetail", p + Vector3.UP * .49, Vector3(.46,.13,.17), yaw, Color("#9e372e"))
		3:
			for j in [-1.0,0.0,1.0]:
				_box_surface("StreetDetail", p + direction.z * j * 0.65 + Vector3.UP * .35, Vector3(.095,.70,.095), yaw, grey)
		4:
			_box_surface("StreetDetail", p + Vector3.UP * .18, Vector3(.62,.36,1.25), yaw, concrete)
			_box_surface("StreetDetail", p + Vector3.UP * .37, Vector3(.51,.045,1.12), yaw, Color("#806740"))
		5:
			_box_surface("StreetDetail", p + Vector3.UP * .48, Vector3(.46,.96,.72), yaw, Color("#647370"))
		6:
			for offset in [-.69,.69]:
				_box_surface("StreetDetail", p + direction.z * offset + Vector3.UP * 1.14, Vector3(.08,2.28,.08), yaw, grey)
			_box_surface("StreetDetail", p + Vector3.UP * 2.31, Vector3(.87,.045,1.64), yaw, grey)
			_box_surface("StreetDetail", p + direction.x*.43 + Vector3.UP*1.8, Vector3(.035,.33,1.40), yaw, Color("#35616d"))
		7:
			var start := p + Vector3.UP * .068
			for j in 16:
				var a := j * TAU / 16.0
				var b := (j+1) * TAU / 16.0
				_tri("StreetDetail", start, start+Vector3(cos(a)*.31,0,sin(a)*.31), start+Vector3(cos(b)*.31,0,sin(b)*.31), black, Vector3.UP)

func _pool(at: Vector3, heading: float) -> void:
	prop_center = at
	prop_yaw = heading
	var direction := Basis(Vector3.UP, heading)
	var a := direction.x * 3.7
	var b := direction.z * 5.4
	uv_hint = Vector2(7.4, 10.8)
	_quad("Spill", at-a-b, at+a-b, at+a+b, at-a+b, Color("#e5b77f"), Vector3.UP)
	uv_hint = Vector2.INF

func _building(record: Array, key: String, collision: bool) -> void:
	var height: float = record[1]
	style = float(record[2])
	wall_seed = float(absi(str(record[0]).hash()) % 173)
	var color: Color = BUILDING_COLORS[int(record[2])]
	_flat(record[4], height, key, color.darkened(0.28), collision)
	if street_center and collision and height > 9.5 and height < 74.0 and not record[3].is_empty() and record[3][0].size() >= 4:
		var sum := Vector3.ZERO
		var ring: Array = record[3][0]
		for p in ring:
			sum += _point(p, 0, height)
		var p := sum / ring.size()
		_box_surface("StreetDetail", p+Vector3.UP*.52, Vector3(2.5,1.04,1.6), .3, color.darkened(.18))
	for ring in record[3]:
		for j in ring.size():
			var a := _point(ring[j], 0, 0)
			var b := _point(ring[(j + 1) % ring.size()], 0, 0)
			var normal := (b - a).cross(Vector3.UP).normalized()
			wall_u = a.direction_to(b)
			wall_origin = a
			_quad(key, a, a + Vector3.UP * height, b + Vector3.UP * height, b,
				color, normal, collision)
			if street_center and collision and a.distance_to(b) > 1.3:
				var from := a + Vector3.UP*.087
				var end := b + Vector3.UP*.087
				wall_normal = normal
				contact_range = 1.18
				_quad("Contact",from,end,end+normal*contact_range,from+normal*contact_range,Color.WHITE,Vector3.UP)
			if street_center and collision and height > 8.0:
				var crevice := normal * .18
				var width := a.distance_to(b)
				var yaw := atan2(wall_u.x, wall_u.z)
				if width > 5.0:
					var center := a.lerp(b,.5)
					_box_surface("StreetDetail", center + crevice + Vector3.UP*4.25, Vector3(.50,.20,width*.94), yaw, color.lightened(.07))
					if style > 4.5 and width > 7.0:
						for jx in range(1, mini(9, floori(width/2.7))):
							var source := a + wall_u * jx * 2.7 + crevice + Vector3.UP*1.92
							_box_surface("StreetDetail", source, Vector3(.41,3.84,.24), yaw, color.lightened(.15))
			if int(record[2]) >= 5 and collision and height > 12.0:
				for h in [3.05, height - 0.75, height - 2.0]:
					var offset := normal * 0.12
					var c: Vector3 = a + Vector3.UP * h + offset
					var d: Vector3 = b + Vector3.UP * h + offset
					_quad("details", c - offset * 2.0, c + Vector3.UP * 0.26 - offset * 2.0,
						d + Vector3.UP * 0.26 - offset * 2.0, d - offset * 2.0, color.lightened(0.22), normal)
					_quad("details", c, c + Vector3.UP * 0.26, d + Vector3.UP * 0.26, d,
						color.lightened(0.22), normal)

func _attach(root: Node3D, key: String, material: int, begin := 0.0, end := 0.0) -> void:
	if not surfaces.has(key):
		return
	var st: SurfaceTool = surfaces[key]
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = key
	if key in ["ground","seabed","roads","footways","lawn","paint","water","Contact","Spill"]:
		mi.layers = 2
	mi.mesh = st.commit()
	mi.material_override = materials[material]
	mi.visibility_range_begin = begin
	mi.visibility_range_end = end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key in ["buildings", "near_buildings", "StreetDetail"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root

func _batch(root: Node3D, label: String, items: Array, mesh: Mesh, color: Color, height: float, distance_limit: float, begin := 0.0, override: Material = null) -> void:
	if items.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index in items.size():
		var item: Array = items[index]
		var scale_factor: float = item[2] if label != "LampPoles" else 1.0
		var yaw := float(index % 17) * 0.31 if label.begins_with("Tree") else 0.0
		multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), _point(item, 0, height * scale_factor) - origin))
	var mi := MultiMeshInstance3D.new()
	mi.name = label
	mi.multimesh = multi
	mi.material_override = override if override != null else material
	mi.visibility_range_begin = begin
	mi.visibility_range_end = distance_limit
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root

func _bake(key: String, data: Dictionary) -> void:
	surfaces = {}
	solid = PackedVector3Array()
	var root := Node3D.new()
	root.name = "Chunk_" + key.replace("-", "N")
	origin = _center(key)
	street_center = not data.get("street_props", []).is_empty()
	root.position = origin
	_flat(data.get("ground", []), 0.0, "ground", Color("#545953"), true)
	_flat(data.get("water", []), -0.62, "water", Color.WHITE)
	_flat(data.get("water", []), -5.4, "seabed", Color("#26352e"), true)
	_flat(data.get("park", []), 0.017, "lawn", Color("#395c43"))
	for row in data.get("road", []):
		var rank := int(row[0])
		var key_name := "footways" if rank in [0, 4] else "roads"
		_flat(row[2], row[1], key_name, Color("#a8a49d") if rank in [0, 4] else ROAD_COLORS[rank].lightened(0.36))
	for row in data.get("deck", []):
		_flat(row[1], row[0], "roads", Color("#41454d"), true)
	for row in data.get("marks", []):
		var a := _point(row, 0, row[4])
		var b := _point(row, 2, row[4])
		var side := (b - a).cross(Vector3.UP).normalized() * 0.075
		_quad("paint", a - side, b - side, b + side, a + side, Color("#ddd9bf"), Vector3.UP)
	for row in data.get("street_props", []):
		_fixture(row)
	for row in data.get("crossings", []):
		var p := _point(row, 0, .074)
		var direction := Basis(Vector3.UP, row[2])
		var width: float = row[3]
		for ix in range(-floori(width), floori(width)+1):
			if ix % 2 == 0:
				_box_surface("paint", p + direction.x * ix * .49, Vector3(.38,.009,2.9), row[2], Color("#d5d3c6"))
	for row in data.get("lamps", []):
		var p := _point(row, 0, 5.5)
		var forward := Vector3(sin(row[2]), 0, cos(row[2]))
		var side := forward.cross(Vector3.UP)
		if street_center:
			_pool(Vector3(p.x,.084,p.z) + side*3.15, row[2])
		_quad("lamp_glow", p - side * 0.25, p - side * 0.25 + forward * 0.54,
			p + side * 0.25 + forward * 0.54, p + side * 0.25, Color("#ffe2a3"), Vector3.UP)
	for row in data.get("supports", []):
		var p := _point(row, 0, 0.0)
		var h: float = row[2]
		var ring := [[p.x - 0.81, p.z - 0.72], [p.x - 0.81, p.z + 0.72], [p.x + 0.81, p.z + 0.72], [p.x + 0.81, p.z - 0.72]]
		for j in 4:
			var a := _point(ring[j], 0, 0.0)
			var b := _point(ring[(j + 1) % 4], 0, 0.0)
			_quad("details", a, a + Vector3.UP * h, b + Vector3.UP * h, b, Color("#686a66"), (b - a).cross(Vector3.UP).normalized(), true)
	var distant := {}
	for building in data.get("skyline", []):
		distant[building[0]] = true
	for building in data.get("buildings", []):
		_building(building, "near_buildings" if distant.has(building[0]) else "buildings", true)
	_attach(root, "ground", 2)
	_attach(root, "roads", 1)
	_attach(root, "footways", 5)
	_attach(root, "lawn", 6)
	_attach(root, "paint", 7, 0.0, 285.0)
	_attach(root, "water", 4)
	_attach(root, "seabed", 2)
	_attach(root, "buildings", 0)
	_attach(root, "near_buildings", 0, 0.0, 407.0)
	_attach(root, "details", 2, 0.0, 300.0)
	_attach(root, "lamp_glow", 3, 0.0, 430.0)
	_attach(root, "StreetDetail", 2, 0.0, 210.0)
	_attach(root, "Spill", 8, 0.0, 180.0)
	_attach(root, "Contact", 9, 0.0, 128.0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.115
	trunk.bottom_radius = 0.22
	trunk.rings = 0
	trunk.radial_segments = 6
	trunk.height = 3.9
	_batch(root, "TreeTrunks", data.get("trees", []), trunk, Color("#625b4d"), 1.95, 430.0)
	_batch(root, "TreeFoliage", data.get("trees", []), foliage, Color.WHITE, 4.85, 155.0, 0.0, leaf_material)
	var canopy := SphereMesh.new()
	canopy.radial_segments = 7
	canopy.rings = 4
	canopy.radius = 1.67
	canopy.height = 2.9
	_batch(root, "TreeCrowns", data.get("trees", []), canopy, Color("#445539"), 4.8, 480.0, 150.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.050
	pole.bottom_radius = 0.11
	pole.radial_segments = 6
	pole.rings = 0
	pole.height = 5.5
	_batch(root, "LampPoles", data.get("lamps", []), pole, Color("#3b4349"), 2.75, 380.0)
	if not solid.is_empty():
		var body := StaticBody3D.new()
		body.name = "Geometry"
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(solid)
		collider.shape = shape
		root.add_child(body)
		body.owner = root
		body.add_child(collider)
		collider.owner = root
	_save(root, "res://maps/chunks/%s.scn" % key)

func _save(root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not bake %s (%s)" % [path, error])
	root.free()

extends Node3D

const A = preload("res://scripts/art.gd")
const SURFACE = preload("res://shaders/landmarks.gdshader")
const MODEL_KEYS := ["pearl", "shanghai", "jinmao", "swfc", "convention", "peace", "customs", "bridge"]
const PALETTE := {
	"Limestone": ["#b7afa1", 0, 0.0, 0.78], "Plinth": ["#84827a", 0, 0.0, 0.78],
	"Steel": ["#657476", 1, 0.60, 0.48], "Silver": ["#9aa9ac", 1, 0.62, 0.42],
	"Glazing": ["#657d8d", 2, 0.50, 0.22], "GlassDark": ["#364853", 2, 0.38, 0.31],
	"Rose": ["#9d4160", 1, 0.35, 0.41], "Copper": ["#47655e", 1, 0.43, 0.58],
	"NightWarm": ["#f0af68", 3, 0.05, 0.44], "NightRose": ["#ed3868", 4, 0.12, 0.41],
	"NightCool": ["#70bbdf", 5, 0.12, 0.42], "Clock": ["#e5d4a1", 3, 0.0, 0.57],
}
var models: Array[Dictionary] = []
var materials: Dictionary = {}
var lod_clock := 0.0

func build(specs: Array, bridge_ends: Array) -> void:
	for entry in specs:
		var key: String = entry[0]
		if key not in MODEL_KEYS and key != "wharf":
			continue
		var root := Node3D.new()
		root.name = key
		root.position = Vector3(entry[3][0], 0, entry[3][1])
		add_child(root)
		if key == "wharf":
			_wharf(root)
			continue
		var near := _mesh(root, key, "near")
		var far := _mesh(root, key, "far")
		far.hide()
		if key in ["swfc", "peace", "customs"]:
			root.rotation.y = {"swfc":0.12,"peace":-0.27925,"customs":-0.33161}[key]
		if key == "bridge":
			var begin := Vector3(bridge_ends[0][0], 3.65, bridge_ends[0][1])
			var end := Vector3(bridge_ends[1][0], 3.65, bridge_ends[1][1])
			root.position = begin.lerp(end, .5)
			root.rotation.y = atan2(end.x-begin.x, end.z-begin.z)
			for part in [near, far]:
				part.scale.z = begin.distance_to(end) / 106.0
			_bridge_approaches(root, begin.distance_to(end) * 0.5)
		else:
			_place_collision(root, key)
		models.append({"root": root, "near": near, "far": far, "key": key})

func _mesh(root: Node3D, key: String, detail: String) -> Node3D:
	var scene: PackedScene = load("res://assets/landmarks/models/%s_%s.glb" % [key,detail])
	var asset := scene.instantiate() as Node3D
	root.add_child(asset)
	for item in asset.find_children("*", "MeshInstance3D", true, false):
		var mat_name: String = item.mesh.surface_get_material(0).resource_name
		item.material_override = _material(mat_name)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail == "near" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return asset

func _material(mat_name: String) -> Material:
	if materials.has(mat_name):
		return materials[mat_name]
	var spec: Array = PALETTE.get(mat_name, PALETTE.Limestone)
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("finish", Color(spec[0]))
	mat.set_shader_parameter("material_kind", spec[1])
	mat.set_shader_parameter("metal", spec[2])
	mat.set_shader_parameter("rough", spec[3])
	var texture_name := "concrete" if int(spec[1]) == 0 else "metal"
	mat.set_shader_parameter("color_tex", load("res://assets/textures/pbr/%s_albedo.jpg" % texture_name))
	mat.set_shader_parameter("rough_tex", load("res://assets/textures/pbr/%s_rma.png" % texture_name))
	materials[mat_name] = mat
	return mat

func update_lod(at: Vector3, quality: int, scale_factor: float, delta: float) -> void:
	lod_clock += delta
	if lod_clock < 0.3:
		return
	lod_clock = 0.0
	var cutoff: float = [100.0, 175.0, 245.0, 355.0, 560.0][quality] * scale_factor
	for entry in models:
		var anchor: Vector3 = entry.root.position
		var close := Vector2(at.x,at.z).distance_squared_to(Vector2(anchor.x,anchor.z)) < cutoff*cutoff
		entry.near.visible = close
		entry.far.visible = not close

func _place_collision(root: Node3D, key: String) -> void:
	match key:
		"pearl":
			A.collider(root, Vector3(0,2.7,0), Vector3(36,5.4,34))
			A.collider(root, Vector3(0,43,0), Vector3(14,83,14))
			for i in 3:
				var angle := i*TAU/3.0 + .2
				A.collider(root,Vector3(cos(angle)*37,2,sin(angle)*37),Vector3(10,7,10))
		"shanghai":
			A.collider(root,Vector3(0,5,0),Vector3(58,10,57))
		"jinmao":
			A.collider(root,Vector3(0,14,0),Vector3(52,28,52))
		"swfc":
			A.collider(root,Vector3(0,18,0),Vector3(54,36,38))
		"convention":
			A.collider(root,Vector3(0,10,2),Vector3(96,20,57))
			for x in [-48.0,48.0]:
				A.collider(root,Vector3(x,12,-17),Vector3(32,24,32))
		"peace":
			A.collider(root,Vector3(0,15.5,0),Vector3(55,31,46))
		"customs":
			A.collider(root,Vector3(0,13,0),Vector3(36,26,28))

func _bridge_approaches(root: Node3D, half_span: float) -> void:
	for side in [-1.0, 1.0]:
		var a := Vector3(0,0,side*half_span)
		var b := Vector3(0,-3.55,side*(half_span+19))
		var shape := Vector3(11,.4,a.distance_to(b))
		var ramp := A.collider(root,a.lerp(b,.5)-Vector3.UP*.19,shape)
		ramp.basis = Basis.looking_at(ramp.position.direction_to(b),Vector3.UP)
		A.box(ramp,Vector3.ZERO,shape,_material("Steel"))

func _wharf(root: Node3D) -> void:
	root.rotation.y = deg_to_rad(-29)
	A.box(root, Vector3(0,0.5,0), Vector3(15,1,49), _material("Limestone"))
	A.collider(root, Vector3(0,0.5,0), Vector3(15,1,49))
	A.box(root, Vector3(0,4.8,0), Vector3(12,.65,38), _material("Copper"))
	for z in [-15,-5,5,15]:
		for x in [-5,5]:
			A.cylinder(root,Vector3(x,2.5,z),5,.35,.3,_material("Steel"),9)

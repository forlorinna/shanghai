extends RefCounted

const A = preload("res://scripts/art.gd")
const PAINT = preload("res://shaders/automotive.gdshader")
const SHADOW = preload("res://shaders/contact_shadow.gdshader")
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
static var contact_mat: ShaderMaterial

static func finish(color: Color, kind := 0, damage := 0.0) -> ShaderMaterial:
	var key := [color, kind, roundi(damage * 10)]
	if materials.has(key):
		return materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = PAINT
	mat.set_shader_parameter("paint", color)
	mat.set_shader_parameter("finish", kind)
	mat.set_shader_parameter("damage", damage)
	materials[key] = mat
	return mat

static func _vertex(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.add_vertex(p)

static func _grid(st: SurfaceTool, rings: Array, profile_count: int) -> void:
	for row in range(1, rings.size()):
		var a: Array = rings[row - 1]
		var b: Array = rings[row]
		for j in range(1, profile_count):
			var u := float(j) / (profile_count - 1)
			var v := float(row) / (rings.size() - 1)
			var previous_v := float(row - 1) / (rings.size() - 1)
			var previous_u := float(j - 1) / (profile_count - 1)
			_vertex(st, a[j-1], Vector2(previous_v,previous_u))
			_vertex(st, a[j], Vector2(previous_v,u))
			_vertex(st, b[j], Vector2(v,u))
			_vertex(st, a[j-1], Vector2(previous_v,previous_u))
			_vertex(st, b[j], Vector2(v,u))
			_vertex(st, b[j-1], Vector2(v,previous_u))

static func body(size: Vector3, low: bool) -> Mesh:
	var key := [size, low]
	if meshes.has(key):
		return meshes[key]
	var rings := []
	var count := 28 if low else 76
	var w := size.x * .5
	var h := size.y
	var l := size.z
	var wheel_radius := clampf(h*.235,.27,.49)
	var axle := size.z * .32
	for j in range(count + 1):
		var u := float(j)/count
		var z := (u-.5)*l
		var end := pow(absf(u*2.0-1.0), 6.0)
		var belly := w*(1.0-end*(.16 if u<.5 else .13))
		var top := h*(.595-.155*end + .025*sin(u*PI*2.0))
		var bottom := h*.15 + end*.055
		var near_wheel := absf(absf(z)-axle)
		var r := wheel_radius*1.13
		if near_wheel < r:
			bottom = maxf(bottom, wheel_radius+sqrt(r*r-near_wheel*near_wheel))
		bottom = minf(bottom, top-.075)
		rings.append([
			Vector3(-belly*.87,bottom,z), Vector3(-belly*.985,bottom+.035,z),
			Vector3(-belly*1.015,lerpf(bottom,top,.62),z), Vector3(-belly*.95,top-.037,z),
			Vector3(-belly*.77,top,z), Vector3(0,top+.028,z),
			Vector3(belly*.77,top,z), Vector3(belly*.95,top-.037,z),
			Vector3(belly*1.015,lerpf(bottom,top,.62),z), Vector3(belly*.985,bottom+.035,z), Vector3(belly*.87,bottom,z),
		])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st,rings,11)
	for o in [0,rings.size()-1]:
		var row: Array = rings[o]
		for j in range(2,row.size()):
			_vertex(st, row[0], Vector2(0,0))
			_vertex(st, row[j] if o == 0 else row[j-1], Vector2(.5,.5))
			_vertex(st, row[j-1] if o == 0 else row[j], Vector2(1,1))
	st.generate_normals()
	st.index()
	var result := st.commit()
	meshes[key] = result
	return result

static func greenhouse(root: Node3D, size: Vector3, paint: Material, glass: Material, ratio: float, low: bool) -> void:
	var span := size.z * ratio
	var base := size.y * .56
	var crown := size.y * .94
	var w := size.x*.5
	var glass_rings := []
	var roof_rings := []
	for j in range(13):
		var u := j/12.0
		var z := (u-.5)*span + span*.045
		var slope := minf(smoothstep(0.0,.26,u),smoothstep(1.0,.79,u))
		var height := lerpf(base+.03,crown,slope)
		var shoulder := w*(.82 - .04*pow(absf(2.0*u-1.0), 3.0))
		var lip := shoulder*(.77 + .22*(1.0-slope))
		glass_rings.append([Vector3(-shoulder,base,z), Vector3(-lip,height,z),
			Vector3(0,height+.029*slope,z), Vector3(lip,height,z), Vector3(shoulder,base,z)])
		if j > 2 and j < 10:
			roof_rings.append([Vector3(-lip-.011,height+.025,z), Vector3(0,height+.055,z), Vector3(lip+.011,height+.025,z)])
	var window_mesh := SurfaceTool.new()
	window_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(window_mesh,glass_rings,5)
	window_mesh.generate_normals()
	A.mesh(root,window_mesh.commit(),Vector3.ZERO,glass)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(roof, roof_rings, 3)
	roof.generate_normals()
	A.mesh(root,roof.commit(),Vector3.ZERO,paint)
	if not low:
		var rubber := A.material(Color("#1c2323"),.13,.72)
		for side in [-1.0, 1.0]:
			for j in [3,7,9]:
				var ring: Array = glass_rings[j]
				var lower: Vector3 = ring[0] if side < 0 else ring[-1]
				var upper: Vector3 = ring[1] if side < 0 else ring[-2]
				A.beam(root,lower+Vector3(side*.008,0,0),upper+Vector3(side*.008,0,0),.024,rubber,5)

static func contact(root: Node3D, size: Vector2) -> void:
	if contact_mat == null:
		contact_mat = ShaderMaterial.new()
		contact_mat.shader = SHADOW
	var plane := PlaneMesh.new()
	plane.size = size
	var item := A.mesh(root,plane,Vector3.UP*.083,contact_mat)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.visibility_range_end = 70.0

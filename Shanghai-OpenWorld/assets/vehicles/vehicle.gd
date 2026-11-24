extends CharacterBody3D

const A = preload("res://scripts/art.gd")
const Imported = preload("res://assets/vehicles/imported_vehicle.gd")
const Art = preload("res://assets/vehicles/vehicle_art.gd")
const TYPES := ["sedan", "suv", "sports", "taxi", "bus", "motorcycle", "police"]
const SIZES := [
	Vector3(1.82, 1.46, 4.40), Vector3(2.02, 1.92, 4.64), Vector3(1.98, 1.25, 4.30),
	Vector3(1.84, 1.53, 4.43), Vector3(2.62, 3.18, 9.2), Vector3(0.67, 1.26, 2.18),
	Vector3(1.86, 1.54, 4.58),
]
const TOP_SPEED := [38.0, 35.0, 54.0, 36.0, 25.0, 45.0, 44.0]
var game
var variant := 0
var paint := Color("#458b9d")
var size := Vector3.ONE
var active := false
var speed := 0.0
var steering := 0.0
var integrity := 100.0
var shell := Node3D.new()
var wheels: Array[Node3D] = []
var wheel_rest: Array[Vector3] = []
var imported := false
var wheel_spinning: Array[Node3D] = []
var sedan_paint: StandardMaterial3D
var model_headlights: Array[BaseMaterial3D] = []
var model_brakelights: Array[BaseMaterial3D] = []
var suspension_clocks := 0.0
var body_pitch := 0.0
var headlamps: Array[MeshInstance3D] = []
var rear: Array[MeshInstance3D] = []
var signals: Array[MeshInstance3D] = []
var body_panels: Array[MeshInstance3D] = []
var door: Node3D
var door_timer := 0.0
var light: SpotLight3D
var cooldown := 0.0
var surface_clock := 0.0
var engine: AudioStreamPlayer3D
var spray: GPUParticles3D
var blades: Array[Node3D] = []

func create(context, model: int, color: Color, is_traffic := false, stripped := false) -> void:
	game = context
	variant = clampi(model, 0, TYPES.size() - 1)
	paint = color
	size = SIZES[variant]
	collision_layer = 4 if not is_traffic else 8
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.58
	floor_max_angle = deg_to_rad(47)
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * 0.94, size.y * 0.74, size.z * 0.96)
	hit.shape = shape
	hit.position.y = shape.size.y * 0.5 + 0.014
	add_child(hit)
	add_child(shell)
	imported = Imported.mount(self, stripped)
	if not imported:
		_build(stripped)
	if not is_traffic:
		engine = AudioStreamPlayer3D.new()
		engine.stream = context.audio.samples.get("motor")
		engine.unit_size = 10.0
		engine.max_distance = 55.0
		engine.bus = &"Effects"
		engine.volume_db = -16
		add_child(engine)

func _panel(at: Vector3, extent: Vector3, mat: Material, contoured := false) -> MeshInstance3D:
	var part := A.coachwork(shell, at, extent, mat) if contoured else A.box(shell, at, extent, mat)
	body_panels.append(part)
	return part

func _build(stripped: bool) -> void:
	var body := Art.finish(paint)
	var tires := A.material(Color("#1d2228"))
	var trim := A.material(Color("#25313a"), 0.30)
	var windows := Art.finish(Color("#50636c"),1)
	var metal := A.material(Color("#a2aeb0"), 0.6, 0.32)
	var red := A.material(Color("#b73d37"))
	var white := A.material(Color("#e9f3f1"), 0.1, 0.28)
	var w := size.x
	var h := size.y
	var l := size.z
	if variant == 5:
		_panel(Vector3(0, h * 0.62, -l * 0.14), Vector3(w * 0.91, h * 0.52, l * 0.50), body)
		A.box(shell, Vector3(0, h * 0.72, l * 0.13), Vector3(w * 0.66, 0.15, l * 0.46), trim)
		A.beam(shell, Vector3(0, 0.43, -l * 0.30), Vector3(0, 1.14, -l * 0.17), 0.04, metal)
		A.box(shell, Vector3(0, 1.16, -l * 0.17), Vector3(w, 0.075, 0.08), trim)
	else:
		if variant == 4:
			_panel(Vector3(0,h*.32,0),Vector3(w,h*.47,l),body)
		else:
			body_panels.append(A.mesh(shell, Art.body(size,stripped), Vector3.ZERO, body))
		var cabin_ratio := 0.89 if variant == 4 else (0.70 if variant == 1 else 0.58)
		if variant == 4:
			A.box(shell,Vector3(0,h*.72,0),Vector3(w*.97,h*.32,l*cabin_ratio),windows)
			_panel(Vector3(0,h*.94,0),Vector3(w*.98,h*.08,l*.92),body)
		else:
			Art.greenhouse(shell,size,body,windows,cabin_ratio,stripped)
		var front := -l * .512
		var intake := A.material(Color("#181e21"), .21, .83)
		A.coachwork(shell,Vector3(0,h*.321,front+.016),Vector3(w*.53,h*.136,.087),trim)
		A.box(shell,Vector3(0,h*.322,front-.037),Vector3(w*.45,h*.090,.021),intake)
		A.box(shell,Vector3(0,h*.326,front-.056),Vector3(w*.465,.022,.021),metal)
		var lower := A.box(shell,Vector3(0,h*.208,front+.014),Vector3(w*.77,.072,.083),intake)
		lower.rotation.x = -.13
		for side in [-1.0,1.0]:
			var inlet := A.box(shell,Vector3(side*w*.292,h*.241,front+.049),Vector3(w*.119,h*.075,.071),intake)
			inlet.rotation.y = side*.13
		A.box(shell, Vector3(0,h*.299,l*.47), Vector3(w*.8,h*.085,.072),trim)
		if not stripped and variant != 4:
			_details(trim, metal, body)
			Art.contact(self,Vector2(w*1.51,l*1.10))
		if variant == 3 or variant == 6:
			A.box(shell, Vector3(0, h * 1.01, 0), Vector3(w * 0.48, 0.13, 0.28), A.material(Color("#ffce63") if variant == 3 else Color("#519dff"), 0, 0.5, true))
		if not stripped:
			door = Node3D.new()
			door.position = Vector3(-w * 0.508, h * 0.52, -l * 0.12)
			shell.add_child(door)
			var door_panel := A.box(door, Vector3(w*.011, 0, l * 0.118), Vector3(.025,h*.16,l*.238),body)
			body_panels.append(door_panel)
			A.box(door, Vector3(-0.042, h * 0.039, l * 0.20), Vector3(0.04, 0.036, 0.15), metal)
	for side in ([-1, 1] if variant != 5 else [0]):
		for axle in [-1, 1]:
			var radius := clampf(h * 0.235, 0.27, 0.49)
			var tire := Node3D.new()
			tire.position = Vector3(side * w * 0.46, radius, axle * l * 0.32)
			tire.rotation.z = PI * 0.5
			shell.add_child(tire)
			A.cylinder(tire, Vector3.ZERO, .192, radius, radius, tires, 32 if not stripped else 13)
			if not stripped:
				A.cylinder(tire, Vector3(0,.082,0), .029, radius*.961, radius*.98, tires, 32)
				A.cylinder(tire, Vector3(0,-.082,0), .029, radius*.98, radius*.961, tires, 32)
				var face := -(1.0 if side >= 0 else -1.0)
				A.cylinder(tire, Vector3(0,face*.096,0),.03,radius*.76,radius*.76,trim,27)
				A.cylinder(tire, Vector3(0,face*.114,0),.020,radius*.28,radius*.28,metal,22)
				for spoke in 6:
					var angle := spoke*TAU/6.0
					var spoke_mesh := A.box(tire,Vector3(cos(angle)*radius*.41,face*.113,sin(angle)*radius*.41),Vector3(radius*.64,.021,radius*.135),metal)
					spoke_mesh.rotation.y = -angle
			wheels.append(tire)
			wheel_rest.append(tire.position)
	for side in ([-1, 1] if variant != 5 else [0]):
		var lamp := A.box(shell,Vector3(w*side*.30,h*.405,-l*.505),Vector3(w*.205,h*.037,.062),white)
		lamp.rotation.y = side*.215
		headlamps.append(lamp)
		if not stripped and variant != 5:
			var housing := A.box(shell,lamp.position+Vector3(0,-.023,.017),Vector3(w*.212,.068,.065),trim)
			housing.rotation.y = lamp.rotation.y
		rear.append(A.box(shell,Vector3(w*side*.31,h*.429,l*.487),Vector3(w*.196,h*.042,.075),red))
		if not stripped:
			signals.append(A.box(shell, Vector3(w * side * 0.467, h * 0.47, l * 0.499), Vector3(0.087, 0.11, 0.071), A.material(Color("#a65d29"))))

func repaint(color: Color) -> void:
	paint = color
	if imported:
		Imported.repaint(self)
		return
	var surface := Art.finish(paint,0,(100.0-integrity)*.01)
	for panel in body_panels:
		panel.material_override = surface

func use_driver(value: bool) -> void:
	active = value
	door_timer = 0.7
	if value and light == null:
		light = SpotLight3D.new()
		light.position = Vector3(0, size.y * 0.47, -size.z * 0.53)
		light.spot_range = 46
		light.spot_angle = 33
		light.rotation.x = -0.075
		light.light_color = Color("#e3f6ff")
		light.light_energy = 3.8
		add_child(light)
		if variant != 5:
			_make_spray()
	if engine:
		if value and engine.stream and DisplayServer.get_name() != "headless":
			engine.play()
		else:
			engine.stop()
	if light:
		light.visible = value and game.climate.night > 0.25

func animate_wheels(delta: float, value: float) -> void:
	if imported:
		Imported.roll(self, delta, value)
		return
	for tire in wheels:
		tire.rotate_object_local(Vector3.UP, -value * delta * 2.8)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_playing() or collision_layer == 8:
		return
	if not active and position.distance_squared_to(game.focus()) > 70_000:
		return
	if door_timer > 0.0:
		door_timer = maxf(door_timer - delta, 0.0)
		if door:
			door.rotation.y = -sin(door_timer * PI / 0.7) * 0.86
	var controls: Vector2 = game.motion() if active else Vector2.ZERO
	var brake: bool = active and game.flag("handbrake")
	var throttle := -controls.y
	var old_speed := speed
	cooldown = maxf(0.0, cooldown - delta)
	var drive := 12.8 if variant == 2 or variant == 5 else 9.6
	if integrity < 30.0:
		drive *= 0.62
	var reversing := throttle * speed < -0.4
	speed += throttle * (26.5 if reversing else drive) * delta
	speed = move_toward(speed, 0.0, (20.0 if brake else (1.0 + absf(speed) * 0.026)) * delta)
	speed = clampf(speed, -12.0, TOP_SPEED[variant])
	if absf(speed) < 0.35 and absf(throttle) < 0.08:
		speed = 0.0
	steering = lerpf(steering, controls.x, 1.0 - exp(-delta * 8.0))
	var grip: float = (0.85 - game.climate.wetness * 0.20) if brake else (1.0 - game.climate.wetness * 0.18)
	var steering_gain := (2.05 / (1.0 + absf(speed) * 0.079)) * minf(1.0, absf(speed) * 0.30)
	if active:
		rotation.y -= steering * steering_gain * signf(speed) * delta * float(game.settings.get("steering", 1.0))
		if brake and cooldown == 0.0 and absf(old_speed) > 12.0:
			game.feedback("drift" if absf(steering) > 0.3 else "brake", global_position)
			cooldown = 0.75
	var aim := -global_basis.z * speed
	var response := 1.0 - exp(-delta * (2.6 if brake else 11.0) * grip)
	velocity.x = lerpf(velocity.x, aim.x, response)
	velocity.z = lerpf(velocity.z, aim.z, response)
	velocity.y = -1.6 if is_on_floor() else velocity.y - 17.4 * delta
	var before_velocity := velocity
	move_and_slide()
	var impact := Vector2(velocity.x - before_velocity.x, velocity.z - before_velocity.z).length()
	if get_slide_collision_count() and impact > 2.0:
		speed *= 0.26 if impact > 8 else 0.57
		if cooldown == 0.0 and active:
			integrity = maxf(0, integrity - impact * 1.8)
			game.feedback("crash_heavy" if impact > 8.0 else "crash", global_position)
			game.collision_offence(impact, get_last_slide_collision().get_collider())
			if impact > 8.0 and imported:
				Imported.repaint(self)
			elif impact > 8.0 and not body_panels.is_empty():
				body_panels[0].scale.x = maxf(0.88, body_panels[0].scale.x - impact * 0.0016)
				body_panels[0].material_override = Art.finish(paint,0,(100.0-integrity)*.01)
			cooldown = 0.6
	if active and global_position.y < -11 and not game.in_tunnel:
		game.leave_vehicle(true)
		game.respawn()
		return
	animate_wheels(delta, speed)
	if not blades.is_empty():
		var wipe: float = (0.18+0.90*pow(maxf(0.0,sin(Time.get_ticks_msec()*.0044)),1.3)) if game.climate.wetness > .39 and active else .18
		for blade in blades:
			blade.rotation.z = wipe
	if spray:
		spray.emitting = active and is_on_floor() and absf(speed) > 7.4 and game.climate.wetness > .60
		spray.amount_ratio = clampf(absf(speed)/22.0, .16, 1.0)
	shell.rotation.z = lerpf(shell.rotation.z, steering * speed * (0.008 if variant == 5 else 0.0012), response)
	suspension_clocks += delta
	if active and suspension_clocks >= 0.055:
		_sample_suspension(suspension_clocks)
		suspension_clocks = 0
	shell.rotation.x = lerpf(shell.rotation.x, body_pitch + clampf((speed - old_speed) * 0.13, -0.075, 0.075), response)
	if active and engine:
		engine.pitch_scale = clampf(0.68 + absf(speed) * 0.038 + absf(throttle) * 0.12, 0.6, 2.25)
		if game.consume("horn"):
			game.audio.play_spatial("horn", global_position, -1.0)
	if active and is_on_floor() and absf(speed) > 9.0:
		surface_clock += delta
		if surface_clock > 2.9:
			surface_clock = 0.0
			if absf(get_floor_normal().y) < 0.985:
				game.feedback("bump", global_position)
	_lights(reversing or brake, active and game.flag("turn_left"), active and game.flag("turn_right"))

func _sample_suspension(delta: float) -> void:
	var front_height := 0.0
	var rear_height := 0.0
	for index in wheels.size():
		var tire := wheels[index]
		var rest := wheel_rest[index]
		var at := to_global(Vector3(rest.x, 0, rest.z))
		var params := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.65, at - Vector3.UP * 0.67, 1)
		var ground := get_world_3d().direct_space_state.intersect_ray(params)
		var lift := -0.15 if ground.is_empty() else clampf(float(ground.position.y) - global_position.y, -0.16, 0.16)
		var target_y := rest.y + lift
		if imported:
			var coordinates := tire.get_parent_node_3d().to_local(shell.to_global(Vector3(rest.x, target_y, rest.z)))
			target_y = coordinates.y
		tire.position.y = lerpf(tire.position.y, target_y, 1.0 - exp(-delta * 16.0))
		if rest.z < 0:
			front_height += lift
		else:
			rear_height += lift
	var axles := float(maxi(1, wheels.size() / 2))
	body_pitch = clampf((front_height - rear_height) / (size.z * axles), -0.12, 0.12)

func _lights(braking: bool, left: bool, right: bool) -> void:
	var night: bool = game.climate.night > 0.25
	if imported:
		Imported.lighting(self, night, braking, left, right)
		if light:
			light.visible = active and (night or game.climate.wetness > .63 or game.in_tunnel)
		return
	for lamp in headlamps:
		lamp.material_override = A.material(Color("#e1effe"), 0.1, 0.4, night)
	for lamp in rear:
		lamp.material_override = A.material(Color("#f35a4e") if braking else Color("#ae392e"), 0.05, 0.5, night or braking)
	var blink := (Time.get_ticks_msec() / 450) % 2 == 0
	for i in signals.size():
		signals[i].material_override = A.material(Color("#f4a445") if blink and (left if i == 0 else right) else Color("#a65d29"), 0, 0.6, blink and (left if i == 0 else right))
	if light:
		light.visible = active and (night or game.climate.wetness > .63 or game.in_tunnel)

func _details(trim: Material, metal: Material, coat: Material) -> void:
	var dashboard := A.box(shell,Vector3(0,size.y*.61,-size.z*.205),Vector3(size.x*.90,.105,.24),trim)
	dashboard.rotation.x = -.15
	var cluster := A.box(shell,Vector3(-size.x*.19,size.y*.68,-size.z*.185),Vector3(.24,.075,.085),A.material(Color("#43aab7"),.09,.55,true))
	cluster.rotation.x = -.2
	for side in [-1.0,1.0]:
		var x: float = side * size.x*.52
		A.beam(shell,Vector3(x*.90,size.y*.66,-size.z*.11),Vector3(x*1.07,size.y*.65,-size.z*.125),.027,trim,6)
		var mirror := A.sphere(shell,Vector3(x*1.08,size.y*.678,-size.z*.137),Vector3(.214,.101,.14),coat,14)
		mirror.rotation.y = side*.12
		A.box(shell,Vector3(x*1.10,size.y*.679,-size.z*.121),Vector3(.153,.066,.024),metal)
		A.box(shell,Vector3(x*.926,size.y*.564,size.z*.092),Vector3(.035,.022,.134),metal)
		var axle := Node3D.new()
		axle.position = Vector3(side*size.x*.18,size.y*.626,-size.z*.252)
		axle.rotation.x = -.54
		shell.add_child(axle)
		A.box(axle,Vector3(.13,0,0),Vector3(.26,.014,.014),trim)
		blades.append(axle)
	var plate := Label3D.new()
	plate.text = "沪 A · 0208"
	plate.font = load("res://assets/textures/city-font.otf")
	plate.font_size = 40
	plate.outline_size = 0
	plate.pixel_size = .00165
	plate.modulate = Color("#f5f5ed")
	plate.position = Vector3(0,size.y*.334,size.z*.499 + .018)
	plate.visibility_range_end = 25
	shell.add_child(plate)
	var plate_mat := A.material(Color("#244986"),.12,.65)
	A.box(shell,plate.position+Vector3.FORWARD*.021,Vector3(.365,.106,.025),plate_mat)
	var front := plate.duplicate() as Label3D
	front.position = Vector3(0,size.y*.296,-size.z*.514-.034)
	front.rotation.y = PI
	shell.add_child(front)
	A.box(shell,front.position-Vector3.FORWARD*.018,Vector3(.365,.106,.025),plate_mat)

func _make_spray() -> void:
	spray = GPUParticles3D.new()
	spray.amount = 46
	spray.lifetime = .51
	spray.emitting = false
	spray.position = Vector3(0,.20,size.z*.32)
	spray.visibility_aabb = AABB(Vector3(-2,-1,-2),Vector3(4,3,9))
	var settings := ParticleProcessMaterial.new()
	settings.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	settings.emission_box_extents = Vector3(size.x*.44,.12,.13)
	settings.direction = Vector3(0,.38,1)
	settings.spread = 29.0
	settings.initial_velocity_min = 2.1
	settings.initial_velocity_max = 5.0
	settings.gravity = Vector3(0,-6.1,0)
	spray.process_material = settings
	var drop := BoxMesh.new()
	drop.size = Vector3(.073,.027,.12)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(.54,.61,.64,.28)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = water
	spray.draw_pass_1 = drop
	add_child(spray)

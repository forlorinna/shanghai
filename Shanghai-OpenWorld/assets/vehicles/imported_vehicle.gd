extends RefCounted

const DIRECTORY := "res://assets/vehicles/models/"
const MODELS := {0:"sedan", 1:"suv", 2:"m4", 3:"sedan", 4:"city_bus", 6:"sedan"}
const PHOTO_SHADOW = preload("res://assets/vehicles/vehicle_art.gd")

static func mount(car, traffic: bool) -> bool:
	if not MODELS.has(car.variant):
		return false
	var name: String = MODELS[car.variant]
	var path := DIRECTORY + name + ("_traffic.glb" if traffic else "_near.glb")
	if not ResourceLoader.exists(path):
		if name == "city_bus":
			return false
		name = "m4"
		path = DIRECTORY + name + ("_traffic.glb" if traffic else "_near.glb")
	var packed := load(path) as PackedScene
	if not packed:
		return false
	var asset := packed.instantiate() as Node3D
	asset.name = "ImportedBody"
	car.shell.add_child(asset)
	if name == "city_bus":
		asset.rotation.y = PI
		asset.scale = Vector3(car.size.x/2.55, car.size.y/3.1, car.size.z/12.0)
	else:
		var imported_size: Vector3 = Vector3(2.00, 1.44, 4.59) if name == "m4" else car.size
		asset.scale = car.size/imported_size
	for part: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
		if traffic:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var first := part.mesh.surface_get_material(0) as BaseMaterial3D
		if first == null:
			continue
		var tag := (String(part.name) + " " + first.resource_name).to_lower()
		if tag.begins_with("paint") or tag.contains("exterior_paint") or (name == "m4" and tag.contains("mesheszx1mtl")):
			car.body_panels.append(part)
		for surface in part.mesh.get_surface_count():
			var source := part.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var finish := source.resource_name.to_lower()
			if tag.begins_with("headlight") or finish.contains("light_front"):
				var lamp := source.duplicate() as BaseMaterial3D
				part.set_surface_override_material(surface, lamp)
				car.model_headlights.append(lamp)
			elif tag.begins_with("taillight") or finish.contains("lamp_red") or finish.contains("light_rear"):
				var lamp := source.duplicate() as BaseMaterial3D
				part.set_surface_override_material(surface, lamp)
				car.model_brakelights.append(lamp)
	for wheel_name in ["Wheel_LF", "Wheel_RF", "Wheel_LR", "Wheel_RR", "wheel_FL", "wheel_FR", "wheel_RL", "wheel_RR"]:
		var wheel := asset.find_child(wheel_name, true, false) as Node3D
		if wheel == null or wheel.get_child_count() == 0:
			continue
		var roll_node := Node3D.new()
		wheel.add_child(roll_node)
		for part in wheel.get_children():
			if part != roll_node:
				part.owner = null
				part.reparent(roll_node, false)
		car.wheel_spinning.append(roll_node)
		# The original local hub stays under the imported body. Use a meter-space
		# anchor for suspension queries, independent of model import scaling.
		var at := wheel.position
		var ancestor := wheel.get_parent() as Node3D
		while ancestor != car.shell:
			at = ancestor.transform * at
			ancestor = ancestor.get_parent() as Node3D
		var rest: Vector3 = at
		car.wheel_rest.append(rest)
		car.wheels.append(wheel)
	if name != "city_bus":
		repaint(car)
	if not traffic:
		_indicators(car)
		PHOTO_SHADOW.contact(car, Vector2(car.size.x * 1.46, car.size.z * 1.09))
	if car.variant in [3, 6]:
		_service_sign(car)
	return true

static func repaint(car) -> void:
	if car.sedan_paint == null:
		car.sedan_paint = StandardMaterial3D.new()
		car.sedan_paint.metallic = .61
		car.sedan_paint.clearcoat_enabled = true
		car.sedan_paint.clearcoat = .83
		car.sedan_paint.clearcoat_roughness = .16
	car.sedan_paint.albedo_color = car.paint
	car.sedan_paint.roughness = lerpf(.3, .53, (100.0-car.integrity)*.01)
	for panel in car.body_panels:
		panel.material_override = car.sedan_paint

static func roll(car, delta: float, speed: float) -> void:
	for i in car.wheel_spinning.size():
		var front: bool = car.wheel_rest[i].z < 0.0
		if front and car.active and car.variant != 4:
			car.wheels[i].rotation.y = -car.steering * .37
		var radius: float = maxf(.23, car.wheel_rest[i].y)
		car.wheel_spinning[i].rotate_object_local(Vector3.RIGHT, -speed * delta / radius)

static func lighting(car, night: bool, braking: bool, left: bool, right: bool) -> void:
	for material: BaseMaterial3D in car.model_headlights:
		material.emission_enabled = night
		material.emission = Color("#e7f4ff")
		material.emission_energy_multiplier = 1.55
	for material: BaseMaterial3D in car.model_brakelights:
		material.emission_enabled = night or braking
		material.emission = Color("#d62919")
		material.emission_energy_multiplier = 2.4 if braking else 1.1
	var pulse := (Time.get_ticks_msec() / 430) % 2 == 0
	for i in car.signals.size():
		car.signals[i].visible = pulse and (left if i < 2 else right)

static func _indicators(car) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#e9a041")
	material.emission_enabled = true
	material.emission = Color("#ff9f13")
	material.emission_energy_multiplier = 3.5
	var lens := SphereMesh.new()
	lens.radial_segments = 10
	lens.rings = 4
	lens.radius = 0.05
	lens.height = 0.027
	lens.material = material
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var indication := MeshInstance3D.new()
			indication.mesh = lens
			indication.rotate_x(PI*.5)
			var y: float = car.size.y * (.30 if car.variant == 4 else (.46 if end < 0 else .48))
			indication.position = Vector3(side*car.size.x*.36,y,end*car.size.z*.486)
			indication.hide()
			car.shell.add_child(indication)
			car.signals.append(indication)

static func _service_sign(car) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d9e2de") if car.variant == 3 else Color("#365d9c")
	material.roughness = .43
	var cover := BoxMesh.new()
	cover.size = Vector3(.40, .09, .17)
	cover.material = material
	var mount_point := MeshInstance3D.new()
	mount_point.mesh = cover
	mount_point.position = Vector3(0, car.size.y+.025, .045)
	car.shell.add_child(mount_point)
	if car.variant == 3:
		for side in [-1.0, 1.0]:
			var text := Label3D.new()
			text.text = "TAXI"
			text.modulate = Color("#283531")
			text.position = Vector3(0, .006, side * .086)
			text.rotation.y = 0.0 if side > 0 else PI
			text.font_size = 48
			text.pixel_size = .0014
			text.outline_size = 0
			mount_point.add_child(text)

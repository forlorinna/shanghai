extends Node3D

const A = preload("res://scripts/art.gd")
var skeleton := Skeleton3D.new()
var bones: Dictionary = {}
var clock := 0.0
var gait := 0.0
var stance := 0.0
var preset := 0
var idle := 0.0
var articulation := 0.0
var seat := 0.0

func build(style := 0) -> void:
	preset = style
	add_child(skeleton)
	var skin := A.material(Color("#b78062") if style % 3 else Color("#ce9875"))
	var shirt := A.textured("fabric", [Color("#fffdf0"), Color("#d4ede7"), Color("#d6b58f")][style % 3],.89,2.4)
	var jacket := A.textured("fabric", [Color("#779eaa"), Color("#bc8b79"), Color("#768598"), Color("#cdb999")][style % 4],.81,3.0)
	var jeans := A.textured("fabric", [Color("#5d6d85"), Color("#655d62"), Color("#555956")][style % 3],.88,2.9)
	var shoes := A.material(Color("#20232a"))
	var hair := A.material(Color("#29211d"),.0,.81)
	var zipper := A.material(Color("#495452"),.39,.52)
	var eyes := A.material(Color("#312522"),.0,.30)
	var socks := A.material(Color("#868382"),.0,.88)
	var torso := _bone("hips", -1, Vector3(0, 0.88, 0))
	var chest := _bone("spine", bones.hips, Vector3(0, 0.22, 0))
	var head := _bone("neck", bones.spine, Vector3(0, 0.34, 0))
	A.sphere(torso, Vector3(0, 0.06, 0), Vector3(0.39, 0.34, 0.25), jeans, 10)
	var torso_width := 0.415 + (style % 4) * .012
	A.coachwork(chest, Vector3(0,.09,0), Vector3(torso_width,.49,.234), jacket, true)
	A.sphere(chest,Vector3(0,.290,-.005),Vector3(.122,.122,.114),shirt,12)
	A.box(chest,Vector3(0,.113,-.119),Vector3(.028,.38,.005),zipper)
	for side in [-1.0,1.0]:
		var lapel := A.box(chest,Vector3(side*.075,.272,-.103),Vector3(.060,.13,.013),jacket)
		lapel.rotation.z = side*.38
		var pocket := A.box(chest,Vector3(side*.114,.032,-.121),Vector3(.105,.024,.012),jacket)
		pocket.rotation.z = side*.20
	A.sphere(head,Vector3(0,.121,.003),Vector3(.204,.263,.191),skin,24)
	A.sphere(head,Vector3(0,.071,-.017),Vector3(.153,.144,.151),skin,20)
	A.sphere(head,Vector3(-.014,.228,.016),Vector3(.215,.112,.205),hair,22)
	A.sphere(head,Vector3(.008,.193,.041),Vector3(.204,.091,.139),hair,18)
	A.sphere(head,Vector3(0,.114,-.093),Vector3(.050,.062,.041),skin,14)
	for side in [-1.0,1.0]:
		A.sphere(head,Vector3(side*.101,.102,.003),Vector3(.034,.056,.029),skin,14)
		A.sphere(head,Vector3(side*.044,.145,-.081),Vector3(.025,.009,.009),eyes,8)
	for side in [-1, 1]:
		var tag := "l" if side == -1 else "r"
		var shoulder := _bone("arm_" + tag, bones.spine, Vector3(side * 0.212, 0.23, 0))
		A.sphere(shoulder, Vector3(0, -0.13, 0), Vector3(0.135, 0.38, 0.145), jacket)
		var elbow := _bone("forearm_" + tag, bones["arm_" + tag], Vector3(0, -0.262, 0))
		A.sphere(elbow, Vector3(0, -0.091, 0), Vector3(0.102, 0.24, 0.11), jacket)
		A.sphere(elbow, Vector3(0, -0.225, 0), Vector3(0.099, 0.155, 0.105), skin, 10)
		var hip := _bone("leg_" + tag, bones.hips, Vector3(side * 0.113, -0.033, 0))
		A.sphere(hip, Vector3(0, -0.15, 0), Vector3(0.185, 0.46, 0.196), jeans)
		var knee := _bone("calf_" + tag, bones["leg_" + tag], Vector3(0, -0.383, 0))
		A.sphere(knee, Vector3(0, -0.167, 0), Vector3(0.132, 0.416, 0.14), jeans)
		var shoe := A.coachwork(knee,Vector3(0,-.369,-.061),Vector3(.141,.109,.234),shoes)
		shoe.rotation.y = float(side) * .04
		A.coachwork(knee,Vector3(0,-.419,-.064),Vector3(.148,.031,.243),socks)

func _bone(label: String, parent: int, offset: Vector3) -> BoneAttachment3D:
	var index := skeleton.add_bone(label)
	bones[label] = index
	skeleton.set_bone_parent(index, parent)
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
	skeleton.set_bone_pose_position(index, offset)
	var socket := BoneAttachment3D.new()
	skeleton.add_child(socket)
	socket.bone_name = label
	return socket

func _bend(label: String, angles: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bones[label], Quaternion.from_euler(angles))

func animate(delta: float, speed: float, mode: String) -> void:
	gait = move_toward(gait, clampf(speed / 4.0, 0.0, 1.2), delta * 6.0)
	stance = move_toward(stance, 1.0 if mode == "crouch" else 0.0, delta * 6.0)
	clock += (2.4 + speed * 1.21) * delta if speed > .09 else 0.0
	idle += delta * 1.9
	var swing := sin(clock) * gait
	articulation = lerpf(articulation, 1.0 if mode in ["jump", "climb", "swim"] else 0.0, minf(1.0, delta * 8.3))
	seat = lerpf(seat, 1.0 if mode == "enter" else 0.0, minf(1.0, delta * 8.0))
	var dead := mode == "down"
	var step_lift := (absf(cos(clock))-.44) * .035 * gait
	skeleton.set_bone_pose_position(bones.hips, Vector3(sin(clock)*.018*gait, .88-stance*.28+step_lift-seat*.34+sin(idle)*.006,0))
	_bend("hips", Vector3(PI * 0.5 if dead else stance * 0.20, 0, 0))
	_bend("spine", Vector3(-gait * 0.10 - stance * 0.27, sin(clock) * gait * 0.11, 0.0))
	for side in [-1, 1]:
		var tag := "l" if side == -1 else "r"
		_bend("leg_" + tag, Vector3(swing * side * 0.71 - stance * .60 - articulation * .45 - seat*.67, 0.0, 0.04 * side))
		_bend("calf_" + tag, Vector3(maxf(0, swing * side * .92) + stance * .80 + seat*.95, 0, 0))
		_bend("arm_" + tag, Vector3(-swing * side * 0.57 + (-1.25*articulation - seat*.58), 0, 0.12 * side))
		_bend("forearm_" + tag, Vector3(-0.16 - gait * 0.34, 0, 0))

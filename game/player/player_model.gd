extends Node3D
## Simple procedural soldier made of a few primitive meshes (no imported assets).
## A cheap code-driven walk cycle swings arms and legs according to speed.

var _hips: Node3D
var _torso: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0
var _crouch := 0.0


func _ready() -> void:
	var cloth := _mat(Color(0.32, 0.38, 0.26))
	var dark := _mat(Color(0.16, 0.17, 0.15))
	var skin := _mat(Color(0.86, 0.68, 0.55))
	var gun := _mat(Color(0.1, 0.1, 0.11))

	_hips = Node3D.new()
	_hips.position.y = 0.95
	add_child(_hips)

	_torso = Node3D.new()
	_hips.add_child(_torso)
	_box(_torso, Vector3(0.46, 0.6, 0.26), Vector3(0, 0.32, 0), cloth)
	_box(_torso, Vector3(0.48, 0.2, 0.3), Vector3(0, 0.08, 0), dark)  # belt / vest bottom
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.14
	hs.height = 0.3
	hs.radial_segments = 12
	hs.rings = 6
	head.mesh = hs
	head.material_override = skin
	head.position = Vector3(0, 0.78, 0)
	_torso.add_child(head)
	_box(_torso, Vector3(0.3, 0.1, 0.32), Vector3(0, 0.9, -0.02), dark)  # cap

	_leg_l = _limb(_hips, Vector3(-0.13, 0, 0), Vector3(0.17, 0.92, 0.2), dark)
	_leg_r = _limb(_hips, Vector3(0.13, 0, 0), Vector3(0.17, 0.92, 0.2), dark)
	_arm_l = _limb(_torso, Vector3(-0.3, 0.58, 0), Vector3(0.13, 0.6, 0.14), cloth)
	_arm_r = _limb(_torso, Vector3(0.3, 0.58, 0), Vector3(0.13, 0.6, 0.14), cloth)
	# Rifle held in front.
	var rifle := Node3D.new()
	rifle.position = Vector3(0.12, 0.36, -0.32)
	_torso.add_child(rifle)
	_box(rifle, Vector3(0.07, 0.1, 0.75), Vector3.ZERO, gun)
	_box(rifle, Vector3(0.05, 0.16, 0.08), Vector3(0, -0.1, 0.12), gun)


func animate(delta: float, speed: float, on_floor: bool, crouching: bool, aiming: bool) -> void:
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, 1.0 - exp(-10.0 * delta))
	var stride := clampf(speed / 6.0, 0.0, 1.4)
	if on_floor and speed > 0.2:
		_phase += delta * (4.0 + speed * 1.3)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, 1.0 - exp(-8.0 * delta))
	var swing := sin(_phase) * 0.75 * stride
	var air := 0.0 if on_floor else 0.5
	_leg_l.rotation.x = swing + air - _crouch * 1.1
	_leg_r.rotation.x = -swing + air * 0.4 - _crouch * 0.4
	_hips.position.y = 0.95 - _crouch * 0.38 + absf(cos(_phase)) * 0.04 * stride
	_torso.rotation.x = -0.12 * stride - _crouch * 0.25
	if aiming:
		_arm_l.rotation.x = -1.35
		_arm_r.rotation.x = -1.5
	else:
		_arm_l.rotation.x = lerpf(-1.1, -swing * 0.6, clampf(stride, 0.0, 1.0) * 0.4)
		_arm_r.rotation.x = -1.25


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, s: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## A limb pivots at its top joint and hangs down.
func _limb(parent: Node3D, joint: Vector3, s: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	parent.add_child(pivot)
	_box(pivot, s, Vector3(0, -s.y * 0.5, 0), mat)
	return pivot

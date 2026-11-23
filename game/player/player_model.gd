extends Node3D
## Procedural city character with realistic proportions (1.8 m): jointed legs and
## arms, t-shirt (fabric normal map), jeans (denim), sneakers, hair and sunglasses.
## The look is configurable so pedestrians can reuse the same model.
## Both hands are placed on the rifle with two-bone IK.

const UPPER_ARM := 0.29
const FOREARM := 0.28
const HIP_Y := 0.98

## Appearance. Set before the node enters the tree.
var look := {
	"skin": Color(0.76, 0.58, 0.46),
	"shirt": Color(0.86, 0.86, 0.84),
	"pants": Color(1, 1, 1),
	"shoes": Color(0.92, 0.92, 0.9),
	"hair": Color(0.12, 0.09, 0.07),
	"armed": true,
}

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _rifle: Node3D
var _legs := {}     # "l"/"r" -> {thigh, knee, ankle}
var _arms := {}     # "l"/"r" -> {shoulder, elbow}
var _phase := 0.0
var _crouch := 0.0
var _aim := 0.0
var _stride := 0.0


func _ready() -> void:
	var shirt := Mats.pbr_uv("fabric", 3.0, look["shirt"], 0.95, "none")
	var jeans := Mats.pbr_uv("fabric", 2.0, look["pants"], 0.9, "denim")
	var skin := Mats.plain(look["skin"], 0.55)
	var hair := Mats.pbr_uv("fabric", 6.0, look["hair"], 0.8, "none")
	var shoes := Mats.plain(look["shoes"], 0.6)
	var sole := Mats.plain(Color(0.2, 0.2, 0.2), 0.8)
	var dark := Mats.plain(Color(0.06, 0.06, 0.07), 0.2, 0.3)

	_hips = _node(self, Vector3(0, HIP_Y, 0))
	_capsule(_hips, 0.14, 0.4, Vector3(0, 0.02, 0), jeans, Vector3(0, 0, PI * 0.5), Vector3(1, 1, 0.8))
	_capsule(_hips, 0.148, 0.34, Vector3(0, 0.09, 0), Mats.plain(Color(0.15, 0.1, 0.07), 0.5), Vector3(0, 0, PI * 0.5), Vector3(1, 0.25, 0.8))  # belt

	_torso = _node(_hips, Vector3(0, 0.08, 0))
	_capsule(_torso, 0.17, 0.56, Vector3(0, 0.27, 0), shirt, Vector3.ZERO, Vector3(1.15, 1, 0.7))
	_cyl(_torso, 0.055, 0.12, Vector3(0, 0.555, 0), skin)

	_head = _node(_torso, Vector3(0, 0.6, 0))
	_sphere(_head, 0.105, Vector3(0, 0.07, 0), skin, Vector3(0.92, 1.12, 1.0))
	_sphere(_head, 0.03, Vector3(0, 0.055, -0.105), skin, Vector3(0.7, 1.0, 1.0))       # nose
	_sphere(_head, 0.022, Vector3(-0.1, 0.07, 0), skin, Vector3(0.6, 1.2, 1.0))         # ears
	_sphere(_head, 0.022, Vector3(0.1, 0.07, 0), skin, Vector3(0.6, 1.2, 1.0))
	var cap := MeshInstance3D.new()       # short hair
	var hm := SphereMesh.new()
	hm.radius = 0.113
	hm.height = 0.12
	hm.is_hemisphere = true
	hm.radial_segments = 16
	hm.rings = 6
	cap.mesh = hm
	cap.material_override = hair
	cap.position = Vector3(0, 0.105, 0.008)
	cap.scale = Vector3(0.95, 1.0, 1.05)
	_head.add_child(cap)
	_box(_head, Vector3(0.16, 0.035, 0.02), Vector3(0, 0.085, -0.098), dark)   # sunglasses

	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		# Leg: hip -> knee -> ankle.
		var thigh := _node(_hips, Vector3(sx * 0.1, -0.03, 0))
		_capsule(thigh, 0.085, 0.47, Vector3(0, -0.21, 0), jeans)
		var knee := _node(thigh, Vector3(0, -0.43, 0))
		_capsule(knee, 0.068, 0.46, Vector3(0, -0.2, 0), jeans)
		var ankle := _node(knee, Vector3(0, -0.41, 0))
		_capsule(ankle, 0.058, 0.27, Vector3(0, -0.05, -0.05), shoes, Vector3(PI * 0.5, 0, 0), Vector3(1.05, 1, 0.7))
		_box(ankle, Vector3(0.11, 0.025, 0.28), Vector3(0, -0.085, -0.05), sole)
		_legs[side] = {"thigh": thigh, "knee": knee, "ankle": ankle}
		# Arm: short sleeve, bare forearm and hand (orientation set by IK every frame).
		var shoulder := _node(_torso, Vector3(sx * 0.21, 0.47, 0))
		_capsule(shoulder, 0.062, 0.2, Vector3(0, -0.06, 0), shirt)
		_capsule(shoulder, 0.05, UPPER_ARM + 0.02, Vector3(0, -UPPER_ARM * 0.55, 0), skin)
		var elbow := _node(shoulder, Vector3(0, -UPPER_ARM, 0))
		_capsule(elbow, 0.043, FOREARM + 0.04, Vector3(0, -FOREARM * 0.5, 0), skin)
		_sphere(elbow, 0.045, Vector3(0, -FOREARM - 0.03, 0), skin, Vector3(0.75, 1.15, 1.0))
		_arms[side] = {"shoulder": shoulder, "elbow": elbow}

	_rifle = _build_rifle(_torso)
	_rifle.visible = look["armed"]


func _build_rifle(parent: Node3D) -> Node3D:
	var metal := Mats.plain(Color(0.07, 0.07, 0.075), 0.35, 0.7)
	var polymer := Mats.plain(Color(0.12, 0.115, 0.1), 0.6)
	var r := _node(parent, Vector3.ZERO)
	# Origin is the pistol grip; the rifle points toward -Z.
	_box(r, Vector3(0.055, 0.085, 0.34), Vector3(0, 0.05, -0.1), metal)          # receiver
	_box(r, Vector3(0.06, 0.07, 0.26), Vector3(0, 0.055, -0.38), polymer)       # handguard
	_cyl(r, 0.011, 0.2, Vector3(0, 0.06, -0.6), metal, Vector3(PI * 0.5, 0, 0)) # barrel
	_cyl(r, 0.017, 0.06, Vector3(0, 0.06, -0.72), metal, Vector3(PI * 0.5, 0, 0)) # muzzle brake
	_box(r, Vector3(0.045, 0.1, 0.26), Vector3(0, 0.015, 0.2), polymer)         # stock
	_box(r, Vector3(0.05, 0.13, 0.04), Vector3(0, 0.0, 0.33), polymer)          # butt pad
	_box(r, Vector3(0.034, 0.1, 0.045), Vector3(0, -0.04, 0.0), polymer, Vector3(0.3, 0, 0))   # grip
	_box(r, Vector3(0.03, 0.16, 0.07), Vector3(0, -0.06, -0.15), metal, Vector3(-0.2, 0, 0))   # magazine
	_box(r, Vector3(0.03, 0.025, 0.12), Vector3(0, 0.105, -0.08), metal)        # optic mount
	_cyl(r, 0.022, 0.15, Vector3(0, 0.135, -0.08), metal, Vector3(PI * 0.5, 0, 0)) # optic
	return r


## Called every physics tick by the player.
func animate(delta: float, speed: float, on_floor: bool, crouching: bool, aiming: bool) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, k)
	_aim = lerpf(_aim, 1.0 if aiming else 0.0, 1.0 - exp(-14.0 * delta))
	_stride = lerpf(_stride, clampf(speed / 6.5, 0.0, 1.3), k)
	if on_floor and speed > 0.2:
		_phase = fmod(_phase + delta * (3.2 + speed * 1.05), TAU)

	var a := 0.62 * _stride
	var air := 0.0 if on_floor else 1.0
	for side in ["l", "r"]:
		var ph := _phase + (0.0 if side == "l" else PI)
		var swing := sin(ph) * a
		var knee_bend := 0.12 + maxf(0.0, cos(ph)) * 1.1 * _stride
		var leg: Dictionary = _legs[side]
		var thigh_x := swing + _crouch * (1.15 if side == "l" else 0.55) + air * (0.6 if side == "l" else 0.2)
		var knee_x := -knee_bend - _crouch * (1.9 if side == "l" else 1.5) - air * 0.9
		leg["thigh"].rotation.x = thigh_x
		leg["knee"].rotation.x = knee_x
		leg["ankle"].rotation.x = -(thigh_x + knee_x) * 0.6   # keep the foot roughly flat

	var bob := absf(sin(_phase)) * 0.035 * _stride
	_hips.position.y = HIP_Y - _crouch * 0.36 + bob - air * 0.05
	_hips.rotation.y = sin(_phase) * 0.12 * _stride
	_torso.rotation.y = -_hips.rotation.y
	_torso.rotation.x = -0.1 * _stride - _crouch * 0.2 + _aim * 0.05
	_head.rotation.x = -_torso.rotation.x * 0.7

	# Rifle: low ready while moving, shouldered when aiming.
	var low := Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3(0.12, 0.2, -0.22))
	var up := Transform3D(Basis(), Vector3(0.11, 0.42, -0.24))
	_rifle.transform = low.interpolate_with(up, _aim)
	_solve_arm("r", _rifle.transform * Vector3(0, -0.03, 0.0), Vector3(0.6, -1, 0.3))
	_solve_arm("l", _rifle.transform * Vector3(0, 0.0, -0.36), Vector3(-0.8, -1, 0.2))


## Two-bone IK in torso space: aims the shoulder and elbow so the hand reaches target.
func _solve_arm(side: String, target: Vector3, pole: Vector3) -> void:
	var arm: Dictionary = _arms[side]
	var shoulder: Node3D = arm["shoulder"]
	var elbow: Node3D = arm["elbow"]
	var s := shoulder.position
	var to_t := target - s
	var dist := clampf(to_t.length(), 0.05, UPPER_ARM + FOREARM - 0.001)
	var dir := to_t.normalized()
	# Law of cosines: angle between the upper arm and the shoulder-target line.
	var cos_a := (UPPER_ARM * UPPER_ARM + dist * dist - FOREARM * FOREARM) / (2.0 * UPPER_ARM * dist)
	var ang := acos(clampf(cos_a, -1.0, 1.0))
	var bend_axis := dir.cross(pole.normalized()).normalized()
	if bend_axis.length() < 0.01:
		bend_axis = Vector3.RIGHT
	var upper_dir := dir.rotated(bend_axis, ang)
	var elbow_pos := s + upper_dir * UPPER_ARM
	shoulder.basis = _basis_down_to(upper_dir, pole)
	var fore_dir := (target - elbow_pos).normalized()
	elbow.basis = shoulder.basis.inverse() * _basis_down_to(fore_dir, pole)


## Basis whose -Y axis points along dir (limbs hang along -Y).
func _basis_down_to(dir: Vector3, hint: Vector3) -> Basis:
	var y := -dir.normalized()
	var x := hint.cross(y)
	if x.length() < 0.01:
		x = Vector3.FORWARD.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# ------------------------------------------------------------ mesh helpers

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _place(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 3
	_place(parent, m, pos, mat, rot, scl)


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	_place(parent, m, pos, mat, Vector3.ZERO, scl)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	_place(parent, m, pos, mat, rot)


func _box(parent: Node3D, s: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = s
	_place(parent, m, pos, mat, rot)

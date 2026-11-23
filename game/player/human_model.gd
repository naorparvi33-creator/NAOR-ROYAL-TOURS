extends Node3D
## Realistic rigged human (generated with MakeHuman/MPFB2, CC0) animated in code:
##  * legs: each foot follows a step path on the ground and two-bone IK bends the knee,
##    so walking, running and crouching all come from the same few lines;
##  * arms: two-bone IK onto the rifle grip and handguard, or a natural swing when unarmed;
##  * spine lean, hip sway and head stabilisation.
## No animation files are needed. Works in skeleton space where the character faces +Z.

const FWD := Vector3(0, 0, 1)
const UP := Vector3(0, 1, 0)
const RIGHT := Vector3(-1, 0, 0)    # character's right side in skeleton space

@export var model_path := "res://assets/characters/player.glb"
var armed := true

var skeleton: Skeleton3D
var rifle: Node3D
var _visual: Node3D
var _b := {}            # bone name -> index
var _rest := {}         # bone name -> global rest Transform3D
var _len := {}
var _phase := 0.0
var _stride := 0.0
var _crouch := 0.0
var _aim := 0.0
var _air := 0.0


func _ready() -> void:
	_visual = load(model_path).instantiate()
	_visual.rotation.y = PI          # model faces +Z, the game uses -Z as forward
	add_child(_visual)
	skeleton = _visual.find_children("*", "Skeleton3D", true, false)[0]
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		_b[n] = i
		_rest[n] = skeleton.get_bone_global_rest(i)
	_len["thigh"] = _pos("calf_l").distance_to(_pos("thigh_l"))
	_len["calf"] = _pos("foot_l").distance_to(_pos("calf_l"))
	_len["upper"] = _pos("lowerarm_l").distance_to(_pos("upperarm_l"))
	_len["fore"] = _pos("hand_l").distance_to(_pos("lowerarm_l"))
	rifle = RifleMesh.build()
	skeleton.add_child(rifle)
	rifle.visible = armed
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 120.0


func set_armed(on: bool) -> void:
	armed = on
	if rifle:
		rifle.visible = on


func _pos(bone: String) -> Vector3:
	return (_rest[bone] as Transform3D).origin


## Called every physics tick. speed in m/s.
func animate(delta: float, speed: float, on_floor: bool, crouching: bool, aiming: bool) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, k)
	_aim = lerpf(_aim, 1.0 if (aiming and armed) else 0.0, 1.0 - exp(-14.0 * delta))
	_stride = lerpf(_stride, clampf(speed / 6.5, 0.0, 1.3), k)
	_air = lerpf(_air, 0.0 if on_floor else 1.0, 1.0 - exp(-12.0 * delta))
	if on_floor and speed > 0.15:
		# Cadence rises with speed; stride length does the rest.
		_phase = fmod(_phase + delta * (5.2 + speed * 0.9), TAU)
	pose()


func pose() -> void:
	skeleton.reset_bone_poses()
	var run := clampf(_stride, 0.0, 1.0)

	# ---- pelvis: bob, sway, crouch
	var bob := (absf(sin(_phase)) - 0.5) * 0.05 * run
	var pelvis_off := Vector3(sin(_phase) * 0.02 * run, bob - _crouch * 0.38 - _air * 0.04, 0)
	_offset_bone("pelvis", pelvis_off)
	_rotate_bone("pelvis", UP, sin(_phase) * 0.12 * run)
	_rotate_bone("spine_01", RIGHT, -(0.08 * run + _crouch * 0.25))
	_rotate_bone("spine_02", UP, -sin(_phase) * 0.1 * run * (1.0 - _aim))
	_rotate_bone("neck_01", RIGHT, 0.06 * run + _crouch * 0.15)

	# ---- legs: feet follow a step cycle, IK places the knees
	for side in ["l", "r"]:
		var ph := _phase + (0.0 if side == "l" else PI)
		var hip := skeleton.get_bone_global_pose(_b["thigh_" + side]).origin
		var ankle_rest := _pos("foot_" + side)
		var step := 0.38 * _stride
		var target := Vector3(ankle_rest.x, ankle_rest.y, ankle_rest.z)
		target += FWD * sin(ph) * step
		target += UP * maxf(0.0, cos(ph)) * (0.07 + 0.12 * run) * minf(_stride * 3.0, 1.0)
		if _crouch > 0.01:
			# One knee down in a crouch: that foot steps back.
			target += FWD * (0.12 if side == "l" else -0.18) * _crouch
		target += UP * _air * (0.25 if side == "l" else 0.12)
		_leg_ik(side, hip, target)

	# ---- arms
	if armed:
		var chest := skeleton.get_bone_global_pose(_b["spine_03"]).origin
		var low := Transform3D(Basis(RIGHT, 0.45).rotated(UP, PI), chest + RIGHT * 0.12 + FWD * 0.3 + UP * -0.1)
		var up := Transform3D(Basis(UP, PI), chest + RIGHT * 0.1 + FWD * 0.4 + UP * 0.16)   # stock on the shoulder
		rifle.transform = low.interpolate_with(up, _aim)
		_arm_ik("r", rifle.transform * Vector3(0, -0.03, 0.0), RIGHT * 1.0 + UP * -1.0 + FWD * -0.3)
		_arm_ik("l", rifle.transform * Vector3(0, 0.0, -0.28), -RIGHT * 0.6 + UP * -1.0 + FWD * -0.2)
	else:
		for side in ["l", "r"]:
			var ph := _phase + (PI if side == "l" else 0.0)
			var sx := -1.0 if side == "r" else 1.0
			var sh := skeleton.get_bone_global_pose(_b["upperarm_" + side]).origin
			var swing := sin(ph) * 0.45 * run
			var dir := (UP * -1.0 + FWD * swing + Vector3(sx, 0, 0) * 0.12).normalized()
			var elbow: Vector3 = sh + dir * float(_len["upper"])
			var fore := (dir + FWD * (0.25 + run * 0.5)).normalized()
			_set_limb("upperarm_" + side, sh, elbow)
			_set_limb("lowerarm_" + side, elbow, elbow + fore * _len["fore"])


## Two-bone IK for a leg (knee bends forward).
func _leg_ik(side: String, hip: Vector3, target: Vector3) -> void:
	var knee: Vector3 = _solve(hip, target, _len["thigh"], _len["calf"], FWD)
	_set_limb("thigh_" + side, hip, knee)
	_set_limb("calf_" + side, knee, target)
	# Keep the foot flat on the ground.
	var foot: int = _b["foot_" + side]
	skeleton.set_bone_global_pose(foot, Transform3D((_rest["foot_" + side] as Transform3D).basis, target))


## Two-bone IK for an arm (elbow toward the pole direction).
func _arm_ik(side: String, target: Vector3, pole: Vector3) -> void:
	var sh := skeleton.get_bone_global_pose(_b["upperarm_" + side]).origin
	var elbow: Vector3 = _solve(sh, target, _len["upper"], _len["fore"], pole.normalized())
	_set_limb("upperarm_" + side, sh, elbow)
	_set_limb("lowerarm_" + side, elbow, target)


func _solve(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to_t := target - a
	var d := clampf(to_t.length(), 0.01, l1 + l2 - 0.001)
	var dir := to_t.normalized()
	var cos_a := (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
	var ang := acos(clampf(cos_a, -1.0, 1.0))
	var axis := dir.cross(pole)
	if axis.length() < 0.001:
		axis = dir.cross(RIGHT)
	return a + dir.rotated(axis.normalized(), ang) * l1


## Rotates a bone from its rest direction so it points from `from` toward `to`.
func _set_limb(bone: String, from: Vector3, to: Vector3) -> void:
	var rest: Transform3D = _rest[bone]
	var child := _child_of(bone)
	var rest_dir := (_pos(child) - rest.origin).normalized()
	var new_dir := (to - from).normalized()
	var q := _from_to(rest_dir, new_dir)
	skeleton.set_bone_global_pose(_b[bone], Transform3D(Basis(q) * rest.basis, from))


func _child_of(bone: String) -> String:
	match bone.substr(0, bone.length() - 2):
		"thigh": return "calf" + bone.right(2)
		"calf": return "foot" + bone.right(2)
		"upperarm": return "lowerarm" + bone.right(2)
		"lowerarm": return "hand" + bone.right(2)
	return bone


func _from_to(a: Vector3, b: Vector3) -> Quaternion:
	var c := a.cross(b)
	var d := a.dot(b)
	if d < -0.9999:
		var axis := a.cross(Vector3.RIGHT)
		if axis.length() < 0.01:
			axis = a.cross(Vector3.UP)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(c.x, c.y, c.z, 1.0 + d).normalized()


## Rotation about a skeleton-space axis, applied in the bone's rest frame.
func _rotate_bone(bone: String, axis: Vector3, angle: float) -> void:
	if not _b.has(bone) or absf(angle) < 0.0001:
		return
	var i: int = _b[bone]
	var g: Basis = (_rest[bone] as Transform3D).basis
	var local_axis := (g.inverse() * axis).normalized()
	skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * Quaternion(local_axis, angle))


func _offset_bone(bone: String, offset: Vector3) -> void:
	var i: int = _b[bone]
	var parent := skeleton.get_bone_parent(i)
	var pb := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i) + pb.inverse() * offset)

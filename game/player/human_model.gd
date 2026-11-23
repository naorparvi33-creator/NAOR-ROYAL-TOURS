extends Node3D
## Realistic rigged human (generated with MakeHuman/MPFB2, CC0) animated in code.
## No animation files: every pose is built each frame from a few procedural layers.
##  * gait: a real stance / swing cycle per foot. Cadence and stride follow the speed so the
##    planted foot moves backwards at exactly the body speed (no sliding); stance gets shorter
##    as walking turns into a jog and a run. Heel strike -> flat foot -> heel lift about the
##    ball -> toe off, toes stay flat while the heel rises.
##  * body: pelvis bob (walk: high at mid-stance, run: low at mid-stance), lateral sway onto
##    the standing leg, pelvis yaw / hip drop, counter-rotating shoulders, arm swing with
##    speed-dependent elbow bend, forward lean with speed and acceleration, lean into turns,
##    head stabilised against the torso twist.
##  * idle: breathing (chest + shoulders), slow weight shift from leg to leg with the free knee
##    relaxed, small postural sway, glances; people look at the player when he is close; the
##    player's head follows the camera.
##  * events: landing compression, hit reactions (flinch), and a limp, staged death fall that
##    follows the callers' existing "tip the node over" (rotation.x) without any change there.
## Shading: player/look/char_look.gd swaps in the skin / eye / hair / cloth shaders.
## Works in skeleton space where the character faces +Z.

const FWD := Vector3(0, 0, 1)
const UP := Vector3(0, 1, 0)
const RIGHT := Vector3(-1, 0, 0)    # character's right side in skeleton space
const LOOK := preload("res://player/look/char_look.gd")
const FINGERS := ["index", "middle", "ring", "pinky"]

@export var model_path := "res://assets/characters/player.glb"
var armed := true
## 0 = fists / nothing, 1 = pistol, 2 = rifle
var weapon_kind := 2
## Idle behaviour for people in the street (unarmed only):
## IDLE_NONE, IDLE_LOOK (glances around when standing) or IDLE_PHONE (looks at a phone).
enum { IDLE_NONE, IDLE_LOOK, IDLE_PHONE }
var idle_style := IDLE_NONE

var skeleton: Skeleton3D
var rifle: Node3D
var pistol: Node3D
var phone: MeshInstance3D
var _visual: Node3D
var _t := 0.0            # local clock (desynchronised per person)
var _still := 0.0        # 0 walking .. 1 standing still
var _phone_k := 0.0
var _look_target := Vector2.ZERO
var _look := Vector2.ZERO
var _look_timer := 0.0
var _punch := 0.0
var _punch_side := "r"
var _b := {}            # bone name -> index
var _rest := {}         # bone name -> global rest Transform3D
var _len := {}
var _knuckle := {}      # side -> knuckle axis (rest skeleton space) for finger curl
var _phase := 0.0
var _stride := 0.0
var _crouch := 0.0
var _aim := 0.0
var _air := 0.0
# gait
var _cycle := 0.0        # 0..1, left heel strike at 0, right at 0.5
var _speed := 0.0        # smoothed speed (m/s)
var _accel := 0.0
var _run := 0.0          # 0 walk .. 1 run gait
var _move := 0.0         # 0 standing .. 1 full gait amplitude
var _duty := 0.62        # fraction of the cycle a foot is on the ground
var _stride_len := 0.0   # stance travel of a foot (m)
var _yaw_prev := 0.0
var _turn := 0.0         # smoothed yaw rate (rad/s, + = turning left)
# events
var _air_time := 0.0
var _land_t := 9.0
var _land_amt := 0.0
var _hit := 0.0
var _hit_side := 1.0
var _hit_back := 1.0
var _shift := 0.0
var _shift_target := 0.0
var _shift_timer := 0.0
var _dead := 0.0
var _limp_side := 1.0
var _detail := true
static var _player_ref: Node3D = null
## Animation LOD (pedestrians): skip the bone update when off-screen or out of draw range,
## and pose every second call when far. The player's own model always animates.
var lod_enabled := true
var _lod_tick := 0
static var lod_posed := 0
static var lod_skipped := 0


func _ready() -> void:
	_t = randf() * 100.0
	_limp_side = 1.0 if randf() < 0.5 else -1.0
	_shift_timer = randf_range(0.5, 4.0)
	rifle = RifleMesh.build()
	pistol = RifleMesh.build_pistol()
	phone = _build_phone()
	_load_visual()
	set_weapon(weapon_kind if armed else 0)
	_yaw_prev = global_rotation.y if is_inside_tree() else 0.0


## Swaps the character model at runtime (same 53-bone rig), keeping weapons and state.
func change_model(path: String) -> void:
	if path == model_path and _visual != null:
		return
	model_path = path
	if is_inside_tree():
		_load_visual()


func _load_visual() -> void:
	for n in [rifle, pistol, phone]:
		if n and n.get_parent():
			n.get_parent().remove_child(n)
	if _visual:
		_visual.queue_free()
	var res: Resource = load(model_path)
	if res == null:
		push_warning("human_model: missing " + model_path)
		res = load("res://assets/characters/player.glb")
	_visual = (res as PackedScene).instantiate()
	_visual.rotation.y = PI          # model faces +Z, the game uses -Z as forward
	add_child(_visual)
	skeleton = _visual.find_children("*", "Skeleton3D", true, false)[0]
	_b.clear()
	_rest.clear()
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		_b[n] = i
		_rest[n] = skeleton.get_bone_global_rest(i)
	_len["thigh"] = _pos("calf_l").distance_to(_pos("thigh_l"))
	_len["calf"] = _pos("foot_l").distance_to(_pos("calf_l"))
	_len["upper"] = _pos("lowerarm_l").distance_to(_pos("upperarm_l"))
	_len["fore"] = _pos("hand_l").distance_to(_pos("lowerarm_l"))
	_knuckle.clear()
	for side in ["l", "r"]:
		if _b.has("index_01_" + side) and _b.has("pinky_01_" + side):
			_knuckle[side] = (_pos("index_01_" + side) - _pos("pinky_01_" + side)).normalized()
	skeleton.add_child(rifle)
	skeleton.add_child(pistol)
	skeleton.add_child(phone)
	phone.visible = false
	lod_enabled = not (get_parent() != null and get_parent().is_in_group("player"))
	for g in _visual.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 120.0
	LOOK.apply(_visual)


func _build_phone() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.072, 0.15, 0.009)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	m.metallic = 0.4
	m.roughness = 0.3
	# The screen glows faintly (emission only, no light).
	m.emission_enabled = true
	m.emission = Color(0.25, 0.35, 0.45)
	m.emission_energy_multiplier = 0.35
	bm.material = m
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 40.0
	return mi


func set_armed(on: bool) -> void:
	set_weapon(2 if on else 0)


func set_weapon(kind: int) -> void:
	weapon_kind = kind
	armed = kind > 0
	if rifle:
		rifle.visible = kind == 2
		pistol.visible = kind == 1


## Starts a punch (alternating hands).
func punch() -> void:
	_punch = 1.0
	_punch_side = "l" if _punch_side == "r" else "r"


## Hit reaction: the upper body recoils and twists, the head snaps, the pelvis staggers.
## `from_dir` (world space, optional) is the direction the hit came from.
func flinch(from_dir := Vector3.ZERO) -> void:
	_hit = 1.0
	_hit_side = 1.0 if randf() < 0.5 else -1.0
	_hit_back = 1.0
	if from_dir.length_squared() > 0.001 and is_inside_tree():
		var l := global_basis.orthonormalized().inverse() * from_dir
		# Hit from the front (-Z local) pushes back; from the left (-X) twists to the right.
		_hit_back = -1.0 if l.z > 0.3 else 1.0
		_hit_side = -signf(l.x) if absf(l.x) > 0.2 else _hit_side


func _pos(bone: String) -> Vector3:
	return (_rest[bone] as Transform3D).origin


## Called every physics tick. speed in m/s.
func animate(delta: float, speed: float, on_floor: bool, crouching: bool, aiming: bool) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, k)
	_aim = lerpf(_aim, 1.0 if (aiming and armed) else 0.0, 1.0 - exp(-14.0 * delta))
	var prev := _speed
	_speed = lerpf(_speed, maxf(speed, 0.0), 1.0 - exp(-7.0 * delta))
	_accel = lerpf(_accel, (_speed - prev) / maxf(delta, 0.001), 1.0 - exp(-5.0 * delta))
	_stride = clampf(_speed / 6.5, 0.0, 1.3)
	_run = smoothstep(2.3, 4.6, _speed)
	_move = clampf(_speed / 0.9, 0.0, 1.0)
	# Landing: compression scaled by the time spent in the air.
	if on_floor:
		if _air_time > 0.28:
			_land_amt = clampf(_air_time * 1.3, 0.35, 1.0)
			_land_t = 0.0
		_air_time = 0.0
	else:
		_air_time += delta
	_land_t += delta
	_air = lerpf(_air, 0.0 if on_floor else 1.0, 1.0 - exp(-12.0 * delta))
	# Cadence (cycles / s) rises with speed; stride is limited by leg reach, beyond that the
	# cadence goes up instead, so the planted foot always travels at the body speed.
	_duty = lerpf(0.62, 0.36, _run)
	var f := clampf(0.62 + 0.24 * _speed, 0.85, 2.3)
	var lmax := lerpf(0.78, 0.5, _crouch)
	var stance := _speed * _duty / f
	if stance > lmax:
		f = _speed * _duty / lmax
		stance = lmax
	_stride_len = stance
	if on_floor and _speed > 0.05:
		_cycle = fmod(_cycle + delta * f, 1.0)
	_phase = _cycle * TAU
	# Turn rate for leaning into curves.
	var yaw := global_rotation.y
	var dy := wrapf(yaw - _yaw_prev, -PI, PI) / maxf(delta, 0.001)
	_yaw_prev = yaw
	_turn = lerpf(_turn, clampf(dy, -5.0, 5.0), 1.0 - exp(-6.0 * delta))
	_punch = maxf(_punch - delta / 0.32, 0.0)
	_hit = maxf(_hit - delta / 0.55, 0.0)
	_t += delta
	_still = lerpf(_still, 1.0 if speed < 0.2 else 0.0, 1.0 - exp(-3.0 * delta))
	var wants_phone := idle_style == IDLE_PHONE and not armed and speed < 2.2 and _hit <= 0.0
	_phone_k = lerpf(_phone_k, 1.0 if wants_phone else 0.0, 1.0 - exp(-5.0 * delta))
	# Weight shift from leg to leg while standing.
	_shift_timer -= delta
	if _shift_timer <= 0.0:
		_shift_timer = randf_range(4.0, 9.0)
		_shift_target = (1.0 if randf() < 0.5 else -1.0) * randf_range(0.5, 1.0)
	_shift = lerpf(_shift, _shift_target * _still * (1.0 - _aim) * (1.0 - _crouch), 1.0 - exp(-1.3 * delta))
	_update_look(delta)
	# The callers tip a dead body over with rotation.x; follow it with a limp fall.
	_dead = clampf(-rotation.x / (PI * 0.5), 0.0, 1.0)
	if _dead > 0.0:
		lod_posed += 1
		pose()
		return
	if lod_enabled and not _lod_should_pose():
		lod_skipped += 1
		return
	lod_posed += 1
	pose()


func _lod_should_pose() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_visible_in_tree():
		return false
	var c := global_position + Vector3(0, 0.9, 0)
	var d := cam.global_position.distance_to(c)
	if d > 125.0:
		return false               # beyond the model's visibility range
	for pl in cam.get_frustum():
		if (pl as Plane).distance_to(c) > 1.2:
			return false           # whole body outside the view
	_detail = d < 14.0
	if d > 60.0:
		_lod_tick += 1
		return _lod_tick % 2 == 0
	return true


## Head target: the player's head follows the camera; people glance around and look at the
## player when he comes close.
func _update_look(delta: float) -> void:
	var target := Vector2.ZERO
	var rate := 3.0
	if not lod_enabled:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam:
			var lk := _local_look(-cam.global_basis.z)
			var fade := 1.0 - smoothstep(1.7, 2.3, absf(lk.x))
			target = Vector2(clampf(lk.x, -1.1, 1.1), clampf(lk.y * 0.6, -0.4, 0.35)) * fade
			rate = 5.0
	else:
		_look_timer -= delta
		if _look_timer <= 0.0:
			# A new thing to glance at: mostly ahead, sometimes to the side.
			_look_timer = randf_range(1.2, 4.0)
			var side := randf_range(-0.9, 0.9) if randf() < (0.6 if idle_style != IDLE_NONE else 0.35) else 0.0
			_look_target = Vector2(side * (0.35 + 0.65 * _still), randf_range(-0.12, 0.08))
		target = _look_target
		var pl := _player()
		if pl and is_inside_tree():
			var to := pl.global_position + Vector3(0, 1.5, 0) - (global_position + Vector3(0, 1.6, 0))
			var d := to.length()
			# Close by: look at him for a few seconds, then lose interest for a while.
			if d < 7.0 and d > 0.3 and fmod(_t * 0.18, 1.0) < 0.55:
				var lk := _local_look(to / d)
				if absf(lk.x) < 1.6:
					target = Vector2(clampf(lk.x, -1.1, 1.1), clampf(lk.y, -0.4, 0.35))
					rate = 4.0
	_look = _look.lerp(target, 1.0 - exp(-rate * delta))


## World direction -> (yaw, pitch) relative to the character (+yaw = to its left).
func _local_look(dir: Vector3) -> Vector2:
	var l := global_basis.orthonormalized().inverse() * dir
	var yaw := atan2(-l.x, -l.z)
	var pitch := asin(clampf(l.y / maxf(l.length(), 0.001), -1.0, 1.0))
	return Vector2(yaw, pitch)


func _player() -> Node3D:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = null
		if is_inside_tree():
			_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	return _player_ref


func pose() -> void:
	skeleton.reset_bone_poses()
	phone.visible = false
	if _dead > 0.0:
		_pose_dead()
		return
	if rifle:
		rifle.visible = weapon_kind == 2
		pistol.visible = weapon_kind == 1
	var run := _run
	var mv := _move
	var c := _cycle * TAU
	var land := 0.0
	if _land_t < 0.6:
		land = _land_amt * (_land_t / 0.07 if _land_t < 0.07 else exp(-(_land_t - 0.07) * 7.0))
	var hk := minf((1.0 - _hit) / 0.1, 1.0) * pow(_hit, 1.4)

	# ---- pelvis: bob, sway onto the standing leg, yaw, hip drop, crouch, landing
	var walk_bob := -cos(2.0 * c) * 0.024
	var run_bob := -cos(2.0 * c - _duty * TAU) * 0.035
	var bob := lerpf(walk_bob, run_bob, run) * mv
	var sway := sin(c) * lerpf(0.03, 0.012, run) * mv
	var lean_turn := clampf(-_turn * _speed * 0.04, -0.28, 0.28) * (1.0 - _crouch * 0.5)
	var pelvis_off := Vector3(
		sway + _shift * 0.035 + sin(_t * 0.6) * 0.005 * _still + lean_turn * 0.12,
		bob - _crouch * 0.38 - _air * 0.04 - run * 0.02 * mv - land * 0.17 - absf(_shift) * 0.012 - 0.008 * mv,
		-hk * 0.06 * _hit_back)
	_offset_bone("pelvis", pelvis_off)
	var p_yaw := -cos(c) * lerpf(0.1, 0.16, run) * mv * (1.0 - 0.6 * _aim)
	var p_roll := sin(c) * lerpf(0.055, 0.03, run) * mv + _shift * 0.05
	_rotate_bone("pelvis", UP, p_yaw)
	_rotate_bone("pelvis", FWD, p_roll + lean_turn)

	# ---- spine: lean with speed / acceleration, counter-rotate the shoulders, breathe
	var fwd_lean := 0.04 * mv + 0.24 * run * mv + clampf(_accel * 0.025, -0.06, 0.14) + _crouch * 0.25 + land * 0.35
	var s_yaw := cos(c) * lerpf(0.08, 0.17, run) * mv * (1.0 - _aim)
	var breath := sin(_t * 1.7)
	_rotate_bone("spine_01", UP, -p_yaw * 0.9)
	_rotate_bone("spine_01", FWD, -p_roll * 0.65 - lean_turn * 0.35)
	_rotate_bone("spine_01", RIGHT, -fwd_lean * 0.5 + hk * 0.3 * _hit_back)
	_rotate_bone("spine_02", RIGHT, -fwd_lean * 0.3)
	_rotate_bone("spine_02", UP, s_yaw * 0.5 + hk * 0.35 * _hit_side)
	_rotate_bone("spine_02", FWD, -_shift * 0.05 + hk * 0.12 * _hit_side)
	_rotate_bone("spine_03", UP, s_yaw * 0.5 + _look.x * 0.12 * (1.0 - _aim))
	_rotate_bone("spine_03", RIGHT, -breath * 0.018 * (0.4 + _still) - fwd_lean * 0.2)
	# Shoulders rise a little with each breath and with the arm swing.
	_rotate_bone("clavicle_l", FWD, breath * 0.022 * (0.3 + _still) + hk * 0.08)
	_rotate_bone("clavicle_r", FWD, -breath * 0.022 * (0.3 + _still) - hk * 0.08)
	_rotate_bone("clavicle_l", UP, -cos(c) * 0.06 * mv * (1.0 - _aim))
	_rotate_bone("clavicle_r", UP, -cos(c) * 0.06 * mv * (1.0 - _aim))
	# Neck / head: keep the gaze level and steady against the torso motion.
	_rotate_bone("neck_01", RIGHT, fwd_lean * 0.55 + 0.02 * run + _crouch * 0.15)
	_rotate_bone("neck_01", UP, -s_yaw * 0.85)
	_rotate_bone("head", FWD, p_roll * 0.3 + lean_turn * 0.3 + _shift * 0.03 - hk * 0.18 * _hit_side)
	_rotate_bone("head", RIGHT, hk * 0.3 * _hit_back - bob * 0.8)
	var free := (1.0 - _phone_k) * (1.0 - _aim)
	if free > 0.01:
		_rotate_bone("neck_01", UP, _look.x * 0.35 * free)
		_rotate_bone("head", UP, _look.x * 0.5 * free)
		# (a negative angle about RIGHT tips the head forward / down)
		_rotate_bone("neck_01", RIGHT, _look.y * 0.35 * free)
		_rotate_bone("head", RIGHT, _look.y * 0.65 * free)
	if _phone_k > 0.01:
		_rotate_bone("head", RIGHT, -_phone_k * 0.42)
		_rotate_bone("neck_01", RIGHT, -_phone_k * 0.2)

	# ---- legs: each foot runs its own stance / swing cycle, IK places the knees
	var toe_off := lerpf(0.55, 0.8, run)
	var strike := lerpf(0.24, 0.08, run)
	for side in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0
		var p := fmod(_cycle + (0.0 if side == "l" else 0.5), 1.0)
		var hip := skeleton.get_bone_global_pose(_b["thigh_" + side]).origin
		var a_rest := _pos("foot_" + side)
		var base := Vector3(sx * lerpf(0.135, 0.1, mv), a_rest.y, a_rest.z + 0.02 * mv)
		var z := 0.0
		var lift := 0.0
		var pitch := 0.0
		var on_ground := true
		if p < _duty:
			var s := p / _duty
			z = _stride_len * (0.5 - s)
			pitch = strike * (1.0 - smoothstep(0.0, 0.2, s)) - toe_off * smoothstep(0.55, 1.0, s)
		else:
			var s := (p - _duty) / (1.0 - _duty)
			var e := s * s * (3.0 - 2.0 * s)
			z = _stride_len * (-0.5 + e)
			# Walking: low, even clearance. Running: the heel kicks up behind early in the swing,
			# then the knee drives forward and the foot reaches down for the next strike.
			lift = sin(PI * pow(s, lerpf(0.75, 0.5, run))) * (0.075 + 0.3 * run)
			pitch = lerpf(-toe_off, strike, smoothstep(0.0, 0.85, s))
			on_ground = false
		lift *= minf(mv * 1.5, 1.0)
		pitch *= mv
		# Relaxed free leg while standing: knee bent, heel up a touch, foot a bit forward.
		var free_leg := clampf(-_shift * sx, 0.0, 1.0)
		z += 0.06 * free_leg
		pitch -= 0.12 * free_leg
		base.x += sx * 0.025 * free_leg
		var ankle := _foot_ankle(side, base + FWD * z, pitch) + UP * lift
		if _crouch > 0.01:
			# One knee down in a crouch: that foot steps back.
			ankle += FWD * (0.12 if side == "l" else -0.18) * _crouch
		ankle += UP * _air * (0.25 if side == "l" else 0.12)
		_leg_ik(side, hip, ankle, pitch)
		# Toes stay flat on the ground while the heel lifts.
		if pitch < 0.0:
			_rotate_bone("ball_" + side, RIGHT, -pitch * (0.85 if on_ground else 0.3))

	# ---- arms
	var chest := skeleton.get_bone_global_pose(_b["spine_03"]).origin
	if weapon_kind == 1:
		# Pistol: held low in both hands, raised to eye line when aiming.
		var plow := Transform3D(Basis(RIGHT, 0.7).rotated(UP, PI), chest + RIGHT * 0.05 + FWD * 0.3 + UP * -0.22)
		var pup := Transform3D(Basis(UP, PI), chest + RIGHT * 0.06 + FWD * 0.5 + UP * 0.2)
		pistol.transform = plow.interpolate_with(pup, _aim)
		var grip := pistol.transform * Vector3(0, -0.04, 0.03)
		_arm_ik("r", grip, RIGHT * 1.0 + UP * -1.0 + FWD * -0.2)
		_arm_ik("l", grip + RIGHT * -0.03 + UP * -0.02, -RIGHT * 1.0 + UP * -1.0 + FWD * -0.2)
	elif weapon_kind == 2:
		var low := Transform3D(Basis(RIGHT, 0.45).rotated(UP, PI), chest + RIGHT * 0.12 + FWD * 0.3 + UP * -0.1)
		var up := Transform3D(Basis(UP, PI), chest + RIGHT * 0.1 + FWD * 0.4 + UP * 0.16)   # stock on the shoulder
		rifle.transform = low.interpolate_with(up, _aim)
		_arm_ik("r", rifle.transform * Vector3(0, -0.03, 0.0), RIGHT * 1.0 + UP * -1.0 + FWD * -0.3)
		_arm_ik("l", rifle.transform * Vector3(0, 0.0, -0.28), -RIGHT * 0.6 + UP * -1.0 + FWD * -0.2)
	elif _punch > 0.0:
		# Punch: one fist shoots forward at chin height, the other guards the face.
		var reach := sin(_punch * PI)
		for side in ["l", "r"]:
			var sx := -1.0 if side == "r" else 1.0
			var guard := chest + UP * 0.3 + FWD * 0.22 + Vector3(sx * 0.1, 0, 0)
			var target := guard
			if side == _punch_side:
				target = chest + UP * 0.28 + FWD * (0.25 + 0.42 * reach) + Vector3(sx * 0.03, 0, 0)
			_arm_ik(side, target, Vector3(sx, -1.0, -0.3))
			if _detail:
				_curl_fingers(side, 1.25)
		_rotate_bone("spine_02", UP, (0.35 if _punch_side == "r" else -0.35) * reach)
	else:
		for side in ["l", "r"]:
			var sx := 1.0 if side == "l" else -1.0
			var sh := skeleton.get_bone_global_pose(_b["upperarm_" + side]).origin
			# Each arm swings with the opposite leg, lagging it slightly.
			var amp := lerpf(0.3, 0.5, run) * mv
			var swing := -sx * cos(c - 0.2) * amp + 0.05 - 0.05 * run * mv
			var abd := 0.13 + 0.04 * run + _air * 0.3 + land * 0.25 + hk * 0.15
			var dir := (Basis(RIGHT, swing) * Vector3(sx * abd, -1.0, -0.02)).normalized()
			var elbow: Vector3 = sh + dir * float(_len["upper"])
			var flex := lerpf(0.2 + 0.4 * maxf(swing, 0.0), 1.45 + 0.25 * swing, run) * maxf(mv, 0.0)
			flex = maxf(flex, 0.16) + hk * 0.7 + land * 0.3
			var fore := (Basis(RIGHT, flex) * dir)
			fore.x -= sx * 0.22 * run * mv
			fore = fore.normalized()
			if side == "r" and _phone_k > 0.02:
				# Phone in the right hand, held in front of the chest at reading distance.
				var hand: Vector3 = elbow + fore * float(_len["fore"])
				var hold := chest + FWD * 0.3 + UP * 0.02 + RIGHT * 0.06
				var target := hand.lerp(hold, _phone_k)
				_arm_ik("r", target, RIGHT * 1.0 + UP * -1.0 + FWD * -0.4)
				var eyes := skeleton.get_bone_global_pose(_b["head"]).origin + UP * 0.07 + FWD * 0.06
				var at := target + FWD * 0.03 + UP * 0.04
				phone.transform = Transform3D(Basis.looking_at(eyes - at, UP), at)
				phone.visible = _phone_k > 0.35
				continue
			_set_limb("upperarm_" + side, sh, elbow)
			_set_limb("lowerarm_" + side, elbow, elbow + fore * _len["fore"])
			if _detail:
				# Relaxed hands curl a little; running hands close into loose fists.
				_curl_fingers(side, 0.35 + 0.55 * run * mv)


## Ankle position for a foot whose sole pivots on the heel (toes up, pitch > 0) or on the
## ball (heel up, pitch < 0). `base` is the ankle position with the foot flat.
func _foot_ankle(side: String, base: Vector3, pitch: float) -> Vector3:
	if absf(pitch) < 0.001:
		return base
	var pivot: Vector3
	if pitch > 0.0:
		pivot = Vector3(base.x, 0.0, base.z - 0.06)
	else:
		var d := _pos("ball_" + side) - _pos("foot_" + side)
		pivot = Vector3(base.x + d.x, _pos("ball_" + side).y, base.z + d.z)
	return pivot + Basis(RIGHT, pitch) * (base - pivot)


## Two-bone IK for a leg (knee bends forward); the foot is pitched about the ankle.
func _leg_ik(side: String, hip: Vector3, target: Vector3, pitch := 0.0) -> void:
	var knee: Vector3 = _solve(hip, target, _len["thigh"], _len["calf"], FWD)
	_set_limb("thigh_" + side, hip, knee)
	_set_limb("calf_" + side, knee, target)
	var foot: int = _b["foot_" + side]
	skeleton.set_bone_global_pose(foot, Transform3D(Basis(RIGHT, pitch) * (_rest["foot_" + side] as Transform3D).basis, target))


## Two-bone IK for an arm (elbow toward the pole direction).
func _arm_ik(side: String, target: Vector3, pole: Vector3) -> void:
	var sh := skeleton.get_bone_global_pose(_b["upperarm_" + side]).origin
	var elbow: Vector3 = _solve(sh, target, _len["upper"], _len["fore"], pole.normalized())
	_set_limb("upperarm_" + side, sh, elbow)
	_set_limb("lowerarm_" + side, elbow, target)


## Bends the four fingers (and a bit of the thumb) toward the palm.
func _curl_fingers(side: String, amount: float) -> void:
	if not _knuckle.has(side):
		return
	var ax: Vector3 = _knuckle[side] * (-1.0 if side == "l" else 1.0)
	for i in FINGERS.size():
		var f: String = FINGERS[i]
		var a := amount * (0.8 + 0.12 * i)       # the pinky curls most
		_rotate_bone(f + "_01_" + side, ax, a * 0.35)
		_rotate_bone(f + "_02_" + side, ax, a * 0.55)
		_rotate_bone(f + "_03_" + side, ax, a * 0.4)
	_rotate_bone("thumb_02_" + side, ax, amount * 0.2)


## Limp fall that follows the node being tipped over (0 = standing, 1 = on the ground).
func _pose_dead() -> void:
	var k := _dead
	var e := k * k * (3.0 - 2.0 * k)
	var mid := sin(PI * minf(k * 1.25, 1.0))
	var s := _limp_side
	if rifle:
		rifle.visible = weapon_kind == 2 and k < 0.3
		pistol.visible = weapon_kind == 1 and k < 0.3
	_offset_bone("pelvis", Vector3(0, -0.06 * mid, 0))
	_rotate_bone("pelvis", FWD, 0.1 * s * e)
	_rotate_bone("spine_01", RIGHT, -0.35 * mid + 0.06 * e)
	_rotate_bone("spine_02", UP, 0.22 * s * e)
	_rotate_bone("spine_02", FWD, 0.12 * s * e)
	_rotate_bone("spine_03", RIGHT, -0.1 * mid)
	_rotate_bone("neck_01", RIGHT, 0.3 * e - 0.2 * mid)
	_rotate_bone("head", UP, 1.15 * s * e)
	_rotate_bone("head", FWD, 0.25 * s * e)
	for side in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0
		var bent := (sx > 0.0) == (s > 0.0)
		var hip := skeleton.get_bone_global_pose(_b["thigh_" + side]).origin
		# Knees buckle forward during the fall, then one leg ends up bent out to the side.
		var th := _blend3(Vector3(sx * 0.08, -1.0, 0.0), Vector3(sx * 0.12, -1.0, 0.55),
			Vector3(sx * 0.6, -0.8, 0.12) if bent else Vector3(sx * 0.14, -1.0, 0.03), k)
		var ca := _blend3(Vector3(0.0, -1.0, 0.0), Vector3(sx * 0.05, -1.0, -0.45),
			Vector3(sx * 0.2, -0.45, -0.85) if bent else Vector3(sx * 0.05, -1.0, -0.12), k)
		var knee: Vector3 = hip + th * float(_len["thigh"])
		var ankle: Vector3 = knee + ca * float(_len["calf"])
		_set_limb("thigh_" + side, hip, knee)
		_set_limb("calf_" + side, knee, ankle)
		skeleton.set_bone_global_pose(_b["foot_" + side],
			Transform3D(Basis(RIGHT, -1.1 * e) * (_rest["foot_" + side] as Transform3D).basis, ankle))
		# Arms reach out to break the fall, then lie limp: one up by the head, one by the side.
		var sh := skeleton.get_bone_global_pose(_b["upperarm_" + side]).origin
		var up_arm := not bent
		var ua := _blend3(Vector3(sx * 0.15, -1.0, 0.0), Vector3(sx * 0.35, 0.05, 1.0),
			Vector3(sx * 0.95, 0.4, 0.15) if up_arm else Vector3(sx * 0.3, -0.95, 0.12), k)
		var fa := _blend3(Vector3(sx * 0.05, -1.0, 0.2), Vector3(sx * 0.1, 0.35, 1.0),
			Vector3(sx * 0.1, 1.0, 0.2) if up_arm else Vector3(sx * 0.05, -0.9, 0.3), k)
		var elbow: Vector3 = sh + ua * float(_len["upper"])
		_set_limb("upperarm_" + side, sh, elbow)
		_set_limb("lowerarm_" + side, elbow, elbow + fa * float(_len["fore"]))
		_curl_fingers(side, 0.6)


## Direction that goes a -> b (first 45 % of k) -> c (rest), normalised.
func _blend3(a: Vector3, b: Vector3, c: Vector3, k: float) -> Vector3:
	var an := a.normalized()
	var bn := b.normalized()
	var cn := c.normalized()
	if k < 0.45:
		return an.lerp(bn, smoothstep(0.0, 0.45, k)).normalized()
	return bn.lerp(cn, smoothstep(0.45, 1.0, k)).normalized()


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

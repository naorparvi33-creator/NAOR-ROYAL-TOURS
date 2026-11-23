extends Node3D
## Third-person over-the-shoulder camera. Follows the player smoothly using the
## physics-interpolated transform, so it stays smooth at 60, 90 and 120 FPS.

const PITCH_MIN := -75.0
const PITCH_MAX := 65.0
const SHOULDER := 0.55
const NORMAL := {"len": 3.1, "fov": 72.0, "shoulder": SHOULDER}
const ADS := {"len": 1.25, "fov": 52.0, "shoulder": 0.5}
const SPRINT_FOV := 78.0
const CAR := {"len": 6.8, "fov": 72.0, "shoulder": 0.0}

var target: Node3D
var yaw := 0.0        # degrees
var pitch := -8.0     # degrees
var eye_height := 1.6
var aiming := false
var sprinting := false
## Following a vehicle: longer arm, auto-turns behind the car.
var vehicle: Node3D = null
var _idle_look := 0.0
## Camera feel (cinematic pass): smoothed follow, speed FOV kick, handheld sway and
## rotational shake. add_shake(0..1) is called on explosions and hard crashes.
var _follow := Vector3.INF
var _trauma := 0.0
var _t := 0.0
var _last_speed := 0.0
var _fov_kick := 0.0

var camera: Camera3D
var _pivot: Node3D
var _arm: SpringArm3D
var _eye := 1.6


func _init() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pivot = Node3D.new()
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = NORMAL["len"]
	_arm.margin = 0.15
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	_arm.shape = sphere
	_arm.collision_mask = 1
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = NORMAL["fov"]
	camera.near = 0.05
	_arm.add_child(camera)


func _ready() -> void:
	camera.current = true
	camera.far = float(Settings.get_value("draw_distance"))
	Settings.changed.connect(func(k):
		if k == "draw_distance":
			camera.far = float(Settings.get_value("draw_distance")))
	if target is CollisionObject3D:
		_arm.add_excluded_object(target.get_rid())


func _process(delta: float) -> void:
	if target == null:
		return
	_apply_look(delta)

	var follow: Node3D = vehicle if vehicle else target
	var tp: Vector3 = follow.get_global_transform_interpolated().origin
	_eye = lerpf(_eye, eye_height, 1.0 - exp(-12.0 * delta))
	# Slight follow lag (a camera operator, not a rigid stick); snaps on teleports and
	# stays tight while aiming so the crosshair is exact.
	if _follow == Vector3.INF or _follow.distance_to(tp) > 6.0:
		_follow = tp
	var lag := 40.0 if aiming else (11.0 if vehicle else 18.0)
	_follow = _follow.lerp(tp, 1.0 - exp(-lag * delta))
	global_position = _follow + Vector3(0, _eye, 0)
	rotation_degrees = Vector3(0, yaw, 0)
	_pivot.rotation_degrees = Vector3(pitch, 0, 0)

	var mode: Dictionary = ADS if aiming else NORMAL
	if vehicle:
		mode = CAR
		_follow_vehicle(delta)
	var k := 1.0 - exp(-14.0 * delta)
	_arm.spring_length = lerpf(_arm.spring_length, mode["len"], k)
	_pivot.position.x = lerpf(_pivot.position.x, mode["shoulder"], k)
	var fov_target: float = mode["fov"]
	if sprinting and not aiming:
		fov_target = SPRINT_FOV
	var speed := 0.0
	if vehicle and "linear_velocity" in vehicle:
		var lv: Vector3 = vehicle.get("linear_velocity")
		speed = lv.length()
		# Speed FOV kick, eased in (no pumping at city speeds).
		fov_target += clampf((speed - 8.0) * 0.32, 0.0, 14.0)
		# A hard stop (crash) shakes the camera.
		var drop := _last_speed - speed
		if drop > 6.0:
			add_shake(clampf((drop - 6.0) / 14.0 + 0.25, 0.0, 0.8))
	_last_speed = speed
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-(5.0 if vehicle else 14.0) * delta))
	_apply_feel(delta)


## Adds camera shake (0..1, saturates).
func add_shake(amount: float) -> void:
	_trauma = clampf(maxf(_trauma, amount), 0.0, 1.0)


func _apply_feel(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - delta * 1.1, 0.0)
	# Handheld: a slow, small breathing drift on foot; almost none while aiming or driving.
	var hand := 0.0 if vehicle else (0.05 if aiming else 0.55)
	if sprinting:
		hand = 0.9
	var sx := (sin(_t * 0.9) * 0.6 + sin(_t * 2.3 + 1.3) * 0.25) * hand
	var sy := (sin(_t * 0.7 + 0.4) * 0.6 + sin(_t * 1.9 + 2.1) * 0.25) * hand
	var sz := sin(_t * 0.5 + 0.8) * 0.35 * hand
	# Trauma shake: squared falloff, fast noise.
	var sh := _trauma * _trauma
	sx += (sin(_t * 37.0) + sin(_t * 23.0 + 1.7)) * 1.4 * sh
	sy += (sin(_t * 31.0 + 0.5) + sin(_t * 19.0 + 2.9)) * 1.4 * sh
	sz += sin(_t * 27.0 + 0.9) * 1.8 * sh
	camera.rotation_degrees = Vector3(sx * 0.35, sy * 0.35, sz * 0.5)


func _follow_vehicle(delta: float) -> void:
	var v: Variant = vehicle
	var vel: Vector3 = v.linear_velocity
	if _idle_look > 1.0 and Vector2(vel.x, vel.z).length() > 2.0:
		var d: Vector3 = vehicle.global_basis.z
		var want := rad_to_deg(atan2(-d.x, -d.z))
		yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(want), 1.0 - exp(-2.5 * delta)))
		pitch = lerpf(pitch, -12.0, 1.0 - exp(-2.0 * delta))


func set_vehicle(v: Node3D) -> void:
	vehicle = v
	if v is CollisionObject3D:
		_arm.add_excluded_object((v as CollisionObject3D).get_rid())


func _apply_look(delta: float) -> void:
	var look := GameInput.consume_look()
	_idle_look = 0.0 if look.length() > 0.01 else _idle_look + delta
	# Optional gyroscope aiming (fine adjustment).
	var gmode := int(Settings.get_value("gyro_mode"))
	if gmode == 2 or (gmode == 1 and aiming):
		var g := Input.get_gyroscope()
		var gs := float(Settings.get_value("gyro_sens")) * rad_to_deg(delta)
		look += Vector2(-g.y, -g.x) * gs
	if Settings.get_value("invert_y"):
		look.y = -look.y
	yaw -= look.x
	pitch = clampf(pitch - look.y, PITCH_MIN, PITCH_MAX)


## Forward direction on the ground plane (for movement).
func flat_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw))


## Ray from the screen center, used for shooting.
func aim_ray() -> Array:
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	return [camera.project_ray_origin(center), camera.project_ray_normal(center)]

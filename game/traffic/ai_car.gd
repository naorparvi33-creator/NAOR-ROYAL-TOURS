extends "res://vehicles/car.gd"
## A city car with an AI driver (traffic/traffic.gd steers it).
## While the AI drives, the body is a frozen kinematic RigidBody that the traffic
## manager moves along lane curves: stable, cheap and it never drifts into a wall.
## The moment the player takes the car or something hits it, it becomes a normal
## physics car again (vehicles/car.gd) with the same visuals, sound and damage.

enum { DRIVE, CRASHED, PLAYER, PARKED }

const RIDE_Y := 0.08          # body origin above the road when the wheels touch it

var mode := DRIVE
var traffic: Node = null
var pooled := true            # owned by the traffic pool (false once the player took it)
var has_driver := true

# --- path state (written by traffic.gd)
var cell := Vector2i.ZERO     # straight: intersection behind us; turn: the intersection we are in
var dir := 0                  # 0 +X, 1 +Z, 2 -X, 3 -Z
var next_dir := 0
var turning := false
var p0 := Vector3.ZERO
var p1 := Vector3.ZERO
var p2 := Vector3.ZERO
var plen := 1.0
var dist := 0.0
var ai_speed := 0.0
var cruise := 12.0
var lane_off := 0.0           # sideways shift (overtaking a stopped car)
var lane_target := 0.0
var pass_until := -1.0
var blocked_t := 0.0
var honk_cd := 0.0
var panic_t := 0.0
var crash_t := 0.0
var honks_left := 0
var horn_pitch := 1.0
var gap := 999.0              # free road ahead (m), refreshed every few frames
var gap_speed := 0.0          # speed of whatever is ahead along our heading
var gap_kind := 0
var gap_ref: Object = null
var heading := Vector3.BACK   # unit forward (+Z of the car)
var steer_vis := 0.0
var last_yaw := 0.0
var braking_vis := false

var _paint_mats: Array[StandardMaterial3D] = []
var _tail_mat: StandardMaterial3D = null
var _wheel_meshes: Array[Node3D] = []
var _spin := 0.0
var _ride_y := RIDE_Y         # per vehicle type (vehicles/vehicle_types.gd wheel geometry)
var _wheel_r := 0.34


func _ready() -> void:
	super._ready()
	remove_from_group("vehicle")     # only offered to the player while slow (traffic.gd)
	add_to_group("traffic_car")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	if spec is Dictionary and spec.has("wheel"):
		var wh: Dictionary = spec["wheel"]
		_wheel_r = float(wh["r"])
		_ride_y = float(wh["r"]) + float(wh["rest"]) - float(wh["y"])
	for ch in get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (ch as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s) as StandardMaterial3D
				if mat == null:
					continue
				if mat.clearcoat_enabled and not _paint_mats.has(mat):
					_paint_mats.append(mat)
				elif mat.emission_enabled and mat.emission.r > 0.6 and mat.emission.g < 0.2:
					_tail_mat = mat
			break
	for w in _wheels:
		for ch in w.get_children():
			if ch is Node3D:
				_wheel_meshes.append(ch)


func set_paint(c: Color) -> void:
	paint = c
	for m in _paint_mats:
		m.albedo_color = c


## Places the kinematic body on the lane (called by traffic.gd every physics tick).
func ai_pose(pos: Vector3, fwd: Vector3, accel: float, delta: float) -> void:
	heading = fwd
	var b := Basis.looking_at(-fwd, Vector3.UP)
	# A little nose dive under braking and squat when pulling away.
	b = b * Basis(Vector3.RIGHT, clampf(accel * 0.006, -0.03, 0.02))
	global_transform = Transform3D(b, Vector3(pos.x, _ride_y, pos.z))
	# Wheels: roll with the speed and steer with the path curvature.
	var yaw := atan2(fwd.x, fwd.z)
	var yaw_rate := wrapf(yaw - last_yaw, -PI, PI) / maxf(delta, 0.001)
	last_yaw = yaw
	var target_steer := 0.0
	if ai_speed > 0.5:
		target_steer = clampf(atan(2.7 * yaw_rate / ai_speed), -0.6, 0.6)
	steer_vis = lerpf(steer_vis, target_steer, 1.0 - exp(-10.0 * delta))
	_spin = fmod(_spin + ai_speed / _wheel_r * delta, TAU)
	steering = steer_vis     # VehicleBody3D turns the front wheel nodes
	for i in _wheels.size():
		var w := _wheels[i]
		var wm := _wheel_meshes[i] if i < _wheel_meshes.size() else null
		if wm:
			wm.rotation.x = _spin if w.position.x > 0.0 else -_spin
	var br := accel < -0.6 or ai_speed < 0.2
	if br != braking_vis and _tail_mat:
		braking_vis = br
		_tail_mat.emission_energy_multiplier = 4.5 if br else 1.2


## The AI stops steering: the car is a normal physics body from now on.
func go_physical(vel: Vector3) -> void:
	if not freeze:
		return
	freeze = false
	sleeping = false
	linear_velocity = vel
	angular_velocity = Vector3.ZERO
	_prev_speed = vel.length()
	_engine.stop()
	for i in _wheels.size():
		var wm := _wheel_meshes[i] if i < _wheel_meshes.size() else null
		if wm:
			wm.rotation.x = 0.0
	if _tail_mat:
		_tail_mat.emission_energy_multiplier = 1.2
	braking_vis = false


## Back to an AI car for the pool (recycling).
func reset_for_pool() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	mode = DRIVE
	pooled = true
	has_driver = true
	health = 100.0
	_smoke.emitting = false
	_fire.emitting = false
	_engine.stop()
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	lane_off = 0.0
	lane_target = 0.0
	pass_until = -1.0
	blocked_t = 0.0
	panic_t = 0.0
	crash_t = 0.0
	honks_left = 0
	gap = 999.0
	gap_ref = null
	remove_from_group("vehicle")


func _physics_process(delta: float) -> void:
	if mode == DRIVE:
		return       # traffic.gd drives
	super._physics_process(delta)


func enter(who: Node3D) -> void:
	if mode == DRIVE or mode == CRASHED:
		if traffic and is_instance_valid(traffic):
			traffic.on_carjack(self)
		if mode == DRIVE:
			go_physical(heading * ai_speed)
	mode = PLAYER
	pooled = false
	has_driver = false
	add_to_group("vehicle")
	super.enter(who)


func exit() -> Vector3:
	mode = PARKED
	return super.exit()


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if health <= 0.0 and mode == DRIVE and traffic and is_instance_valid(traffic):
		traffic.crash(self, null)


func on_hit(point: Vector3, damage: float, dir_: Vector3, bullet: bool) -> void:
	super.on_hit(point, damage, dir_, bullet)
	if traffic and is_instance_valid(traffic):
		traffic.on_car_shot(self)

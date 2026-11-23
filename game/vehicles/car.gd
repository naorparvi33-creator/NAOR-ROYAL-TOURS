extends VehicleBody3D
## Drivable car: "realistic enough" arcade handling tuned for phones.
## Weight, acceleration, braking and a handbrake drift; steering gets gentler with
## speed (steering assist). Engine sound follows the revs, hard hits damage the car
## (smoke, then fire), and anyone the car hits at speed is knocked down.

signal destroyed

const MAX_ENGINE := 3300.0
const MAX_BRAKE := 60.0
const TOP_SPEED := 42.0          # m/s (~150 km/h)
const MAX_STEER := 0.55

var driver: Node3D = null
var peds: Node = null
var health := 100.0
var paint := Color(0.6, 0.05, 0.05)

var _engine: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _fire: CPUParticles3D
var _wheels: Array[VehicleWheel3D] = []
var _prev_speed := 0.0
var _crash_cooldown := 0.0


func _ready() -> void:
	add_to_group("vehicle")
	mass = 1250.0
	collision_layer = 1 | 8
	collision_mask = 1
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.45, 0.1)
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.05
	angular_damp = 0.6

	var body := MeshInstance3D.new()
	body.mesh = CarMesh.build(paint)
	add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.78, 0.62, 4.3)
	col.shape = box
	col.position = Vector3(0, 0.66, 0)
	add_child(col)
	var col2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(1.5, 0.46, 1.9)
	col2.shape = box2
	col2.position = Vector3(0, 1.18, -0.3)
	add_child(col2)

	var wmesh := CarMesh.wheel_mesh()
	for wz in [1.38, -1.35]:
		for wx in [0.8, -0.8]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(wx, 0.42, wz)
			w.use_as_steering = wz > 0.0
			w.use_as_traction = true
			w.wheel_radius = 0.34
			w.wheel_rest_length = 0.16
			w.suspension_travel = 0.22
			w.suspension_stiffness = 48.0
			w.suspension_max_force = 9000.0
			w.damping_compression = 2.4
			w.damping_relaxation = 3.0
			w.wheel_friction_slip = 2.8 if wz > 0.0 else 2.5
			w.wheel_roll_influence = 0.25
			var wm := MeshInstance3D.new()
			wm.mesh = wmesh
			wm.rotation.y = 0.0 if wx > 0.0 else PI
			w.add_child(wm)
			add_child(w)
			_wheels.append(w)

	_engine = AudioStreamPlayer3D.new()
	_engine.stream = load("res://assets/audio/car_engine.wav")
	_engine.unit_size = 5.0
	_engine.max_distance = 80.0
	add_child(_engine)

	_smoke = _particles(Color(0.25, 0.25, 0.25, 0.6), 0.25, 1.2, 3.0)
	_smoke.position = Vector3(0, 0.95, 1.6)
	_fire = _particles(Color(1.0, 0.45, 0.1, 0.9), 0.18, 0.5, 4.0)
	_fire.position = Vector3(0, 0.95, 1.7)
	body_entered.connect(_on_body_entered)


func _particles(c: Color, size: float, life: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	p.mesh = q
	p.amount = 24
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.emitting = false
	add_child(p)
	return p


func enter(who: Node3D) -> void:
	driver = who
	sleeping = false
	Sfx.play_3d("car_door", global_position, 0.0)
	_engine.play()


func exit() -> Vector3:
	driver = null
	engine_force = 0.0
	brake = 8.0
	_engine.stop()
	Sfx.play_3d("car_door", global_position, 0.0)
	# Step out on the driver's side, or the other side if that is blocked.
	return global_position + global_basis.x * 1.6 + Vector3(0, 0.3, 0)


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func _physics_process(delta: float) -> void:
	_crash_cooldown -= delta
	var fwd_speed := linear_velocity.dot(global_basis.z)
	var spd := linear_velocity.length()
	if driver == null or health <= 0.0:
		engine_force = 0.0
		steering = move_toward(steering, 0.0, delta * 2.0)
		if driver == null:
			brake = 4.0
		_prev_speed = spd
		return

	var mv := GameInput.get_move()
	var steer_in := mv.x
	var throttle := clampf(-mv.y, -1.0, 1.0)
	if GameInput.drive_gas:
		throttle = 1.0
	var braking := GameInput.drive_brake or (throttle < -0.1 and fwd_speed > 1.0)
	if GameInput.drive_brake and absf(fwd_speed) < 1.0:
		throttle = -0.6     # holding brake at a stop = reverse
		braking = false

	# Steering assist: less lock at speed so the car stays easy to control.
	var max_steer := MAX_STEER / (1.0 + spd * 0.06)
	steering = move_toward(steering, -steer_in * max_steer, delta * 3.0)
	var power := 1.0 - clampf(absf(fwd_speed) / TOP_SPEED, 0.0, 1.0)
	engine_force = 0.0 if braking else throttle * MAX_ENGINE * (0.35 + 0.65 * power)
	brake = MAX_BRAKE if braking else 0.0
	# Handbrake: rear wheels lock and slide for a drift.
	var hand := GameInput.drive_handbrake
	for w in _wheels:
		if w.position.z < 0.0:
			w.brake = 25.0 if hand else 0.0
			w.wheel_friction_slip = 1.1 if hand else 2.5

	# Engine note: pitch follows a fake gearbox.
	var gear_pos := fmod(absf(fwd_speed) / 11.0, 1.0)
	_engine.pitch_scale = 0.75 + gear_pos * 0.7 + absf(throttle) * 0.1
	_engine.volume_db = -6.0 + absf(throttle) * 4.0

	# Running people over.
	if peds and spd > 3.5:
		var front := global_position + global_basis.z * 1.6
		var hits: int = peds.vehicle_impact(front, linear_velocity, 1.5)
		if hits > 0:
			linear_velocity *= 0.9
	_prev_speed = spd


func _on_body_entered(_b: Node) -> void:
	var drop := _prev_speed - linear_velocity.length()
	if drop > 5.0 and _crash_cooldown <= 0.0:
		_crash_cooldown = 0.6
		Sfx.play_3d("car_crash", global_position, clampf(drop - 8.0, -8.0, 6.0))
		take_damage(drop * 2.5)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if driver and driver.has_method("take_damage"):
		driver.take_damage(amount * 0.3)
	_smoke.emitting = health < 45.0
	if health <= 0.0:
		_fire.emitting = true
		_engine.stop()
		destroyed.emit()


func on_hit(point: Vector3, damage: float, _dir: Vector3, _bullet: bool) -> void:
	Fx.sparks(point, Vector3.UP)
	Sfx.play_3d("bullet_impact", point, -4.0)
	take_damage(damage * 0.25)

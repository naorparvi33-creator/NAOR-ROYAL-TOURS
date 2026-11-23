extends VehicleBody3D
## Drivable vehicle: "realistic enough" arcade handling tuned for phones.
## Set `vtype` before adding it to the tree (sedan, hatch, sports, pickup, van, moto;
## see vehicles/vehicle_types.gd). Each type has its own mass, power, gearbox, grip,
## suspension, engine note, horn and procedural body (vehicles/car_mesh.gd).
##
##  * Driving: throttle / brake / reverse / handbrake drift, a gearbox the engine
##    pitch follows, steering assist (speed-sensitive lock, counter-steer, yaw
##    damping - strength in the settings) and optional tilt steering.
##  * Tyres leave skid marks and smoke when they slide (vehicles/vehicle_fx.gd).
##  * Horn while driving (the crouch button becomes the horn), people jump away.
##  * Damage: the body dents on the side that hits, lamps break, smoke, then fire;
##    a burning vehicle explodes a few seconds later (blast damage, scorched paint).
##  * The motorcycle keeps 4 physics wheels on a narrow track for stability, is held
##    upright by an assist torque and leans (visual) into turns with a rider on it.
## Anyone the vehicle hits at speed is knocked down.

signal destroyed
signal exploded

const VT := preload("res://vehicles/vehicle_types.gd")
## Sedan values, kept for subclasses (police / traffic cars) that drive with them.
const MAX_ENGINE := 3300.0
const MAX_BRAKE := 60.0
const TOP_SPEED := 42.0
const MAX_STEER := 0.55

## Vehicle type (key in vehicle_types.gd SPECS). Set before _ready.
var vtype := "sedan"
var driver: Node3D = null
var peds: Node = null
var health := 100.0:
	set(v):
		health = v
		# A pool (traffic) recycled the car: undo the wreck / dents / broken lamps.
		if v > 0.0 and (burning or (_scarred and (wrecked or v >= 100.0))):
			repair.call_deferred()
var paint := Color(0.6, 0.05, 0.05)
var plate := ""
var spec: Dictionary = {}
## Gearbox state read by the HUD: gear (-1 = reverse, 0 = neutral) and revs 0..1.
var gear := 1
var rpm := 0.0
var burning := false
var wrecked := false
var horn_on := false
var skid_level := 0.0

var _engine: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _fire: CPUParticles3D
var _wheels: Array[VehicleWheel3D] = []
var _prev_speed := 0.0
var _prev_vel := Vector3.ZERO
var _crash_cooldown := 0.0

var _body: MeshInstance3D
var _mesh: ArrayMesh
var _verts := PackedVector3Array()
var _verts0 := PackedVector3Array()
var _broken := {}
var _horn: AudioStreamPlayer3D
var _skid_snd: AudioStreamPlayer3D
var _fire_snd: AudioStreamPlayer3D
var _rider: MeshInstance3D
var _lean_node: Node3D
var _front: Node3D
var _vis_wheels: Array[Node3D] = []
var _vis_spin := 0.0
var _lean := 0.0
var _shift_t := 0.0
var _burn_t := 0.0
var _explode_at := 5.0
var _overkill := 0.0
var _wreck_t := 0.0
var _flip_t := 0.0
var _horn_scare := 0.0
var _rider_t := 0.0
var _fx: Node = null
var _engine_per_wheel := 3300.0
var _inertia_y := 2000.0
var _inertia_roll := 20.0
var _rng := RandomNumberGenerator.new()
var _interior_view := false
var _scarred := false        # dents, broken lamps or burnt (repair() undoes them)


func _ready() -> void:
	VT.register()
	add_to_group("vehicle")
	_rng.randomize()
	spec = VT.get_spec(vtype)
	var wh: Dictionary = spec["wheel"]
	var length: float = spec["L"]
	var width: float = spec["W"]
	mass = spec["mass"]
	collision_layer = 1 | 8
	collision_mask = 1
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec["com"]
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.05
	angular_damp = 0.6
	_inertia_y = mass * (length * length + width * width) / 12.0
	_inertia_roll = mass * (width * width + 0.8) / 12.0
	if plate == "":
		plate = VT.random_plate(_rng)

	var is_moto := vtype == "moto"
	_mesh = CarMesh.build_type(vtype, paint)
	_body = MeshInstance3D.new()
	_body.mesh = _mesh
	if is_moto:
		# Body, rider and visual wheels hang under a lean node (pivot on the road).
		_lean_node = Node3D.new()
		add_child(_lean_node)
		_lean_node.add_child(_body)
	else:
		add_child(_body)        # first MeshInstance3D child: traffic code finds the paint here
	_add_plates()

	for c in spec["cols"]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		col.shape = box
		col.position = c[1]
		add_child(col)

	var drive: String = spec["drive"]
	var traction := 0
	var wmesh := CarMesh.wheel_mesh(float(wh["r"]), float(wh["w"]))
	for wz in [float(wh["zf"]), float(wh["zr"])]:
		for wx in [float(wh["x"]), -float(wh["x"])]:
			var w := VehicleWheel3D.new()
			var front: bool = wz > 0.0
			w.position = Vector3(wx, float(wh["y"]), wz)
			w.use_as_steering = front
			w.use_as_traction = drive == "awd" or (drive == "fwd") == front
			if w.use_as_traction:
				traction += 1
			w.wheel_radius = wh["r"]
			w.wheel_rest_length = wh["rest"]
			w.suspension_travel = wh["travel"]
			w.suspension_stiffness = wh["stiff"]
			w.suspension_max_force = wh["maxf"]
			w.damping_compression = wh["dc"]
			w.damping_relaxation = wh["dr"]
			w.wheel_friction_slip = wh["slip_f"] if front else wh["slip_r"]
			w.wheel_roll_influence = wh["roll"]
			if not is_moto:
				var wm := MeshInstance3D.new()
				wm.mesh = wmesh
				wm.rotation.y = 0.0 if wx > 0.0 else PI
				w.add_child(wm)
			add_child(w)
			_wheels.append(w)
	_engine_per_wheel = float(spec["accel"]) * mass / maxf(traction, 1)
	if is_moto:
		_build_moto_parts(wmesh)

	_engine = AudioStreamPlayer3D.new()
	_engine.stream = load("res://assets/audio/%s.wav" % spec["sound"])
	_engine.unit_size = 5.0
	_engine.max_distance = 80.0
	add_child(_engine)

	var bay := Vector3(0, float(spec["prof"][spec["prof"].size() - 1][1]) + 0.25, length * 0.5 - 0.7) if spec.has("prof") else Vector3(0, 0.8, 0.1)
	_smoke = _particles(Color(0.25, 0.25, 0.25, 0.6), 0.25, 1.2, 3.0)
	_smoke.position = bay
	_fire = _particles(Color(1.0, 0.45, 0.1, 0.9), 0.18, 0.5, 4.0)
	_fire.position = bay + Vector3(0, 0, 0.1)
	body_entered.connect(_on_body_entered)

	_rider = MeshInstance3D.new()
	_rider.mesh = CarMesh.rider_mesh(is_moto)
	_rider.position = spec["seat"]
	_rider.visible = false
	_rider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rider.visibility_range_end = 120.0
	if is_moto:
		_lean_node.add_child(_rider)
	else:
		add_child(_rider)


func _add_plates() -> void:
	var pf: Vector3 = _mesh.get_meta("plate_f", Vector3.ZERO)
	var pr: Vector3 = _mesh.get_meta("plate_r", Vector3.ZERO)
	for i in 2:
		var p := pf if i == 0 else pr
		if p == Vector3.ZERO:
			continue
		var lab := Label3D.new()
		lab.text = plate
		lab.font_size = 44
		lab.pixel_size = 0.0021
		lab.modulate = Color(0.04, 0.04, 0.04)
		lab.outline_size = 0
		lab.double_sided = false
		lab.position = p + Vector3(0, 0, 0.004 if i == 0 else -0.004)
		lab.rotation.y = 0.0 if i == 0 else PI
		if vtype == "moto":
			lab.rotation.x = 0.25
			lab.font_size = 30
		lab.visibility_range_end = 18.0
		lab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(_lean_node if _lean_node else self as Node3D).add_child(lab)


func _build_moto_parts(wmesh: ArrayMesh) -> void:
	var wh: Dictionary = spec["wheel"]
	var head := Vector3(0, 1.0, 0.5)
	_front = Node3D.new()
	_front.position = head
	_lean_node.add_child(_front)
	var fm := MeshInstance3D.new()
	fm.mesh = CarMesh.moto_front_mesh()
	_front.add_child(fm)
	var fw := MeshInstance3D.new()
	fw.mesh = wmesh
	fw.position = Vector3(0, float(wh["y"]), float(wh["zf"])) - head
	_front.add_child(fw)
	var rw := MeshInstance3D.new()
	rw.mesh = wmesh
	rw.position = Vector3(0, float(wh["y"]), float(wh["zr"]))
	_lean_node.add_child(rw)
	_vis_wheels = [fw, rw]


func _particles(c: Color, size: float, life: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
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
	Sfx.play_3d("car_door", global_position, -6.0 if vtype == "moto" else 0.0, 1.4 if vtype == "moto" else 1.0)
	_engine.play()
	gear = 1
	_rider.visible = true
	var fx := _get_fx()
	if fx:
		fx.on_enter(self)


func exit() -> Vector3:
	var fx := _get_fx()
	if fx:
		fx.on_exit(self)
	driver = null
	engine_force = 0.0
	brake = 8.0
	_engine.stop()
	_set_horn(false)
	_set_skid_sound(0.0)
	_rider.visible = _ai_has_driver()
	Sfx.play_3d("car_door", global_position, 0.0)
	# Step out on the driver's side.
	var side := 0.9 if vtype == "moto" else float(spec["W"]) * 0.5 + 0.75
	return global_position + global_basis.x * side + Vector3(0, 0.3, 0)


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func display_name() -> String:
	return Loc.t(spec.get("name", "veh_sedan"))


# ================================================================ physics

func _physics_process(delta: float) -> void:
	_crash_cooldown -= delta
	var fwd_speed := linear_velocity.dot(global_basis.z)
	var spd := linear_velocity.length()
	if burning or wrecked:
		_burn_tick(delta)
	if float(spec["roll_assist"]) > 0.0 and not wrecked:
		_upright_assist(float(spec["roll_assist"]))
	elif driver != null and health > 0.0:
		_roll_stability()
	_rider_t -= delta
	if _rider_t <= 0.0:
		_rider_t = 0.4
		if driver == null:
			_rider.visible = _ai_has_driver() and health > 0.0

	if driver == null or health <= 0.0:
		engine_force = 0.0
		steering = move_toward(steering, 0.0, delta * 2.0)
		if driver == null:
			brake = 4.0 * mass / 1250.0
		_set_horn(false)
		if spd > 4.0 and not freeze:
			_tyres(delta, spd, false)
		else:
			_set_skid_sound(0.0)
		_moto_visuals(delta, spd)
		_prev_speed = spd
		_prev_vel = linear_velocity
		return

	var assist := float(Settings.get_value("veh_steer_assist"))
	var mv := GameInput.get_move()
	var steer_in := mv.x
	var fx := _get_fx()
	if fx and int(Settings.get_value("veh_tilt")) > 0 and absf(steer_in) < 0.08:
		steer_in = fx.tilt_steer()
	var throttle := clampf(-mv.y, -1.0, 1.0)
	if GameInput.drive_gas:
		throttle = 1.0
	var braking := GameInput.drive_brake or (throttle < -0.1 and fwd_speed > 1.0)
	if GameInput.drive_brake and absf(fwd_speed) < 1.0:
		throttle = -0.6     # holding brake at a stop = reverse
		braking = false
	var hand := GameInput.drive_handbrake

	# Steering assist: less lock at speed, counter-steer into slides, yaw damping.
	var top: float = spec["top"]
	var max_steer := float(spec["steer"]) / (1.0 + spd * 0.1 * (0.15 + assist))
	var target := -steer_in * max_steer
	var local_v := global_basis.inverse() * linear_velocity
	if fwd_speed > 3.0 and not hand and assist > 0.0:
		var slip := atan2(local_v.x, maxf(absf(local_v.z), 1.0))
		target += clampf(slip, -0.5, 0.5) * assist * 0.7
	var rate := 3.2 if absf(target) > absf(steering) else 4.5
	steering = move_toward(steering, clampf(target, -float(spec["steer"]), float(spec["steer"])), delta * rate)
	if assist > 0.0 and absf(steer_in) < 0.1 and not hand and _on_ground():
		apply_torque(Vector3(0, -angular_velocity.y * _inertia_y * 1.6 * assist, 0))

	_gearbox(delta, fwd_speed, throttle)
	var power := 1.0 - clampf(absf(fwd_speed) / top, 0.0, 1.0)
	var shift_cut := 0.35 if _shift_t > 0.0 else 1.0
	var low_gear := 1.15 if gear == 1 else 1.0
	engine_force = 0.0 if braking else throttle * _engine_per_wheel * (0.35 + 0.65 * power) * shift_cut * low_gear
	if fwd_speed > top and throttle > 0.0:
		engine_force = 0.0
	brake = float(spec["brake"]) if braking else 0.0
	# Handbrake: rear wheels lock and slide for a drift.
	var wh: Dictionary = spec["wheel"]
	for w in _wheels:
		if w.position.z < 0.0:
			w.brake = 25.0 * mass / 1250.0 if hand else 0.0
			w.wheel_friction_slip = float(wh["slip_r"]) * (0.45 if hand else 1.0)

	_tyres(delta, spd, hand)
	_moto_visuals(delta, spd)

	# Horn: the crouch button (touch), C / H keys or the B pad button.
	var honk := GameInput.drive_horn or Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_H)
	_set_horn(honk)
	if honk:
		_horn_scare -= delta
		if _horn_scare <= 0.0 and peds and peds.has_method("_panic_near"):
			_horn_scare = 0.8
			peds.call("_panic_near", global_position + global_basis.z * 6.0, 9.0)

	# Running people over.
	if peds and spd > 3.5:
		var front := global_position + global_basis.z * float(spec["L"]) * 0.36
		var hits: int = peds.vehicle_impact(front, linear_velocity, 0.9 if vtype == "moto" else 1.5)
		if hits > 0:
			linear_velocity *= 0.9
			if vtype == "moto":
				take_damage(4.0)

	# Upside down for a while: put it back on its wheels (phone players can't rock it).
	if global_basis.y.y < 0.3 and spd < 3.0:
		_flip_t += delta
		if _flip_t > 2.5:
			_flip_t = 0.0
			var f := global_basis.z
			f.y = 0.0
			if f.length() < 0.1:
				f = Vector3.FORWARD
			global_transform = Transform3D(Basis.looking_at(-f.normalized(), Vector3.UP), global_position + Vector3(0, 1.2, 0))
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		_flip_t = 0.0
	_prev_speed = spd
	_prev_vel = linear_velocity


func _on_ground() -> bool:
	for w in _wheels:
		if w.is_in_contact():
			return true
	return false


## Fake gearbox: revs climb through each gear, shifts cut the power for a moment.
func _gearbox(delta: float, fwd_speed: float, throttle: float) -> void:
	var n: int = spec["gears"]
	var top: float = spec["top"]
	var v := absf(fwd_speed)
	_shift_t -= delta
	var target := 0.0
	if fwd_speed < -0.5 and throttle < 0.0:
		gear = -1
		target = clampf(v / (top * 0.22), 0.0, 1.0)
	else:
		if gear < 1:
			gear = 1
		var g_top := top * pow(float(gear) / n, 0.8)
		var g_low := top * pow(float(gear - 1) / n, 0.8) if gear > 1 else 0.0
		target = clampf(v / g_top, 0.0, 1.05)
		if target > 0.94 and gear < n and throttle > 0.2:
			gear += 1
			_shift_t = 0.22
		elif gear > 1 and v < g_low * 0.8:
			gear -= 1
	var idle := 0.12 + absf(throttle) * (0.3 if v < 2.0 else 0.0)
	target = maxf(target, idle)
	if _shift_t > 0.0:
		target *= 0.72
	rpm = lerpf(rpm, target, 1.0 - exp(-9.0 * delta))
	var pitch: float = spec["pitch"]
	_engine.pitch_scale = pitch * (0.62 + rpm * 1.05) + absf(throttle) * 0.04
	_engine.volume_db = -8.0 + absf(throttle) * 5.0 + rpm * 2.0


## Skid marks, tyre smoke and squeal when the tyres slide.
func _tyres(_delta: float, spd: float, hand: bool) -> void:
	var fx := _get_fx()
	var local_v := global_basis.inverse() * linear_velocity
	var lat := clampf((absf(local_v.x) - 1.8) / 4.0, 0.0, 1.0)
	var top_level := 0.0
	for i in _wheels.size():
		var w := _wheels[i]
		var s := 0.0
		if w.is_in_contact() and spd > 3.0:
			s = maxf(lat, clampf((0.55 - w.get_skidinfo()) * 2.2, 0.0, 1.0))
			if hand and w.position.z < 0.0 and spd > 5.0:
				s = maxf(s, 0.75)
		top_level = maxf(top_level, s)
		if fx and (vtype != "moto" or i % 2 == 0):
			fx.skid(self, i, w.get_contact_point() if s > 0.0 else Vector3.ZERO, s, spd)
	skid_level = top_level
	_set_skid_sound(top_level if spd > 4.0 else 0.0)


func _set_skid_sound(level: float) -> void:
	if level < 0.15:
		if _skid_snd and _skid_snd.playing:
			_skid_snd.stop()
		return
	if _skid_snd == null:
		_skid_snd = _player3d("veh_skid", 7.0)
	_skid_snd.volume_db = linear_to_db(clampf(level, 0.05, 1.0)) - 4.0
	_skid_snd.pitch_scale = 0.9 + level * 0.2
	if not _skid_snd.playing:
		_skid_snd.play(randf() * 0.8)


func _set_horn(on: bool) -> void:
	if on == horn_on:
		return
	horn_on = on
	if on:
		if _horn == null:
			_horn = _player3d(spec["horn"], 12.0)
		_horn.play()
	elif _horn:
		_horn.stop()


func _player3d(sound: String, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/%s.wav" % sound)
	p.unit_size = unit
	p.max_distance = 120.0
	p.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")), 0.0001))
	add_child(p)
	return p


## Motorcycle: keep the frame upright (torque about the forward axis).
func _upright_assist(k: float) -> void:
	var fwd := global_basis.z
	var up := global_basis.y
	var err := up.cross(Vector3.UP).dot(fwd)
	var w := angular_velocity.dot(fwd)
	apply_torque(fwd * (err * 140.0 - w * 20.0) * _inertia_roll * k)


## Cars: resist body roll past ~10 degrees so hard turns slide instead of tipping over.
func _roll_stability() -> void:
	var fwd := global_basis.z
	var up := global_basis.y
	if up.y < 0.4 or not _on_ground():
		return
	var err := up.cross(Vector3.UP).dot(fwd)
	var lim := 0.17
	if absf(err) < lim:
		return
	var w := angular_velocity.dot(fwd)
	apply_torque(fwd * ((err - signf(err) * lim) * 260.0 - w * 12.0) * _inertia_roll)


## Motorcycle visuals: lean into turns, steer the fork, spin the wheels.
func _moto_visuals(delta: float, spd: float) -> void:
	if _lean_node == null:
		return
	var wb := float(spec["wheel"]["zf"]) - float(spec["wheel"]["zr"])
	var want := 0.0
	if spd > 1.0 and not wrecked:
		want = clampf(atan(spd * spd * tan(steering) / (wb * 9.8)), -0.75, 0.75)
	elif driver == null and not wrecked:
		want = -0.12       # on its side stand
	_lean = lerpf(_lean, want, 1.0 - exp(-6.0 * delta))
	_lean_node.rotation.z = -_lean
	var rake := Vector3(0, 0.946, -0.325)
	_front.basis = Basis(rake, steering)
	var r: float = spec["wheel"]["r"]
	_vis_spin = fmod(_vis_spin + linear_velocity.dot(global_basis.z) / r * delta, TAU)
	for vw in _vis_wheels:
		vw.rotation.x = _vis_spin


# ================================================================ damage

func _on_body_entered(_b: Node) -> void:
	var dv := linear_velocity - _prev_vel
	dv.y *= 0.3
	var impact := dv.length()
	if impact > 5.0 and _crash_cooldown <= 0.0:
		_crash_cooldown = 0.6
		Sfx.play_3d("car_crash", global_position, clampf(impact - 8.0, -8.0, 6.0))
		var local_dir := global_basis.inverse() * (-dv).normalized()
		_dent(local_dir, clampf((impact - 4.0) / 22.0, 0.05, 1.0) * 0.2)
		take_damage(impact * 2.5)
		if vtype == "moto" and impact > 9.0 and driver:
			_throw_rider(impact)


## A hard hit throws the rider off the bike.
func _throw_rider(impact: float) -> void:
	var who := driver
	var vel := _prev_vel
	if who.has_method("exit_vehicle"):
		who.exit_vehicle()
	if "velocity" in who:
		who.velocity = vel * 0.45 + Vector3.UP * 4.0
	if who.has_method("take_damage"):
		who.take_damage(impact * 1.2)


func take_damage(amount: float) -> void:
	if wrecked:
		return
	if health <= 0.0:
		# Already burning: more damage sets it off sooner.
		_overkill += amount
		if _overkill > 35.0:
			explode()
		return
	health -= amount
	if driver and driver.has_method("take_damage"):
		driver.take_damage(amount * 0.3)
	_smoke.emitting = health < 45.0
	if amount > 18.0 and _rng.randf() < 0.35:
		_break_light(_rng.randi() % 4)
	if health <= 0.0:
		burning = true
		_burn_t = 0.0
		_explode_at = _rng.randf_range(4.0, 7.0)
		_fire.emitting = true
		_engine.stop()
		_set_horn(false)
		destroyed.emit()
		if amount > 140.0:
			explode()


func on_hit(point: Vector3, damage: float, _dir: Vector3, _bullet: bool) -> void:
	Fx.sparks(point, Vector3.UP)
	Sfx.play_3d("bullet_impact", point, -4.0)
	# Shots near a lamp break it.
	var lp := to_local(point)
	var hd: Array = spec.get("head", [])
	var tl: Array = spec.get("tail", [])
	var half: float = float(spec["L"]) * 0.5
	if not hd.is_empty() and absf(lp.y - float(hd[1])) < 0.2:
		if lp.z > half - 0.45:
			_break_light(CarMesh.S_HEAD_L if lp.x > 0.0 else CarMesh.S_HEAD_R)
		elif lp.z < -half + 0.45 and absf(lp.y - float(tl[1])) < 0.25:
			_break_light(CarMesh.S_TAIL_L if lp.x > 0.0 else CarMesh.S_TAIL_R)
	take_damage(damage * 0.25)


## Breaks one lamp: kind is a CarMesh.S_HEAD_* / S_TAIL_* value (or 0..3 = any).
func _break_light(kind: int) -> void:
	if kind < CarMesh.S_HEAD_L:
		kind = CarMesh.S_HEAD_L + kind
	if _broken.has(kind):
		return
	var idx := CarMesh.surface_of(_mesh, kind)
	if idx < 0:
		return
	_broken[kind] = true
	_scarred = true
	_mesh.surface_set_material(idx, CarMesh.shared_mat("broken_lens"))
	var fx := _get_fx()
	if fx:
		fx.play_at("veh_glass", to_global(_light_pos(kind)), -6.0)
	Fx.sparks(to_global(_light_pos(kind)), global_basis.z)


func _light_pos(kind: int) -> Vector3:
	var front := kind == CarMesh.S_HEAD_L or kind == CarMesh.S_HEAD_R
	var arr: Array = spec.get("head" if front else "tail", [0.5, 0.7, 0.2, 0.1])
	var sx := 1.0 if kind == CarMesh.S_HEAD_L or kind == CarMesh.S_TAIL_L else -1.0
	return Vector3(sx * float(arr[0]), float(arr[1]), float(spec["L"]) * (0.5 if front else -0.5))


## Pushes the body in on the side that took the hit (vertex offsets, cheap: only on impacts).
func _dent(local_dir: Vector3, depth: float) -> void:
	if vtype == "moto" or depth <= 0.0:
		return
	if _verts0.is_empty():
		_verts0 = CarMesh.body_vertices(vtype)
		_verts = _verts0.duplicate()
	_scarred = true
	var d := local_dir
	d.y *= 0.4
	if d.length() < 0.01:
		return
	d = d.normalized()
	var half := Vector3(float(spec["W"]) * 0.5, 0.45, float(spec["L"]) * 0.5)
	var center := Vector3(0, float(spec["bottom"]) + 0.4, 0)
	var seed_x := _rng.randf() * 10.0
	# Light lens on the hit side breaks with a dent at that end.
	if depth > 0.06:
		if d.z > 0.6:
			_break_light(CarMesh.S_HEAD_L if d.x > 0.0 else CarMesh.S_HEAD_R)
		elif d.z < -0.6:
			_break_light(CarMesh.S_TAIL_L if d.x > 0.0 else CarMesh.S_TAIL_R)
	for i in _verts0.size():
		var v0 := _verts0[i]
		var rel := (v0 - center) / half
		var a := rel.normalized().dot(d)
		if a < 0.78:
			continue
		var k := (a - 0.78) / 0.22
		var wobble := 0.75 + 0.25 * sin(v0.x * 11.0 + v0.z * 7.0 + v0.y * 5.0 + seed_x)
		var p := _verts[i] - d * depth * k * k * wobble
		var off := p - v0
		if off.length() > 0.3:
			p = v0 + off.normalized() * 0.3
		_verts[i] = p
	CarMesh.apply_body_vertices(_mesh, vtype, _verts)


func _burn_tick(delta: float) -> void:
	if burning and not wrecked:
		_burn_t += delta
		if _fire_snd == null:
			_fire_snd = _player3d("veh_fire", 6.0)
			_fire_snd.play()
		# The fire grows until it reaches the tank.
		_fire.amount = 24
		_fire.scale_amount_max = 3.0 + _burn_t * 0.6
		if _burn_t >= _explode_at:
			explode()
	elif wrecked:
		_wreck_t += delta
		if _wreck_t > 25.0 and _fire.emitting:
			_fire.emitting = false
			if _fire_snd:
				_fire_snd.stop()
		if _wreck_t > 70.0 and _smoke.emitting:
			_smoke.emitting = false


## Blows the vehicle up: blast (damage + push around), scorched paint, broken glass.
func explode() -> void:
	if wrecked:
		return
	wrecked = true
	_scarred = true
	burning = false
	_wreck_t = 0.0
	health = minf(health, 0.0)
	_engine.stop()
	_set_horn(false)
	_set_skid_sound(0.0)
	var center := global_position + global_basis.y * 0.8
	var fx := _get_fx()
	if fx:
		fx.explosion(center, self)
	else:
		Sfx.play_3d("car_crash", center, 6.0, 0.6)
	if driver and driver.has_method("exit_vehicle"):
		var who := driver
		who.exit_vehicle()
		if who.has_method("take_damage"):
			who.take_damage(60.0)
	# Scorched look: dark paint, black glass, dead lamps, no driver.
	var pm: StandardMaterial3D = _mesh.get_meta("paint_mat")
	pm.albedo_color = Color(0.05, 0.045, 0.04)
	pm.metallic = 0.15
	pm.roughness = 0.95
	pm.clearcoat_enabled = false
	var gi := CarMesh.surface_of(_mesh, CarMesh.S_GLASS)
	if gi >= 0:
		_mesh.surface_set_material(gi, CarMesh.shared_mat("burnt_glass"))
	for k in [CarMesh.S_HEAD_L, CarMesh.S_HEAD_R, CarMesh.S_TAIL_L, CarMesh.S_TAIL_R]:
		var idx := CarMesh.surface_of(_mesh, k)
		if idx >= 0:
			_mesh.surface_set_material(idx, CarMesh.shared_mat("burnt"))
			_broken[k] = true
	_rider.visible = false
	_dent(Vector3(0, 1, 0), 0.08)
	_fire.emitting = true
	_fire.scale_amount_max = 4.0
	_smoke.emitting = true
	_smoke.amount = 32
	if _fire_snd == null:
		_fire_snd = _player3d("veh_fire", 6.0)
	_fire_snd.play()
	# The blast lifts and spins the wreck.
	sleeping = false
	apply_central_impulse(Vector3.UP * mass * 5.5 + global_basis.x * mass * _rng.randf_range(-1.5, 1.5))
	apply_torque_impulse(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * _inertia_roll * 6.0)
	exploded.emit()


## Undoes all damage (used when a pool recycles the vehicle).
func repair() -> void:
	if not _scarred and not burning:
		return
	_scarred = false
	wrecked = false
	burning = false
	_overkill = 0.0
	_burn_t = 0.0
	_wreck_t = 0.0
	_fire.emitting = false
	_smoke.emitting = false
	if _fire_snd:
		_fire_snd.stop()
	var pm: StandardMaterial3D = _mesh.get_meta("paint_mat")
	pm.albedo_color = paint
	pm.metallic = 0.55
	pm.roughness = 0.22
	pm.clearcoat_enabled = true
	var gi := CarMesh.surface_of(_mesh, CarMesh.S_GLASS)
	if gi >= 0:
		_mesh.surface_set_material(gi, CarMesh.shared_mat("glass"))
	for k in [CarMesh.S_HEAD_L, CarMesh.S_HEAD_R, CarMesh.S_TAIL_L, CarMesh.S_TAIL_R]:
		var idx := CarMesh.surface_of(_mesh, k)
		if idx >= 0:
			var front: bool = k == CarMesh.S_HEAD_L or k == CarMesh.S_HEAD_R
			_mesh.surface_set_material(idx, _mesh.get_meta("head_mat" if front else "tail_mat"))
	_broken.clear()
	if not _verts0.is_empty():
		_verts = _verts0.duplicate()
		CarMesh.apply_body_vertices(_mesh, vtype, _verts)


# ================================================================ helpers

func _get_fx() -> Node:
	if _fx == null or not is_instance_valid(_fx):
		if not is_inside_tree():
			return null
		_fx = get_tree().get_first_node_in_group("vehicle_fx")
	return _fx


func _ai_has_driver() -> bool:
	return bool(get("has_driver")) if "has_driver" in self else false


## Cockpit camera: show the inside of the shell, hide our own driver.
func set_interior_view(on: bool) -> void:
	_interior_view = on
	var pm: StandardMaterial3D = _mesh.get_meta("paint_mat")
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED if on else BaseMaterial3D.CULL_BACK
	_rider.visible = driver != null and (not on or vtype == "moto") and not wrecked
	if vtype == "moto" and on:
		_rider.visible = false

extends Node3D
## Vehicle module (registered in world/main.gd). Shared, pooled driving effects and
## the in-vehicle extras that are not part of a single car:
##  * Skid marks: one MultiMesh ring buffer of road decal strips (one draw call).
##  * Tyre smoke: a few pooled particle emitters handed to the sliding wheels.
##  * Explosions: pooled fireball / smoke / debris bursts, a short flash light
##    (no shadows), blast damage and push around, camera shake.
##  * Cameras: chase (the normal rig), hood and first-person / helmet. Double-tap the
##    free screen area on the right (or V / pad Back) to switch; also in the settings.
##  * Tilt steering (accelerometer, calibrated when you get in) for car.gd.
##  * Small gauge next to the speedometer: gear, revs and vehicle damage.

const VT := preload("res://vehicles/vehicle_types.gd")
const MARKS := 700
const SMOKERS := 4
const BLASTS := 2
const ONESHOTS := 4
const BLAST_RADIUS := 9.0

var main: Node = null

var _marks: MultiMesh
var _mark_i := 0
var _mark_count := 0
var _last_pt := {}          # car id * 8 + wheel -> last mark point
var _smokers: Array[CPUParticles3D] = []
var _smoke_key: Array[int] = []
var _smoke_t: Array[float] = []
var _blasts: Array = []      # [fireball, smoke, debris]
var _blast_i := 0
var _flash: OmniLight3D
var _flash_t := 0.0
var _oneshots: Array[AudioStreamPlayer3D] = []
var _os_i := 0
var _streams := {}
var _shake := 0.0
var _time := 0.0

var _cam: Camera3D
var _cam_car: Node = null
var _cam_mode := -1
var _last_tap_t := -10.0
var _last_tap_p := Vector2.ZERO
var _tilt_neutral := INF
var _hint_shown := false
var _gauge: Control


func _ready() -> void:
	VT.register()
	add_to_group("vehicle_fx")
	_build_marks()
	_build_smoke()
	_build_blasts()
	for i in ONESHOTS:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 10.0
		p.max_distance = 220.0
		add_child(p)
		_oneshots.append(p)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.62, 0.3)
	_flash.omni_range = 16.0
	_flash.shadow_enabled = false
	_flash.light_energy = 0.0
	_flash.visible = false
	_flash.top_level = true
	add_child(_flash)
	_cam = Camera3D.new()
	_cam.top_level = true
	_cam.near = 0.05
	_cam.fov = 74.0
	add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_gauge = Control.new()
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	layer.add_child(_gauge)


# ================================================================ skid marks / smoke

func _build_marks() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat
	_marks = MultiMesh.new()
	_marks.transform_format = MultiMesh.TRANSFORM_3D
	_marks.use_colors = true
	_marks.mesh = quad
	_marks.instance_count = MARKS
	_marks.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _marks
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)


func _build_smoke() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# BILLBOARD_ENABLED + keep_scale: billboard particles with vertex colours draw
	# not-yet-emitted particles as black quads at the emitter.
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = mat
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.85, 0.85, 0.55))
	ramp.set_color(1, Color(0.75, 0.75, 0.75, 0.0))
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	for i in SMOKERS:
		var p := CPUParticles3D.new()
		p.mesh = q
		p.amount = 36
		p.lifetime = 2.0
		p.emitting = false
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.25
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 0.5, 0)
		p.damping_min = 0.8
		p.damping_max = 1.6
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.6
		p.scale_amount_curve = curve
		p.color_ramp = ramp
		p.top_level = true
		add_child(p)
		_smokers.append(p)
		_smoke_key.append(-1)
		_smoke_t.append(-10.0)


## Called by car.gd every physics tick per wheel. point = ZERO when not sliding.
func skid(car: Node3D, wheel: int, point: Vector3, level: float, speed: float) -> void:
	var key := car.get_instance_id() * 8 + wheel
	if level < 0.3 or point == Vector3.ZERO:
		_last_pt.erase(key)
		return
	if _last_pt.has(key):
		var last: Vector3 = _last_pt[key]
		var d := last.distance_to(point)
		if d > 3.0:
			_last_pt[key] = point
		elif d > 0.35:
			_add_mark(last, point, level, 0.2 if str(car.get("vtype")) != "moto" else 0.12)
			_last_pt[key] = point
	else:
		_last_pt[key] = point
	if level > 0.45 and speed > 5.0:
		_smoke_at(key, point, level)


func _add_mark(a: Vector3, b: Vector3, level: float, width: float) -> void:
	var dir := b - a
	dir.y = 0.0
	var length := dir.length()
	if length < 0.01:
		return
	var dn := dir / length
	var x := Vector3.UP.cross(dn) * width
	var xf := Transform3D(Basis(x, Vector3.UP, dn * (length + 0.06)), (a + b) * 0.5 + Vector3(0, 0.025, 0))
	_marks.set_instance_transform(_mark_i, xf)
	_marks.set_instance_color(_mark_i, Color(1, 1, 1, clampf(0.25 + level * 0.5, 0.0, 0.75)))
	_mark_i = (_mark_i + 1) % MARKS
	_mark_count = mini(_mark_count + 1, MARKS)
	_marks.visible_instance_count = _mark_count


func _smoke_at(key: int, point: Vector3, level: float) -> void:
	var idx := _smoke_key.find(key)
	if idx == -1:
		# Take a free emitter, else the one used longest ago.
		var oldest := 0
		for i in SMOKERS:
			if _smoke_t[i] < _smoke_t[oldest]:
				oldest = i
		idx = oldest
		_smoke_key[idx] = key
	var p := _smokers[idx]
	p.global_position = point + Vector3(0, 0.25, 0)
	p.emitting = true
	_smoke_t[idx] = _time


# ================================================================ explosions

func _build_blasts() -> void:
	var fire_ramp := Gradient.new()
	fire_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 1.0])
	fire_ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.12, 0.95),
		Color(0.45, 0.12, 0.04, 0.7), Color(0.08, 0.07, 0.07, 0.0)])
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.12, 0.11, 0.1, 0.85))
	smoke_ramp.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(0.3, 1.0))
	grow.add_point(Vector2(1, 1.4))
	var puff: Material = _smokers[0].mesh.surface_get_material(0)
	var fq := QuadMesh.new()
	fq.size = Vector2(2.2, 2.2)
	fq.material = puff
	var sq := QuadMesh.new()
	sq.size = Vector2(3.2, 3.2)
	sq.material = puff
	var debris := BoxMesh.new()
	debris.size = Vector3(0.18, 0.06, 0.25)
	debris.material = Mats.plain(Color(0.06, 0.055, 0.05), 0.9)
	for i in BLASTS:
		var fire := _burst(fq, 40, 1.1, 2.0, 10.0, 180.0, Vector3(0, 2.0, 0), fire_ramp, grow)
		fire.damping_min = 4.0
		fire.damping_max = 7.0
		var smoke := _burst(sq, 26, 4.5, 1.5, 4.0, 50.0, Vector3(0, 1.6, 0), smoke_ramp, grow)
		smoke.explosiveness = 0.6
		var deb := _burst(debris, 22, 2.4, 6.0, 15.0, 70.0, Vector3(0, -9.8, 0), null, null)
		deb.angular_velocity_min = -400.0
		deb.angular_velocity_max = 400.0
		deb.particle_flag_rotate_y = true
		_blasts.append([fire, smoke, deb])


func _burst(mesh: Mesh, amount: int, life: float, v0: float, v1: float, spread: float, grav: Vector3,
		ramp: Gradient, curve: Curve) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	if ramp:
		p.color_ramp = ramp
	if curve:
		p.scale_amount_curve = curve
	p.top_level = true
	add_child(p)
	return p


## Fireball, debris, sound, light flash, damage and push within BLAST_RADIUS.
func explosion(center: Vector3, source: Node = null) -> void:
	var burst_set: Array = _blasts[_blast_i]
	_blast_i = (_blast_i + 1) % BLASTS
	for p in burst_set:
		(p as CPUParticles3D).global_position = center
		(p as CPUParticles3D).restart()
	_flash.global_position = center + Vector3(0, 1.0, 0)
	_flash.visible = true
	_flash.light_energy = 9.0
	_flash_t = 0.45
	play_at("veh_explosion", center, 8.0)
	Fx.sparks(center, Vector3.UP)
	# Camera shake by distance.
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(center)
		_shake = maxf(_shake, clampf(1.0 - d / 45.0, 0.0, 1.0))
	get_tree().call_group("panic_listeners", "on_gunshot", center)
	_blast_damage(center, source)


func _blast_damage(center: Vector3, source: Node) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = BLAST_RADIUS
	q.shape = sph
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = 1 | 2 | 4 | 8
	q.collide_with_bodies = true
	var seen := {}
	for r in space.intersect_shape(q, 48):
		var c: Object = r["collider"]
		if c == null or c == source or seen.has(c.get_instance_id()):
			continue
		seen[c.get_instance_id()] = true
		var n := c as Node3D
		if n == null:
			continue
		var to := n.global_position + Vector3(0, 0.8, 0) - center
		var dist := to.length()
		var k := clampf(1.0 - dist / BLAST_RADIUS, 0.0, 1.0)
		if k <= 0.0:
			continue
		var dir := to.normalized() if dist > 0.01 else Vector3.UP
		if c is VehicleBody3D:
			var vb := c as VehicleBody3D
			if vb.has_method("take_damage"):
				vb.take_damage(135.0 * k)
			vb.sleeping = false
			vb.apply_central_impulse((dir + Vector3.UP * 0.6) * vb.mass * 7.0 * k)
		elif c.has_method("on_hit"):
			c.on_hit(n.global_position + Vector3(0, 1.0, 0), 160.0 * k, dir, false)
		elif c is CharacterBody3D and c.has_method("take_damage"):
			c.take_damage(95.0 * k)
			(c as CharacterBody3D).velocity += (dir + Vector3.UP * 0.5) * 9.0 * k
		elif c is RigidBody3D:
			(c as RigidBody3D).apply_central_impulse(dir * (c as RigidBody3D).mass * 6.0 * k)


func play_at(sound: String, pos: Vector3, db := 0.0) -> void:
	if not _streams.has(sound):
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	var p := _oneshots[_os_i]
	_os_i = (_os_i + 1) % ONESHOTS
	p.stream = _streams[sound]
	p.global_position = pos
	p.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")), 0.0001)) + db
	p.pitch_scale = randf_range(0.92, 1.06)
	p.play()


# ================================================================ per frame

func _process(delta: float) -> void:
	_time += delta
	for i in SMOKERS:
		if _smokers[i].emitting and _time - _smoke_t[i] > 0.12:
			_smokers[i].emitting = false
			_smoke_key[i] = -1
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.light_energy = maxf(_flash_t / 0.45, 0.0) * 9.0
		if _flash_t <= 0.0:
			_flash.visible = false
	_update_camera(delta)
	if _gauge:
		_gauge.queue_redraw()


func _player_vehicle() -> Node3D:
	if main == null or main.player == null:
		return null
	var p: Node = main.player
	if bool(p.in_vehicle) and p.vehicle and is_instance_valid(p.vehicle):
		return p.vehicle
	return null


func _update_camera(delta: float) -> void:
	var v := _player_vehicle()
	var mode := int(Settings.get_value("veh_cam"))
	var rig: Node = main.player.rig if main and main.player else null
	var rig_cam: Camera3D = rig.camera if rig else null
	var use := v != null and mode > 0 and "spec" in v and not (v.get("spec") as Dictionary).is_empty()
	if not use:
		if _cam.current:
			_cam.current = false
			if rig_cam:
				rig_cam.current = true
		if _cam_car and is_instance_valid(_cam_car) and _cam_car.has_method("set_interior_view"):
			_cam_car.set_interior_view(false)
		_cam_car = null
		_apply_shake(rig_cam, delta)
		return
	if _cam_car != v:
		if _cam_car and is_instance_valid(_cam_car) and _cam_car.has_method("set_interior_view"):
			_cam_car.set_interior_view(false)
		_cam_car = v
		_cam_mode = -1
	if _cam_mode != mode:
		_cam_mode = mode
		v.set_interior_view(mode == 2)
		_center_rig(v, 1.0)
	if not _cam.current:
		_cam.far = float(Settings.get_value("draw_distance"))
		_cam.current = true
	var sp: Dictionary = v.spec
	var xf: Transform3D = v.get_global_transform_interpolated()
	var local: Vector3 = sp["hood_cam"] if mode == 1 else sp["eye"]
	var lean := float(v.get("_lean")) if str(v.get("vtype")) == "moto" else 0.0
	local = Basis(Vector3.BACK, -lean) * local
	# Free look: follow the rig's yaw offset (it swings back behind the car by itself).
	var off := 0.0
	var pitch_off := 0.0
	if rig:
		# Let go of the look drag and the view swings back to the road ahead.
		if float(rig.get("_idle_look")) > 0.7:
			_center_rig(v, 1.0 - exp(-3.0 * delta))
		var d := xf.basis.z
		var want := atan2(-d.x, -d.z)
		off = clampf(wrapf(deg_to_rad(float(rig.yaw)) - want, -PI, PI), -1.9, 1.9)
		pitch_off = deg_to_rad(clampf(float(rig.pitch) + 10.0, -35.0, 30.0)) * 0.7
	var b := xf.basis.orthonormalized() * Basis(Vector3.UP, PI + off) * Basis(Vector3.RIGHT, pitch_off)
	if lean != 0.0:
		b = b * Basis(Vector3.BACK, lean * 0.8)
	_cam.global_transform = Transform3D(b, xf * local)
	var spd: float = (v as RigidBody3D).linear_velocity.length()
	_cam.fov = lerpf(_cam.fov, (72.0 if mode == 2 else 76.0) + clampf(spd * 0.25, 0.0, 12.0), 1.0 - exp(-4.0 * delta))
	_apply_shake(_cam, delta)


## Turns the camera rig toward the vehicle's heading (t = 1 snaps).
func _center_rig(v: Node3D, t: float) -> void:
	var rig: Node = main.player.rig if main and main.player else null
	if rig == null:
		return
	var d := v.global_basis.z
	var want := atan2(-d.x, -d.z)
	rig.yaw = rad_to_deg(lerp_angle(deg_to_rad(float(rig.yaw)), want, t))
	rig.pitch = lerpf(float(rig.pitch), -10.0, t)


func _apply_shake(cam: Camera3D, delta: float) -> void:
	if cam == null:
		return
	if _shake > 0.001:
		_shake = maxf(_shake - delta * 1.2, 0.0)
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
	elif cam.h_offset != 0.0 or cam.v_offset != 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func cycle_camera() -> void:
	var mode := (int(Settings.get_value("veh_cam")) + 1) % 3
	Settings.set_value("veh_cam", mode)
	_toast(Loc.t(["veh_cam_chase", "veh_cam_hood", "veh_cam_cockpit"][mode]))


func _toast(text: String) -> void:
	if main and main.hud and main.hud.has_method("toast"):
		main.hud.toast(text)


# ================================================================ input

func _input(event: InputEvent) -> void:
	if _player_vehicle() == null or GameInput.menu_open:
		return
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = event.position
		var vp := get_viewport().get_visible_rect().size
		if p.x < vp.x * 0.45 or p.y < vp.y * 0.12:
			return
		var touch: Node = main.hud.touch if main.hud and "touch" in main.hud else null
		if touch and touch.has_method("_button_at") and str(touch.call("_button_at", p, false)) != "":
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_tap_t < 0.32 and p.distance_to(_last_tap_p) < vp.y * 0.12:
			_last_tap_t = -10.0
			cycle_camera()
		else:
			_last_tap_t = now
			_last_tap_p = p
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		cycle_camera()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		cycle_camera()


# ================================================================ car callbacks

func on_enter(car: Node) -> void:
	_tilt_neutral = INF
	_cam_mode = -1
	_calibrate_tilt()
	if not _hint_shown:
		_hint_shown = true
		var name_text: String = car.display_name() if car.has_method("display_name") else ""
		_toast(name_text + "  -  " + Loc.t("veh_cam_hint"))


func on_exit(car: Node) -> void:
	if car.has_method("set_interior_view"):
		car.set_interior_view(false)
	for k in _last_pt.keys():
		if int(k) / 8 == car.get_instance_id():
			_last_pt.erase(k)


func _calibrate_tilt() -> void:
	var acc := Input.get_accelerometer()
	if acc.length() > 2.0:
		_tilt_neutral = atan2(acc.x, acc.y)


## Steering from tilting the phone like a wheel: -1 (left) .. 1 (right).
func tilt_steer() -> float:
	var acc := Input.get_accelerometer()
	if acc.length() < 2.0:
		return 0.0
	var ang := atan2(acc.x, acc.y)
	if _tilt_neutral == INF:
		_tilt_neutral = ang
	var d := angle_difference(_tilt_neutral, ang)
	var dead := deg_to_rad(2.5)
	if absf(d) < dead:
		return 0.0
	d -= signf(d) * dead
	var s := clampf(-d / deg_to_rad(26.0) * float(Settings.get_value("veh_tilt_sens")), -1.0, 1.0)
	return -s if int(Settings.get_value("veh_tilt")) == 2 else s


# ================================================================ gauge

func _draw_gauge() -> void:
	var v := _player_vehicle()
	if v == null or not "rpm" in v:
		return
	var s := _gauge.size
	var font := _gauge.get_theme_default_font()
	var cx := s.x * 0.5
	var y := s.y - 58.0
	# Rev bar under the speed read-out (red at the limiter).
	var r: float = clampf(float(v.rpm), 0.0, 1.0)
	var bar := Rect2(cx - 110.0, y, 220.0, 9.0)
	_gauge.draw_rect(bar, Color(0, 0, 0, 0.45))
	var col := Color(1, 1, 1, 0.85) if r < 0.85 else Color(1.0, 0.3, 0.2, 0.95)
	_gauge.draw_rect(Rect2(bar.position, Vector2(bar.size.x * r, bar.size.y)), col)
	# Gear.
	var g: int = v.gear
	var gt := Loc.t("veh_gear_r") if g < 0 else str(g)
	_gauge.draw_string(font, Vector2(cx + 122.0, s.y - 78.0), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44,
		Color(1.0, 0.82, 0.3, 0.95))
	# Vehicle damage: a small bar left of the speed, green -> red.
	var hp: float = clampf(float(v.health) / 100.0, 0.0, 1.0)
	var hb := Rect2(cx - 150.0, s.y - 118.0, 10.0, 60.0)
	_gauge.draw_rect(hb, Color(0, 0, 0, 0.45))
	var hc := Color(0.35, 0.9, 0.4).lerp(Color(1.0, 0.25, 0.15), 1.0 - hp)
	if float(v.health) <= 0.0:
		hc = Color(1.0, 0.25, 0.15, 0.5 + 0.5 * sin(_time * 12.0))
	_gauge.draw_rect(Rect2(hb.position + Vector2(0, hb.size.y * (1.0 - hp)), Vector2(hb.size.x, hb.size.y * hp)), hc)

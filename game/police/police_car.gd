extends "res://vehicles/car.gd"
## Police patrol car: the normal drivable car body in black and white, with a roof
## light bar (flashing red/blue emissive, no real lights) and a looping siren.
## While nobody is in it, simple steering drives it along the roads toward the
## player (police.gd gives the goal). Near a player on foot it brakes and drops off
## its two officers. The player can steal it like any other car.

const NAV := preload("res://police/road_nav.gd")
const LANE := 2.4

var police: Node = null
var ai := true
var crew := 2
var state := "pursue"           # pursue / parked / leave
var sees_player := false
var los_timer := 0.0
var out_of_view_t := 0.0
var flipped_t := 0.0

var _siren: AudioStreamPlayer3D
var _red: StandardMaterial3D
var _blue: StandardMaterial3D
var _flash_t := 0.0
var _stuck_t := 0.0
var _reverse_t := 0.0
var _parked_t := 0.0
var _ram_cd := 0.0
var _nav_point := Vector3.ZERO
var _nav_t := 0.0
var _leave_goal := Vector3.ZERO


func _ready() -> void:
	paint = Color(0.035, 0.04, 0.05)
	super._ready()
	add_to_group("police_unit")
	add_to_group("police_car")
	_build_livery()
	_siren = AudioStreamPlayer3D.new()
	var s: AudioStream = load("res://assets/audio/siren.wav")
	_siren.stream = s
	_siren.unit_size = 9.0
	_siren.max_distance = 260.0
	_siren.attenuation_filter_cutoff_hz = 9000.0
	add_child(_siren)
	_apply_volume()
	Settings.changed.connect(_on_setting)
	_siren.play(randf() * 3.5)


func _on_setting(k: String) -> void:
	if k == "sfx_volume":
		_apply_volume()


func _apply_volume() -> void:
	_siren.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")) * 0.75, 0.0001))


func _build_livery() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.93, 0.92)
	white.metallic = 0.4
	white.roughness = 0.25
	var dark := Mats.plain(Color(0.05, 0.05, 0.06), 0.4)
	_red = StandardMaterial3D.new()
	_red.albedo_color = Color(0.6, 0.02, 0.02)
	_red.emission_enabled = true
	_red.emission = Color(1.0, 0.05, 0.03)
	_blue = StandardMaterial3D.new()
	_blue.albedo_color = Color(0.02, 0.06, 0.6)
	_blue.emission_enabled = true
	_blue.emission = Color(0.1, 0.25, 1.0)
	var bar := Node3D.new()
	bar.position = Vector3(0, 1.43, -0.32)
	add_child(bar)
	_mesh_box(bar, Vector3(1.1, 0.07, 0.28), Vector3(0, 0, 0), dark)
	_mesh_box(bar, Vector3(0.5, 0.1, 0.24), Vector3(0.28, 0.08, 0), _red)
	_mesh_box(bar, Vector3(0.5, 0.1, 0.24), Vector3(-0.28, 0.08, 0), _blue)
	# White doors with the word "police" on both sides.
	for sx in [-1.0, 1.0]:
		_mesh_box(self, Vector3(0.025, 0.34, 1.75), Vector3(sx * 0.885, 0.78, -0.08), white)
		var lab := Label3D.new()
		lab.text = "משטרה"
		lab.font_size = 64
		lab.pixel_size = 0.0045
		lab.modulate = Color(0.06, 0.08, 0.2)
		lab.outline_size = 0
		lab.double_sided = false
		lab.position = Vector3(sx * 0.902, 0.79, -0.08)
		lab.rotation.y = sx * PI * 0.5
		lab.visibility_range_end = 45.0
		add_child(lab)


func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 150.0
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	# Light bar: quick double flashes alternating red and blue.
	_flash_t += delta
	var lights_on := health > 0.0 and (ai or driver != null)
	var ph := fmod(_flash_t, 0.8)
	var red_on := lights_on and (ph < 0.08 or (ph > 0.16 and ph < 0.24))
	var blue_on := lights_on and (ph > 0.4 and ph < 0.48 or (ph > 0.56 and ph < 0.64))
	_red.emission_energy_multiplier = 7.0 if red_on else 0.15
	_blue.emission_energy_multiplier = 7.0 if blue_on else 0.15


## Hands the car over to whoever gets in (the player stealing it).
func enter(who: Node3D) -> void:
	ai = false
	_siren.stop()
	super.enter(who)


func take_damage(amount: float) -> void:
	super.take_damage(amount * (0.45 if ai else 1.0))
	if health <= 0.0:
		_siren.stop()
		ai = false


func _physics_process(delta: float) -> void:
	if driver != null or not ai or police == null or health <= 0.0:
		super._physics_process(delta)
		return
	_ram_cd -= delta
	if global_basis.y.y < 0.35:
		flipped_t += delta
	else:
		flipped_t = 0.0
	var player: Node3D = police.player
	var pp: Vector3 = player.global_position
	var to_p := pp - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var fwd_speed := linear_velocity.dot(global_basis.z)
	var spd := linear_velocity.length()
	var stars: int = police.stars

	var goal: Vector3 = police.last_known
	if sees_player:
		goal = pp
	var max_speed := 15.0 + stars * 2.2
	match state:
		"parked":
			_parked_t += delta
			_hold(delta)
			if _parked_t > 4.0 and _siren.playing:
				_siren.stop()         # lights keep flashing
			# The player ran off: give chase again (the crew stays on foot).
			if _parked_t > 6.0 and (dist > 45.0 or player.get("in_vehicle")):
				state = "pursue"
				if not _siren.playing:
					_siren.play()
			_prev_speed = spd
			return
		"leave":
			if _leave_goal == Vector3.ZERO:
				var away := global_position - pp
				away.y = 0.0
				_leave_goal = global_position + away.normalized() * 300.0
			goal = _leave_goal
			max_speed = 12.0
			if _siren.playing:
				_siren.stop()

	# Pick where to drive: straight at the target when it is close and in sight,
	# otherwise along the roads on the right-hand lane.
	var on_foot: bool = not player.get("in_vehicle")
	if on_foot and state == "pursue":
		goal = _curb_point(goal)        # stay on the road; the crew walks the rest
	var gdist := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z).length()
	var target := goal
	var road := false
	var direct := sees_player and dist < 40.0 and not on_foot
	if on_foot and gdist < 14.0 and sees_player:
		direct = true
	if not direct or state == "leave":
		_nav_t -= delta
		if _nav_t <= 0.0:
			_nav_t = 0.25
			var np: Array = NAV.next_point(global_position, goal)
			_nav_point = np[0]
			if np[1]:
				_nav_point = NAV.lane_point(global_position, _nav_point, LANE)
		target = _nav_point
		road = true
	elif player.get("in_vehicle"):
		# Ram: aim where the player's car is going to be.
		var pv: Vector3 = player.vehicle.linear_velocity if player.vehicle else Vector3.ZERO
		target = pp + pv * clampf(dist / maxf(spd, 5.0), 0.0, 1.2)

	var local := global_transform.affine_inverse() * target
	var angle := atan2(local.x, local.z)
	var tdist := Vector2(local.x, local.z).length()
	var desired := max_speed * clampf(1.0 - absf(angle) / 1.4, 0.25, 1.0)
	if road:
		desired = minf(desired, maxf(tdist * 0.75, 7.0))
	if on_foot and state == "pursue":
		desired = minf(desired, maxf(gdist - 5.0, 0.0) * 0.55 + (0.0 if gdist < 6.0 else 3.0))
	# On foot target close by: stop at the curb and send the officers out.
	if state == "pursue" and on_foot and (dist < 16.0 or (gdist < 6.0 and dist < 40.0)):
		desired = 0.0
		if spd < 2.0:
			state = "parked"
			_parked_t = 0.0
			police.deploy_crew(self)
	if state == "pursue" and not sees_player and gdist < 10.0:
		desired = minf(desired, 4.0)     # crawl around the last known position

	# Stuck against something: back up with the wheels turned the other way.
	if _reverse_t > 0.0:
		_reverse_t -= delta
		steering = move_toward(steering, -signf(angle) * MAX_STEER, delta * 4.0)
		engine_force = -MAX_ENGINE * 0.7
		brake = 0.0
	else:
		if desired > 3.0 and spd < 1.2:
			_stuck_t += delta
			if _stuck_t > 1.6:
				_stuck_t = 0.0
				_reverse_t = 1.3
		else:
			_stuck_t = maxf(_stuck_t - delta, 0.0)
		var lock := MAX_STEER / (1.0 + spd * 0.03)
		steering = move_toward(steering, clampf(angle * 1.4, -lock, lock), delta * 3.5)
		if angle > PI * 0.6 or angle < -PI * 0.6:
			# Target behind: three-point turn.
			if spd < 3.0:
				_reverse_t = 0.9
		var err := desired - fwd_speed
		if err < -1.5:
			engine_force = 0.0
			brake = clampf(-err * 6.0, 4.0, MAX_BRAKE)
		else:
			var power := 1.0 - clampf(absf(fwd_speed) / TOP_SPEED, 0.0, 1.0)
			engine_force = clampf(err * 0.35, 0.0, 1.0) * MAX_ENGINE * (0.4 + 0.6 * power)
			brake = 0.0
	for w in _wheels:
		if w.position.z < 0.0:
			w.brake = 0.0
			w.wheel_friction_slip = 2.6

	# Hitting the player on foot hurts.
	if on_foot and spd > 6.0 and _ram_cd <= 0.0:
		var front := global_position + global_basis.z * 1.8
		var off := pp - front
		off.y = 0.0
		if off.length() < 1.8:
			_ram_cd = 1.0
			Sfx.play_3d("hit_flesh", pp + Vector3(0, 1, 0), 3.0, 0.8)
			player.take_damage(spd * 2.2)
			if player is CharacterBody3D:
				(player as CharacterBody3D).velocity += linear_velocity * 0.6 + Vector3.UP * 4.0
			linear_velocity *= 0.8
	_prev_speed = spd


## Nearest point on a road centre line to p (cars do not drive onto sidewalks/parks).
func _curb_point(p: Vector3) -> Vector3:
	var ix := NAV.nearest_line(p.x)
	var jz := NAV.nearest_line(p.z)
	var dx := absf(p.x - NAV.line(ix))
	var dz := absf(p.z - NAV.line(jz))
	if dx < 8.0 or dz < 8.0:
		return p                          # already on a road
	if dx < dz:
		return Vector3(NAV.line(ix) + signf(p.x - NAV.line(ix)) * 4.0, p.y, p.z)
	return Vector3(p.x, p.y, NAV.line(jz) + signf(p.z - NAV.line(jz)) * 4.0)


func _hold(delta: float) -> void:
	engine_force = 0.0
	brake = MAX_BRAKE * 0.6
	steering = move_toward(steering, 0.0, delta * 2.0)


func start_leaving() -> void:
	if ai and state != "leave":
		state = "leave"
		_leave_goal = Vector3.ZERO
		sees_player = false
		_nav_t = 0.0


func resume_chase() -> void:
	if ai and state == "leave":
		state = "pursue"
		_nav_t = 0.0
		if not _siren.playing:
			_siren.play()

extends CharacterBody3D
## Police officer on foot. Reuses the realistic pedestrian models (human_model.gd) in a
## navy uniform with a peaked cap and a badge. Chases the player along the roads,
## stops at firing range and shoots short bursts (hitscan with accuracy that drops
## with distance and with the player's speed). Can be shot or punched like a pedestrian.
## Driven by police.gd, which owns spawning, line-of-sight bookkeeping and recycling.

const NAV := preload("res://police/road_nav.gd")
const MODELS := ["ped_01", "ped_02", "ped_03", "ped_04", "ped_05", "ped_06", "ped_07", "ped_08", "ped_17"]
## Models that already wear their own gear (helmet, plate carrier): no cap or badge added.
const GEARED := ["ped_17"]
const GRAVITY := 22.0
const STEP_UP := 0.42
const RUN := 5.2
const SPRINT := 6.6
const WALK := 1.7
const SHIRT := Color(0.16, 0.24, 0.42)
const PANTS := Color(0.16, 0.18, 0.3)
const BODY_TIME := 25.0

static var _mat_cache := {}
static var _cap_mesh: ArrayMesh
static var _badge_mesh: ArrayMesh

var police: Node                # police.gd
var model: Node3D               # human_model.gd
var model_name := "ped_01"
var weapon_kind := 1            # 1 pistol, 2 rifle
var hp := 100.0
var state := "chase"            # chase / search / leave / dead
var sees_player := false
var los_timer := 0.0
var out_of_view_t := 0.0        # police.gd: how long nobody could see this officer
var stuck_t := 0.0

var _rng := RandomNumberGenerator.new()
var _fire_cd := 1.0
var _burst := 0
var _aim_t := 0.0
var _sidestep := Vector3.ZERO
var _sidestep_t := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _leave_dir := Vector3.ZERO
var _facing := 0.0
var _fall := 0.0
var _dead_t := 0.0
var _knock := Vector3.ZERO
var _frame := 0
var _nav_point := Vector3.ZERO
var _nav_t := 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("police_unit")
	collision_layer = 4            # hit by bullets and fists like pedestrians
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.88
	add_child(col)

	model = preload("res://player/human_model.gd").new()
	model.model_path = "res://assets/characters/%s.glb" % model_name
	model.armed = true
	model.weapon_kind = weapon_kind
	add_child(model)
	_dress()
	_frame = _rng.randi() % 3
	_fire_cd = _rng.randf_range(0.8, 1.6)


## Navy uniform: re-colours the shirt, trousers and shoes, adds a cap and a badge.
func _dress() -> void:
	for g in model.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var nm := src.resource_name if src else ""
			var key := model_name + ":" + nm
			if nm in ["shirt", "pants", "shoes"]:
				if not _mat_cache.has(key):
					var m: StandardMaterial3D
					if src is StandardMaterial3D:
						m = (src as StandardMaterial3D).duplicate()
					else:
						m = StandardMaterial3D.new()
					match nm:
						"shirt":
							m.albedo_texture = null
							m.albedo_color = SHIRT
							m.roughness = 0.82
						"pants":
							m.albedo_color = PANTS if m.albedo_texture == null else Color(0.3, 0.34, 0.55)
							m.roughness = 0.85
						"shoes":
							m.albedo_texture = null
							m.albedo_color = Color(0.03, 0.03, 0.035)
							m.roughness = 0.35
					_mat_cache[key] = m
				mi.set_surface_override_material(i, _mat_cache[key])
	var skel: Skeleton3D = model.skeleton
	if skel == null or model_name in GEARED:
		return
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		head.bone_name = "head"
		skel.add_child(head)
		var capi := MeshInstance3D.new()
		capi.mesh = _cap()
		capi.position = Vector3(0, 0.135, 0.005)
		capi.visibility_range_end = 90.0
		capi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(capi)
	if skel.find_bone("spine_03") >= 0:
		var chest := BoneAttachment3D.new()
		chest.bone_name = "spine_03"
		skel.add_child(chest)
		var b := MeshInstance3D.new()
		b.mesh = _badge()
		b.position = Vector3(0.075, 0.08, 0.13)
		b.visibility_range_end = 40.0
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chest.add_child(b)


static func _cap() -> ArrayMesh:
	if _cap_mesh:
		return _cap_mesh
	var navy := StandardMaterial3D.new()
	navy.albedo_color = Color(0.07, 0.09, 0.17)
	navy.roughness = 0.7
	var peak := StandardMaterial3D.new()
	peak.albedo_color = Color(0.02, 0.02, 0.025)
	peak.roughness = 0.25
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.68, 0.25)
	gold.metallic = 0.9
	gold.roughness = 0.3
	_cap_mesh = ArrayMesh.new()
	# Crown: slightly wider at the top, like a peaked uniform cap.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.125
	crown.bottom_radius = 0.104
	crown.height = 0.085
	crown.radial_segments = 14
	crown.rings = 1
	st.append_from(crown, 0, Transform3D.IDENTITY)
	var band := CylinderMesh.new()
	band.top_radius = 0.106
	band.bottom_radius = 0.106
	band.height = 0.03
	band.radial_segments = 14
	band.rings = 1
	st.append_from(band, 0, Transform3D(Basis(), Vector3(0, -0.045, 0)))
	st.set_material(navy)
	st.commit(_cap_mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var visor := CylinderMesh.new()
	visor.top_radius = 0.07
	visor.bottom_radius = 0.075
	visor.height = 0.012
	visor.radial_segments = 12
	visor.rings = 1
	# Flattened half-disc sticking out in front (+Z is the character's front).
	st.append_from(visor, 0, Transform3D(Basis().scaled(Vector3(1.25, 1.0, 1.0)).rotated(Vector3.RIGHT, 0.25), Vector3(0, -0.055, 0.1)))
	st.set_material(peak)
	st.commit(_cap_mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emblem := BoxMesh.new()
	emblem.size = Vector3(0.035, 0.035, 0.008)
	st.append_from(emblem, 0, Transform3D(Basis(), Vector3(0, -0.005, 0.12)))
	st.set_material(gold)
	st.commit(_cap_mesh)
	return _cap_mesh


static func _badge() -> ArrayMesh:
	if _badge_mesh:
		return _badge_mesh
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.7, 0.3)
	gold.metallic = 0.9
	gold.roughness = 0.3
	var bm := BoxMesh.new()
	bm.size = Vector3(0.045, 0.055, 0.01)
	bm.material = gold
	_badge_mesh = ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(bm, 0, Transform3D.IDENTITY)
	st.set_material(gold)
	st.commit(_badge_mesh)
	return _badge_mesh


func is_dead() -> bool:
	return state == "dead"


func dead_time() -> float:
	return _dead_t


# ------------------------------------------------------------ damage

func on_hit(point: Vector3, damage: float, dir: Vector3, bullet: bool) -> void:
	if state == "dead":
		return
	var head := point.y - global_position.y > 1.5
	if head and bullet:
		damage *= 3.0
	hp -= damage
	Fx.blood(point, dir)
	Sfx.play_3d("hit_flesh", point, -2.0)
	model.flinch()
	_fire_cd = maxf(_fire_cd, 0.35)
	if hp <= 0.0:
		_die(dir * (1.5 if bullet else 2.5))
	if police:
		police.on_officer_hurt(self, hp <= 0.0)


func _die(knock: Vector3) -> void:
	state = "dead"
	_fall = 0.0
	_dead_t = 0.0
	_knock = knock
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	sees_player = false


# ------------------------------------------------------------ behaviour

func _physics_process(delta: float) -> void:
	if police == null:
		return
	if state == "dead":
		_update_dead(delta)
		return
	var player: Node3D = police.player
	var pp: Vector3 = player.global_position
	var to_p := pp - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var stars: int = police.stars
	var shoot_range := 26.0 if weapon_kind == 2 else 17.0

	var goal := Vector3.ZERO
	var speed := 0.0
	var aiming := false
	match state:
		"chase":
			if sees_player:
				goal = pp
				if dist > shoot_range:
					speed = SPRINT if stars >= 3 else RUN
				elif dist > shoot_range * 0.6 and not _wants_to_fire():
					speed = WALK * 1.6        # close in slowly while reloading
				aiming = dist < shoot_range * 1.3
			else:
				goal = police.last_known
				var gd := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z).length()
				speed = RUN
				if gd < 4.0:
					state = "search"
					_wander_t = 0.0
		"search":
			if sees_player:
				state = "chase"
			_wander_t -= delta
			if _wander_t <= 0.0:
				var lk: Vector3 = police.last_known
				_wander = lk + Vector3(_rng.randf_range(-18, 18), 0, _rng.randf_range(-18, 18))
				_wander_t = _rng.randf_range(4.0, 7.0)
			goal = _wander
			speed = WALK * 1.4
			if police.last_known.distance_to(global_position) > 30.0:
				state = "chase"
		"leave":
			if _leave_dir == Vector3.ZERO:
				var away := global_position - pp
				away.y = 0.0
				_leave_dir = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			goal = global_position + _leave_dir * 30.0
			speed = WALK

	# Steering: direct when the goal is visible or close, otherwise along the roads.
	var move_dir := Vector3.ZERO
	if speed > 0.0:
		var target := goal
		var gflat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
		if not (state == "chase" and sees_player) and gflat.length() > 12.0 and state != "leave":
			_nav_t -= delta
			if _nav_t <= 0.0:
				_nav_t = 0.5
				_nav_point = NAV.next_point(global_position, goal)[0]
			target = _nav_point
		move_dir = Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		if move_dir.length() < 0.6:
			move_dir = Vector3.ZERO
		else:
			move_dir = move_dir.normalized()
		if _sidestep_t > 0.0:
			_sidestep_t -= delta
			move_dir = (move_dir * 0.3 + _sidestep).normalized()

	var target_vel := move_dir * speed
	var horiz := Vector3(velocity.x, 0, velocity.z).lerp(target_vel, 1.0 - exp(-10.0 * delta))
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Step up curbs and low ledges (a capsule alone cannot climb a 15 cm curb).
	if move_dir != Vector3.ZERO and is_on_wall() and is_on_floor():
		var up := Vector3(0, STEP_UP, 0)
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), move_dir * 0.35):
			global_position += up + move_dir * 0.12

	# Unstick: slide sideways along whatever blocks the way.
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if speed > 1.0 and real < 0.4:
		stuck_t += delta
		if stuck_t > 0.7 and _sidestep_t <= 0.0:
			var side := move_dir.cross(Vector3.UP)
			_sidestep = side * (1.0 if _rng.randf() < 0.5 else -1.0)
			_sidestep_t = 1.2
			if is_on_floor() and stuck_t > 2.5:
				velocity.y = 6.0     # hop over a low obstacle
	else:
		stuck_t = maxf(stuck_t - delta * 2.0, 0.0)

	# Facing: toward the player while aiming, otherwise along the movement.
	if aiming and dist > 0.5:
		_facing = lerp_angle(_facing, atan2(-to_p.x, -to_p.z), 1.0 - exp(-12.0 * delta))
	elif horiz.length() > 0.3:
		_facing = lerp_angle(_facing, atan2(-horiz.x, -horiz.z), 1.0 - exp(-8.0 * delta))
	model.rotation.y = _facing

	# Shooting.
	_fire_cd -= delta
	_aim_t = _aim_t + delta if aiming else 0.0
	if aiming and sees_player and _aim_t > 0.45 and _fire_cd <= 0.0 and dist < shoot_range * 1.4:
		_fire(pp, dist)

	# Animate far officers less often (like pedestrians).
	_frame += 1
	var near := dist < 45.0
	if near or _frame % 3 == 0:
		model.animate(delta * (1.0 if near else 3.0), horiz.length(), is_on_floor(), false, aiming)


func _wants_to_fire() -> bool:
	return _fire_cd < 0.6


func _fire(pp: Vector3, dist: float) -> void:
	var stars: int = police.stars
	if weapon_kind == 2:
		_burst += 1
		if _burst >= 3:
			_burst = 0
			_fire_cd = _rng.randf_range(1.1, 1.8)
		else:
			_fire_cd = 0.11
	else:
		_fire_cd = _rng.randf_range(0.55, 1.0) - stars * 0.04
	var fwd := Vector3(-sin(_facing), 0, -cos(_facing))
	var muzzle := global_position + Vector3(0, 1.45, 0) + fwd * 0.55
	Sfx.play_3d("gun_rifle" if weapon_kind == 2 else "gun_pistol", muzzle, -1.0, 1.04)
	Fx.sparks(muzzle, fwd)
	police.on_police_gunshot(muzzle)
	police.resolve_shot(self, muzzle, dist, weapon_kind)


func start_leaving() -> void:
	if state != "dead":
		state = "leave"
		_leave_dir = Vector3.ZERO
		sees_player = false


func resume_chase() -> void:
	if state == "leave" or state == "search":
		state = "chase"


func _update_dead(delta: float) -> void:
	_dead_t += delta
	if _fall < 1.0:
		_fall = minf(_fall + delta / 0.55, 1.0)
		var k := _fall
		model.rotation.x = -k * k * PI * 0.5
		model.rotation.z = k * 0.25
		var kn := _knock
		kn.y = 0.0
		global_position += kn * delta * (1.0 - k)
		model.animate(delta, 0.0, true, false, false)
		if _fall >= 1.0:
			var back := model.global_basis.y.normalized()
			var chest := global_position + Vector3(back.x, 0, back.z) * 1.1
			Fx.blood_pool(Vector3(chest.x, global_position.y, chest.z))

extends Node3D
## Hostile person for missions and street events: a realistic human (human_model.gd)
## with a hit capsule, simple steering on the ground and hitscan shooting at the player.
## Modes:
##   "hold"    stand at the post and fight
##   "advance" walk to `goal` (or toward the player when chase_player) and fight
##   "patrol"  guard walking between patrol points with a visible vision cone (stealth)
##   "pace"    unarmed target walking back and forth between patrol points
##   "flee"    run away from the player toward `goal`
##   "dead"
## Owners (mission scripts) free the node when the mission ends.

signal died(h: Node3D)
signal hurt_by_player(h: Node3D)

const Geo := preload("res://missions/geo.gd")
const EYE := 1.6

var player: Node3D
var peds: Node            # optional: lets cars that run people over see us as well
var model_name := "ped_02"
var weapon_kind := 2       # 0 unarmed, 1 pistol, 2 rifle
var hp := 100.0
var mode := "hold"
var goal := Vector3.ZERO
var chase_player := false
var stop_dist := 16.0
var speed := 3.4
var run_speed := 5.6
var patrol_pts: Array = []
var fixed_y := NAN         # stand on a roof (no ground probe)
var alerted := true        # fights when it sees the player
var accuracy := 0.32       # chance to hit at close range
var damage := 7.0
var fire_range := 42.0
var fire_interval := 1.2
var burst := 3
var vision := false
var vision_range := 20.0
var vision_half_deg := 52.0
var suspicion := 0.0       # 0..1 shown on the cone colour (set by the stealth mission)
var sees_player := false
var facing := 0.0
var tag := ""

var model: Node3D
var _hitbox: StaticBody3D
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _flash: MeshInstance3D
var _flash_t := 0.0
var _cool := 1.0
var _burst_left := 0
var _los_t := 0.0
var _probe_t := 0.0
var _ground := 0.0
var _avoid_t := 0.0
var _avoid_dir := Vector3.ZERO
var _patrol_i := 0
var _pause := 0.0
var _look_t := 0.0
var _fall := 0.0
var _knock := Vector3.ZERO
var _anim_skip := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("mission_hostile")
	model = preload("res://player/human_model.gd").new()
	model.model_path = "res://assets/characters/%s.glb" % model_name
	model.armed = weapon_kind > 0
	model.weapon_kind = weapon_kind
	add_child(model)
	model.rotation.y = facing

	_hitbox = Hitbox.new()
	_hitbox.owner_h = self
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.78
	col.shape = cap
	col.position.y = 0.89
	_hitbox.add_child(col)
	add_child(_hitbox)

	# Muzzle flash: a tiny unshaded quad shown for a frame or two.
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_color = Color(1.0, 0.8, 0.35, 0.9)
	q.material = fm
	_flash.mesh = q
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)

	if vision:
		_build_cone()
	if not is_nan(fixed_y):
		_ground = fixed_y
	else:
		_ground = global_position.y
	_cool = _rng.randf_range(0.6, 1.6)


func _build_cone() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var half := deg_to_rad(vision_half_deg)
	for i in segs:
		var a0 := -half + 2.0 * half * float(i) / segs
		var a1 := -half + 2.0 * half * float(i + 1) / segs
		st.set_color(Color(1, 1, 1, 0.32))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(Vector3(-sin(a1), 0, -cos(a1)) * vision_range)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(Vector3(-sin(a0), 0, -cos(a0)) * vision_range)
	_cone = MeshInstance3D.new()
	_cone.mesh = st.commit()
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.vertex_color_use_as_albedo = true
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.albedo_color = Color(1.0, 0.9, 0.3)
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position.y = 0.12
	add_child(_cone)


func is_dead() -> bool:
	return mode == "dead"


func forward() -> Vector3:
	return Vector3(-sin(facing), 0, -cos(facing))


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if mode == "dead":
		_update_dead(delta)
		return
	var pp: Vector3 = player.global_position
	var to_p := pp - global_position
	to_p.y = 0.0
	var dist := to_p.length()

	# Line of sight (a few times per second).
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.2 + _rng.randf() * 0.08
		sees_player = dist < maxf(fire_range, vision_range) + 5.0 and _has_los()

	_check_run_over()
	if mode == "dead":
		return

	var move_dir := Vector3.ZERO
	var spd := 0.0
	var aiming := false
	var can_fight := alerted and weapon_kind > 0 and sees_player and dist < fire_range
	match mode:
		"hold":
			pass
		"advance":
			var tgt := goal
			if chase_player:
				tgt = pp
			var d := Geo.flat_dist(tgt, global_position)
			var stop := stop_dist if chase_player else 1.0
			if d > stop:
				move_dir = (tgt - global_position)
				spd = speed * (0.6 if can_fight else 1.0)
		"patrol", "pace":
			if _pause > 0.0:
				_pause -= delta
				_look_t += delta
				facing += sin(_look_t * 1.3) * delta * 0.9     # look around
			elif patrol_pts.size() > 0:
				var tgt: Vector3 = patrol_pts[_patrol_i]
				if Geo.flat_dist(tgt, global_position) < 0.8:
					_patrol_i = (_patrol_i + 1) % patrol_pts.size()
					_pause = _rng.randf_range(1.5, 3.5)
				else:
					move_dir = tgt - global_position
					spd = speed * 0.45
		"flee":
			var away := goal - global_position
			if away.length() < 2.0:
				away = -to_p
			move_dir = away
			spd = run_speed

	if move_dir.length() > 0.01:
		move_dir.y = 0.0
		move_dir = _avoid(move_dir.normalized(), delta)
		global_position += move_dir * spd * delta
		if not can_fight or mode == "flee":
			facing = lerp_angle(facing, atan2(-move_dir.x, -move_dir.z), 1.0 - exp(-8.0 * delta))
	# Ground height.
	if is_nan(fixed_y):
		_probe_t -= delta
		if _probe_t <= 0.0 and spd > 0.0:
			_probe_t = 0.25
			_ground = Geo.ground_y(get_world_3d(), global_position, _ground, 1.2)
		global_position.y = lerpf(global_position.y, _ground, 1.0 - exp(-14.0 * delta))
	else:
		global_position.y = fixed_y

	if can_fight and mode != "flee":
		aiming = true
		facing = lerp_angle(facing, atan2(-to_p.x, -to_p.z), 1.0 - exp(-10.0 * delta))
		_try_shoot(delta, dist)
	elif mode == "flee" and alerted and weapon_kind > 0 and sees_player and dist < 25.0:
		_try_shoot(delta, dist)       # shoots back over the shoulder now and then
	elif sees_player == false and mode in ["hold", "advance"] and alerted and dist < fire_range * 1.5:
		facing = lerp_angle(facing, atan2(-to_p.x, -to_p.z), 1.0 - exp(-2.0 * delta))

	model.rotation.y = facing
	if _cone:
		_cone.rotation.y = facing
		var c := Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.15, 0.1), clampf(suspicion, 0.0, 1.0))
		_cone_mat.albedo_color = c
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.visible = _flash_t > 0.0
	# Far away people animate at a lower rate.
	_anim_skip += 1
	if dist < 45.0 or _anim_skip % 3 == 0:
		model.animate(delta * (1.0 if dist < 45.0 else 3.0), spd, true, false, aiming)
	_hitbox.global_position = global_position


func _has_los() -> bool:
	var from := global_position + Vector3(0, EYE, 0)
	var pp: Vector3 = player.global_position
	var to := pp + Vector3(0, 1.0 if not player.get("crouching") else 0.7, 0)
	var ex: Array = [_hitbox.get_rid()]
	if player is CollisionObject3D:
		ex.append((player as CollisionObject3D).get_rid())
	if player.get("in_vehicle") and player.get("vehicle") != null:
		ex.append((player.vehicle as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Steers around walls and poles with a short feeler ray.
func _avoid(dir: Vector3, delta: float) -> Vector3:
	_avoid_t -= delta
	if _avoid_t > 0.0:
		return _avoid_dir
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.3, 1, [_hitbox.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return dir
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	_avoid_dir = dir.rotated(Vector3.UP, side * deg_to_rad(75.0))
	_avoid_t = 0.7
	return _avoid_dir


func _try_shoot(delta: float, dist: float) -> void:
	_cool -= delta
	if _cool > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = burst
	_burst_left -= 1
	_cool = 0.13 if (_burst_left > 0 and weapon_kind == 2) else fire_interval * _rng.randf_range(0.8, 1.4)
	var muzzle := global_position + Vector3(0, 1.45, 0) + forward() * 0.6
	_flash.global_position = muzzle
	_flash.visible = true
	_flash_t = 0.06
	Sfx.play_3d("gun_rifle" if weapon_kind == 2 else "gun_pistol", muzzle, -3.0, _rng.randf_range(0.92, 1.05))
	get_tree().call_group("panic_listeners", "on_gunshot", muzzle)
	# Hit chance falls with distance; moving targets, crouching and cars help the player.
	var p := accuracy * clampf(1.1 - dist / fire_range, 0.1, 1.0)
	var pv: Vector3 = player.velocity if "velocity" in player else Vector3.ZERO
	if player.get("in_vehicle"):
		var v: Node3D = player.vehicle
		if v and "linear_velocity" in v:
			pv = v.linear_velocity
	if Vector2(pv.x, pv.z).length() > 4.0:
		p *= 0.55
	if player.get("crouching"):
		p *= 0.7
	var pp: Vector3 = player.global_position
	if _rng.randf() < p:
		if player.get("in_vehicle") and player.vehicle != null and player.vehicle.has_method("take_damage"):
			player.vehicle.take_damage(damage * 0.9)
			Fx.sparks(player.vehicle.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		elif player.has_method("take_damage"):
			player.take_damage(damage)
	else:
		var miss := pp + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(0.0, 1.8), _rng.randf_range(-1.6, 1.6))
		var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + (miss - muzzle).normalized() * (dist + 8.0), 1, [_hitbox.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			Fx.sparks(hit["position"], hit["normal"])
			Sfx.play_3d("bullet_impact", hit["position"], -8.0)


## The player's car knocks us down when it hits us at speed.
func _check_run_over() -> void:
	if not player.get("in_vehicle"):
		return
	var v: Node3D = player.vehicle
	if v == null or not ("linear_velocity" in v):
		return
	var vel: Vector3 = v.linear_velocity
	if vel.length() < 5.0:
		return
	var off := global_position - v.global_position
	off.y = 0.0
	if off.length() < 2.3:
		hp = 0.0
		Fx.blood(global_position + Vector3(0, 1.0, 0), vel)
		Sfx.play_3d("hit_flesh", global_position + Vector3(0, 1.0, 0), 4.0, 0.8)
		_die(vel * 0.6 + Vector3.UP * 2.0)
		hurt_by_player.emit(self)


## Called by the hit capsule for bullets and fists.
func hurt(point: Vector3, amount: float, dir: Vector3, bullet: bool) -> void:
	if mode == "dead":
		return
	var head := point.y - global_position.y > 1.5
	if head and bullet:
		amount *= 3.0
	# Silent takedown: a punch on an unaware guard drops him.
	if not bullet and mode in ["patrol", "pace"] and suspicion < 0.5:
		amount = 999.0
	hp -= amount
	Fx.blood(point, dir)
	Sfx.play_3d("hit_flesh", point, -2.0)
	model.flinch()
	hurt_by_player.emit(self)
	if not alerted and weapon_kind > 0 and mode != "pace":
		alerted = true
	if hp <= 0.0:
		_die(dir * (1.5 if bullet else 2.5))


func _die(knock: Vector3) -> void:
	mode = "dead"
	_fall = 0.0
	_knock = knock
	_hitbox.collision_layer = 0
	if _cone:
		_cone.visible = false
	_flash.visible = false
	died.emit(self)


func _update_dead(delta: float) -> void:
	if _fall >= 1.0:
		return
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


## Hit capsule that forwards hits to the hostile.
class Hitbox extends StaticBody3D:
	var owner_h: Node

	func on_hit(point: Vector3, damage: float = 30.0, dir: Vector3 = Vector3.ZERO, bullet: bool = true) -> void:
		if is_instance_valid(owner_h):
			owner_h.hurt(point, damage, dir, bullet)

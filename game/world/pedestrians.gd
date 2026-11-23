extends Node3D
## Pedestrians on the sidewalks around the player. A small pool of realistic people
## (MakeHuman models, procedural animation) is recycled as the player moves.
## Each person has health: bullets and fists hurt them (blood, flinch), gunfire makes
## everyone nearby run away in panic, and a hit from a fast car knocks them down.
## Missions can add special people (targets) through add_special().

signal ped_killed(ped: Dictionary)

const MODELS := ["ped_01", "ped_02", "ped_03", "ped_04", "ped_05", "ped_06", "ped_07", "ped_08"]
const COUNT := 10
const RECYCLE_DIST := 110.0
const PATH_INSET := 2.6      # metres from the curb
const FULL_RATE_DIST := 45.0
const PANIC_RADIUS := 45.0
const FLEE_SPEED := 4.8
const BODY_TIME := 30.0      # how long a body stays before the pool reuses the person

var player: Node3D
var city: Node3D
var _peds: Array = []
var _rng := RandomNumberGenerator.new()
var _frame := 0


func _ready() -> void:
	add_to_group("panic_listeners")
	_rng.randomize()
	for i in COUNT:
		var p := _make_ped(MODELS[i % MODELS.size()])
		_respawn(p)


func _make_ped(model: String) -> Dictionary:
	var m := preload("res://player/human_model.gd").new()
	m.model_path = "res://assets/characters/%s.glb" % model
	m.armed = false
	m.weapon_kind = 0
	add_child(m)
	var body := StaticBody3D.new()
	body.set_script(preload("res://world/ped_hitbox.gd"))
	body.collision_layer = 4
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.88
	body.add_child(col)
	add_child(body)
	var p := {"node": m, "body": body, "block": Vector2i.ZERO, "s": 0.0, "dir": 1.0, "speed": 1.4,
		"pause": 0.0, "hp": 100.0, "state": "walk", "timer": 0.0, "fall": 0.0, "knock": Vector3.ZERO,
		"special": false, "free_target": Vector3.ZERO}
	body.manager = self
	body.ped = p
	_peds.append(p)
	return p


## Adds a scripted person (mission target) standing near a point. Returns the ped.
func add_special(model: String, at: Vector3) -> Dictionary:
	var p := _make_ped(model)
	p["special"] = true
	p["state"] = "idle"
	var n: Node3D = p["node"]
	n.global_position = at
	n.reset_physics_interpolation()
	return p


func remove_special(p: Dictionary) -> void:
	_peds.erase(p)
	(p["node"] as Node).queue_free()
	(p["body"] as Node).queue_free()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_frame += 1
	var pp := player.global_position
	for p in _peds:
		var n: Node3D = p["node"]
		var d := n.global_position.distance_to(pp)
		match p["state"]:
			"dead":
				_update_dead(p, delta)
				if not p["special"] and (d > RECYCLE_DIST or p["timer"] > BODY_TIME):
					Fx.clear_pool_near(n.global_position)
					_respawn(p)
				continue
			"idle":
				n.animate(delta, 0.0, true, false, false)
				_sync_body(p)
				continue
		if not p["special"] and d > RECYCLE_DIST:
			_respawn(p)
			continue
		var speed: float = p["speed"]
		if p["state"] == "flee":
			p["timer"] -= delta
			speed = FLEE_SPEED
			if p["timer"] <= 0.0:
				p["state"] = "walk"
		elif p["pause"] > 0.0:
			p["pause"] -= delta
			speed = 0.0
		elif _rng.randf() < delta * 0.02:
			p["pause"] = _rng.randf_range(1.5, 4.0)     # stop for a moment now and then
		p["s"] = float(p["s"]) + float(p["dir"]) * speed * delta
		var info := _path_point(p["block"], p["s"])
		n.global_position = info[0]
		var t: Vector3 = info[1] * float(p["dir"])
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-t.x, -t.z), 1.0 - exp(-8.0 * delta))
		_sync_body(p)
		# Animate far pedestrians less often to save CPU.
		if d < FULL_RATE_DIST or (_frame + int(p["s"])) % 3 == 0:
			n.animate(delta * (1.0 if d < FULL_RATE_DIST else 3.0), speed, true, false, false)


func _sync_body(p: Dictionary) -> void:
	var b: Node3D = p["body"]
	b.global_position = (p["node"] as Node3D).global_position


# ------------------------------------------------------------ damage

func damage(p: Dictionary, point: Vector3, amount: float, dir: Vector3, bullet: bool) -> void:
	if p["state"] == "dead":
		return
	var n: Node3D = p["node"]
	var head := point.y - n.global_position.y > 1.5
	if head and bullet:
		amount *= 3.0
	p["hp"] = float(p["hp"]) - amount
	Fx.blood(point, dir)
	Sfx.play_3d("hit_flesh", point, -2.0)
	n.flinch()
	if p["hp"] <= 0.0:
		_kill(p, dir * (1.5 if bullet else 2.5))
	else:
		_flee_from(p, point - dir)
	# Witnesses run too.
	if bullet:
		on_gunshot(point)
	else:
		_panic_near(point, 12.0)


## A car moving at speed hits anyone it touches.
func vehicle_impact(pos: Vector3, vel: Vector3, radius: float) -> int:
	var hits := 0
	if vel.length() < 3.5:
		return 0
	for p in _peds:
		if p["state"] == "dead":
			continue
		var n: Node3D = p["node"]
		var off := n.global_position - pos
		off.y = 0.0
		if off.length() < radius:
			p["hp"] = 0.0
			Fx.blood(n.global_position + Vector3(0, 1.0, 0), vel)
			Sfx.play_3d("hit_flesh", n.global_position + Vector3(0, 1.0, 0), 4.0, 0.8)
			_kill(p, vel * 0.6 + Vector3.UP * 2.0)
			hits += 1
	if hits > 0:
		_panic_near(pos, 30.0)
	return hits


func on_gunshot(pos: Vector3) -> void:
	_panic_near(pos, PANIC_RADIUS)


func _panic_near(pos: Vector3, radius: float) -> void:
	for p in _peds:
		if p["state"] in ["walk", "flee"] and (p["node"] as Node3D).global_position.distance_to(pos) < radius:
			_flee_from(p, pos)


func _flee_from(p: Dictionary, danger: Vector3) -> void:
	if p["state"] == "idle":
		return
	var info := _path_point(p["block"], p["s"])
	var t: Vector3 = info[1]
	var away: Vector3 = (p["node"] as Node3D).global_position - danger
	p["dir"] = 1.0 if t.dot(away) >= 0.0 else -1.0
	p["state"] = "flee"
	p["timer"] = _rng.randf_range(8.0, 14.0)
	p["pause"] = 0.0


func _kill(p: Dictionary, knock: Vector3) -> void:
	p["state"] = "dead"
	p["fall"] = 0.0
	p["timer"] = 0.0
	p["knock"] = knock
	(p["body"] as CollisionObject3D).collision_layer = 0
	ped_killed.emit(p)


func _update_dead(p: Dictionary, delta: float) -> void:
	var n: Node3D = p["node"]
	p["timer"] = float(p["timer"]) + delta
	if p["fall"] < 1.0:
		p["fall"] = minf(float(p["fall"]) + delta / 0.55, 1.0)
		var k: float = p["fall"]
		# Topple backwards around the feet with a little twist; slide with the impact.
		n.rotation.x = -k * k * PI * 0.5
		n.rotation.z = k * 0.25
		var knock: Vector3 = p["knock"]
		knock.y = 0.0
		n.global_position += knock * delta * (1.0 - k)
		n.animate(delta, 0.0, true, false, false)
		if p["fall"] >= 1.0:
			var back := n.global_basis.y.normalized()    # body now lies along its local up axis
			var chest := n.global_position + Vector3(back.x, 0, back.z) * 1.1
			Fx.blood_pool(Vector3(chest.x, n.global_position.y, chest.z))


func _respawn(p: Dictionary) -> void:
	var c: Variant = city
	var pitch: float = c.PITCH
	var rings: int = c.RINGS
	var pp := player.global_position if player else Vector3.ZERO
	var bi := clampi(roundi(pp.x / pitch) + _rng.randi_range(-1, 1), -rings, rings)
	var bj := clampi(roundi(pp.z / pitch) + _rng.randi_range(-1, 1), -rings, rings)
	p["block"] = Vector2i(bi, bj)
	p["s"] = _rng.randf() * _loop_half() * 8.0
	p["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
	p["speed"] = _rng.randf_range(1.15, 1.6)
	p["pause"] = 0.0
	p["hp"] = 100.0
	p["state"] = "walk"
	p["timer"] = 0.0
	var n: Node3D = p["node"]
	n.rotation = Vector3.ZERO
	var info := _path_point(p["block"], p["s"])
	n.global_position = info[0]
	n.reset_physics_interpolation()
	(p["body"] as CollisionObject3D).collision_layer = 4
	_sync_body(p)


func _loop_half() -> float:
	var c: Variant = city
	return float(c.BLOCK) * 0.5 - PATH_INSET


## Point and tangent on the rectangular sidewalk loop of a block (s = distance along it).
func _path_point(block: Vector2i, s: float) -> Array:
	var c: Variant = city
	var pitch: float = c.PITCH
	var r := _loop_half()
	var side_len := r * 2.0
	var total := side_len * 4.0
	s = fposmod(s, total)
	var k := int(s / side_len)
	var t := s - k * side_len - r
	var center := Vector3(block.x * pitch, float(c.CURB_H), block.y * pitch)
	match k:
		0:
			return [center + Vector3(t, 0, -r), Vector3(1, 0, 0)]
		1:
			return [center + Vector3(r, 0, t), Vector3(0, 0, 1)]
		2:
			return [center + Vector3(-t, 0, r), Vector3(-1, 0, 0)]
	return [center + Vector3(-r, 0, -t), Vector3(0, 0, -1)]

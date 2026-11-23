extends Node3D
## Pedestrians walking the sidewalks around the player. A small fixed pool of
## realistic people (MakeHuman models, procedural walk) is recycled: anyone who ends
## up far behind the player reappears on a sidewalk nearby, so the city always feels
## alive while only a handful of characters exist at once.

const MODELS := ["ped_01", "ped_02", "ped_03", "ped_04", "ped_05", "ped_06", "ped_07", "ped_08"]
const COUNT := 10
const RECYCLE_DIST := 110.0
const PATH_INSET := 2.6      # metres from the curb
const FULL_RATE_DIST := 45.0

var player: Node3D
var city: Node3D
var _peds: Array = []
var _rng := RandomNumberGenerator.new()
var _frame := 0


func _ready() -> void:
	_rng.randomize()
	for i in COUNT:
		var m := preload("res://player/human_model.gd").new()
		m.model_path = "res://assets/characters/%s.glb" % MODELS[i % MODELS.size()]
		m.armed = false
		add_child(m)
		var p := {"node": m, "block": Vector2i.ZERO, "s": 0.0, "dir": 1.0, "speed": 1.4, "pause": 0.0}
		_peds.append(p)
		_respawn(p, true)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_frame += 1
	var pp := player.global_position
	for p in _peds:
		var n: Node3D = p["node"]
		var d := n.global_position.distance_to(pp)
		if d > RECYCLE_DIST:
			_respawn(p, false)
			continue
		var speed: float = p["speed"]
		if p["pause"] > 0.0:
			p["pause"] -= delta
			speed = 0.0
		elif _rng.randf() < delta * 0.02:
			p["pause"] = _rng.randf_range(1.5, 4.0)     # stop for a moment now and then
		p["s"] = float(p["s"]) + float(p["dir"]) * speed * delta
		var info := _path_point(p["block"], p["s"])
		n.global_position = info[0]
		var t: Vector3 = info[1] * float(p["dir"])
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-t.x, -t.z), 1.0 - exp(-8.0 * delta))
		# Animate far pedestrians less often to save CPU.
		if d < FULL_RATE_DIST or (_frame + p["s"] as int) % 3 == 0:
			n.animate(delta * (1.0 if d < FULL_RATE_DIST else 3.0), speed, true, false, false)


func _respawn(p: Dictionary, initial: bool) -> void:
	var c: Variant = city
	var pitch: float = c.PITCH
	var rings: int = c.RINGS
	var pp := player.global_position if player else Vector3.ZERO
	var bi := clampi(roundi(pp.x / pitch) + _rng.randi_range(-1, 1), -rings, rings)
	var bj := clampi(roundi(pp.z / pitch) + _rng.randi_range(-1, 1), -rings, rings)
	p["block"] = Vector2i(bi, bj)
	var r := _loop_half()
	p["s"] = _rng.randf() * r * 8.0
	p["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
	p["speed"] = _rng.randf_range(1.15, 1.6)
	p["pause"] = 0.0
	var n: Node3D = p["node"]
	var info := _path_point(p["block"], p["s"])
	n.global_position = info[0]
	n.reset_physics_interpolation()


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

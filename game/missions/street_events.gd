extends Node3D
## Random street events while the player is free roaming:
##  * mugging: an armed mugger threatens a bystander on the sidewalk; he runs (and
##    shoots back) when the player comes close or fires. Stop him before he escapes.
##  * getaway car: robbers race away from a job; wreck their car before it gets away.
## One event at a time, only when no mission is running. Everything is cleaned up.

signal event_finished(kind: String, passed: bool)

const Geo := preload("res://missions/geo.gd")
const Hostile := preload("res://missions/hostile.gd")
const MissionCar := preload("res://missions/mission_car.gd")

var campaign: Node
var player: Node3D
var peds: Node
var missions: Node
var ui: CanvasLayer

var kind := ""                 # "" when idle
var done_count := 0
var _cooldown := 75.0
var _spawned: Array = []
var _victim: Dictionary = {}
var _target: Node3D
var _t := 0.0
var _flee := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_cooldown = _rng.randf_range(60.0, 110.0)
	player.died.connect(func():
		if kind != "":
			_end(false, ""))
	player.weapon.fired.connect(func():
		if kind == "mug":
			_flee = true)


func is_active() -> bool:
	return kind != ""


func waypoint() -> Variant:
	if kind == "" or _target == null or not is_instance_valid(_target):
		return null
	return _target.global_position


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if kind == "":
		if campaign.is_busy() or player.health <= 0.0:
			return
		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = _rng.randf_range(90.0, 170.0)
			if player.in_vehicle and _rng.randf() < 0.65:
				start("chase")
			else:
				start("mug")
		return
	_t += delta
	match kind:
		"mug":
			_tick_mug(delta)
		"chase":
			_tick_chase()


## Starts an event now (also used by tests). Returns false when no spot was found.
func start(k: String) -> bool:
	if kind != "":
		return false
	_t = 0.0
	_flee = false
	if k == "mug":
		if not _start_mug():
			return false
	else:
		_start_chase()
	kind = k
	missions.blocked = true
	Sfx.play_ui("mission_start")
	return true


func _start_mug() -> bool:
	# A sidewalk spot 30-50 m away from the player.
	var pp: Vector3 = player.global_position
	var spot := Vector3.INF
	for tries in 60:
		var bi := clampi(roundi(pp.x / Geo.PITCH) + _rng.randi_range(-1, 1), -Geo.RINGS, Geo.RINGS)
		var bj := clampi(roundi(pp.z / Geo.PITCH) + _rng.randi_range(-1, 1), -Geo.RINGS, Geo.RINGS)
		if bi == 0 and bj == 0:
			continue
		var p := Geo.walk_point(bi, bj, _rng.randi_range(0, 3), _rng.randf_range(-0.8, 0.8))
		var d := Geo.flat_dist(p, pp)
		if d > 25.0 and d < 70.0:
			spot = p
			break
	if spot == Vector3.INF:
		return false
	var dir := Vector3(1, 0, 0).rotated(Vector3.UP, _rng.randf() * TAU)
	_victim = peds.add_special(["ped_01", "ped_03", "ped_05"][_rng.randi() % 3], spot)
	var vn: Node3D = _victim["node"]
	vn.rotation.y = atan2(dir.x, dir.z)
	var h: Hostile = Hostile.new()
	h.player = player
	h.model_name = "ped_06"
	h.weapon_kind = 1
	h.mode = "hold"
	h.alerted = false
	h.hp = 70.0
	h.accuracy = 0.22
	h.damage = 6.0
	h.fire_range = 30.0
	h.facing = atan2(dir.x, dir.z) + PI
	add_child(h)
	h.global_position = spot + dir * 1.3
	_spawned.append(h)
	_target = h
	missions.objective_changed.emit(Loc.t("ev_mug") + ": " + Loc.t("ev_mug_ob"))
	ui.notice(Loc.t("ev_mug"), Loc.t("ev_mug_ob"), Color(1.0, 0.6, 0.35), 2.2)
	missions.timer_changed.emit(60.0)
	return true


func _tick_mug(_delta: float) -> void:
	var h := _target as Hostile
	if h == null or not is_instance_valid(h):
		_end(false, "")
		return
	missions.timer_changed.emit(maxf(60.0 - _t, 0.0))
	if h.is_dead():
		player.add_money(300)
		ui.notice(Loc.t("ev_mug_thanks"), "+$300", Color(0.6, 1.0, 0.6), 2.5)
		_end(true, "ev_mug")
		return
	var d := Geo.flat_dist(h.global_position, player.global_position)
	if (d < 13.0 or _flee or _t > 25.0) and h.mode != "flee":
		h.mode = "flee"
		h.alerted = true
		h.run_speed = 5.2
		var away := h.global_position - player.global_position
		away.y = 0.0
		h.goal = h.global_position + away.normalized() * 200.0
	if d > 120.0 or _t > 60.0:
		ui.notice(Loc.t("ev_mug_escaped"), "", Color(1.0, 0.5, 0.4), 2.0)
		_end(false, "ev_mug")


func _start_chase() -> void:
	var pp: Vector3 = player.global_position
	var n := Geo.nearest_node(pp)
	# Start one or two intersections away, heading away from the player.
	var opts: Array = Geo.neighbours(n)
	var from: Vector2i = opts[_rng.randi() % opts.size()]
	var nexts: Array = Geo.neighbours(from)
	nexts.erase(n)
	var to: Vector2i = nexts[_rng.randi() % nexts.size()] if nexts.size() > 0 else n
	var a := Geo.node_pos(from)
	var b := Geo.node_pos(to)
	var f := (b - a).normalized()
	var pos := a + f * 16.0 + Geo.right_of(f) * Geo.LANE
	var c: MissionCar = MissionCar.new()
	c.paint = Color(0.12, 0.3, 0.12)
	c.peds = peds
	c.bullet_mult = 0.7
	add_child(c)
	c.global_transform = Transform3D(Basis.looking_at(-f, Vector3.UP), pos + Vector3(0, 0.55, 0))
	c.reset_physics_interpolation()
	c.remove_from_group("vehicle")
	c.flee_from(player, from, 19.0)
	c.route = Geo.lane_points([from, to])
	c._last_node = to
	c._prev_node = from
	_spawned.append(c)
	_target = c
	missions.objective_changed.emit(Loc.t("ev_chase") + ": " + Loc.t("ev_chase_ob"))
	ui.notice(Loc.t("ev_chase"), Loc.t("ev_chase_ob"), Color(1.0, 0.6, 0.35), 2.2)


func _tick_chase() -> void:
	var c := _target as MissionCar
	if c == null or not is_instance_valid(c):
		_end(false, "")
		return
	missions.timer_changed.emit(maxf(90.0 - _t, 0.0))
	ui.set_bar("ev_car", Loc.t("bar_target_car"), c.health / 100.0, Color(1.0, 0.5, 0.3))
	if c.health <= 0.0:
		c.ai_mode = "idle"
		player.add_money(600)
		ui.notice(Loc.t("ev_chase"), "+$600", Color(0.6, 1.0, 0.6), 2.5)
		_end(true, "ev_chase")
		return
	var d := Geo.flat_dist(c.global_position, player.global_position)
	if d > 260.0 or _t > 90.0:
		ui.notice(Loc.t("ev_chase_lost"), "", Color(1.0, 0.5, 0.4), 2.0)
		_end(false, "ev_chase")


func _end(passed: bool, title_key: String) -> void:
	var k := kind
	kind = ""
	ui.clear_bar("ev_car")
	missions.objective_changed.emit("")
	missions.timer_changed.emit(-1.0)
	if title_key != "" and passed:
		missions.mission_result.emit(true, Loc.t(title_key), 0)
		done_count += 1
	missions.blocked = false
	# A short delay before the wreck / mugger disappear, then clean up.
	var nodes := _spawned.duplicate()
	_spawned.clear()
	var victim := _victim
	_victim = {}
	_target = null
	get_tree().create_timer(8.0).timeout.connect(func():
		for nd in nodes:
			if is_instance_valid(nd):
				if player.get("in_vehicle") and player.vehicle == nd:
					campaign.add_leftover(nd)
					continue
				nd.queue_free()
		if not victim.is_empty():
			peds.remove_special(victim))
	event_finished.emit(k, passed)


## Ends a running event at once (a story mission starting, tests).
func cancel() -> void:
	if kind == "":
		return
	var nodes := _spawned.duplicate()
	var victim := _victim
	_spawned.clear()
	_victim = {}
	kind = ""
	_target = null
	ui.clear_bar("ev_car")
	missions.objective_changed.emit("")
	missions.timer_changed.emit(-1.0)
	missions.blocked = false
	for nd in nodes:
		if is_instance_valid(nd):
			nd.queue_free()
	if not victim.is_empty():
		peds.remove_special(victim)

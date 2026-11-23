extends Node3D
## Runs the 8 story chapters of the campaign. Each chapter is a coroutine that
## talks (dialogue box), sets objectives, spawns what it needs and waits for
## conditions. Every wait checks a run token, so when a chapter passes, fails or the
## player dies, the coroutine simply stops and _cleanup() frees everything it spawned.
## Only the next chapter's start marker (blue/violet, distinct from the yellow odd
## jobs) is shown in the city.

signal chapter_finished(index: int, passed: bool)

const Geo := preload("res://missions/geo.gd")
const Data := preload("res://missions/story_data.gd")
const Hostile := preload("res://missions/hostile.gd")
const MissionCar := preload("res://missions/mission_car.gd")
const CHAPTERS := 8
const STORY_COLOR := Color(0.45, 0.45, 1.0, 0.42)

var campaign: Node
var player: Node3D
var peds: Node
var city: Node3D
var missions: Node
var ui: CanvasLayer

var story_index := 0          # next chapter to play (CHAPTERS = finished)
var active := -1
var _run := 0
var _time_left := -1.0
var _wp: Variant = null       # Vector3 or Node3D
var _spawned: Array = []
var _checks: Array = []       # Callables returning a fail reason key ("" = fine)
var _s: Dictionary = {}       # per-chapter state
var _marker: Node3D
var _marker_label: Label3D
var _beam: Node3D
var _starts: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_starts = [
		Geo.walk_point(0, 1, 3, -0.25),
		Geo.walk_point(2, 1, 2, 0.85),
		Geo.walk_point(-1, 1, 0, 0.55),
		Geo.walk_point(-1, 0, 3, 0.6),
		Geo.walk_point(0, 1, 3, 0.6),
		Geo.walk_point(-1, 1, 0, -0.55),
		Geo.walk_point(1, -2, 1, 0.5),
		Geo.walk_point(0, -1, 0, -0.6),
	]
	_marker = _make_beam(STORY_COLOR, 1.3, 40.0)
	add_child(_marker)
	_marker.add_to_group("map_marker")
	_marker.set_meta("map_color", Color(0.45, 0.45, 1.0))
	_marker_label = Label3D.new()
	_marker_label.font_size = 80
	_marker_label.pixel_size = 0.013
	_marker_label.outline_size = 18
	_marker_label.modulate = Color(0.75, 0.8, 1.0)
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.no_depth_test = true
	_marker_label.position = Vector3(0, 3.4, 0)
	_marker.add_child(_marker_label)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.25
	tm.outer_radius = 1.6
	tm.rings = 24
	tm.ring_segments = 6
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.5, 0.55, 1.0)
	tm.material = rm
	ring.mesh = tm
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(ring)
	_beam = _make_beam(Color(0.4, 0.6, 1.0, 0.35), 2.2, 60.0)
	_beam.visible = false
	add_child(_beam)
	player.died.connect(func():
		if active >= 0:
			_finish(false, "fail_died"))
	player.weapon.fired.connect(_on_player_fired)
	Loc.language_changed.connect(_update_marker)
	_update_marker()


func _make_beam(c: Color, radius: float, height: float) -> Node3D:
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 20
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = c
	cyl.material = mat
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height * 0.5
	holder.add_child(mi)
	return holder


func title(i: int) -> String:
	return Loc.t("st_%d" % (i + 1))


func _update_marker() -> void:
	if story_index >= CHAPTERS:
		_marker.visible = false
		return
	_marker.global_position = _starts[story_index] + Vector3(0, 0.05, 0)
	_marker_label.text = "%s %d: %s" % [Loc.t("story"), story_index + 1, title(story_index)]


func is_active() -> bool:
	return active >= 0


func waypoint() -> Variant:
	if active < 0 or _wp == null:
		return null
	if _wp is Node3D:
		if is_instance_valid(_wp):
			return (_wp as Node3D).global_position
		return null
	return _wp


# ------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if active < 0:
		var show: bool = story_index < CHAPTERS and not campaign.is_busy()
		_marker.visible = show
		if show:
			var d := Geo.flat_dist(player.global_position, _marker.global_position)
			var r := 4.5 if player.in_vehicle else 2.2
			if d < r and absf(player.global_position.y - _marker.global_position.y) < 3.0 and player.health > 0.0:
				start(story_index)
		return
	_marker.visible = false
	if _time_left >= 0.0:
		_time_left -= delta
		missions.timer_changed.emit(_time_left)
		if _time_left <= 0.0:
			_finish(false, "fail_time")
			return
	for c in _checks:
		var reason: String = (c as Callable).call()
		if reason != "":
			_finish(false, reason)
			return
	if _beam.visible and _wp is Vector3:
		_beam.global_position = _wp


func start(i: int) -> void:
	if active >= 0 or i < 0 or i >= CHAPTERS:
		return
	active = i
	_run += 1
	_s = {}
	_checks.clear()
	_time_left = -1.0
	_wp = null
	missions.blocked = true
	Sfx.play_ui("mission_start")
	missions.objective_changed.emit("%s %d · %s" % [Loc.t("story"), i + 1, title(i)])
	var run := _run
	match i:
		0: _ch_escort(run)
		1: _ch_chase(run)
		2: _ch_defend(run)
		3: _ch_stealth(run)
		4: _ch_sniper(run)
		5: _ch_delivery(run)
		6: _ch_evidence(run)
		7: _ch_final(run)


func _finish(passed: bool, reason := "") -> void:
	if active < 0:
		return
	var i := active
	var reward: int = Data.REWARDS[i] if passed else 0
	_run += 1
	active = -1
	_cleanup()
	if passed:
		player.add_money(reward)
		Sfx.play_ui("mission_done")
		story_index = maxi(story_index, i + 1)
		missions.mission_result.emit(true, "%s %d · %s" % [Loc.t("story"), i + 1, title(i)], reward)
	else:
		Sfx.play_ui("mission_fail")
		var sub := title(i)
		if reason != "":
			sub += " · " + Loc.t(reason)
		missions.mission_result.emit(false, sub, 0)
	_update_marker()
	chapter_finished.emit(i, passed)
	if passed and story_index >= CHAPTERS:
		get_tree().create_timer(4.5).timeout.connect(func():
			ui.notice(Loc.t("story_done"), Loc.t("story_credits"), Color(0.6, 0.75, 1.0), 7.0))


## Abort without a result (used by tests / debug).
func abort() -> void:
	if active >= 0:
		_finish(false, "")


func _cleanup() -> void:
	ui.stop_dialogue()
	ui.clear_bars()
	_beam.visible = false
	_wp = null
	_checks.clear()
	_time_left = -1.0
	missions.timer_changed.emit(-1.0)
	missions.objective_changed.emit("")
	for n in _spawned:
		if not is_instance_valid(n):
			continue
		if player.in_vehicle and player.vehicle == n:
			# The player keeps driving it; it becomes an ordinary car.
			if n is MissionCar:
				(n as MissionCar).ai_mode = "idle"
			if not n.is_in_group("vehicle"):
				n.add_to_group("vehicle")
			campaign.add_leftover(n)
			continue
		n.queue_free()
	_spawned.clear()
	_s = {}
	missions.blocked = false


# ------------------------------------------------------------ coroutine helpers

func _tick(run: int) -> bool:
	await get_tree().physics_frame
	return run == _run


func _wait(run: int, sec: float) -> bool:
	var t := sec
	while t > 0.0:
		if not await _tick(run):
			return false
		if not get_tree().paused:
			t -= get_physics_process_delta_time()
	return true


func _talk(run: int, beat: String) -> bool:
	if run != _run:
		return false
	var lines: Array = Data.dialogue(active, beat)
	ui.say(lines)
	while ui.talking:
		if not await _tick(run):
			return false
	return run == _run


func _obj(key: String, args: Array = []) -> void:
	var t := Loc.t(key)
	if args.size() > 0:
		t = t % args
	missions.objective_changed.emit(t)


func _set_dest(p: Vector3) -> void:
	_wp = p
	_beam.global_position = p
	_beam.visible = true


func _pdist(p: Vector3) -> float:
	return Geo.flat_dist(player.global_position, p)


func _on_player_fired() -> void:
	var w: Node = player.weapon
	if w == null or not ("WEAPONS" in w) or not ("current" in w):
		return
	var info: Dictionary = w.WEAPONS[w.current]
	if int(info.get("kind", 0)) != 0:
		_s["gunshot"] = int(_s.get("gunshot", 0)) + 1


# ------------------------------------------------------------ spawning helpers

func _hostile(pos: Vector3, opts: Dictionary = {}) -> Hostile:
	var h: Hostile = Hostile.new()
	h.player = player
	h.model_name = opts.get("model", ["ped_02", "ped_04", "ped_06", "ped_08", "ped_07"][_rng.randi() % 5])
	h.weapon_kind = int(opts.get("weapon", 2 if _rng.randf() < 0.6 else 1))
	h.hp = float(opts.get("hp", 100.0))
	h.mode = opts.get("mode", "hold")
	h.accuracy = float(opts.get("accuracy", 0.26))
	h.damage = float(opts.get("damage", 5.5))
	h.fire_range = float(opts.get("range", 40.0))
	h.alerted = bool(opts.get("alerted", true))
	h.chase_player = bool(opts.get("chase", false))
	h.stop_dist = float(opts.get("stop", _rng.randf_range(12.0, 20.0)))
	h.vision = bool(opts.get("vision", false))
	h.patrol_pts = opts.get("patrol", [])
	h.goal = opts.get("goal", pos)
	h.facing = float(opts.get("facing", _rng.randf() * TAU))
	if opts.has("fixed_y"):
		h.fixed_y = float(opts["fixed_y"])
	if opts.has("burst"):
		h.burst = int(opts["burst"])
	h.tag = opts.get("tag", "")
	add_child(h)
	h.global_position = pos
	_spawned.append(h)
	return h


func _car(pos: Vector3, dir: Vector3, paint: Color, ai: bool) -> VehicleBody3D:
	var c: VehicleBody3D
	if ai:
		c = MissionCar.new()
	else:
		c = preload("res://vehicles/car.gd").new()
	c.paint = paint
	c.peds = peds
	add_child(c)
	var d := dir
	d.y = 0.0
	var b := Basis.looking_at(-d.normalized(), Vector3.UP)
	c.global_transform = Transform3D(b, _free_spot(pos, b) + Vector3(0, 0.55, 0))
	c.reset_physics_interpolation()
	if ai:
		c.remove_from_group("vehicle")    # the player can't jump into the AI's seat
	_spawned.append(c)
	return c


## A spot for a car near `pos` that doesn't overlap parked cars or props: tries along
## the road both ways.
func _free_spot(pos: Vector3, b: Basis) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.2, 5.0)
	q.shape = box
	q.collision_mask = 1 | 8
	for step in [0.0, 7.0, -7.0, 14.0, -14.0, 21.0, -21.0, 28.0, -28.0]:
		var p := pos + b.z * float(step)
		q.transform = Transform3D(b, p + Vector3(0, 0.9, 0))
		if space.intersect_shape(q, 1).is_empty():
			return p
	return pos


func _crate(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.pbr("planks", 1.5)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	add_child(body)
	body.global_position = pos + Vector3(0, size.y * 0.5, 0)
	_spawned.append(body)


func _pickup(pos: Vector3, ctx_label: String, col: Color) -> Pickup:
	var p := Pickup.new()
	p.color = col
	p.set_meta("ctx_label", ctx_label)
	add_child(p)
	p.global_position = pos
	_spawned.append(p)
	return p


func _alive(list: Array) -> Array:
	return list.filter(func(h): return is_instance_valid(h) and not h.is_dead())


func _equip_longest() -> void:
	var w: Node = player.weapon
	if w == null or not ("WEAPONS" in w) or not ("current" in w):
		return
	var best: int = w.current
	var best_r := -1.0
	for i in w.WEAPONS.size():
		var info: Dictionary = w.WEAPONS[i]
		var r := float(info.get("range", 0.0))
		if r > best_r:
			best_r = r
			best = i
	if best != w.current:
		w.current = best
		var info: Dictionary = w.WEAPONS[best]
		player.model.set_weapon(int(info.get("kind", 2)))
		if w.has_signal("weapon_changed"):
			w.weapon_changed.emit(info.get("key", ""))


func _wave_spawn_points(center: Vector3, along: Vector3, across: Vector3, n: int) -> Array:
	var pts: Array = []
	for k in n:
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var p := center + along * sgn * _rng.randf_range(40.0, 58.0) + across * _rng.randf_range(-6.0, 9.0)
		p.y = Geo.ground_y(get_world_3d(), p, 0.0, 2.0)
		pts.append(p)
	return pts


# ------------------------------------------------------------ 1 · escort

func _ch_escort(run: int) -> void:
	var nodes := [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
	var a := Geo.node_pos(nodes[0])
	var vip := _car(a + Vector3(4, 0, 0) + Geo.right_of(Vector3(1, 0, 0)) * Geo.LANE, Vector3(1, 0, 0), Color(0.85, 0.85, 0.82), true) as MissionCar
	vip.cautious = true
	vip.bullet_mult = 0.25
	vip.crash_mult = 0.35
	_wp = vip
	if not await _talk(run, "intro"):
		return
	vip.drive_nodes(nodes, 13.0)
	_obj("ob_escort_follow")
	_s["far"] = 0.0
	_checks.append(func() -> String:
		if vip.health <= 0.0:
			return "fail_vip_dead"
		return "")
	var ambush_at := Geo.node_pos(Vector2i(0, 1)).lerp(Geo.node_pos(Vector2i(1, 1)), 0.62)
	var ambushed := false
	while vip.ai_mode != "idle":
		if not await _tick(run):
			return
		var dt := get_physics_process_delta_time()
		ui.set_bar("vip", Loc.t("bar_vip"), vip.health / 100.0, Color(0.6, 1.0, 0.55))
		var d := _pdist(vip.global_position)
		# Eli waits for the player when left behind.
		vip.hold = d > 55.0 or bool(_s.get("ambush", false))
		if d > 55.0:
			_obj("ob_escort_close")
			_s["far"] = float(_s["far"]) + dt
			if float(_s["far"]) > 25.0 and d > 160.0:
				_finish(false, "fail_vip_lost")
				return
		elif not _s.get("ambush", false):
			_s["far"] = 0.0
			_obj("ob_escort_follow")
		if not ambushed and Geo.flat_dist(vip.global_position, ambush_at) < 38.0:
			ambushed = true
			_s["ambush"] = true
			vip.hold = true
			if not await _ambush(run, vip, ambush_at):
				return
			_s["ambush"] = false
			if not await _talk(run, "resume"):
				return
	if vip.health <= 0.0:
		return
	if not await _talk(run, "outro"):
		return
	_finish(true)


func _ambush(run: int, vip: MissionCar, at: Vector3) -> bool:
	# A car across the road and gunmen on both sidewalks.
	var block := _car(at + Vector3(10, 0, -5.2), Vector3(0.8, 0, 0.6), Color(0.08, 0.08, 0.09), false)
	block.health = 60.0
	var foes: Array = []
	for k in 4:
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := at + Vector3(_rng.randf_range(2.0, 14.0), 0.15, side * _rng.randf_range(10.5, 13.0))
		foes.append(_hostile(p, {"mode": "advance", "chase": true, "stop": 14.0 + k * 2.0, "accuracy": 0.26}))
	_wp = foes[0]
	if not await _talk(run, "ambush"):
		return false
	while true:
		var alive := _alive(foes)
		if alive.is_empty():
			break
		_wp = alive[0]
		_obj("ob_escort_ambush", [alive.size()])
		# Gunmen near the car keep shooting at it.
		for h in alive:
			if Geo.flat_dist(h.global_position, vip.global_position) < 40.0:
				vip.take_damage(0.9 * get_physics_process_delta_time())
		ui.set_bar("vip", Loc.t("bar_vip"), vip.health / 100.0, Color(0.6, 1.0, 0.55))
		if not await _tick(run):
			return false
	_wp = vip
	return await _wait(run, 1.0)


# ------------------------------------------------------------ 2 · chase

func _ch_chase(run: int) -> void:
	var my_car := _car(Geo.curb_road_point(2, 1, 2, 0.85), Vector3(0, 0, -1), Color(0.1, 0.25, 0.6), false)
	var from := Vector2i(1, 0)
	var to := Vector2i(1, -1)
	var start := Geo.node_pos(from) + Vector3(0, 0, -22) + Geo.right_of(Vector3(0, 0, -1)) * Geo.LANE
	var runner := _car(start, Vector3(0, 0, -1), Color(0.05, 0.05, 0.06), true) as MissionCar
	runner.health = 100.0
	runner.bullet_mult = 0.6
	_wp = runner
	if not await _talk(run, "intro"):
		return
	_time_left = 200.0
	runner.flee_from(player, from, 20.0)
	runner.route = Geo.lane_points([from, to])
	runner._last_node = to
	runner._prev_node = from
	if not player.in_vehicle:
		_obj("ob_get_car")
		_wp = my_car
		var waited := 0.0
		while not player.in_vehicle and waited < 6.0:
			if not await _tick(run):
				return
			waited += get_physics_process_delta_time()
		_wp = runner
	_s["far"] = 0.0
	var stopped := 0.0
	while runner.health > 0.0:
		if not await _tick(run):
			return
		var dt := get_physics_process_delta_time()
		var d := _pdist(runner.global_position)
		ui.set_bar("car", Loc.t("bar_target_car"), runner.health / 100.0, Color(1.0, 0.5, 0.3))
		if d > 140.0:
			_obj("ob_chase_far")
			_s["far"] = float(_s["far"]) + dt
			if float(_s["far"]) > 12.0 or d > 300.0:
				_finish(false, "fail_lost_car")
				return
		else:
			_s["far"] = 0.0
			_obj("ob_chase" if player.in_vehicle or d < 60.0 else "ob_get_car")
		# Rammed to a stop next to the player counts as stopped.
		if runner.linear_velocity.length() < 1.5 and d < 14.0:
			stopped += dt
			if stopped > 4.0:
				runner.take_damage(runner.health + 1.0)
		else:
			stopped = 0.0
	runner.ai_mode = "idle"
	ui.clear_bar("car")
	var ledger := _pickup(runner.global_position + runner.global_basis.x * 2.2 + Vector3(0, 0.1, 0), "ctx_ledger", Color(0.2, 0.2, 0.25))
	ledger.global_position.y = Geo.ground_y(get_world_3d(), ledger.global_position, 0.0) + 0.05
	_wp = ledger
	_obj("ob_grab_ledger")
	if not await _talk(run, "wreck"):
		return
	while is_instance_valid(ledger) and not ledger.taken:
		if not await _tick(run):
			return
	_time_left = -1.0
	missions.timer_changed.emit(-1.0)
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 3 · defend

func _ch_defend(run: int) -> void:
	var g := Geo.walk_point(-1, 1, 0, 0.0)
	var wall := Geo.walk_point(-1, 1, 0, 0.0, 41.15)
	# The garage shutter and fuel barrels.
	var door := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 3.2, 5.0)
	door.mesh = bm
	door.material_override = Mats.plain(Color(0.75, 0.42, 0.12), 0.55, 0.5)
	add_child(door)
	door.global_position = wall + Vector3(0, 1.6, 0)
	_spawned.append(door)
	for k in 3:
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.9
		bar.mesh = cm
		bar.material_override = Mats.plain(Color(0.7, 0.08, 0.05), 0.5, 0.3)
		add_child(bar)
		bar.global_position = wall + Vector3(0.6, 0.45, -3.4 - k * 0.7)
		_spawned.append(bar)
	_set_dest(g)
	_wp = g
	if not await _talk(run, "intro"):
		return
	_beam.visible = false
	_s["hp"] = 100.0
	_s["away"] = 0.0
	_checks.append(func() -> String:
		if float(_s.get("hp", 100.0)) <= 0.0:
			return "fail_garage"
		if float(_s.get("away", 0.0)) > 10.0:
			return "fail_left"
		return "")
	var sizes := [3, 4, 5]
	for wave in 3:
		if wave > 0:
			_obj("ob_defend_next")
			if not await _wait(run, 3.0):
				return
			if wave == 1 and not await _talk(run, "wave"):
				return
		var pts := _wave_spawn_points(Vector3(-53, 0, 106), Vector3(0, 0, 1), Vector3(1, 0, 0), sizes[wave])
		var foes: Array = []
		for p in pts:
			var to_g: Vector3 = g - p
			to_g.y = 0.0
			var goal: Vector3 = g - to_g.normalized() * _rng.randf_range(7.0, 13.0) + Vector3(0, 0, _rng.randf_range(-4.0, 4.0))
			foes.append(_hostile(p, {"mode": "advance", "goal": goal, "accuracy": 0.24 + wave * 0.03}))
		while true:
			var alive := _alive(foes)
			if alive.is_empty():
				break
			var dt := get_physics_process_delta_time()
			for h in alive:
				if Geo.flat_dist(h.global_position, g) < 15.0:
					_s["hp"] = float(_s["hp"]) - 1.5 * dt
			var away := _pdist(g) > 60.0
			_s["away"] = float(_s["away"]) + dt if away else 0.0
			_obj("ob_defend_return" if away else "ob_defend", [] if away else [wave + 1, alive.size()])
			_wp = g if away else alive[0]
			ui.set_bar("garage", Loc.t("bar_garage"), float(_s["hp"]) / 100.0, Color(1.0, 0.65, 0.25))
			if not await _tick(run):
				return
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 4 · stealth

func _ch_stealth(run: int) -> void:
	var t := Geo.walk_point(-1, -1, 3, 0.0, 41.8)
	var cx := t.x
	var sz := -148.5
	_crate(t + Vector3(0, -0.15, 0.3), Vector3(1.2, 0.9, 1.0))
	_crate(t + Vector3(14, -0.15, -1.2), Vector3(1.6, 1.4, 1.4))
	_crate(t + Vector3(-13, -0.15, -1.6), Vector3(1.6, 1.4, 1.4))
	_crate(t + Vector3(-24, -0.15, -2.0), Vector3(1.4, 1.2, 1.2))
	_crate(t + Vector3(24, -0.15, -1.0), Vector3(1.4, 1.2, 1.2))
	var manifest := _pickup(t + Vector3(0, 0.95, 0.3), "ctx_manifest", Color(0.95, 0.95, 0.85))
	var guards: Array = []
	var gy := 0.15
	var common := {"mode": "patrol", "vision": true, "alerted": false, "weapon": 2, "accuracy": 0.4}
	var o1 := common.duplicate()
	o1["patrol"] = [Vector3(cx - 34, gy, sz), Vector3(cx - 7, gy, sz)]
	guards.append(_hostile(o1["patrol"][0], o1))
	var o2 := common.duplicate()
	o2["patrol"] = [Vector3(cx + 7, gy, sz), Vector3(cx + 34, gy, sz)]
	guards.append(_hostile(o2["patrol"][1], o2))
	var o3 := common.duplicate()
	o3["patrol"] = [Vector3(cx - 3, 0.0, -154.5), Vector3(cx + 3, 0.0, -154.5)]
	o3["facing"] = PI
	guards.append(_hostile(o3["patrol"][0], o3))
	var o4 := common.duplicate()
	o4["patrol"] = [Vector3(cx - 36, 0.0, -160.5), Vector3(cx + 36, 0.0, -160.5)]
	guards.append(_hostile(o4["patrol"][0], o4))
	var o5 := common.duplicate()
	o5["patrol"] = [Vector3(cx - 42.5, gy, -140), Vector3(cx - 42.5, gy, -112)]
	guards.append(_hostile(o5["patrol"][0], o5))
	_wp = manifest
	if not await _talk(run, "intro"):
		return
	_obj("ob_stealth_in")
	_s["meter"] = 0.0
	_s["gunshot"] = 0
	var got := false
	while true:
		if not await _tick(run):
			return
		var dt := get_physics_process_delta_time()
		var seen := 0.0
		var pp: Vector3 = player.global_position
		var crouch: bool = player.crouching and not player.in_vehicle
		for gd in _alive(guards):
			var h: Hostile = gd
			var rng: float = h.vision_range * (0.55 if crouch else 1.0)
			var to := pp - h.global_position
			to.y = 0.0
			var d := to.length()
			var in_cone := false
			if d < rng and h.sees_player:
				var ang := rad_to_deg(h.forward().angle_to(to.normalized()))
				in_cone = ang < h.vision_half_deg or d < 2.2
			if in_cone:
				seen = maxf(seen, 0.6 + 1.6 * (1.0 - d / rng))
				# Suspicious guards turn toward what they saw.
				h.facing = lerp_angle(h.facing, atan2(-to.x, -to.z), 1.0 - exp(-1.5 * dt))
		var shots := int(_s.get("gunshot", 0))
		if shots > 0:
			_s["gunshot"] = 0
			for gd in _alive(guards):
				if Geo.flat_dist((gd as Hostile).global_position, pp) < 55.0:
					_s["meter"] = float(_s["meter"]) + 0.6 * shots
					break
		var m := float(_s["meter"])
		m = m + seen * dt if seen > 0.0 else maxf(m - 0.3 * dt, 0.0)
		_s["meter"] = m
		for gd in _alive(guards):
			(gd as Hostile).suspicion = m
		ui.set_bar("detect", Loc.t("bar_detect"), m, Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.9, 0.3), 1.0 - m))
		if m >= 1.0:
			for gd in _alive(guards):
				(gd as Hostile).alerted = true
				(gd as Hostile).mode = "hold"
			_finish(false, "fail_spotted")
			return
		if not got and (not is_instance_valid(manifest) or manifest.taken):
			got = true
			_wp = t + Vector3(0, 0, 80)
			_obj("ob_stealth_out")
			ui.notice(Loc.t("ctx_manifest"), "", Color(0.9, 0.95, 1.0), 1.5)
		if got and _pdist(t) > 75.0:
			break
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 5 · sniper

func _ch_sniper(run: int) -> void:
	# Target building: the west-most building of the block east of the park.
	var best: Dictionary = {}
	var bx := INF
	var list: Array = city.get("_buildings") if city.get("_buildings") != null else []
	for b in list:
		var bc: Vector3 = b["block"]
		if bc.distance_to(Vector3(Geo.PITCH, 0, 0)) > 1.0:
			continue
		var pos: Vector3 = b["pos"]
		var size: Vector3 = b["size"]
		var west := pos.x - size.x * 0.5 + absf(pos.z) * 0.05
		if west < bx:
			bx = west
			best = b
	var tpos: Vector3
	var roof := 14.0
	if best.is_empty():
		tpos = Vector3(66, roof, 0)
	else:
		var pos: Vector3 = best["pos"]
		var size: Vector3 = best["size"]
		roof = pos.y + size.y * 0.5 + 0.5
		var z := clampf(0.0, pos.z - size.z * 0.5 + 4.0, pos.z + size.z * 0.5 - 4.0)
		tpos = Vector3(pos.x - size.x * 0.5 + 1.3, roof, z)
	# Sniping spot in the park, on open ground.
	var spot := Vector3(-12, 0, tpos.z)
	for x in [-12.0, -16.0, -8.0, -20.0, -4.0]:
		var found := false
		for dz in [0.0, 6.0, -6.0, 12.0, -12.0]:
			var p := Vector3(x, 0, tpos.z + dz)
			var gy := Geo.ground_y(get_world_3d(), p, 0.0, 25.0)
			if gy < 0.6:
				spot = Vector3(p.x, gy, p.z)
				found = true
				break
		if found:
			break
	var target: Hostile = _hostile(tpos, {"model": "ped_05", "weapon": 0, "hp": 80.0, "mode": "pace",
		"alerted": false, "fixed_y": roof, "facing": -PI * 0.5,
		"patrol": [tpos + Vector3(0, 0, -3), tpos + Vector3(0, 0, 3)], "tag": "target"})
	var guards: Array = []
	for dz in [-5.0, 5.0]:
		guards.append(_hostile(tpos + Vector3(2.5, 0, dz), {"weapon": 2, "mode": "hold", "alerted": false,
			"fixed_y": roof, "range": 170.0, "accuracy": 0.12, "damage": 5.0, "facing": -PI * 0.5}))
	_set_dest(spot)
	if not await _talk(run, "intro"):
		return
	_time_left = 240.0
	_obj("ob_sniper_go")
	var dead := [false]
	target.died.connect(func(_h): dead[0] = true)
	while _pdist(spot) > 3.0:
		if dead[0]:
			break
		if Geo.flat_dist(player.global_position, tpos) < 45.0:
			_finish(false, "fail_target_escaped")
			return
		if not await _tick(run):
			return
	_beam.visible = false
	_wp = target
	if not dead[0]:
		_equip_longest()
		if not await _talk(run, "spot"):
			return
		_time_left = 90.0
	_obj("ob_sniper_shoot")
	_s["gunshot"] = 0
	var flee_t := -1.0
	while not dead[0]:
		if not await _tick(run):
			return
		var dt := get_physics_process_delta_time()
		var d := Geo.flat_dist(player.global_position, tpos)
		if d < 45.0 and flee_t < 0.0:
			flee_t = 0.0
		elif d < 60.0 and flee_t < 0.0:
			_obj("ob_sniper_close")
		elif flee_t < 0.0:
			_obj("ob_sniper_shoot")
		if int(_s.get("gunshot", 0)) > 0 and flee_t < 0.0:
			flee_t = 0.0
		if flee_t >= 0.0:
			if flee_t == 0.0:
				target.mode = "flee"
				target.run_speed = 3.2
				target.goal = tpos + Vector3(14, 0, 0)
				for gd in guards:
					(gd as Hostile).alerted = true
				_obj("ob_sniper_flee")
			flee_t += dt
			if flee_t > 6.0 and not dead[0]:
				_finish(false, "fail_target_escaped")
				return
	if not await _wait(run, 1.2):
		return
	_time_left = -1.0
	missions.timer_changed.emit(-1.0)
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 6 · timed delivery

func _ch_delivery(run: int) -> void:
	var car := _car(Geo.curb_road_point(-1, 1, 0, -0.55), Vector3(0, 0, -1), Color(0.9, 0.75, 0.15), false)
	var dest := Geo.curb_road_point(1, -2, 1, 0.0)
	_wp = car
	if not await _talk(run, "intro"):
		return
	_time_left = 80.0
	_checks.append(func() -> String:
		if car.health <= 0.0:
			return "fail_car_lost"
		if car.health < 35.0:
			return "fail_cargo"
		return "")
	while true:
		if not await _tick(run):
			return
		ui.set_bar("cargo", Loc.t("bar_cargo"), clampf((car.health - 35.0) / 65.0, 0.0, 1.0), Color(0.6, 0.85, 1.0))
		if player.in_vehicle and player.vehicle == car:
			_set_dest(dest)
			_obj("ob_deliver_go")
			if Geo.flat_dist(car.global_position, dest) < 7.0:
				break
		else:
			_beam.visible = false
			_wp = car
			_obj("ob_deliver_get")
	_time_left = -1.0
	missions.timer_changed.emit(-1.0)
	_beam.visible = false
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 7 · evidence

func _ch_evidence(run: int) -> void:
	var spots := [
		[Geo.walk_point(2, -1, 2, -0.3, 41.3), true],
		[Geo.walk_point(2, 0, 3, 0.4, 41.3), false],
		[Geo.walk_point(0, -2, 0, 0.2, 41.3), true],
		[Geo.walk_point(-1, -2, 1, 0.5, 41.3), false],
	]
	var items: Array = []
	for s in spots:
		var p: Vector3 = s[0]
		items.append(_pickup(p + Vector3(0, 0.05, 0), "ctx_evidence", Color(0.95, 0.85, 0.4)))
		if s[1]:
			for k in 2:
				var off := Vector3(_rng.randf_range(-6.0, 6.0), 0, _rng.randf_range(-6.0, 6.0))
				_hostile(p + off, {"mode": "hold", "range": 34.0, "accuracy": 0.27})
	if not await _talk(run, "intro"):
		return
	_time_left = 420.0
	var got := 0
	while got < 4:
		if not await _tick(run):
			return
		var left: Array = items.filter(func(it): return is_instance_valid(it) and not it.taken)
		var now := 4 - left.size()
		if now > got:
			got = now
			Sfx.play_ui("money")
			if got < 4:
				_talk(run, "got%d" % got)     # plays while the player keeps moving
		if left.is_empty():
			break
		# Waypoint: the closest piece left.
		var best: Node3D = left[0]
		for it in left:
			if _pdist((it as Node3D).global_position) < _pdist(best.global_position):
				best = it
		_wp = best
		_obj("ob_evidence", [got])
	while ui.talking:
		if not await _tick(run):
			return
	_time_left = -1.0
	missions.timer_changed.emit(-1.0)
	if not await _talk(run, "outro"):
		return
	_finish(true)


# ------------------------------------------------------------ 8 · final shootout

func _ch_final(run: int) -> void:
	var arena := Vector3(56, 0, -106)
	var entrance := Geo.walk_point(1, -1, 2, 0.0, 41.6)
	_wp = arena
	if not await _talk(run, "intro"):
		return
	_s["away"] = 0.0
	_checks.append(func() -> String:
		if float(_s.get("away", 0.0)) > 15.0:
			return "fail_left"
		return "")
	for wave in 2:
		var foes: Array = []
		var n := 5
		for k in n:
			var p: Vector3
			if wave == 0:
				p = Vector3(_rng.randf_range(58.0, 66.0), 0.15, -106.0 + _rng.randf_range(-30.0, 30.0))
			else:
				var sgn := 1.0 if k % 2 == 0 else -1.0
				p = Vector3(53.0 + _rng.randf_range(-5.0, 5.0), 0.0, -106.0 + sgn * _rng.randf_range(48.0, 60.0))
			foes.append(_hostile(p, {"mode": "advance", "chase": true, "accuracy": 0.27 + wave * 0.04, "damage": 7.0,
				"stop": _rng.randf_range(10.0, 22.0)}))
		if not await _fight(run, foes, wave, arena):
			return
		if not await _wait(run, 2.0):
			return
	# Wave 3: Barzel and two bodyguards come out of the tower.
	var boss: Hostile = _hostile(entrance, {"model": "ped_07", "weapon": 2, "hp": 450.0, "mode": "advance",
		"chase": true, "stop": 11.0, "accuracy": 0.4, "damage": 9.0, "burst": 5, "range": 50.0, "tag": "boss"})
	var foes3: Array = [boss]
	for dz in [-4.0, 4.0]:
		foes3.append(_hostile(entrance + Vector3(1.5, 0, dz), {"mode": "advance", "chase": true, "accuracy": 0.32}))
	if not await _talk(run, "boss"):
		return
	_obj("ob_final_boss")
	while true:
		var alive := _alive(foes3)
		if alive.is_empty():
			break
		ui.set_bar("boss", Loc.t("bar_boss"), maxf(boss.hp, 0.0) / 450.0, Color(0.9, 0.2, 0.2))
		_wp = boss if not boss.is_dead() else alive[0]
		_s["away"] = float(_s["away"]) + get_physics_process_delta_time() if _pdist(arena) > 160.0 else 0.0
		if not await _tick(run):
			return
	ui.clear_bar("boss")
	if not await _wait(run, 1.5):
		return
	var gideon: Hostile = _hostile(entrance, {"model": "ped_05", "weapon": 0, "mode": "hold", "alerted": false,
		"facing": -PI * 0.5, "hp": 9999.0})
	_wp = gideon
	if not await _talk(run, "arrest"):
		return
	_obj("ob_final_arrest")
	while _pdist(gideon.global_position) > 3.0:
		if not await _tick(run):
			return
	missions.objective_changed.emit("")
	if not await _talk(run, "outro"):
		return
	_finish(true)


func _fight(run: int, foes: Array, wave: int, arena: Vector3) -> bool:
	while true:
		var alive := _alive(foes)
		if alive.is_empty():
			return true
		_obj("ob_final_wave", [wave + 1, alive.size()])
		_wp = alive[0]
		_s["away"] = float(_s["away"]) + get_physics_process_delta_time() if _pdist(arena) > 160.0 else 0.0
		if not await _tick(run):
			return false
	return true


## Mission item picked up with the context button.
class Pickup extends Node3D:
	var color := Color.WHITE
	var taken := false
	var _t := 0.0
	var _mesh: MeshInstance3D

	func _ready() -> void:
		_mesh = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.08, 0.32)
		_mesh.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color * 0.35
		m.roughness = 0.6
		_mesh.material_override = m
		_mesh.position.y = 0.3
		add_child(_mesh)
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 6.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		bmat.albedo_color = Color(0.5, 0.6, 1.0, 0.28)
		cyl.material = bmat
		beam.mesh = cyl
		beam.position.y = 3.0
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		add_to_group("pickup")

	func _process(delta: float) -> void:
		_t += delta
		_mesh.rotation.y = _t * 1.5
		_mesh.position.y = 0.3 + sin(_t * 3.0) * 0.05

	func collect(_player: Node) -> void:
		taken = true
		Sfx.play_ui("money")
		queue_free()

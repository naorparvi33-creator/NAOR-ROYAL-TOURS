extends Node3D
## City traffic: a recycled pool of AI cars driving the road grid around the player.
##  * Right-hand traffic in the inner lane of each road (2 m from the centre line;
##    the curb lane holds the parked cars). Cars follow straight lane pieces and
##    quadratic curves through the intersections (straight / left / right).
##  * One global traffic-light cycle for the whole city (roads along Z, then along X)
##    shown on the city's traffic lights; cars stop at the stop line on red and amber,
##    left-turners yield to oncoming traffic.
##  * Cars keep a time gap to anything ahead (cars, the player, people), honk at the
##    player, and overtake a car that is stuck in the lane when the other lane is free.
##  * Crashes: a car that is hit becomes a physics car, takes damage and the driver
##    honks (and may run away). Shooting at a car makes the driver flee at speed.
##  * Carjacking: slow AI cars are offered to the player's context button; the driver
##    jumps out and runs, and the car becomes the player's (traffic/ai_car.gd).
## Cars spawn out of sight 60-150 m from the player and are recycled when far / unseen.

const TRAFFIC_TYPES := ["sedan", "sedan", "sedan", "hatch", "hatch", "sports", "pickup", "van"]
const AiCar := preload("res://traffic/ai_car.gd")

const RED := 0
const AMBER := 1
const GREEN := 2
const DIRS := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
const STEPS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const LANE := 2.0             # lane centre from the road centre line
const BOX := 8.0              # intersection half size (ROAD_W / 2)
const STOP_BACK := 6.6        # car centre stops this far before the end of a straight piece
const CAR_HALF_L := 2.2
const CAR_HALF_W := 0.95
const LOOKAHEAD := 48.0
const SPAWN_MIN := 60.0
const SPAWN_MAX := 150.0
const DESPAWN_SEEN := 175.0
const DESPAWN_UNSEEN := 100.0
# Phase cycle: [z state, x state, seconds]
const CYCLE := [[GREEN, RED, 16.0], [AMBER, RED, 3.0], [RED, RED, 1.5],
	[RED, GREEN, 16.0], [RED, AMBER, 3.0], [RED, RED, 1.5]]
const CAR_COLORS := [Color(0.55, 0.04, 0.05), Color(0.05, 0.08, 0.16), Color(0.85, 0.85, 0.83),
	Color(0.08, 0.08, 0.09), Color(0.45, 0.47, 0.5), Color(0.12, 0.28, 0.5), Color(0.8, 0.55, 0.1),
	Color(0.15, 0.3, 0.18), Color(0.92, 0.92, 0.9), Color(0.3, 0.05, 0.25), Color(0.6, 0.62, 0.64)]
const PED_MODELS := ["ped_01", "ped_02", "ped_03", "ped_04", "ped_05", "ped_06", "ped_07", "ped_08"]

enum { K_AI, K_CAR, K_PLAYER_CAR, K_PLAYER, K_PED }

var main: Node = null
var player: Node3D
var world: Node3D
var peds: Node
var cars: Array = []          # pool (AiCar in DRIVE or CRASHED mode)
var abandoned: Array = []     # former AI cars the player took
var signals: Node3D
var phase := 0
var phase_t := 0.0
var z_state := GREEN
var x_state := RED

var _pitch := 106.0
var _n := 6                   # road lines per axis
var _target_count := 12
var _rng := RandomNumberGenerator.new()
var _obstacles: Array = []    # [pos, fwd, speed, half_l, half_w, kind, ref]
var _frame := 0
var _slow_t := 0.0
var _refill_t := 0.0
var _horns: Array[AudioStreamPlayer3D] = []
var _horn_i := 0
var _horn_short: AudioStreamWAV
var _horn_long: AudioStreamWAV
var _runners: Array = []      # {node, dir, t}
var _cam: Camera3D


func _ready() -> void:
	_rng.randomize()
	Loc.register({
		"he": {"traffic_carjack": "הנהג ברח - הרכב שלך"},
		"en": {"traffic_carjack": "The driver ran off - the car is yours"},
	})
	Settings.register_defaults({"traffic_density": 1.0})
	add_to_group("panic_listeners")     # gunfire nearby makes drivers flee
	if main:
		player = main.player
		world = main.world
		peds = main.peds
	if world == null:
		push_warning("traffic: no world")
		set_physics_process(false)
		return
	_pitch = float(world.get("PITCH"))
	_n = (int(world.get("RINGS")) + 1) * 2
	_update_count()
	Settings.changed.connect(func(k: String):
		if k in ["traffic_density", "battery_saver", "npc_density"]:
			_update_count())

	_horn_short = _make_horn(0.28, 1.0)
	_horn_long = _make_horn(0.95, 1.0)
	for i in 4:
		var h := AudioStreamPlayer3D.new()
		h.unit_size = 9.0
		h.max_distance = 140.0
		h.attenuation_filter_cutoff_hz = 7000.0
		add_child(h)
		_horns.append(h)

	signals = preload("res://traffic/signals.gd").new()
	add_child(signals)
	if not signals.build(world):
		signals.queue_free()
		signals = null
	_apply_phase()
	# Fill the streets right away (also in view) so the city is alive from the start.
	call_deferred("_initial_fill")


func _update_count() -> void:
	var dens := clampf(float(Settings.get_value("traffic_density")), 0.0, 2.0)
	# The quality preset's crowd slider (core/quality.gd) scales traffic too.
	var npc = Settings.get_value("npc_density")
	if npc != null:
		dens *= clampf(float(npc), 0.3, 1.5)
	var base := 9.0 if Settings.get_value("battery_saver") else 13.0
	_target_count = clampi(roundi(base * dens), 0, 24)


func _initial_fill() -> void:
	for i in _target_count:
		var c = _new_car()
		if not _try_spawn(c, 22.0, SPAWN_MAX, false, 40):
			c.visible = false
			c.mode = AiCar.CRASHED     # parked out of the way until the next recycle pass
			c.global_position = Vector3(0, -50, 0)
			c.set_meta("traffic_idle", true)


# ------------------------------------------------------------ public API

## Current light for a driving direction (0 +X, 1 +Z, 2 -X, 3 -Z).
func light_for(d: int) -> int:
	return z_state if d % 2 == 1 else x_state


## Other modules (police, missions) can ask whether a car belongs to traffic.
func is_traffic_car(n: Node) -> bool:
	return n != null and n.is_in_group("traffic_car") and bool(n.get("pooled"))


## Called by ai_car.enter() before the player takes the car.
func on_carjack(c: Node) -> void:
	var car := c as VehicleBody3D
	if bool(c.get("has_driver")):
		_spawn_runner(car)
		if main and main.hud and main.hud.has_method("toast"):
			main.hud.toast(Loc.t("traffic_carjack"))
	if peds and peds.has_method("_panic_near"):
		peds._panic_near(car.global_position, 14.0)
	cars.erase(c)
	abandoned.append(c)


## Something hit the car (or it was destroyed): it stops being AI-driven.
func crash(c: Node, hitter: Node3D) -> void:
	var car = c
	if car.mode != AiCar.DRIVE:
		return
	var own: Vector3 = car.heading * float(car.ai_speed)
	car.go_physical(own)
	car.mode = AiCar.CRASHED
	car.crash_t = 0.0
	car.ai_speed = 0.0
	car.honks_left = 3 if car.health > 0.0 else 0
	car.honk_cd = 0.7
	if hitter and hitter is RigidBody3D:
		var rel: Vector3 = (hitter as RigidBody3D).linear_velocity - own
		car.take_damage(rel.length() * 2.2)
	car.add_to_group("vehicle")


func on_car_shot(c: Node) -> void:
	var car = c
	if car.mode == AiCar.DRIVE and car.has_driver:
		car.panic_t = 10.0
		if float(car.honk_cd) <= 0.0:
			_honk(car, true)
			car.honk_cd = 2.0
	elif car.mode == AiCar.CRASHED and car.has_driver and _rng.randf() < 0.5:
		car.has_driver = false
		_spawn_runner(car)


## Gunfire nearby: drivers floor it (pedestrians.gd uses the same group).
func on_gunshot(pos: Vector3) -> void:
	for c in cars:
		if c.mode == AiCar.DRIVE and (c as Node3D).global_position.distance_to(pos) < 40.0:
			c.panic_t = maxf(float(c.panic_t), 7.0)


# ------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_frame += 1
	_cam = get_viewport().get_camera_3d()
	_tick_lights(delta)
	_collect_obstacles()
	for i in cars.size():
		var c = cars[i]
		if c.mode == AiCar.DRIVE:
			if (_frame + i) % 2 == 0:
				_scan(c)
			_drive(c, delta)
		elif c.mode == AiCar.CRASHED and not c.has_meta("traffic_idle"):
			_crashed_tick(c, delta)
	_check_impacts()
	_tick_runners(delta)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.25
		_slow_tick()


func _tick_lights(delta: float) -> void:
	phase_t += delta
	var cur: Array = CYCLE[phase]
	if phase_t >= float(cur[2]):
		phase_t = 0.0
		phase = (phase + 1) % CYCLE.size()
		_apply_phase()


func _apply_phase() -> void:
	var cur: Array = CYCLE[phase]
	z_state = int(cur[0])
	x_state = int(cur[1])
	if signals:
		signals.show_phase(z_state, x_state)


## Every thing a car must not drive into, gathered once per tick.
func _collect_obstacles() -> void:
	_obstacles.clear()
	var pp := player.global_position
	var pveh: Node3D = player.vehicle if bool(player.in_vehicle) else null
	for c in cars:
		var n := c as Node3D
		if n.has_meta("traffic_idle"):
			continue
		if c.mode == AiCar.DRIVE:
			_obstacles.append([n.global_position, c.heading, float(c.ai_speed), CAR_HALF_L, CAR_HALF_W, K_AI, c])
		else:
			var lv: Vector3 = (n as RigidBody3D).linear_velocity
			_obstacles.append([n.global_position, n.global_basis.z, lv.length(), CAR_HALF_L, CAR_HALF_W, K_CAR, c])
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v is AiCar and v.pooled:
			continue
		var n := v as Node3D
		if n == null or n.global_position.distance_squared_to(pp) > 200.0 * 200.0:
			continue
		var spd := 0.0
		if n is RigidBody3D:
			spd = (n as RigidBody3D).linear_velocity.length()
		_obstacles.append([n.global_position, n.global_basis.z, spd, CAR_HALF_L, CAR_HALF_W,
			K_PLAYER_CAR if n == pveh else K_CAR, n])
	if pveh == null:
		_obstacles.append([pp, Vector3.BACK, 0.0, 0.4, 0.4, K_PLAYER, player])
	if peds:
		var list: Variant = peds.get("_peds")
		if list is Array:
			for p in list:
				var pd: Dictionary = p
				var node: Node3D = pd.get("node")
				if node == null or not is_instance_valid(node):
					continue
				var pos := node.global_position
				if pos.distance_squared_to(pp) < 170.0 * 170.0:
					_obstacles.append([pos, Vector3.BACK, 0.0, 0.45, 0.45, K_PED, null])
	for r in _runners:
		_obstacles.append([(r["node"] as Node3D).global_position, Vector3.BACK, 0.0, 0.45, 0.45, K_PED, null])


## Free road ahead of a car: distance from its nose to the nearest thing in its corridor.
func _scan(c) -> void:
	var me := c as Node3D
	var pos := me.global_position
	var f: Vector3 = c.heading
	var r := f.cross(Vector3.UP)
	var best := 999.0
	var best_speed := 0.0
	var best_kind := -1
	var best_ref: Object = null
	var look := LOOKAHEAD
	for o in _obstacles:
		if o[6] == c:
			continue
		var rel: Vector3 = (o[0] as Vector3) - pos
		var fw := rel.x * f.x + rel.z * f.z
		if fw <= 0.0 or fw > look:
			continue
		var of: Vector3 = o[1]
		var kind: int = o[5]
		var dot_f := absf(of.x * f.x + of.z * f.z)
		var dot_r := absf(of.x * r.x + of.z * r.z)
		var hl: float = o[3]
		var hw: float = o[4]
		var o_lat := dot_r * hl + dot_f * hw
		var o_long := dot_f * hl + dot_r * hw
		var lat := rel.x * r.x + rel.z * r.z
		var margin := 0.35 if kind == K_AI or kind == K_CAR else 0.6
		if absf(lat) > CAR_HALF_W + o_lat + margin:
			continue
		# Inside an intersection only same-way traffic blocks us (the junction must clear).
		if c.turning and kind == K_AI and (of.x * f.x + of.z * f.z) < 0.5:
			continue
		var g := fw - CAR_HALF_L - o_long
		if g < best:
			best = g
			best_speed = float(o[2]) * (of.x * f.x + of.z * f.z)
			best_kind = kind
			best_ref = o[6]
	c.gap = best
	c.gap_speed = best_speed
	c.gap_kind = best_kind
	c.gap_ref = best_ref


func _drive(c, delta: float) -> void:
	var v: float = c.ai_speed
	var panic: bool = float(c.panic_t) > 0.0
	c.panic_t = maxf(float(c.panic_t) - delta, 0.0)
	c.honk_cd = float(c.honk_cd) - delta
	var target: float = float(c.cruise) * (1.55 if panic else 1.0)
	var remaining: float = float(c.plen) - float(c.dist)

	if not c.turning:
		var vt := _turn_speed(c.dir, c.next_dir)
		target = minf(target, sqrt(vt * vt + 2.0 * 2.6 * maxf(remaining, 0.0)))
		var to_stop: float = float(c.plen) - STOP_BACK - float(c.dist)
		if (to_stop > -0.6 or (v < 1.0 and to_stop > -2.5)) and not panic:
			var st := light_for(c.dir)
			var must_stop := st == RED
			if st == AMBER:
				must_stop = to_stop > v * v / (2.0 * 4.5) + 0.5
			if must_stop:
				target = minf(target, _stop_speed(to_stop))
		# Left turn: wait at the junction edge for oncoming traffic.
		if c.next_dir == (int(c.dir) + 3) % 4 and remaining < 30.0 and _oncoming(c):
			target = minf(target, _stop_speed(remaining - 1.2))
	else:
		target = minf(target, _turn_speed(c.dir, c.next_dir) * (1.3 if panic else 1.0))

	# Keep a gap to whatever is ahead.
	var gap: float = c.gap
	if gap < 900.0:
		var min_gap := 2.2 if c.gap_kind == K_AI or c.gap_kind == K_CAR else 3.2
		var ahead_v := maxf(float(c.gap_speed), 0.0)
		var follow := sqrt(maxf(2.0 * 5.0 * (gap - min_gap), 0.0)) + ahead_v * 0.7
		if gap < min_gap + v * 0.8:
			follow = minf(follow, ahead_v * clampf((gap - min_gap) / maxf(v * 0.8, 0.5), 0.0, 1.0))
		target = minf(target, follow)
	# Someone standing right next to the car (about to carjack it): the driver waits.
	if not bool(player.in_vehicle) and v < 3.0:
		if (c as Node3D).global_position.distance_to(player.global_position) < 3.4:
			target = 0.0

	# Blocked: honk at the player, overtake a stuck car.
	var blocked: bool = v < 0.6 and gap < 12.0 and target < 0.5
	if blocked:
		c.blocked_t = float(c.blocked_t) + delta
	else:
		c.blocked_t = 0.0
	if blocked and c.gap_kind in [K_PLAYER, K_PLAYER_CAR] and float(c.blocked_t) > 1.1 and float(c.honk_cd) <= 0.0:
		_honk(c, float(c.blocked_t) > 5.0)
		c.honk_cd = _rng.randf_range(2.5, 5.0)
	elif blocked and c.gap_kind == K_CAR and float(c.blocked_t) > 2.5:
		if not _try_overtake(c) and float(c.blocked_t) > 6.0 and float(c.honk_cd) <= 0.0:
			_honk(c, false)
			c.honk_cd = _rng.randf_range(4.0, 8.0)

	# Speed: gentle acceleration, firm braking when needed.
	var accel := 0.0
	if target > v:
		accel = (3.4 if panic else 2.6) * (1.0 - v / 40.0)
		v = minf(v + accel * delta, target)
	else:
		var dec := clampf(3.0 + (v - target) * 2.5, 3.0, 9.5)
		accel = -dec
		v = maxf(v - dec * delta, target)
		if v < 0.05:
			v = 0.0
	c.ai_speed = v

	# Run over the player on foot if they jump in front at the last moment.
	if c.gap_kind == K_PLAYER and gap < 0.25 and v > 4.0:
		player.take_damage(v * 3.0)
		if "velocity" in player:
			player.velocity = (c.heading as Vector3) * v * 0.8 + Vector3.UP * 4.0
		_honk(c, false)
		c.ai_speed = v * 0.4

	# Advance along the path.
	c.dist = float(c.dist) + v * delta
	var guard := 0
	while float(c.dist) >= float(c.plen) and guard < 3:
		guard += 1
		c.dist = float(c.dist) - float(c.plen)
		_next_piece(c)
	# Overtaking: slide back in once past the obstacle.
	if float(c.pass_until) >= 0.0 and (c.turning or float(c.dist) > float(c.pass_until)):
		c.pass_until = -1.0
		c.lane_target = 0.0
	if c.turning:
		c.lane_target = 0.0
	var prev_off: float = c.lane_off
	c.lane_off = move_toward(prev_off, float(c.lane_target), delta * 2.2)
	var t := clampf(float(c.dist) / float(c.plen), 0.0, 1.0)
	var pos := _bez(c.p0, c.p1, c.p2, t)
	var tg := _bez_d(c.p0, c.p1, c.p2, t)
	tg.y = 0.0
	tg = tg.normalized() if tg.length() > 0.001 else (c.heading as Vector3)
	var right := tg.cross(Vector3.UP)
	pos += right * float(c.lane_off)
	if v > 0.3:
		tg = (tg + right * ((float(c.lane_off) - prev_off) / maxf(delta, 0.001)) / v).normalized()
	c.ai_pose(pos, tg, accel, delta)

	# Offer the car to the context button only while it is (nearly) stopped.
	var slow := v < 2.5
	if slow != c.is_in_group("vehicle"):
		if slow:
			c.add_to_group("vehicle")
		else:
			c.remove_from_group("vehicle")


func _crashed_tick(c, delta: float) -> void:
	c.crash_t = float(c.crash_t) + delta
	c.honk_cd = float(c.honk_cd) - delta
	if c.has_driver and int(c.honks_left) > 0 and float(c.honk_cd) <= 0.0:
		c.honks_left = int(c.honks_left) - 1
		_honk(c, int(c.honks_left) == 0)
		c.honk_cd = _rng.randf_range(0.6, 1.4)
	# A shaken driver leaves a badly damaged car.
	if c.has_driver and float(c.crash_t) > 3.5 and float(c.health) < 55.0:
		c.has_driver = false
		_spawn_runner(c)


func _try_overtake(c) -> bool:
	if c.turning or float(c.pass_until) >= 0.0 or float(c.lane_target) != 0.0:
		return false
	var ref: Node3D = c.gap_ref as Node3D
	if ref == null or not is_instance_valid(ref):
		return false
	var me := c as Node3D
	var f: Vector3 = c.heading
	var ahead := (ref.global_position - me.global_position).dot(f)
	var end_dist: float = float(c.dist) + ahead + 9.0
	if end_dist > float(c.plen) - 4.0:
		return false
	# Oncoming lane must be clear well ahead, and nothing else parked in it.
	var r := f.cross(Vector3.UP)
	for o in _obstacles:
		if o[6] == c or o[6] == ref:
			continue
		var rel: Vector3 = (o[0] as Vector3) - me.global_position
		var fw := rel.dot(f)
		var lat := rel.dot(r)
		if fw > -6.0 and fw < ahead + 70.0 and lat < -1.8 and lat > -6.5:
			return false
	c.lane_target = -LANE * 2.0
	c.pass_until = end_dist
	return true


## True when an oncoming car would cross a left turn at the next junction.
func _oncoming(c) -> bool:
	var b: Vector2i = c.cell + STEPS[c.dir]
	var opp := (int(c.dir) + 2) % 4
	for o in cars:
		if o == c or o.mode != AiCar.DRIVE or int(o.dir) != opp:
			continue
		if o.next_dir == (opp + 3) % 4:
			continue      # opposite left turns do not cross
		if o.turning:
			if o.cell == b:
				return true
		elif o.cell + STEPS[o.dir] == b:
			var rem: float = float(o.plen) - float(o.dist)
			if rem < 42.0 and (float(o.ai_speed) > 1.0 or rem < 5.0):
				# A car waiting at its red light is no threat.
				if float(o.ai_speed) > 1.0 or light_for(opp) != RED:
					return true
	return false


func _turn_speed(d: int, nd: int) -> float:
	if nd == d:
		return 30.0
	if nd == (d + 1) % 4:
		return 4.8     # right turn: tight
	return 6.4         # left turn: wide


func _stop_speed(d: float) -> float:
	if d <= 0.25:
		return 0.0
	return sqrt(2.0 * 4.2 * (d - 0.25))


func _check_impacts() -> void:
	# Movers: the player's / parked cars and wrecks that roll.
	for v in get_tree().get_nodes_in_group("vehicle"):
		if not (v is RigidBody3D) or (v is AiCar and v.pooled and v.mode == AiCar.DRIVE):
			continue
		var rb := v as RigidBody3D
		var vel := rb.linear_velocity
		for c in cars:
			if c.mode != AiCar.DRIVE or c == rb:
				continue
			var cn := c as Node3D
			var cvel: Vector3 = (c.heading as Vector3) * float(c.ai_speed)
			var rel := vel - cvel
			if rel.length() < 1.5:
				continue
			var d2 := cn.global_position.distance_squared_to(rb.global_position)
			if d2 > 49.0:
				continue
			if _cars_touch(rb.global_transform, cn.global_transform, rel.length() * 0.05 + 0.3):
				crash(c, rb)


## Two-circle test for car footprints (front / rear), inflated by margin.
func _cars_touch(a: Transform3D, b: Transform3D, margin: float) -> bool:
	var lim := 2.0 + margin
	for sa in [-1.25, 1.25]:
		var pa := a.origin + a.basis.z * float(sa)
		for sb in [-1.25, 1.25]:
			var pb := b.origin + b.basis.z * float(sb)
			var d := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < lim:
				return true
	return false


# ------------------------------------------------------------ recycling

func _slow_tick() -> void:
	var pp := player.global_position
	# Recycle cars that are far or out of sight.
	for c in cars:
		var n := c as Node3D
		if n.has_meta("traffic_idle"):
			if _try_spawn(c, SPAWN_MIN, SPAWN_MAX, true, 6):
				n.remove_meta("traffic_idle")
				n.visible = true
			continue
		var d := n.global_position.distance_to(pp)
		var seen := _in_view(n.global_position, d)
		var far := d > DESPAWN_SEEN or (d > DESPAWN_UNSEEN and not seen)
		if c.mode == AiCar.CRASHED:
			far = d > 160.0 or (d > 70.0 and not seen) or (float(c.crash_t) > 60.0 and not seen and d > 30.0)
		elif float(c.blocked_t) > 15.0 and not seen and d > 40.0:
			far = true      # hopelessly stuck behind something: quietly replace it
		if far:
			c.reset_for_pool()
			if not _try_spawn(c, SPAWN_MIN, SPAWN_MAX, true, 6):
				n.visible = false
				c.mode = AiCar.CRASHED
				c.freeze = true
				n.global_position = Vector3(0, -50, 0)
				n.set_meta("traffic_idle", true)
		elif c.mode == AiCar.DRIVE:
			_update_engine(c, d)
	# Refill the pool after carjackings, shrink it if the density setting dropped.
	_refill_t -= 0.25
	if cars.size() < _target_count and _refill_t <= 0.0:
		_refill_t = 1.0
		var c = _new_car()
		if not _try_spawn(c, SPAWN_MIN, SPAWN_MAX, true, 10):
			c.visible = false
			c.mode = AiCar.CRASHED
			c.global_position = Vector3(0, -50, 0)
			c.set_meta("traffic_idle", true)
	elif cars.size() > _target_count:
		for c in cars:
			var n := c as Node3D
			if n.has_meta("traffic_idle") or not _in_view(n.global_position, n.global_position.distance_to(pp)):
				cars.erase(c)
				n.queue_free()
				break
	# Cars the player left behind disappear once far away and unseen.
	for i in range(abandoned.size() - 1, -1, -1):
		var a = abandoned[i]
		if not is_instance_valid(a):
			abandoned.remove_at(i)
			continue
		var an := a as Node3D
		if a == player.vehicle:
			continue
		var d := an.global_position.distance_to(pp)
		if (d > 160.0 and not _in_view(an.global_position, d)) or (abandoned.size() > 6 and d > 60.0 and not _in_view(an.global_position, d)):
			abandoned.remove_at(i)
			an.queue_free()


func _update_engine(c, d: float) -> void:
	var eng: AudioStreamPlayer3D = c.get("_engine")
	if eng == null:
		return
	if d < 38.0:
		if not eng.playing:
			eng.play(_rng.randf() * 0.5)
		var v: float = c.ai_speed
		eng.pitch_scale = 0.62 + fmod(v / 9.0, 1.0) * 0.45 + v * 0.004
		eng.volume_db = -16.0 + minf(v, 14.0) * 0.5
	elif eng.playing:
		eng.stop()


func _in_view(pos: Vector3, d: float) -> bool:
	if _cam == null:
		return d < 60.0
	return _cam.is_position_in_frustum(pos + Vector3(0, 1.0, 0))


func _new_car():
	var c = AiCar.new()
	# Mixed city traffic (vehicles/vehicle_types.gd); no motorbikes in the AI pool.
	c.vtype = TRAFFIC_TYPES[_rng.randi() % TRAFFIC_TYPES.size()]
	c.traffic = self
	c.paint = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
	c.cruise = _rng.randf_range(10.0, 13.5)
	c.horn_pitch = _rng.randf_range(0.85, 1.2)
	c.peds = peds
	add_child(c)
	cars.append(c)
	return c


## Puts a pool car on a random lane near the player. Returns false if no place was found.
func _try_spawn(c, dmin: float, dmax: float, hide: bool, tries: int) -> bool:
	var pp := player.global_position
	var off := float(_n) * 0.5
	var ki := clampi(floori(pp.x / _pitch + off - 0.5), 0, _n - 1)
	var kj := clampi(floori(pp.z / _pitch + off - 0.5), 0, _n - 1)
	for attempt in tries:
		var a := Vector2i(clampi(ki + _rng.randi_range(-1, 2), 0, _n - 1), clampi(kj + _rng.randi_range(-1, 2), 0, _n - 1))
		var d := _rng.randi_range(0, 3)
		if not _valid(a + STEPS[d]):
			continue
		var p0 := _cell_pos(a) + (DIRS[d] as Vector3) * BOX + (DIRS[d] as Vector3).cross(Vector3.UP) * LANE
		var dist := _rng.randf_range(4.0, _pitch - BOX * 2.0 - 16.0)
		var pos := p0 + (DIRS[d] as Vector3) * dist
		var dp := pos.distance_to(pp)
		if dp < dmin or dp > dmax:
			continue
		if hide and dp < 115.0 and _in_view(pos, dp):
			continue
		if not _clear(pos, c):
			continue
		_begin_straight(c, a, d)
		c.dist = dist
		c.ai_speed = _rng.randf_range(4.0, 8.0)
		c.heading = DIRS[d]
		c.last_yaw = atan2((DIRS[d] as Vector3).x, (DIRS[d] as Vector3).z)
		c.mode = AiCar.DRIVE
		c.set_paint(CAR_COLORS[_rng.randi() % CAR_COLORS.size()])
		c.ai_pose(pos, DIRS[d], 0.0, 1.0 / 60.0)
		c.reset_physics_interpolation()
		return true
	return false


func _clear(pos: Vector3, me: Node) -> bool:
	for o in cars:
		if o == me or (o as Node3D).has_meta("traffic_idle"):
			continue
		if (o as Node3D).global_position.distance_squared_to(pos) < 15.0 * 15.0:
			return false
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v != me and (v as Node3D).global_position.distance_squared_to(pos) < 8.0 * 8.0:
			return false
	return true


# ------------------------------------------------------------ road graph

func _cell_pos(a: Vector2i) -> Vector3:
	var off := float(_n) * 0.5 - 0.5
	return Vector3((a.x - off) * _pitch, 0.0, (a.y - off) * _pitch)


func _valid(a: Vector2i) -> bool:
	return a.x >= 0 and a.y >= 0 and a.x < _n and a.y < _n


## Straight lane piece from intersection a in direction d; also picks the next turn.
func _begin_straight(c, a: Vector2i, d: int) -> void:
	var dv: Vector3 = DIRS[d]
	var r := dv.cross(Vector3.UP)
	var ca := _cell_pos(a)
	c.cell = a
	c.dir = d
	c.turning = false
	c.p0 = ca + dv * BOX + r * LANE
	c.p2 = ca + dv * (_pitch - BOX) + r * LANE
	c.p1 = (c.p0 + c.p2) * 0.5
	c.plen = (c.p2 - c.p0).length()
	c.dist = 0.0
	# Next move at the junction ahead.
	var b: Vector2i = a + STEPS[d]
	var options: Array[int] = []
	var weights: Array[float] = []
	for nd in [d, (d + 1) % 4, (d + 3) % 4]:
		if _valid(b + STEPS[nd]):
			options.append(nd)
			weights.append(0.55 if nd == d else (0.25 if nd == (d + 1) % 4 else 0.2))
	var total := 0.0
	for w in weights:
		total += w
	var pick := _rng.randf() * total
	c.next_dir = options[0]
	for i in options.size():
		pick -= weights[i]
		if pick <= 0.0:
			c.next_dir = options[i]
			break


func _begin_turn(c, b: Vector2i, d: int, nd: int) -> void:
	var dv: Vector3 = DIRS[d]
	var nv: Vector3 = DIRS[nd]
	var r := dv.cross(Vector3.UP)
	var nr := nv.cross(Vector3.UP)
	var cb := _cell_pos(b)
	c.cell = b
	c.turning = true
	c.p0 = cb - dv * BOX + r * LANE
	c.p2 = cb + nv * BOX + nr * LANE
	c.p1 = (c.p0 + c.p2) * 0.5 if nd == d else cb + r * LANE + nr * LANE
	c.plen = ((c.p2 - c.p0).length() + (c.p1 - c.p0).length() + (c.p2 - c.p1).length()) * 0.5
	c.dist = 0.0


func _next_piece(c) -> void:
	var left: float = c.dist
	if c.turning:
		var nd: int = c.next_dir
		_begin_straight(c, c.cell, nd)
	else:
		_begin_turn(c, c.cell + STEPS[c.dir], c.dir, c.next_dir)
	c.dist = left


static func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u) + b * (2.0 * u * t) + c * (t * t)


static func _bez_d(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return (b - a) * (2.0 * (1.0 - t)) + (c - b) * (2.0 * t)


# ------------------------------------------------------------ horn

func _honk(c: Node3D, long: bool) -> void:
	var h := _horns[_horn_i]
	_horn_i = (_horn_i + 1) % _horns.size()
	h.stream = _horn_long if long else _horn_short
	h.global_position = c.global_position + Vector3(0, 0.8, 0)
	h.pitch_scale = float(c.get("horn_pitch")) if c.get("horn_pitch") != null else 1.0
	h.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")), 0.0001)) - 3.0
	h.play()


## Two-tone car horn synthesised in code (no audio files): a pair of detuned buzzy
## tones (~410 / 515 Hz) with a soft attack, a bit of saturation and a quick release.
static func _make_horn(length: float, pitch: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(length * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f1 := 410.0 * pitch
	var f2 := 515.0 * pitch
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.015, 1.0) * minf((length - t) / 0.05, 1.0)
		var s := 0.0
		for h in [1.0, 2.0, 3.0, 4.0, 5.0]:
			var amp := 1.0 / pow(h, 1.15)
			s += sin(TAU * f1 * h * t) * amp + sin(TAU * f2 * h * t + 0.7) * amp * 0.85
		s *= 1.0 + 0.06 * sin(TAU * 31.0 * t)       # diaphragm flutter
		s = tanh(s * 0.9) * 0.55 * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ------------------------------------------------------------ fleeing drivers

func _spawn_runner(car: Node3D) -> void:
	if _runners.size() >= 3:
		var old: Dictionary = _runners.pop_front()
		(old["node"] as Node).queue_free()
	var m: Node3D = preload("res://player/human_model.gd").new()
	m.model_path = "res://assets/characters/%s.glb" % PED_MODELS[_rng.randi() % PED_MODELS.size()]
	m.armed = false
	m.weapon_kind = 0
	add_child(m)
	var start := car.global_position + car.global_basis.x * 1.4
	start.y = _ground_y(start)
	m.global_position = start
	m.reset_physics_interpolation()
	# Run to the nearest sidewalk, then along it away from the player.
	var q := _road_offset(start)
	var on_z_road := absf(q.x) < absf(q.y)       # nearer a road running along Z
	var side := 1.0
	var along := Vector3.ZERO
	var lateral := Vector3.ZERO
	var away := start - player.global_position
	if on_z_road:
		side = signf(q.x) if absf(q.x) > 0.5 else (signf(away.x) if away.x != 0.0 else 1.0)
		lateral = Vector3(side, 0, 0)
		along = Vector3(0, 0, signf(away.z) if absf(away.z) > 0.1 else 1.0)
	else:
		side = signf(q.y) if absf(q.y) > 0.5 else (signf(away.z) if away.z != 0.0 else 1.0)
		lateral = Vector3(0, 0, side)
		along = Vector3(signf(away.x) if absf(away.x) > 0.1 else 1.0, 0, 0)
	var lat_now := absf(q.x) if on_z_road else absf(q.y)
	var first := start + lateral * maxf(10.0 - lat_now, 0.0) + along * 6.0
	_runners.append({"node": m, "wp": [first, first + along * 40.0], "i": 0, "t": 0.0})


func _tick_runners(delta: float) -> void:
	for i in range(_runners.size() - 1, -1, -1):
		var r: Dictionary = _runners[i]
		var m: Node3D = r["node"]
		r["t"] = float(r["t"]) + delta
		var wps: Array = r["wp"]
		var wi: int = r["i"]
		if float(r["t"]) > 9.0 or wi >= wps.size():
			m.queue_free()
			_runners.remove_at(i)
			continue
		var target: Vector3 = wps[wi]
		var to := target - m.global_position
		to.y = 0.0
		if to.length() < 0.8:
			r["i"] = wi + 1
			continue
		var step := to.normalized() * 5.6 * delta
		var p := m.global_position + step
		p.y = _ground_y(p)
		m.global_position = p
		m.rotation.y = lerp_angle(m.rotation.y, atan2(-step.x, -step.z), 1.0 - exp(-12.0 * delta))
		m.animate(delta, 5.6, true, false, false)


func _road_offset(p: Vector3) -> Vector2:
	var qx := p.x - (floorf(p.x / _pitch) + 0.5) * _pitch
	var qz := p.z - (floorf(p.z / _pitch) + 0.5) * _pitch
	return Vector2(qx, qz)


func _ground_y(p: Vector3) -> float:
	var q := _road_offset(p)
	if absf(q.x) < BOX or absf(q.y) < BOX:
		return 0.0
	return float(world.get("CURB_H"))

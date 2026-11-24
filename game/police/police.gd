extends Node3D
## Wanted level and police (feature module, created from world/main.gd).
##
## Crimes add "heat"; heat thresholds give a 0-5 star wanted level:
##   shooting near people, hurting / killing pedestrians, running people over,
##   robbing a cash register, stealing or shooting cars, attacking the police.
## Pedestrians report what they see, so any witnessed crime is at least one star.
## Officers on foot spawn out of sight near the player and chase on foot; from two
## stars police cars drive in along the roads with lights and sirens and drop off
## their crew. Losing them: stay out of sight of every unit until the search timer
## runs out (stars blink meanwhile). Being taken to hospital clears the level.
##
## Other modules can report crimes: get_tree().call_group("crime_listeners",
## "report_crime", "<kind>", position)  (kinds: see CRIMES).

const NAV := preload("res://police/road_nav.gd")
const OFFICER := preload("res://police/officer.gd")
const CAR := preload("res://police/police_car.gd")

## kind: [heat, needs a witness, cooldown seconds]
const CRIMES := {
	"gunfire": [1.0, true, 3.0],
	"hurt_ped": [2.5, false, 0.6],
	"kill_ped": [4.0, false, 0.0],
	"run_over": [4.0, false, 0.0],
	"rob": [5.0, false, 0.0],
	"steal_car": [2.0, true, 0.0],
	"damage_car": [1.0, true, 4.0],
	"hurt_officer": [5.0, false, 1.0],
	"kill_officer": [9.0, false, 0.0],
	"steal_police_car": [7.0, false, 0.0],
	"damage_police_car": [2.5, false, 2.0],
}
const HEAT_FOR_STAR := [0.0, 1.0, 7.0, 16.0, 30.0, 48.0]
const FOOT_CAP := [0, 2, 3, 4, 6, 6]
const CAR_CAP := [0, 0, 1, 2, 3, 3]
const MAX_BODIES := 4
const WITNESS_RANGE := 35.0
const SEE_RANGE_FOOT := 110.0
const SEE_RANGE_CAR := 130.0

var main: Node
var player: Node3D
var peds: Node
var stars := 0
var heat := 0.0
var last_known := Vector3.ZERO
var searching := false
var search_left := 0.0
var star_flash := 0.0          # > 0 right after the level went up (HUD pulse)

var _officers: Array = []
var _cars: Array = []
var _rng := RandomNumberGenerator.new()
var _unseen_t := 0.0
var _reported_t := 0.0
var _spawn_t := 0.0
var _poll_t := 0.0
var _car_poll_t := 0.0
var _recycle_t := 0.0
var _cooldowns := {}
var _ped_hp := {}
var _car_hp := {}
var _last_fire_ms := -100000
var _despawn_all_t := -1.0
var _panic_cd := 0.0
var _hud_layer: CanvasLayer


func _ready() -> void:
	_rng.randomize()
	Loc.register({
		"he": {
			"police_coming": "המשטרה בדרך!",
			"police_lost": "איבדת את המשטרה",
			"police_searching": "מחפשים אותך",
			"police_stolen": "גנבת ניידת משטרה!",
		},
		"en": {
			"police_coming": "The police are coming!",
			"police_lost": "You lost the police",
			"police_searching": "Searching for you",
			"police_stolen": "You stole a police car!",
		},
	})
	Settings.register_defaults({"police_enabled": true})
	player = main.player
	peds = main.peds
	add_to_group("panic_listeners")
	add_to_group("crime_listeners")
	add_to_group("new_game_listeners")
	if player.weapon and player.weapon.has_signal("fired"):
		player.weapon.fired.connect(_on_player_fired)
	if peds and peds.has_signal("ped_killed"):
		peds.ped_killed.connect(_on_ped_killed)
	player.vehicle_changed.connect(_on_vehicle_changed)
	player.died.connect(_on_player_died)
	last_known = player.global_position

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	var hud: Control = preload("res://police/wanted_hud.gd").new()
	hud.police = self
	_hud_layer.add_child(hud)


func enabled() -> bool:
	return bool(Settings.get_value("police_enabled"))


# ------------------------------------------------------------ crimes

## Public: other modules report crimes here (see CRIMES for the kinds).
func report_crime(kind: String, pos: Vector3) -> void:
	if not enabled() or not CRIMES.has(kind) or _despawn_all_t > 0.0:
		return
	var c: Array = CRIMES[kind]
	var now := Time.get_ticks_msec() * 0.001
	if float(_cooldowns.get(kind, -1000.0)) > now:
		return
	if bool(c[1]) and stars == 0 and not _witnessed(pos):
		return
	_cooldowns[kind] = now + float(c[2])
	heat += float(c[0])
	var target := 0
	for i in HEAT_FOR_STAR.size():
		if heat >= float(HEAT_FOR_STAR[i]):
			target = i
	target = maxi(target, 1)
	_reported_t = 4.0              # witnesses tell the police where you are
	last_known = player.global_position
	if target > stars:
		var was := stars
		stars = target
		star_flash = 1.0
		search_left = _search_time()
		if was == 0:
			_toast(Loc.t("police_coming"))
			_spawn_t = _rng.randf_range(1.5, 3.0)
			for u in _units():
				if u.has_method("resume_chase"):
					u.resume_chase()


func on_crime(kind: String, pos: Vector3) -> void:
	report_crime(kind, pos)


## panic_listeners: called on player gunfire and when a register is robbed.
func on_gunshot(pos: Vector3) -> void:
	_check_gunshot.call_deferred(pos)


func _check_gunshot(pos: Vector3) -> void:
	if Time.get_ticks_msec() - _last_fire_ms < 250:
		return       # the player's own gunfire, handled in _on_player_fired
	if player.get("in_vehicle"):
		return
	if pos.distance_to(player.global_position + Vector3(0, 1.45, 0)) < 0.05:
		return       # player's muzzle (a weapon that does not emit `fired`)
	# Robbery is reported directly by world/shop.gd (Register.collect -> report_crime "rob"),
	# so explosions and enemy gunfire next to the player are not mistaken for one.


func _on_player_fired() -> void:
	var w: Node = player.weapon
	var kind := 1
	if "WEAPONS" in w and "current" in w:
		var wd: Dictionary = w.WEAPONS[w.current]
		kind = int(wd.get("kind", 1))
	if kind == 0:
		return       # a punch: only counts if it hurts someone
	_last_fire_ms = Time.get_ticks_msec()
	report_crime("gunfire", player.global_position)
	if stars > 0:
		_reported_t = maxf(_reported_t, 1.5)    # gunfire gives your position away


func _on_ped_killed(p: Dictionary) -> void:
	var n: Node3D = p.get("node")
	if n == null or not _player_caused(n.global_position, 60.0):
		return
	report_crime("run_over" if player.get("in_vehicle") else "kill_ped", n.global_position)


func _on_vehicle_changed(v: Node3D) -> void:
	if v == null:
		return
	if v.is_in_group("police_car"):
		_cars.erase(v)
		report_crime("steal_police_car", v.global_position)
		_toast(Loc.t("police_stolen"))
	elif not v.has_meta("player_owned"):
		report_crime("steal_car", v.global_position)
	v.set_meta("player_owned", true)


func on_officer_hurt(o: Node3D, killed: bool) -> void:
	report_crime("kill_officer" if killed else "hurt_officer", o.global_position)
	last_known = player.global_position
	for u in _units():
		if u.has_method("resume_chase"):
			u.resume_chase()


func _on_player_died() -> void:
	_clear(false)
	_despawn_all_t = 3.2       # under the red "badly hurt" screen


func _witnessed(pos: Vector3) -> bool:
	if peds and "_peds" in peds:
		for p in peds._peds:
			if p.get("state", "") == "dead":
				continue
			var n: Node3D = p.get("node")
			if n and n.global_position.distance_to(pos) < WITNESS_RANGE:
				return true
	for u in _units():
		if u.global_position.distance_to(pos) < 60.0:
			return true
	return false


## Close to the player, or the player has just fired (a long-range shot).
func _player_caused(pos: Vector3, near: float) -> bool:
	if pos.distance_to(player.global_position) < near:
		return true
	return Time.get_ticks_msec() - _last_fire_ms < 700 and pos.distance_to(player.global_position) < 420.0


## Watches pedestrians' health (hurt but alive) and other cars' damage.
func _poll_victims() -> void:
	if peds and "_peds" in peds:
		for p in peds._peds:
			var n: Node3D = p.get("node")
			if n == null:
				continue
			var id := n.get_instance_id()
			var hp: float = float(p.get("hp", 100.0))
			var prev: float = float(_ped_hp.get(id, hp))
			_ped_hp[id] = hp
			if hp < prev - 0.1 and p.get("state", "") != "dead" and _player_caused(n.global_position, 50.0):
				report_crime("hurt_ped", n.global_position)


func _poll_cars() -> void:
	var recently_shot := Time.get_ticks_msec() - _last_fire_ms < 1500
	var mine: Node3D = player.get("vehicle")
	for v in get_tree().get_nodes_in_group("vehicle"):
		if not ("health" in v):
			continue
		var id: int = v.get_instance_id()
		var h: float = float(v.health)
		var prev: float = float(_car_hp.get(id, h))
		_car_hp[id] = h
		if h >= prev - 0.5 or v == mine:
			continue
		var by_me := recently_shot and (v as Node3D).global_position.distance_to(player.global_position) < 120.0
		if mine and (v as Node3D).global_position.distance_to(mine.global_position) < 7.0:
			by_me = true
		if by_me:
			report_crime("damage_police_car" if v.is_in_group("police_car") else "damage_car", (v as Node3D).global_position)


# ------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if player == null:
		return
	star_flash = maxf(star_flash - delta, 0.0)
	_panic_cd -= delta
	if _despawn_all_t > 0.0:
		_despawn_all_t -= delta
		if _despawn_all_t <= 0.0:
			_free_all()
		return
	if not enabled() and stars > 0:
		_clear(false)

	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 0.15
		_poll_victims()
	_car_poll_t -= delta
	if _car_poll_t <= 0.0:
		_car_poll_t = 0.5
		_poll_cars()

	_update_sight(delta)

	if stars > 0:
		_reported_t -= delta
		var seen := false
		for u in _units():
			if u.sees_player:
				seen = true
				break
		if seen or _reported_t > 0.0:
			last_known = player.global_position
			_unseen_t = 0.0
			search_left = _search_time()
			searching = false
		else:
			_unseen_t += delta
			search_left -= delta
			searching = _unseen_t > 1.0
			if search_left <= 0.0:
				_clear(true)
		_spawn_t -= delta
		if _spawn_t <= 0.0 and stars > 0:
			_spawn_t = 1.2
			_spawn_units()

	_recycle_t -= delta
	if _recycle_t <= 0.0:
		_recycle_t = 0.5
		_recycle()


func _search_time() -> float:
	return 16.0 + stars * 3.0       # 19 s at one star .. 31 s at five


func _units() -> Array:
	var out: Array = []
	for o in _officers:
		if is_instance_valid(o) and not o.is_dead():
			out.append(o)
	for c in _cars:
		if is_instance_valid(c) and c.ai and c.health > 0.0:
			out.append(c)
	return out


## Line of sight from each unit to the player, a few rays per frame.
func _update_sight(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var in_car: bool = player.get("in_vehicle")
	var veh: Node3D = player.get("vehicle")
	var target: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	if in_car and veh:
		target = veh.global_position + Vector3(0, 1.0, 0)
	for u in _units():
		u.los_timer -= delta
		if u.los_timer > 0.0:
			continue
		u.los_timer = 0.2 + _rng.randf() * 0.1
		if stars == 0 or u.state == "leave":
			u.sees_player = false
			continue
		var is_car: bool = u.is_in_group("police_car")
		var eye: Vector3 = u.global_position + Vector3(0, 1.5 if is_car else 1.6, 0)
		var d := eye.distance_to(target)
		if d > (SEE_RANGE_CAR if is_car else SEE_RANGE_FOOT):
			u.sees_player = false
			continue
		var ex: Array[RID] = [(u as CollisionObject3D).get_rid()]
		if veh:
			ex.append((veh as CollisionObject3D).get_rid())
		var q := PhysicsRayQueryParameters3D.create(eye, target, 1, ex)
		u.sees_player = space.intersect_ray(q).is_empty()


## An officer fires at the player: hit or miss from distance, movement and level.
func resolve_shot(o: Node3D, muzzle: Vector3, dist: float, kind: int) -> void:
	var in_car: bool = player.get("in_vehicle")
	var veh: Node3D = player.get("vehicle")
	var chest: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	var vel := Vector3.ZERO
	if in_car and veh:
		chest = veh.global_position + Vector3(0, 0.9, 0)
		vel = (veh as RigidBody3D).linear_velocity
	elif player is CharacterBody3D:
		vel = (player as CharacterBody3D).velocity
	vel.y = 0.0
	var acc := 0.42 + stars * 0.05
	acc *= clampf(1.15 - dist / 45.0, 0.12, 1.0)
	acc *= clampf(1.0 - vel.length() / 13.0, 0.35, 1.0)
	if player.get("crouching"):
		acc *= 0.75
	if kind == 2:
		acc *= 0.8
	var dir := (chest - muzzle).normalized()
	if _rng.randf() < acc:
		var dmg := (8.0 if kind == 1 else 6.5) + stars * 1.0
		if in_car and veh:
			Fx.sparks(chest + Vector3(_rng.randf_range(-0.6, 0.6), 0.1, _rng.randf_range(-1.0, 1.0)), -dir)
			Sfx.play_3d("bullet_impact", chest, -3.0)
			if veh.has_method("take_damage"):
				veh.take_damage(dmg * 0.7)
		else:
			Fx.blood(chest, dir)
			Sfx.play_3d("hit_flesh", chest, -4.0)
			player.take_damage(dmg)
		return
	# Miss: the bullet hits something just around the player.
	var aim := chest + Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(-1.2, 0.8), _rng.randf_range(-1.4, 1.4))
	var mdir := (aim - muzzle).normalized()
	var ex: Array[RID] = [(o as CollisionObject3D).get_rid()]
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + mdir * (dist + 12.0), 1, ex)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if not res.is_empty():
		var hp: Vector3 = res["position"]
		Fx.sparks(hp, res["normal"])
		if hp.distance_to(chest) < 12.0:
			Sfx.play_3d("bullet_impact", hp, -7.0)


func on_police_gunshot(pos: Vector3) -> void:
	if _panic_cd > 0.0 or peds == null:
		return
	_panic_cd = 0.8
	if peds.has_method("on_gunshot"):
		peds.on_gunshot(pos)


# ------------------------------------------------------------ spawning

func _alive_officers() -> int:
	var n := 0
	for o in _officers:
		if is_instance_valid(o) and not o.is_dead() and o.state != "leave":
			n += 1
	return n


func _active_cars() -> int:
	var n := 0
	for c in _cars:
		if is_instance_valid(c) and c.ai and c.health > 0.0 and c.state != "leave":
			n += 1
	return n


func _spawn_units() -> void:
	if player.global_position.y < -20.0:
		return
	if _alive_officers() < int(FOOT_CAP[stars]):
		var p: Variant = _find_foot_spawn()
		if p != null:
			_spawn_officer(p)
	if _active_cars() < int(CAR_CAP[stars]):
		_spawn_car()


func _spawn_officer(at: Vector3) -> Node3D:
	var o: CharacterBody3D = OFFICER.new()
	o.police = self
	o.model_name = OFFICER.MODELS[_rng.randi() % OFFICER.MODELS.size()]
	var rifle_chance := 0.0 if stars < 3 else (0.45 if stars == 3 else 0.7)
	o.weapon_kind = 2 if _rng.randf() < rifle_chance else 1
	o.hp = 100.0 + stars * 10.0
	add_child(o)
	o.global_position = at
	o.reset_physics_interpolation()
	_officers.append(o)
	_trim_bodies()
	return o


func _find_foot_spawn() -> Variant:
	# While searching, reinforcements arrive around the last known position, so
	# hiding somewhere else actually works.
	var pp := player.global_position if _unseen_t < 0.3 else last_known
	var real := player.global_position
	if pp.distance_to(real) > 110.0:
		return null      # searching far away: officers there would be recycled at once
	var space := get_world_3d().direct_space_state
	for attempt in 14:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(38.0, 62.0)
		var p := pp + Vector3(cos(ang), 0, sin(ang)) * d
		# Onto a road (always open ground).
		var ix := NAV.nearest_line(p.x)
		var jz := NAV.nearest_line(p.z)
		if absf(p.x - NAV.line(ix)) < absf(p.z - NAV.line(jz)):
			p.x = NAV.line(ix) + _rng.randf_range(-6.0, 6.0)
		else:
			p.z = NAV.line(jz) + _rng.randf_range(-6.0, 6.0)
		var fd := Vector2(p.x - pp.x, p.z - pp.z).length()
		if fd < 30.0 or fd > 80.0 or absf(p.x) > 275.0 or absf(p.z) > 275.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p + Vector3(0, -5, 0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or float(hit["position"].y) > 1.0:
			continue
		p.y = float(hit["position"].y) + 0.1
		if _visible(p + Vector3(0, 1.0, 0)):
			continue
		if _unseen_t >= 0.3:
			# Do not pop up right in view of a hiding player.
			if p.distance_to(real) < 30.0:
				continue
			var lq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), real + Vector3(0, 1.3, 0), 1)
			if space.intersect_ray(lq).is_empty():
				continue
		return p
	return null


func _spawn_car() -> void:
	var pp := player.global_position if _unseen_t < 0.3 else last_known
	var cands: Array = []
	var ls := NAV.lines()
	for i in ls.size():
		for j in ls.size():
			var n := NAV.node_pos(i, j)
			var d := Vector2(n.x - pp.x, n.z - pp.z).length()
			if d < 90.0 or d > 230.0:
				continue
			if _visible(n + Vector3(0, 1.0, 0)):
				continue
			cands.append(n)
	if cands.is_empty():
		return
	var node: Vector3 = cands[_rng.randi() % cands.size()]
	var next: Vector3 = NAV.next_point(node, pp)[0]
	var dir := next - node
	dir.y = 0.0
	if dir.length() < 0.5:
		dir = Vector3(pp.x - node.x, 0, pp.z - node.z)
	dir = dir.normalized()
	var pos := node + dir.cross(Vector3.UP) * CAR.LANE + dir * 4.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		if (v as Node3D).global_position.distance_to(pos) < 7.0:
			return
	pos.y = 0.45
	var car: VehicleBody3D = CAR.new()
	car.police = self
	car.peds = peds
	car.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)
	add_child(car)
	car.reset_physics_interpolation()
	car.linear_velocity = dir * 10.0
	_cars.append(car)


## A police car stopped near the player: its two officers get out.
func deploy_crew(car: Node3D) -> void:
	var n: int = car.crew
	car.crew = 0
	for k in n:
		if _alive_officers() >= int(FOOT_CAP[maxi(stars, 1)]):
			return
		var side: Vector3 = car.global_basis.x * (1.7 if k == 0 else -1.7)
		var at: Vector3 = car.global_position + side + car.global_basis.z * (0.3 - k * 0.6)
		at.y = car.global_position.y - 0.3
		var o := _spawn_officer(at)
		o.velocity = side.normalized() * 2.0
		Sfx.play_3d("car_door", at, -2.0)


func _trim_bodies() -> void:
	var dead: Array = []
	for o in _officers:
		if is_instance_valid(o) and o.is_dead():
			dead.append(o)
	while dead.size() > MAX_BODIES:
		var o: Node3D = dead.pop_front()
		_free_officer(o)


# ------------------------------------------------------------ recycling

func _visible(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var cp := cam.global_position
	var d := cp.distance_to(p)
	if d > 170.0 or not cam.is_position_in_frustum(p):
		return false
	var q := PhysicsRayQueryParameters3D.create(cp, p, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return cp.distance_to(hit["position"]) > d - 2.5


func _recycle() -> void:
	var pp := player.global_position
	for o in _officers.duplicate():
		if not is_instance_valid(o):
			_officers.erase(o)
			continue
		var seen := _visible(o.global_position + Vector3(0, 1.0, 0))
		o.out_of_view_t = 0.0 if seen else o.out_of_view_t + 0.5
		var d: float = o.global_position.distance_to(pp)
		var gone := false
		if o.is_dead():
			gone = (o.dead_time() > 25.0 and (o.out_of_view_t > 1.0 or d > 80.0)) or d > 150.0
		elif o.state == "leave":
			gone = o.out_of_view_t > 1.5 or d > 90.0
		else:
			gone = (d > 140.0 and o.out_of_view_t > 2.0) or (o.stuck_t > 5.0 and o.out_of_view_t > 1.0)
			gone = gone or o.global_position.y < -20.0
		if gone:
			_free_officer(o)
	for c in _cars.duplicate():
		if not is_instance_valid(c):
			_cars.erase(c)
			continue
		if c.driver != null:
			_cars.erase(c)        # the player took it: it is a normal car now
			continue
		var seen := _visible(c.global_position + Vector3(0, 1.0, 0))
		c.out_of_view_t = 0.0 if seen else c.out_of_view_t + 0.5
		var d: float = c.global_position.distance_to(pp)
		var gone := false
		if c.health <= 0.0 or not c.ai:
			gone = c.out_of_view_t > 10.0 and d > 60.0
		elif c.state == "leave":
			gone = c.out_of_view_t > 2.0 or d > 160.0
		else:
			gone = (d > 260.0 and c.out_of_view_t > 2.0) or (c.flipped_t > 4.0 and c.out_of_view_t > 1.0)
			gone = gone or c.global_position.y < -20.0
		if gone:
			_cars.erase(c)
			c.queue_free()


func _free_officer(o: Node3D) -> void:
	_officers.erase(o)
	Fx.clear_pool_near(o.global_position)
	o.queue_free()


func _free_all() -> void:
	for o in _officers.duplicate():
		if is_instance_valid(o):
			_free_officer(o)
	_officers.clear()
	for c in _cars:
		if is_instance_valid(c) and c.driver == null:
			c.queue_free()
	_cars.clear()


## Wanted level back to zero; every unit stands down and drives / walks away.
func _clear(lost: bool) -> void:
	var had := stars > 0
	stars = 0
	heat = 0.0
	searching = false
	_unseen_t = 0.0
	_reported_t = 0.0
	for u in _units():
		u.start_leaving()
	if lost and had:
		_toast(Loc.t("police_lost"))
		Sfx.play_ui("mission_done")


func on_new_game() -> void:
	_clear(false)


func _toast(text: String) -> void:
	if main and main.hud and main.hud.has_method("toast"):
		main.hud.toast(text)


## For tests and debugging.
func debug_counts() -> Dictionary:
	return {"stars": stars, "heat": heat, "officers": _alive_officers(), "bodies": _officers.size() - _alive_officers(),
		"cars": _active_cars(), "searching": searching, "search_left": search_left}

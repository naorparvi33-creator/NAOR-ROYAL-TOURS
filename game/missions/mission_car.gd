extends "res://vehicles/car.gd"
## A car driven by a mission AI (VIP to escort, a car that flees from the player).
## Uses the same physics as the player's car; the AI only sets throttle, brake and
## steering. Follows lane points on the road grid; in "flee" mode it keeps choosing
## the next intersection that leads away from the player. Gets itself unstuck by
## reversing, and as a last resort is put back on the road when nobody is looking.

const Geo := preload("res://missions/geo.gd")

signal route_done

var ai_mode := "idle"          # "idle", "route", "flee"
var route: Array = []          # lane points (Vector3)
var target_speed := 14.0
var hold := false              # stop where we are (e.g. during an ambush)
var cautious := false          # brakes for cars and people ahead (VIP)
var crash_mult := 1.0          # how much crashes hurt (the VIP car is armoured)
var _blocked_t := 0.0
var bullet_mult := 0.55
var chaser: Node3D             # who we flee from
var _ri := 0
var _stuck := 0.0
var _reverse := 0.0
var _flip := 0.0
var _last_node := Vector2i.ZERO
var _prev_node := Vector2i(99, 99)
var _ray_t := 0.0
var _blocked := false
var _rng2 := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng2.randomize()


## Starts following lane points through the given intersections.
func drive_nodes(nodes: Array, speed: float) -> void:
	route = Geo.lane_points(nodes)
	_ri = 0
	target_speed = speed
	ai_mode = "route"
	if nodes.size() > 0:
		_last_node = nodes[nodes.size() - 1]
	if nodes.size() > 1:
		_prev_node = nodes[nodes.size() - 2]
	_engine.play()


func flee_from(who: Node3D, start_node: Vector2i, speed: float) -> void:
	chaser = who
	ai_mode = "flee"
	target_speed = speed
	route.clear()
	_ri = 0
	_last_node = start_node
	_prev_node = Vector2i(99, 99)
	_extend_flee()
	_engine.play()


func _extend_flee() -> void:
	# Append a few road pieces, each time picking the turn that leads away from the chaser.
	for k in 2:
		var options: Array = Geo.neighbours(_last_node)
		if options.size() > 1:
			options.erase(_prev_node)
		var best: Vector2i = options[0]
		var best_score := -INF
		for o in options:
			var score := _rng2.randf() * 60.0
			if chaser:
				score += Geo.flat_dist(Geo.node_pos(o), chaser.global_position)
			if score > best_score:
				best_score = score
				best = o
		var pts: Array
		if Geo.node_valid(_prev_node):
			pts = Geo.lane_points([_prev_node, _last_node, best]).slice(2)
		else:
			pts = Geo.lane_points([_last_node, best])
		route.append_array(pts)
		_prev_node = _last_node
		_last_node = best


func current_target() -> Vector3:
	if _ri < route.size():
		return route[_ri]
	return global_position


func on_hit(point: Vector3, dmg: float, _dir: Vector3, _bullet: bool) -> void:
	Fx.sparks(point, Vector3.UP)
	Sfx.play_3d("bullet_impact", point, -4.0)
	take_damage(dmg * bullet_mult)


func _on_body_entered(_b: Node) -> void:
	var drop := _prev_speed - linear_velocity.length()
	if drop > 5.0 and _crash_cooldown <= 0.0:
		_crash_cooldown = 0.6
		Sfx.play_3d("car_crash", global_position, clampf(drop - 8.0, -8.0, 6.0))
		take_damage(drop * 2.5 * crash_mult)


func _physics_process(delta: float) -> void:
	if driver != null:
		super._physics_process(delta)    # the player took the wheel
		return
	_crash_cooldown -= delta
	var spd := linear_velocity.length()
	var fwd_speed := linear_velocity.dot(global_basis.z)
	if health <= 0.0 or ai_mode == "idle" or hold or _ri >= route.size():
		engine_force = 0.0
		brake = MAX_BRAKE * 0.6
		steering = move_toward(steering, 0.0, delta * 2.0)
		_prev_speed = spd
		if ai_mode == "route" and _ri >= route.size():
			ai_mode = "idle"
			route_done.emit()
		_engine.volume_db = -14.0
		return

	var tgt: Vector3 = route[_ri]
	var local := global_transform.affine_inverse() * tgt
	if Vector2(local.x, local.z).length() < 5.5 or (local.z < 0.0 and Vector2(local.x, local.z).length() < 12.0):
		_ri += 1
		if ai_mode == "flee" and route.size() - _ri < 3:
			_extend_flee()
		if _ri >= route.size():
			return
		tgt = route[_ri]
		local = global_transform.affine_inverse() * tgt
	var ang := atan2(local.x, local.z)
	var want := clampf(ang * 1.6, -MAX_STEER, MAX_STEER)

	# Slow down for corners: look at the turn after the current point.
	var want_speed := target_speed
	if _ri + 1 < route.size():
		var a: Vector3 = route[_ri] - global_position
		var b: Vector3 = route[_ri + 1] - route[_ri]
		a.y = 0.0
		b.y = 0.0
		if a.length() > 0.1 and b.length() > 0.1:
			var turn := a.normalized().angle_to(b.normalized())
			if turn > 0.6 and a.length() < 30.0:
				want_speed = minf(want_speed, 9.0)
	if absf(ang) > 0.7:
		want_speed = minf(want_speed, 7.0)

	if cautious:
		_ray_t -= delta
		if _ray_t <= 0.0:
			_ray_t = 0.2
			var from := global_position + global_basis.z * 2.5 + Vector3(0, 0.8, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from + global_basis.z * 11.0, 2 | 4 | 8, [get_rid()])
			_blocked = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		if _blocked:
			_blocked_t += delta
			# Wait, but creep forward now and then in case something is parked in the lane.
			want_speed = 0.0 if fposmod(_blocked_t, 8.0) < 4.0 else minf(want_speed, 3.0)
		else:
			_blocked_t = 0.0

	# Reverse out when stuck against something.
	if _reverse > 0.0:
		_reverse -= delta
		steering = -want
		engine_force = -MAX_ENGINE * 0.5
		brake = 0.0
	else:
		steering = move_toward(steering, want, delta * 3.0)
		var err := want_speed - fwd_speed
		if err > 0.0:
			engine_force = clampf(err * 700.0, 0.0, MAX_ENGINE)
			brake = 0.0
		else:
			engine_force = 0.0
			brake = clampf(-err * 6.0, 0.0, MAX_BRAKE) if err < -1.0 else 0.0
		if want_speed > 1.0 and fwd_speed < 0.8:
			_stuck += delta
			if _stuck > 2.2:
				_stuck = 0.0
				_reverse = 1.3
		else:
			_stuck = maxf(_stuck - delta, 0.0)

	# Upside down or wedged for long: put the car back on the road when unseen.
	if global_basis.y.y < 0.4:
		_flip += delta
		if _flip > 2.5 and _far_from_player(25.0):
			_reset_on_road()
	else:
		_flip = 0.0

	var gear_pos := fmod(absf(fwd_speed) / 11.0, 1.0)
	_engine.pitch_scale = 0.75 + gear_pos * 0.7
	_engine.volume_db = -8.0 + clampf(engine_force / MAX_ENGINE, 0.0, 1.0) * 4.0

	if peds and spd > 3.5:
		var front := global_position + global_basis.z * 1.6
		var hits: int = peds.vehicle_impact(front, linear_velocity, 1.5)
		if hits > 0:
			linear_velocity *= 0.9
	_prev_speed = spd


func _far_from_player(d: float) -> bool:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	return pl == null or pl.global_position.distance_to(global_position) > d


func _reset_on_road() -> void:
	_flip = 0.0
	var p: Vector3 = route[mini(_ri, route.size() - 1)] if route.size() > 0 else global_position
	var nxt: Vector3 = route[mini(_ri + 1, route.size() - 1)] if route.size() > 0 else p + Vector3(0, 0, 1)
	var d := nxt - p
	d.y = 0.0
	if d.length() < 0.1:
		d = Vector3(0, 0, 1)
	global_transform = Transform3D(Basis.looking_at(-d.normalized(), Vector3.UP), p + Vector3(0, 0.6, 0))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()

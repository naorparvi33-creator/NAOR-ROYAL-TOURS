extends CanvasLayer
## Screen-edge damage indicator and haptics.
##  * When the player is hurt, a red wedge glows at the screen edge in the direction the
##    damage came from (last gunshot by someone else, or the nearest hostile); damage
##    without a direction (crash, fall) flashes all four edges.
##  * Android vibration (Input.vibrate_handheld): stronger for bigger hits, a short tick
##    when the player's shot or punch lands. Setting "vibration".

const SHOT_MEMORY := 1.2
const LIFE := 1.3

var main: Node
var _overlay: Control
var _marks: Array = []          # {pos: Vector3 or null, t: float, power: float}
var _shots: Array = []          # [pos, time]
var _last_hp := 100.0
var _flash := 0.0


func _ready() -> void:
	name = "DamageFeedback"
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	add_to_group("panic_listeners")
	await get_tree().process_frame
	var pl: Node = main.player if main else null
	if pl == null:
		return
	_last_hp = float(pl.health)
	pl.health_changed.connect(_on_health)
	if pl.weapon:
		pl.weapon.hit.connect(func(is_target: bool):
			if is_target:
				vibrate(18, 0.35))


## Every gunshot in the world reaches the "panic_listeners" group.
func on_gunshot(pos: Vector3) -> void:
	var pl: Node3D = main.player if main else null
	if pl and pos.distance_to(pl.global_position) < 3.0:
		return                      # our own shot
	_shots.append([pos, Time.get_ticks_msec() / 1000.0])
	if _shots.size() > 8:
		_shots.pop_front()


func _on_health(hp: float) -> void:
	var dmg := _last_hp - hp
	_last_hp = hp
	if dmg <= 0.5:
		return
	var src: Variant = _guess_source()
	var power := clampf(dmg / 25.0, 0.35, 1.0)
	_marks.append({"pos": src, "t": LIFE, "power": power})
	if _marks.size() > 5:
		_marks.pop_front()
	if src == null:
		_flash = 1.0
	vibrate(int(clampf(35.0 + dmg * 3.0, 40.0, 160.0)), clampf(0.4 + dmg / 50.0, 0.4, 1.0))


func _guess_source() -> Variant:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_shots.size() - 1, -1, -1):
		if now - float(_shots[i][1]) < SHOT_MEMORY:
			return _shots[i][0]
	var pl: Node3D = main.player
	var best: Variant = null
	var best_d := 70.0
	for g in ["enemy", "hostile", "police"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D:
				var d := (n as Node3D).global_position.distance_to(pl.global_position)
				if d < best_d:
					best_d = d
					best = (n as Node3D).global_position
	return best


func vibrate(ms: int, amplitude: float) -> void:
	if not bool(Settings.get_value("vibration")):
		return
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(ms, amplitude)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	for m in _marks:
		m["t"] = float(m["t"]) - delta
	_marks = _marks.filter(func(m): return float(m["t"]) > 0.0)
	_flash = maxf(_flash - delta * 2.2, 0.0)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var s := _overlay.size
	if _flash > 0.0:
		var c := Color(0.85, 0.05, 0.02, 0.45 * _flash)
		var e := 46.0
		_edge_gradient(Rect2(0, 0, s.x, e), c, Vector2.DOWN)
		_edge_gradient(Rect2(0, s.y - e, s.x, e), c, Vector2.UP)
		_edge_gradient(Rect2(0, 0, e, s.y), c, Vector2.RIGHT)
		_edge_gradient(Rect2(s.x - e, 0, e, s.y), c, Vector2.LEFT)
	var cam := _overlay.get_viewport().get_camera_3d()
	if cam == null:
		return
	var centre := s * 0.5
	for m in _marks:
		var a := clampf(float(m["t"]) / LIFE, 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		if m["pos"] == null:
			continue
		# Direction in camera space: x right, -z forward -> screen angle (0 = up).
		var local: Vector3 = cam.global_transform.affine_inverse() * (m["pos"] as Vector3)
		var ang := atan2(local.x, -local.z)
		var dir := Vector2(sin(ang), -cos(ang))
		var rx := s.x * 0.5 - 28.0
		var ry := s.y * 0.5 - 28.0
		var power: float = m["power"]
		var spread := 0.22 + 0.12 * power
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var steps := 10
		for i in steps + 1:
			var t := ang - spread + spread * 2.0 * float(i) / steps
			var d := Vector2(sin(t), -cos(t))
			pts.append(centre + Vector2(d.x * rx, d.y * ry))
			cols.append(Color(1.0, 0.08, 0.04, 0.85 * a * power))
		for i in range(steps, -1, -1):
			var t := ang - spread + spread * 2.0 * float(i) / steps
			var d := Vector2(sin(t), -cos(t))
			pts.append(centre + Vector2(d.x * (rx - 70.0), d.y * (ry - 70.0)))
			cols.append(Color(1.0, 0.08, 0.04, 0.0))
		_overlay.draw_polygon(pts, cols)
		# A small arrow head pointing outward at the middle of the wedge.
		var tip := centre + Vector2(dir.x * (rx + 10.0), dir.y * (ry + 10.0))
		var base := centre + Vector2(dir.x * (rx - 22.0), dir.y * (ry - 22.0))
		var side := Vector2(-dir.y, dir.x) * 14.0
		_overlay.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1, 0.2, 0.1, 0.9 * a))


func _edge_gradient(r: Rect2, c: Color, inward: Vector2) -> void:
	var p := r.position
	var q := r.position + r.size
	var pts := PackedVector2Array([p, Vector2(q.x, p.y), q, Vector2(p.x, q.y)])
	var clear := Color(c.r, c.g, c.b, 0.0)
	var cols := PackedColorArray()
	# Opaque on the screen edge, clear toward the centre.
	for v in pts:
		var on_edge := false
		if inward == Vector2.DOWN:
			on_edge = v.y == p.y
		elif inward == Vector2.UP:
			on_edge = v.y == q.y
		elif inward == Vector2.RIGHT:
			on_edge = v.x == p.x
		else:
			on_edge = v.x == q.x
		cols.append(c if on_edge else clear)
	_overlay.draw_polygon(pts, cols)

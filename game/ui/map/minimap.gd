extends Control
## Minimap in the top-left corner, under the FPS / health / money lines.
## Rotates with the camera (camera direction = up), zooms out with speed while driving,
## shows the GPS route, markers (important ones stick to the edge), the player arrow and
## a north marker. The turn-by-turn GPS hint is drawn under it. Tap it to open the full map.

const Icons := preload("res://ui/map/map_icons.gd")
const POS := Vector2(18, 112)
const SIZE := 250.0
const ZOOM_FOOT := 1.35       # pixels per metre
const ZOOM_FAST := 0.72

var module: Node

var _clip: Control
var _art: Node2D
var _overlay: Control
var _font: Font
var _zoom := ZOOM_FOOT
var _xf := Transform2D.IDENTITY


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = POS
	size = Vector2(SIZE + 120.0, SIZE + 90.0)
	_font = get_theme_default_font()
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.size = Vector2(SIZE, SIZE)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_art = module.make_art()
	_clip.add_child(_art)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE, SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_clip.add_child(_overlay)


func hit(p: Vector2) -> bool:
	return visible and _clip.get_global_rect().has_point(p)


func _process(delta: float) -> void:
	if not visible or module.main.player == null:
		return
	var pl: Node3D = module.main.player
	var want := ZOOM_FOOT
	if pl.in_vehicle and pl.vehicle != null and pl.vehicle.has_method("speed_kmh"):
		var kmh: float = pl.vehicle.speed_kmh()
		want = lerpf(ZOOM_FOOT * 0.9, ZOOM_FAST, clampf(kmh / 110.0, 0.0, 1.0))
	_zoom = lerpf(_zoom, want, 1.0 - exp(-2.5 * delta))
	var up: Vector2 = module.camera_dir() if bool(Settings.get_value("minimap_rotate")) else Vector2(0, -1)
	# Rotate so that `up` points to the top of the minimap.
	var rot := -PI * 0.5 - up.angle()
	var center := Vector2(SIZE, SIZE) * 0.5
	var pp: Vector2 = module.player_pos()
	_xf = Transform2D(rot, Vector2(_zoom, _zoom), 0.0, Vector2.ZERO)
	_xf.origin = center - _xf.basis_xform(pp)
	_art.transform = _xf
	_overlay.queue_redraw()
	queue_redraw()


func _draw_overlay() -> void:
	var o := _overlay
	var s := Vector2(SIZE, SIZE)
	var center := s * 0.5
	var t: float = module.time
	# Police search area.
	if module.search_area != null:
		var sa: Vector3 = module.search_area
		var c := _xf * Vector2(sa.x, sa.y)
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		o.draw_circle(c, sa.z * _zoom, Color(1.0, 0.15, 0.1, 0.16 + 0.08 * pulse))
		o.draw_arc(c, sa.z * _zoom, 0.0, TAU, 40, Color(1.0, 0.25, 0.2, 0.6), 2.0, true)
	# GPS route.
	var route: PackedVector2Array = module.route
	if route.size() >= 2:
		var pts := PackedVector2Array()
		for q in route:
			pts.append(_xf * q)
		var col: Color = Icons.COL_ROUTE if module.route_kind == "custom" else Icons.COL_OBJECTIVE
		o.draw_polyline(pts, Color(0, 0, 0, 0.6), 8.0, true)
		o.draw_polyline(pts, col, 5.0, true)
	# Markers: unimportant ones only inside, important ones clamp to the edge.
	var inner := Rect2(Vector2(10, 10), s - Vector2(20, 20))
	for m in module.markers:
		var sp: Vector2 = _xf * (m["pos"] as Vector2)
		var kind: String = m["kind"]
		var sz := 8.0 if kind in ["car", "police", "shop", "hospital"] else 10.0
		if kind == "car":
			sz = 6.0
		if inner.has_point(sp):
			Icons.draw(o, _font, kind, sp, sz, t, str(m.get("extra", "")))
		elif bool(m.get("edge", false)):
			var d := sp - center
			var k := (SIZE * 0.5 - 14.0) / maxf(absf(d.x), absf(d.y))
			var ep := center + d * k
			Icons.draw(o, _font, kind, ep, sz * 0.8, t, str(m.get("extra", "")))
	# Player arrow (heading on the map, rotated with it).
	var hd := _xf.basis_xform(module.player_dir())
	Icons.draw_arrow(o, center, hd.angle(), 11.0)
	# North marker on the edge.
	var nd := _xf.basis_xform(Vector2(0, -1)).normalized()
	var nk := (SIZE * 0.5 - 16.0) / maxf(absf(nd.x), absf(nd.y))
	var np := center + nd * nk
	o.draw_circle(np, 13.0, Color(0, 0, 0, 0.75))
	o.draw_arc(np, 13.0, 0.0, TAU, 20, Color(1, 0.35, 0.3), 2.0, true)
	o.draw_string(_font, np + Vector2(-13, 7), Loc.t("map_north"), HORIZONTAL_ALIGNMENT_CENTER, 26, 18, Color.WHITE)
	# Street name strip.
	var street: String = module.current_street()
	if street != "":
		o.draw_rect(Rect2(0, s.y - 30, s.x, 30), Color(0, 0, 0, 0.5))
		o.draw_string(_font, Vector2(0, s.y - 8), street, HORIZONTAL_ALIGNMENT_CENTER, s.x, 19, Color(1, 1, 1, 0.92))
	# Frame.
	o.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.8), false, 5.0)
	o.draw_rect(Rect2(Vector2(2.5, 2.5), s - Vector2(5, 5)), Color(1, 1, 1, 0.35), false, 1.5)


## GPS hint box under the minimap: instruction, street, distance to the destination.
func _draw() -> void:
	var parts: Array = module.turn_parts()
	var main_txt: String = parts[0]
	if main_txt == "":
		return
	var street: String = parts[1]
	var w := SIZE + 110.0
	var r := Rect2(0, SIZE + 8.0, w, 96.0)
	draw_rect(r, Color(0.05, 0.06, 0.08, 0.72))
	var col: Color = Icons.COL_ROUTE if module.route_kind == "custom" else Icons.COL_OBJECTIVE
	var rtl := Loc.is_rtl()
	draw_rect(Rect2(r.position, Vector2(6, r.size.y)) if not rtl else Rect2(r.end.x - 6, r.position.y, 6, r.size.y), col)
	var icon_c := Vector2(r.end.x - 36.0, r.position.y + 44.0) if rtl else Vector2(r.position.x + 36.0, r.position.y + 44.0)
	_turn_icon(icon_c, int(module.turn.get("turn", 0)), col)
	var tx := r.position.x + (12.0 if rtl else 70.0)
	var tw := w - 82.0
	var align := HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(_font, Vector2(tx, r.position.y + 30.0), main_txt, align, tw, 22, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(tx, r.position.y + 30.0), main_txt, align, tw, 22, Color.WHITE)
	if street != "":
		draw_string(_font, Vector2(tx, r.position.y + 58.0), street, align, tw, 20, col.lightened(0.3))
	var total := Loc.t("map_dist") % module.format_dist(float(module.turn.get("total", 0.0)))
	draw_string(_font, Vector2(tx, r.position.y + 85.0), total, align, tw, 17, Color(1, 1, 1, 0.65))


func _turn_icon(c: Vector2, kind: int, col: Color) -> void:
	var w := 5.0
	match kind:
		1, -1:
			var sx := float(kind)
			draw_line(c + Vector2(-sx * 8, 16), c + Vector2(-sx * 8, -4), col, w)
			draw_arc(c + Vector2(0, -4), 8.0, PI if kind == 1 else 0.0, PI * 1.5 if kind == 1 else -PI * 0.5, 8, col, w)
			draw_line(c + Vector2(0, -12), c + Vector2(sx * 10, -12), col, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(sx * 20, -12), c + Vector2(sx * 9, -21), c + Vector2(sx * 9, -3)]), col)
		2:
			draw_line(c + Vector2(8, 16), c + Vector2(8, -6), col, w)
			draw_arc(c + Vector2(0, -6), 8.0, 0.0, -PI, 10, col, w)
			draw_line(c + Vector2(-8, -6), c + Vector2(-8, 6), col, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 16), c + Vector2(-16, 4), c + Vector2(0, 4)]), col)
		_:
			# Chequered flag.
			draw_line(c + Vector2(-10, 18), c + Vector2(-10, -18), col, 4.0)
			for i in 3:
				for j in 2:
					var cc := Color.WHITE if (i + j) % 2 == 0 else Color(0.1, 0.1, 0.1)
					draw_rect(Rect2(c + Vector2(-8 + i * 7, -18 + j * 7), Vector2(7, 7)), cc)

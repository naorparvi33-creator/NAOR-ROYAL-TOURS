extends Control
## Full-screen city map (the game is paused while it is open).
##  * One finger drags the map, two fingers pinch to zoom (mouse wheel / +- buttons too).
##  * Tap places a GPS waypoint (tap a shop / mission to snap to it, tap your pin to remove it).
##  * Legend on the left, buttons in the bottom-right thumb zone, nothing in the top centre.

const Icons := preload("res://ui/map/map_icons.gd")
const TAP_MOVE := 22.0
const TAP_TIME := 2500

var module: Node

var center := Vector2.ZERO        # world point at the middle of the screen
var zoom := 1.5                   # pixels per metre
var _art: Node2D
var _overlay: Control
var _legend: Control
var _side: VBoxContainer
var _gps_check: CheckButton
var _clear_btn: Button
var _font: Font
var _touches := {}                # finger -> position
var _tap_start := Vector2.ZERO
var _tap_ms := 0
var _tap_ok := false
var _xf := Transform2D.IDENTITY
var _flash := ""
var _flash_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	var bg := ColorRect.new()
	bg.color = preload("res://ui/map/map_art.gd").COL_OUTSIDE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = module.make_art()
	add_child(_art)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_build_ui()
	Loc.language_changed.connect(_build_ui)


func _build_ui() -> void:
	if _legend != null:
		_legend.queue_free()
	if _side != null:
		_side.queue_free()
	# Legend (left).
	_legend = Control.new()
	_legend.position = Vector2(20, 24)
	_legend.size = Vector2(300, 90 + Icons.LEGEND.size() * 38)
	_legend.mouse_filter = Control.MOUSE_FILTER_STOP     # touches on the legend do not pan the map
	_legend.draw.connect(_draw_legend)
	add_child(_legend)
	# Buttons (bottom right, right thumb).
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.alignment = BoxContainer.ALIGNMENT_END
	_side.anchor_left = 1.0
	_side.anchor_right = 1.0
	_side.anchor_top = 1.0
	_side.anchor_bottom = 1.0
	_side.offset_left = -330
	_side.offset_right = -24
	_side.offset_top = -520
	_side.offset_bottom = -24
	_side.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_side)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 12)
	_side.add_child(zoom_row)
	for z in [["-", 1.0 / 1.5], ["+", 1.5]]:
		var zb := _button(str(z[0]), func(): _zoom_at(size * 0.5, float(z[1])))
		zb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zb.custom_minimum_size = Vector2(144, 72)
		zb.add_theme_font_size_override("font_size", 40)
		zoom_row.add_child(zb)
	_gps_check = CheckButton.new()
	_gps_check.text = Loc.t("map_gps3d")
	_gps_check.add_theme_font_size_override("font_size", 24)
	_gps_check.custom_minimum_size = Vector2(300, 64)
	_gps_check.button_pressed = bool(Settings.get_value("gps_3d"))
	_gps_check.toggled.connect(func(on): Settings.set_value("gps_3d", on))
	_side.add_child(_gps_check)
	_clear_btn = _button(Loc.t("map_clear"), func():
		module.clear_custom()
		module.refresh_now())
	_side.add_child(_clear_btn)
	_side.add_child(_button(Loc.t("map_center"), func(): center = module.player_pos()))
	var close := _button(Loc.t("map_close"), func(): module.close_map())
	close.custom_minimum_size = Vector2(300, 92)
	close.add_theme_font_size_override("font_size", 34)
	_side.add_child(close)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func open() -> void:
	visible = true
	_touches.clear()
	center = module.player_pos()
	var extent: float = (module.graph.max_coord() + 60.0) * 2.0
	zoom = clampf(minf(size.x, size.y) / extent * 1.2, _min_zoom(), _max_zoom())
	_gps_check.set_pressed_no_signal(bool(Settings.get_value("gps_3d")))


func _min_zoom() -> float:
	var extent: float = (module.graph.max_coord() + 80.0) * 2.0
	return minf(size.x, size.y) / extent * 0.8


func _max_zoom() -> float:
	return 9.0


func _process(delta: float) -> void:
	if not visible:
		return
	_flash_t = maxf(_flash_t - delta, 0.0)
	var lim: float = module.graph.max_coord() + 40.0
	center = center.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
	_xf = Transform2D(0.0, Vector2(zoom, zoom), 0.0, size * 0.5 - center * zoom)
	_art.transform = _xf
	_clear_btn.disabled = module.custom_wp == null
	_overlay.queue_redraw()
	_legend.queue_redraw()


# ------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_tap_start = st.position
				_tap_ms = Time.get_ticks_msec()
				_tap_ok = true
			else:
				_tap_ok = false
		else:
			_touches.erase(st.index)
			if _tap_ok and _touches.is_empty() and st.position.distance_to(_tap_start) < TAP_MOVE \
					and Time.get_ticks_msec() - _tap_ms < TAP_TIME:
				_tap(st.position)
			_tap_ok = false
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		if _touches.size() >= 2:
			var keys := _touches.keys()
			var other: Vector2 = _touches[keys[0]] if keys[0] != sd.index else _touches[keys[1]]
			var old: Vector2 = _touches[sd.index]
			var d_old := old.distance_to(other)
			var d_new := sd.position.distance_to(other)
			var mid_old := (old + other) * 0.5
			var mid_new := (sd.position + other) * 0.5
			center -= (mid_new - mid_old) / zoom
			if d_old > 10.0:
				_zoom_at(mid_new, d_new / d_old)
		else:
			center -= sd.relative / zoom
			if sd.position.distance_to(_tap_start) >= TAP_MOVE:
				_tap_ok = false
		_touches[sd.index] = sd.position
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.15)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.15)
			accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, mg.factor)
		accept_event()


func _zoom_at(screen_p: Vector2, factor: float) -> void:
	var before := center + (screen_p - size * 0.5) / zoom
	zoom = clampf(zoom * factor, _min_zoom(), _max_zoom())
	center = before - (screen_p - size * 0.5) / zoom


func screen_to_world(p: Vector2) -> Vector2:
	return center + (p - size * 0.5) / zoom


func _tap(p: Vector2) -> void:
	# Your own pin: remove it.
	if module.custom_wp != null and (_xf * (module.custom_wp as Vector2) + Vector2(0, -16)).distance_to(p) < 36.0:
		module.clear_custom()
		module.refresh_now()
		return
	# Snap to the nearest point of interest.
	var best: Dictionary = {}
	var best_d := 34.0
	for m in module.markers:
		if not bool(m.get("poi", false)):
			continue
		var d := (_xf * (m["pos"] as Vector2)).distance_to(p)
		if d < best_d:
			best_d = d
			best = m
	if not best.is_empty():
		module.set_custom(best["pos"], str(best.get("label", "")))
	else:
		module.set_custom(screen_to_world(p))
	module.refresh_now()
	_flash = Loc.t("map_wp_set")
	_flash_t = 1.4


# ------------------------------------------------------------ drawing

func _draw_overlay() -> void:
	var o := _overlay
	var t: float = module.time
	var s := size
	var g: RefCounted = module.graph
	# Street names along the roads.
	if zoom >= 1.1:
		var lines: PackedFloat32Array = g.lines
		var nl := lines.size()
		var fs := int(clampf(zoom * 9.0, 14.0, 26.0))
		for i in nl:
			var seg := 1 + (i % 2) * 2
			seg = mini(seg, nl - 2)
			var along := (lines[seg] + lines[seg + 1]) * 0.5
			_road_label(o, _xf * Vector2(lines[i], along), -PI * 0.5, Loc.t(g.V_KEYS[i % g.V_KEYS.size()]), fs)
			_road_label(o, _xf * Vector2(along, lines[i]), 0.0, Loc.t(g.H_KEYS[i % g.H_KEYS.size()]), fs)
	# District labels.
	var city: Node = module.main.world
	var pitch: float = city.PITCH
	_area_label(o, _xf * Vector2(0, -6), Loc.t("map_park"), 22)
	_area_label(o, _xf * Vector2(pitch, -pitch), Loc.t("map_downtown"), 22)
	# Police search area.
	if module.search_area != null:
		var sa: Vector3 = module.search_area
		var c := _xf * Vector2(sa.x, sa.y)
		o.draw_circle(c, sa.z * zoom, Color(1.0, 0.15, 0.1, 0.18 + 0.08 * sin(t * 4.0)))
		o.draw_arc(c, sa.z * zoom, 0.0, TAU, 48, Color(1.0, 0.3, 0.25, 0.7), 2.5, true)
	# Route.
	var route: PackedVector2Array = module.route
	if route.size() >= 2:
		var pts := PackedVector2Array()
		for q in route:
			pts.append(_xf * q)
		var col: Color = Icons.COL_ROUTE if module.route_kind == "custom" else Icons.COL_OBJECTIVE
		o.draw_polyline(pts, Color(0, 0, 0, 0.55), 11.0, true)
		o.draw_polyline(pts, col, 7.0, true)
		# Moving dots along the route show the direction.
		var total: float = g.length_of(route)
		var off := fmod(t * 40.0, 40.0)
		var d := off
		while d < total:
			o.draw_circle(_xf * _point_at(route, d), 2.6, Color(1, 1, 1, 0.85))
			d += 40.0
	# Markers + labels.
	var label_shops := zoom >= 2.0
	for m in module.markers:
		var sp: Vector2 = _xf * (m["pos"] as Vector2)
		if sp.x < -40 or sp.y < -40 or sp.x > s.x + 40 or sp.y > s.y + 40:
			continue
		var kind: String = m["kind"]
		var sz := 13.0
		if kind == "car":
			sz = 8.0
		elif kind in ["police", "shop", "hospital"]:
			sz = 11.0
		Icons.draw(o, _font, kind, sp, sz, t, str(m.get("extra", "")))
		var label: String = str(m.get("label", ""))
		if label != "" and (kind in ["giver", "custom"] or (label_shops and kind in ["shop", "hospital"])):
			var ly := sp.y + sz + 22.0
			if kind == "custom":
				ly = sp.y + 22.0
			o.draw_string_outline(_font, Vector2(sp.x - 120, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 240, 19, 5, Color(0, 0, 0, 0.8))
			o.draw_string(_font, Vector2(sp.x - 120, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 240, 19, Color.WHITE)
	# Player.
	var pp: Vector2 = _xf * module.player_pos()
	var pulse := fmod(t, 1.2) / 1.2
	o.draw_arc(pp, 14.0 + pulse * 22.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6 * (1.0 - pulse)), 2.5, true)
	Icons.draw_arrow(o, pp, (module.player_dir() as Vector2).angle(), 16.0)
	# Compass (top-right corner, away from the top centre).
	var cp := Vector2(s.x - 70, 70)
	o.draw_circle(cp, 34.0, Color(0, 0, 0, 0.6))
	o.draw_arc(cp, 34.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true)
	o.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -28), cp + Vector2(9, 0), cp + Vector2(-9, 0)]), Color(1, 0.3, 0.25))
	o.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, 28), cp + Vector2(9, 0), cp + Vector2(-9, 0)]), Color(0.9, 0.9, 0.9))
	o.draw_string_outline(_font, cp + Vector2(-20, -38), Loc.t("map_north"), HORIZONTAL_ALIGNMENT_CENTER, 40, 22, 5, Color.BLACK)
	o.draw_string(_font, cp + Vector2(-20, -38), Loc.t("map_north"), HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color.WHITE)
	# Scale bar (bottom left, under the legend).
	var bar_m := 100.0 if zoom > 1.2 else 200.0
	var bl := Vector2(30, s.y - 40)
	o.draw_line(bl, bl + Vector2(bar_m * zoom, 0), Color.WHITE, 3.0)
	o.draw_line(bl + Vector2(0, -8), bl + Vector2(0, 4), Color.WHITE, 3.0)
	o.draw_line(bl + Vector2(bar_m * zoom, -8), bl + Vector2(bar_m * zoom, 4), Color.WHITE, 3.0)
	o.draw_string(_font, bl + Vector2(0, -14), module.format_dist(bar_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# Bottom info: route + hint.
	var info: String = Loc.t("map_hint")
	if route.size() >= 2:
		info = module.turn_text() + "   |   " + Loc.t("map_dist") % module.format_dist(g.length_of(route))
	var w := minf(s.x - 760.0, 900.0)
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y - 74, w, 52)
	o.draw_rect(r, Color(0, 0, 0, 0.55))
	o.draw_string(_font, Vector2(r.position.x, r.position.y + 35), info, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color.WHITE)
	if _flash_t > 0.0:
		var a := minf(_flash_t * 2.0, 1.0)
		o.draw_string_outline(_font, Vector2(0, s.y * 0.5 - 140), _flash, HORIZONTAL_ALIGNMENT_CENTER, s.x, 34, 8, Color(0, 0, 0, a))
		o.draw_string(_font, Vector2(0, s.y * 0.5 - 140), _flash, HORIZONTAL_ALIGNMENT_CENTER, s.x, 34, Color(1, 1, 1, a))


func _road_label(o: Control, p: Vector2, ang: float, text: String, fs: int) -> void:
	o.draw_set_transform(p, ang)
	o.draw_string_outline(_font, Vector2(-160, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, 4, Color(0, 0, 0, 0.85))
	o.draw_string(_font, Vector2(-160, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color(1, 1, 1, 0.85))
	o.draw_set_transform(Vector2.ZERO, 0.0)


func _area_label(o: Control, p: Vector2, text: String, fs: int) -> void:
	o.draw_string_outline(_font, p + Vector2(-200, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, 6, Color(0, 0, 0, 0.7))
	o.draw_string(_font, p + Vector2(-200, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, Color(1, 1, 0.9, 0.75))


func _point_at(route: PackedVector2Array, d: float) -> Vector2:
	var acc := 0.0
	for i in range(1, route.size()):
		var seg := route[i - 1].distance_to(route[i])
		if acc + seg >= d:
			return route[i - 1].lerp(route[i], (d - acc) / maxf(seg, 0.001))
		acc += seg
	return route[route.size() - 1]


func _draw_legend() -> void:
	var l := _legend
	var rtl := Loc.is_rtl()
	l.draw_rect(Rect2(Vector2.ZERO, l.size), Color(0, 0, 0, 0.55))
	l.draw_string(_font, Vector2(16, 50), Loc.t("map_title"), HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT, l.size.x - 32, 32, Color.WHITE)
	var y := 96.0
	var t: float = module.time
	for kind in Icons.LEGEND:
		var ix := l.size.x - 34.0 if rtl else 34.0
		Icons.draw(l, _font, kind, Vector2(ix, y + (8.0 if kind == "custom" else 0.0)), 10.0, t, "1" if kind == "checkpoint" else "")
		var tx := 16.0 if rtl else 64.0
		l.draw_string(_font, Vector2(tx, y + 8), Loc.t("map_lg_" + kind), HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT, l.size.x - 82.0, 22, Color(1, 1, 1, 0.9))
		y += 38.0

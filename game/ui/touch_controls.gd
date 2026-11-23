extends Control
## Multi-touch HUD controls built for two thumbs.
##  * Left thumb: floating joystick that appears where you touch. Push to the edge = sprint.
##    Slide up past the joystick to the lock target and let go = run lock (auto-sprint).
##  * Right thumb: drag anywhere to turn the camera. The big fire button can be dragged
##    while firing, so you aim and shoot with the same thumb.
## All drawing is done here in _draw() so there are no extra nodes or textures.

signal edit_selection_changed(id: String)

const LOOK_DEG_PER_PX := 0.13
const HIT_SLOP := 1.2
const LOCK_DISTANCE := 1.9   # in joystick radii above the joystick base
const SPRINT_AT := 0.93

var edit_mode := false:
	set(v):
		edit_mode = v
		_release_all()
		selected_id = ""
		queue_redraw()
var selected_id := ""
## Screen rectangles where touches belong to regular GUI (edit toolbar etc).
var ignore_rects: Array[Rect2] = []
var context_visible := false
var context_label := "ctx_pickup"

var _buttons := {}           # id -> {center, radius, base_r, label, scale}
var _pressed := {}           # finger index -> button id
var _look_fingers := {}      # finger index -> true
var _joy_finger := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _joy_lock_hover := false
var _run_locked := false
var _run_lock_pos := Vector2.ZERO
var _edit_finger := -1
var _edit_offset := Vector2.ZERO
var _font: Font
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	Settings.changed.connect(func(_k): _rebuild())
	Loc.language_changed.connect(queue_redraw)
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var defaults: Dictionary = TouchLayout.defaults(Settings.get_value("layout_preset"))
	var s := size if size.x > 0.0 else get_viewport_rect().size
	var px := s.y / 1080.0
	var global_scale := float(Settings.get_value("btn_scale"))
	_buttons.clear()
	for id in defaults:
		var d: Dictionary = defaults[id]
		var pos: Vector2 = d["pos"]
		var sc := 1.0
		if Settings.layout_overrides.has(id):
			var o: Dictionary = Settings.layout_overrides[id]
			pos = o["pos"]
			sc = o["scale"]
		_buttons[id] = {
			"center": pos * s,
			"radius": float(d["r"]) * px * global_scale * sc,
			"label": d["label"],
			"scale": sc,
		}
	queue_redraw()


func button_ids() -> Array:
	return _buttons.keys()


func get_button_scale(id: String) -> float:
	return _buttons[id]["scale"] if _buttons.has(id) else 1.0


func set_selected_scale(sc: float) -> void:
	if selected_id == "" or not _buttons.has(selected_id):
		return
	var b: Dictionary = _buttons[selected_id]
	Settings.set_layout_override(selected_id, b["center"] / size, sc)


func _process(delta: float) -> void:
	_time += delta
	if _run_locked:
		GameInput.touch_move = Vector2(0, -1)
		GameInput.touch_sprint = true
	queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible or GameInput.menu_open and not edit_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index, event.position)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)


func _on_press(finger: int, p: Vector2) -> void:
	for r in ignore_rects:
		if r.has_point(p):
			return
	if edit_mode:
		var id := _button_at(p, true)
		if id != "":
			_edit_finger = finger
			_edit_offset = _buttons[id]["center"] - p
			selected_id = id
			edit_selection_changed.emit(id)
		return

	var id := _button_at(p, false)
	if id != "":
		_pressed[finger] = id
		_press_button(id, true)
		return

	var s := size
	if p.x < s.x * TouchLayout.JOYSTICK_ZONE_MAX_X and p.y > s.y * TouchLayout.JOYSTICK_ZONE_MIN_Y:
		if _joy_finger == -1:
			_run_locked = false
			GameInput.touch_sprint = false
			_joy_finger = finger
			_joy_base = p
			_joy_knob = p
			GameInput.touch_move = Vector2.ZERO
		return

	_look_fingers[finger] = true


func _on_drag(finger: int, p: Vector2, rel: Vector2) -> void:
	if edit_mode:
		if finger == _edit_finger and selected_id != "":
			var c := (p + _edit_offset).clamp(Vector2.ZERO, size)
			_buttons[selected_id]["center"] = c
		return

	if finger == _joy_finger:
		var r := _joy_radius()
		var off := p - _joy_base
		var dist := off.length()
		_joy_knob = _joy_base + off.limit_length(r)
		var v := off / r
		GameInput.touch_move = v.limit_length(1.0)
		GameInput.touch_sprint = dist >= r * SPRINT_AT and off.y < 0.0
		_joy_lock_hover = off.y < -r * LOCK_DISTANCE and absf(off.x) < r * 1.1
		return

	var looks := _look_fingers.has(finger)
	if _pressed.has(finger):
		var bid: String = _pressed[finger]
		looks = bid == "fire" or bid == "fire2"
	if looks:
		var deg := rel * LOOK_DEG_PER_PX * (1080.0 / maxf(size.y, 1.0)) * GameInput.current_sens()
		GameInput.add_look(deg)


func _on_release(finger: int, _p: Vector2) -> void:
	if edit_mode:
		if finger == _edit_finger and selected_id != "":
			var b: Dictionary = _buttons[selected_id]
			Settings.set_layout_override(selected_id, b["center"] / size, b["scale"])
			_edit_finger = -1
		return

	if finger == _joy_finger:
		_joy_finger = -1
		if _joy_lock_hover:
			_run_locked = true
			_run_lock_pos = _joy_base + Vector2(0, -_joy_radius() * LOCK_DISTANCE)
		else:
			GameInput.touch_move = Vector2.ZERO
			GameInput.touch_sprint = false
		_joy_lock_hover = false
		return

	if _pressed.has(finger):
		var released: String = _pressed[finger]
		_pressed.erase(finger)
		_press_button(released, false)
		return
	_look_fingers.erase(finger)


## Labels used while driving (same buttons, different jobs).
const DRIVE_LABELS := {"fire": "gas", "fire2": "gas", "ads": "brake", "jump": "handbrake", "swap": "radio"}


func _press_button(id: String, down: bool) -> void:
	if GameInput.vehicle_mode:
		_update_drive_buttons()
		if down and id in ["swap", "context", "menu"]:
			GameInput.pulse("radio" if id == "swap" else id)
			if id == "menu":
				_release_all()
		return
	match id:
		"fire":
			GameInput.fire_held = down
		"fire2":
			GameInput.fire_alt_held = down
		_:
			if down:
				GameInput.pulse(id)
				if id == "menu":
					_release_all()


func _update_drive_buttons() -> void:
	var held := {}
	for f in _pressed:
		held[_pressed[f]] = true
	GameInput.set_touch_drive(held.has("fire") or held.has("fire2"), held.has("ads"), held.has("jump"))


func _hidden_in_mode(id: String) -> bool:
	return GameInput.vehicle_mode and id == "crouch"


func _release_all() -> void:
	_pressed.clear()
	_look_fingers.clear()
	_joy_finger = -1
	_joy_lock_hover = false
	_run_locked = false
	_edit_finger = -1
	GameInput.reset_touch()


func _button_at(p: Vector2, include_hidden: bool) -> String:
	var best := ""
	var best_d := INF
	for id in _buttons:
		if id == "context" and not context_visible and not include_hidden:
			continue
		var b: Dictionary = _buttons[id]
		var d := p.distance_to(b["center"])
		if d <= b["radius"] * HIT_SLOP and d < best_d:
			best = id
			best_d = d
	return best


func _joy_radius() -> float:
	return TouchLayout.JOYSTICK_RADIUS * (size.y / 1080.0) * float(Settings.get_value("btn_scale"))


func is_run_locked() -> bool:
	return _run_locked


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var alpha := float(Settings.get_value("btn_opacity"))
	if edit_mode:
		alpha = maxf(alpha, 0.6)
	var fill := Color(0.08, 0.1, 0.12, alpha * 0.55)
	var ring := Color(1, 1, 1, alpha)
	var active := Color(1.0, 0.55, 0.25, minf(alpha + 0.25, 1.0))

	_draw_joystick(alpha, ring, fill, active)

	var pressed_ids := {}
	for f in _pressed:
		pressed_ids[_pressed[f]] = true

	for id in _buttons:
		if (id == "context" and not context_visible and not edit_mode) or _hidden_in_mode(id):
			continue
		var b: Dictionary = _buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var is_down: bool = pressed_ids.has(id) or (id == "fire" and GameInput.fire_held)
		draw_circle(c, r, active if is_down else fill)
		var outline := ring
		if edit_mode and id == selected_id:
			outline = Color(0.3, 1.0, 0.5, 1.0)
		draw_arc(c, r, 0.0, TAU, 48, outline, maxf(2.0, r * 0.06), true)
		if id == "fire" or id == "fire2":
			_draw_crosshair_icon(c, r * 0.42, ring)
		var text := Loc.t(b["label"]) if id != "context" else Loc.t(context_label)
		if GameInput.vehicle_mode and DRIVE_LABELS.has(id):
			text = Loc.t(DRIVE_LABELS[id])
		var fs := int(clampf(r * 0.34, 16.0, 30.0))
		var y_off := r * 0.62 if (id == "fire" or id == "fire2") else fs * 0.35
		if id == "menu":
			_draw_menu_icon(c, r * 0.5, ring)
			continue
		draw_string(_font, Vector2(c.x - r, c.y + y_off), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, ring)


func _draw_joystick(alpha: float, ring: Color, fill: Color, active: Color) -> void:
	var r := _joy_radius()
	if _joy_finger != -1:
		draw_circle(_joy_base, r, fill)
		draw_arc(_joy_base, r, 0.0, TAU, 48, ring, 3.0, true)
		var knob_col := active if GameInput.touch_sprint else ring
		draw_circle(_joy_knob, r * 0.42, knob_col)
		# Run lock target above the joystick.
		var lp := _joy_base + Vector2(0, -r * LOCK_DISTANCE)
		var lc := active if _joy_lock_hover else Color(1, 1, 1, alpha * 0.8)
		draw_arc(lp, r * 0.38, 0.0, TAU, 32, lc, 3.0, true)
		_draw_lock_icon(lp, r * 0.2, lc)
		draw_string(_font, Vector2(lp.x - r, lp.y - r * 0.5), Loc.t("run_lock"), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, lc)
	elif _run_locked:
		var pulse := 0.6 + 0.4 * sin(_time * 5.0)
		var c := Color(active.r, active.g, active.b, active.a * pulse)
		draw_circle(_run_lock_pos, r * 0.42, Color(fill.r, fill.g, fill.b, fill.a))
		draw_arc(_run_lock_pos, r * 0.42, 0.0, TAU, 32, c, 4.0, true)
		_draw_lock_icon(_run_lock_pos, r * 0.22, c)
	else:
		# Faint hint showing where the joystick lives.
		var hint := Vector2(size.x * 0.15, size.y * 0.72)
		draw_arc(hint, r, 0.0, TAU, 48, Color(1, 1, 1, alpha * 0.25), 2.0, true)
		draw_circle(hint, r * 0.42, Color(1, 1, 1, alpha * 0.12))


func _draw_crosshair_icon(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.12)
	draw_arc(c + Vector2(0, -s * 0.25), s * 0.55, 0.0, TAU, 24, col, w, true)
	draw_line(c + Vector2(0, -s * 1.0), c + Vector2(0, -s * 0.6), col, w)
	draw_line(c + Vector2(0, s * 0.1), c + Vector2(0, s * 0.5), col, w)
	draw_line(c + Vector2(-s * 0.75, -s * 0.25), c + Vector2(-s * 0.35, -s * 0.25), col, w)
	draw_line(c + Vector2(s * 0.35, -s * 0.25), c + Vector2(s * 0.75, -s * 0.25), col, w)


func _draw_lock_icon(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-s, -s * 0.2), Vector2(s * 2.0, s * 1.4)), col)
	draw_arc(c + Vector2(0, -s * 0.2), s * 0.65, PI, TAU, 16, col, maxf(2.0, s * 0.3), true)


func _draw_menu_icon(c: Vector2, s: float, col: Color) -> void:
	for i in 3:
		var y := c.y + (i - 1) * s * 0.6
		draw_line(Vector2(c.x - s, y), Vector2(c.x + s, y), col, maxf(2.0, s * 0.22))

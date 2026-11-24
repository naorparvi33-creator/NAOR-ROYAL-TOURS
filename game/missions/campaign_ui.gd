extends CanvasLayer
## Campaign UI: dialogue box (speaker + line, tap or wait to advance), status bars for
## the running mission (VIP car, detection, garage...), short notices (stunt jumps,
## collectibles) and a small progress line under the money. Everything stays out of
## the thumb zones and the top centre (which belongs to the objective text).

signal dialogue_finished

const SPEAKERS := {
	"maya": Color(0.45, 0.85, 1.0),
	"dudi": Color(1.0, 0.65, 0.25),
	"eli": Color(0.6, 1.0, 0.55),
	"noa": Color(1.0, 0.55, 0.8),
	"gideon": Color(1.0, 0.3, 0.25),
	"barzel": Color(0.85, 0.2, 0.2),
	"radio": Color(0.8, 0.8, 0.8),
	"you": Color(1.0, 0.92, 0.5),
	"victim": Color(0.9, 0.9, 0.9),
}

var talking := false
var progress_text := ""

var _panel: PanelContainer
var _name: Label
var _line: Label
var _hint: Label
var _lines: Array = []
var _li := 0
var _line_t := 0.0
var _line_dur := 3.0
var _shown := 0.0
var _canvas: Control
var _bars: Dictionary = {}     # id -> [label, value, color]
var _notice := ""
var _notice_sub := ""
var _notice_t := 0.0
var _notice_col := Color.WHITE
var _font: Font
var _last_tap := 0


func _ready() -> void:
	layer = 11
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_font = _canvas.get_theme_default_font()

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.6
	_panel.anchor_bottom = 0.6
	_panel.offset_left = -460
	_panel.offset_right = 460
	_panel.offset_top = 0
	_panel.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 28)
	_line.custom_minimum_size = Vector2(860, 0)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_line)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint)


## lines: Array of {"who": speaker id, "he": text, "en": text}
func say(lines: Array) -> void:
	if lines.is_empty():
		dialogue_finished.emit()
		return
	_lines = lines
	_li = 0
	talking = true
	_show_line()


func stop_dialogue() -> void:
	if talking:
		talking = false
		_panel.visible = false
		_lines = []


func _show_line() -> void:
	var l: Dictionary = _lines[_li]
	var who: String = l.get("who", "radio")
	var txt: String = l.get(Loc.lang, l.get("he", ""))
	var rtl := Loc.is_rtl()
	var dirn := Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
	var align := HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	_name.text = Loc.t("spk_" + who)
	_name.add_theme_color_override("font_color", SPEAKERS.get(who, Color.WHITE))
	_line.text = txt
	_hint.text = Loc.t("dlg_tap")
	for lab in [_name, _line, _hint]:
		(lab as Label).text_direction = dirn
		(lab as Label).horizontal_alignment = align
	_line.visible_ratio = 0.0
	_shown = 0.0
	_line_t = 0.0
	_line_dur = clampf(2.2 + txt.length() * 0.055, 2.8, 7.5)
	_panel.visible = true
	var vp := get_viewport().get_visible_rect().size
	var w := minf(vp.x * 0.56, 920.0)
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	_line.custom_minimum_size = Vector2(w - 50, 0)


func _advance() -> void:
	if not talking:
		return
	if _line.visible_ratio < 1.0:
		_line.visible_ratio = 1.0       # first tap reveals the whole line
		_shown = 1.0
		return
	_li += 1
	if _li >= _lines.size():
		talking = false
		_panel.visible = false
		dialogue_finished.emit()
	else:
		_show_line()


func _on_panel_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		# A tap can arrive both as touch and as emulated mouse: debounce.
		var now := Time.get_ticks_msec()
		if now - _last_tap > 180:
			_last_tap = now
			_advance()
		_panel.accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if talking and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER):
		_advance()


func _process(delta: float) -> void:
	if talking:
		_shown = minf(_shown + delta * 1.8, 1.0)
		_line.visible_ratio = _shown
		_line_t += delta
		if _line_t > _line_dur:
			_line.visible_ratio = 1.0
			_shown = 1.0
			_advance()
	if _notice_t > 0.0:
		_notice_t -= delta
	_canvas.queue_redraw()


# ------------------------------------------------------------ bars and notices

func set_bar(id: String, label: String, value: float, col: Color) -> void:
	_bars[id] = [label, clampf(value, 0.0, 1.0), col]


func clear_bar(id: String) -> void:
	_bars.erase(id)


func clear_bars() -> void:
	_bars.clear()


func notice(text: String, sub := "", col := Color(1.0, 0.85, 0.3), dur := 2.6) -> void:
	_notice = text
	_notice_sub = sub
	_notice_col = col
	_notice_t = dur


func _draw_canvas() -> void:
	var s := _canvas.size
	# Progress line under the money (top-left).
	if progress_text != "":
		_text(progress_text, Vector2(110, 92), 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, 600)
	# Mission bars, left side under the health bar.
	var y := 110.0
	for id in _bars:
		var b: Array = _bars[id]
		_text(b[0], Vector2(110, y + 18), 20, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 260)
		var r := Rect2(110, y + 26, 220, 12)
		_canvas.draw_rect(r.grow(2), Color(0, 0, 0, 0.5))
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * float(b[1]), r.size.y)), b[2])
		y += 48.0
	# Notice (stunts, collectibles, street events).
	if _notice_t > 0.0:
		var a := clampf(_notice_t / 0.5, 0.0, 1.0)
		var c := Color(_notice_col.r, _notice_col.g, _notice_col.b, a)
		_text(_notice, Vector2(0, s.y * 0.24), 46, c, HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if _notice_sub != "":
			_text(_notice_sub, Vector2(0, s.y * 0.24 + 44), 28, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, s.x)


func _text(t: String, pos: Vector2, fs: int, col: Color, align: HorizontalAlignment, width: float) -> void:
	_canvas.draw_string_outline(_font, pos, t, align, width, fs, 6, Color(0, 0, 0, col.a * 0.8))
	_canvas.draw_string(_font, pos, t, align, width, fs, col)

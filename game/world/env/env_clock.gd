extends CanvasLayer
## Small in-game clock with a weather icon (top-right corner, away from the thumbs and
## the top centre). Drawn in code; redrawn only when the minute or the weather changes.

var dn: Node

var _c: Control
var _font: Font
var _last := ""


func _ready() -> void:
	layer = 9   # under the main HUD layer, so the settings menu covers it
	_c = Control.new()
	_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_clock)
	add_child(_c)
	_font = _c.get_theme_default_font()
	Loc.language_changed.connect(func(): _last = "")


func _process(_delta: float) -> void:
	var key: String = dn.clock_text() + str(dn.weather.state) + str(dn.is_night())
	if key != _last:
		_last = key
		_c.queue_redraw()


func _draw_clock() -> void:
	var s := _c.size
	var right := s.x - 28.0
	var y := 44.0
	var white := Color(1, 1, 1, 0.92)
	var text: String = dn.clock_text()
	var fs := 30
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := right - tw
	_c.draw_string_outline(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7))
	_c.draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	_icon(Vector2(x - 30.0, y - 10.0))
	var wname := Loc.t("weather_" + str(dn.weather.state))
	var ws := 20
	var ww := _font.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, ws).x
	_c.draw_string_outline(_font, Vector2(right - ww, y + 28.0), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, ws, 5, Color(0, 0, 0, 0.6))
	_c.draw_string(_font, Vector2(right - ww, y + 28.0), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, ws, Color(1, 1, 1, 0.75))


func _icon(c: Vector2) -> void:
	var st: String = dn.weather.state
	var night: bool = dn.is_night()
	if st == "clear" or st == "cloudy":
		if night:
			# Crescent moon.
			_c.draw_circle(c, 11.0, Color(0.92, 0.94, 1.0))
			_c.draw_circle(c + Vector2(5, -4), 10.0, Color(0.08, 0.1, 0.18))
		else:
			_c.draw_circle(c, 8.0, Color(1.0, 0.82, 0.3))
			for i in 8:
				var a := i * TAU / 8.0
				_c.draw_line(c + Vector2.from_angle(a) * 11.0, c + Vector2.from_angle(a) * 15.0, Color(1.0, 0.82, 0.3), 2.5, true)
	if st != "clear":
		var cc := Color(0.85, 0.87, 0.9) if st == "cloudy" else Color(0.55, 0.58, 0.64)
		var o := c + Vector2(4, 5)
		_c.draw_circle(o + Vector2(-7, 2), 7.0, cc)
		_c.draw_circle(o + Vector2(1, -3), 9.0, cc)
		_c.draw_circle(o + Vector2(9, 2), 7.0, cc)
		_c.draw_rect(Rect2(o + Vector2(-7, 2), Vector2(16, 7)), cc)
		if st == "rain" or st == "storm":
			for i in 3:
				var p := o + Vector2(-6 + i * 6, 13)
				_c.draw_line(p, p + Vector2(-2, 6), Color(0.6, 0.8, 1.0), 2.0, true)
		if st == "storm":
			var b := o + Vector2(2, 9)
			_c.draw_polyline(PackedVector2Array([b, b + Vector2(-4, 7), b + Vector2(1, 7), b + Vector2(-3, 14)]), Color(1.0, 0.9, 0.3), 2.5, true)

extends RefCounted
## Shared look for the title screen, pause menu and credits: large touch-friendly
## buttons, dark glass panels and a warm accent colour. Static helpers only.

const ACCENT := Color(1.0, 0.72, 0.28)
const TEXT := Color(0.96, 0.96, 0.94)


static func button(text: String, cb: Callable, primary := false, w := 460.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 84)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 34)
	var normal := _box(Color(0.06, 0.07, 0.09, 0.78) if not primary else Color(0.9, 0.55, 0.15, 0.92), primary)
	var hover := _box(Color(0.16, 0.17, 0.2, 0.9) if not primary else Color(1.0, 0.65, 0.22, 0.95), true)
	var pressed := _box(Color(0.95, 0.6, 0.2, 0.95), true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", _outline())
	b.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03) if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03) if primary else Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.03))
	b.pressed.connect(cb)
	return b


static func _box(c: Color, accent_edge: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(14)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if accent_edge:
		s.border_color = ACCENT
		s.set_border_width_all(2)
	else:
		s.border_color = Color(1, 1, 1, 0.12)
		s.set_border_width_all(1)
	return s


static func _outline() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color(1, 1, 1, 0.7)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	return s


static func panel(alpha := 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.035, 0.05, alpha)
	s.set_corner_radius_all(22)
	s.border_color = Color(1, 1, 1, 0.08)
	s.set_border_width_all(1)
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 34
	s.content_margin_bottom = 34
	p.add_theme_stylebox_override("panel", s)
	return p


static func label(text: String, size: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 8 if size >= 40 else 4)
	# Alignment is given in screen terms (RIGHT = right edge), not mirrored by RTL parents.
	l.layout_direction = Control.LAYOUT_DIRECTION_LTR
	# Hebrew paragraphs stay right-to-left even when they start with a Latin name.
	l.text_direction = Control.TEXT_DIRECTION_RTL if Loc.is_rtl() else Control.TEXT_DIRECTION_LTR
	return l


## Right-aligned for Hebrew, left-aligned for English.
static func start_align() -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_RIGHT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT


static func direction() -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR

extends Control
## Settings menu built in code, large touch-friendly rows, Hebrew RTL by default.

signal resume_requested
signal edit_layout_requested
signal save_requested
signal reset_position_requested

const ROW_H := 74.0

var _tabs: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Loc.language_changed.connect(_build)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60 if side in ["left", "right"] else 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = Loc.t("settings")
	title.add_theme_font_size_override("font_size", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var resume := _button(Loc.t("resume"), func(): resume_requested.emit())
	resume.custom_minimum_size = Vector2(300, 80)
	header.add_child(resume)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 32)
	root.add_child(_tabs)

	var g := _tab(Loc.t("tab_graphics"))
	_option(g, "fps_cap", [["60", 60], ["90", 90], ["120", 120]])
	_check(g, "battery_saver")
	_check(g, "dynamic_res")
	_slider(g, "render_scale_max", 0.7, 1.0, 0.05)
	_check(g, "shadows")
	_check(g, "grass")
	_slider(g, "draw_distance", 150.0, 1500.0, 50.0)
	_check(g, "show_perf")
	_slider(g, "music_volume", 0.0, 1.0, 0.05)
	_slider(g, "sfx_volume", 0.0, 1.0, 0.05)
	_check(g, "blood")

	var c := _tab(Loc.t("tab_controls"))
	_option(c, "layout_preset", [[Loc.t("layout_2"), "two_thumbs"], [Loc.t("layout_4"), "four_fingers"]], "layout")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(_button(Loc.t("edit_layout"), func(): edit_layout_requested.emit()))
	row.add_child(_button(Loc.t("reset_layout"), func(): Settings.reset_layout()))
	c.add_child(row)
	_slider(c, "btn_scale", 0.7, 1.5, 0.05, "btn_size")
	_slider(c, "btn_opacity", 0.15, 1.0, 0.05)
	_slider(c, "sens_look", 0.2, 3.0, 0.05)
	_slider(c, "sens_ads", 0.1, 2.0, 0.05)
	_slider(c, "sens_scope", 0.05, 1.5, 0.05)
	_check(c, "invert_y")
	_option(c, "gyro_mode", [[Loc.t("gyro_off"), 0], [Loc.t("gyro_ads"), 1], [Loc.t("gyro_always"), 2]], "gyro")
	_slider(c, "gyro_sens", 0.2, 3.0, 0.1)
	_check(c, "auto_fire")
	_slider(c, "aim_assist", 0.0, 1.0, 0.05)

	var gen := _tab(Loc.t("tab_general"))
	_option(gen, "language", [["עברית", "he"], ["English", "en"]])
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	row2.add_child(_button(Loc.t("save_now"), func(): save_requested.emit()))
	row2.add_child(_button(Loc.t("reset_position"), func(): reset_position_requested.emit()))
	gen.add_child(row2)
	var info := Label.new()
	info.text = "v%s  |  Godot %s" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"]]
	info.modulate = Color(1, 1, 1, 0.5)
	gen.add_child(info)


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box


func _label(parent: Control, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_H
	row.add_theme_constant_override("separation", 24)
	var l := Label.new()
	l.text = Loc.t(key)
	l.custom_minimum_size.x = 520
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	parent.add_child(row)
	return row


func _check(parent: Control, key: String) -> void:
	var row := _label(parent, key)
	var cb := CheckButton.new()
	cb.button_pressed = bool(Settings.get_value(key))
	cb.text = Loc.t("on") if cb.button_pressed else Loc.t("off")
	cb.custom_minimum_size = Vector2(200, ROW_H)
	cb.toggled.connect(func(v):
		cb.text = Loc.t("on") if v else Loc.t("off")
		Settings.set_value(key, v))
	row.add_child(cb)


func _slider(parent: Control, key: String, lo: float, hi: float, step: float, label_key := "") -> void:
	var row := _label(parent, label_key if label_key != "" else key)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(300, 56)
	var val := Label.new()
	val.custom_minimum_size.x = 110
	val.text = _fmt(s.value, step)
	s.value_changed.connect(func(v):
		val.text = _fmt(v, step)
		Settings.set_value(key, v))
	row.add_child(s)
	row.add_child(val)


func _option(parent: Control, key: String, items: Array, label_key := "") -> void:
	var row := _label(parent, label_key if label_key != "" else key)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(320, ROW_H - 8)
	var cur = Settings.get_value(key)
	for i in items.size():
		ob.add_item(str(items[i][0]), i)
		if items[i][1] == cur:
			ob.select(i)
	ob.item_selected.connect(func(i): Settings.set_value(key, items[i][1]))
	row.add_child(ob)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, ROW_H)
	b.pressed.connect(cb)
	return b


func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v

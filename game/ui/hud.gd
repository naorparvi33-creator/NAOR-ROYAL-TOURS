extends CanvasLayer
## Owns every 2D element: touch controls, crosshair, perf counter, settings and
## the button layout editor.

var player: CharacterBody3D
var missions: Node3D
var game_hud: Control
var touch: Control
var crosshair: Control
var menu: Control

var _perf_label: Label
var _info_label: Label
var _toast: Label
var _toast_t := 0.0
var _edit_bar: PanelContainer
var _edit_slider: HSlider
var _weapon_key := "weapon_rifle"
var _collected := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	crosshair = preload("res://ui/crosshair.gd").new()
	crosshair.player = player
	add_child(crosshair)

	game_hud = preload("res://ui/game_hud.gd").new()
	game_hud.player = player
	game_hud.missions = missions
	add_child(game_hud)

	touch = preload("res://ui/touch_controls.gd").new()
	add_child(touch)

	_perf_label = Label.new()
	_perf_label.position = Vector2(110, 14)
	_perf_label.add_theme_font_size_override("font_size", 22)
	_perf_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_perf_label.add_theme_constant_override("outline_size", 6)
	add_child(_perf_label)

	_info_label = Label.new()
	_place(_info_label, Vector2(0.5, 1.0), Rect2(-300, -66, 600, 50))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 26)
	_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_info_label.add_theme_constant_override("outline_size", 6)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_label)

	_toast = Label.new()
	_place(_toast, Vector2(0.5, 0.5), Rect2(-400, -220, 800, 60))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	add_child(_toast)

	menu = preload("res://ui/settings_menu.gd").new()
	menu.visible = false
	add_child(menu)
	menu.resume_requested.connect(close_menu)
	menu.edit_layout_requested.connect(_start_edit)
	menu.save_requested.connect(func():
		get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		toast(Loc.t("saved")))
	menu.reset_position_requested.connect(func():
		player.reset_to_spawn()
		close_menu())

	_build_edit_bar()

	player.context_changed.connect(func(v, label):
		touch.context_visible = v
		if label != "":
			touch.context_label = label)
	player.collected_changed.connect(func(n):
		_collected = n
		_update_info())
	player.weapon.weapon_changed.connect(func(k):
		_weapon_key = k
		_update_info())
	player.vehicle_changed.connect(func(v):
		crosshair.visible = v == null
		_update_info())
	player.money_changed.connect(func(_m): _update_info())
	Sfx.station_changed.connect(func(k): toast(Loc.t(k)))
	player.weapon.hit.connect(crosshair.show_hit)
	player.weapon.fired.connect(crosshair.kick)
	Loc.language_changed.connect(_update_info)
	Perf.stats_updated.connect(_update_perf)
	Settings.changed.connect(func(k):
		if k == "show_perf":
			_perf_label.visible = Settings.get_value("show_perf"))
	_perf_label.visible = Settings.get_value("show_perf")
	_update_info()


func _process(delta: float) -> void:
	if GameInput.consume("menu"):
		if menu.visible:
			close_menu()
		elif not touch.edit_mode:
			open_menu()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0


func open_menu() -> void:
	menu.visible = true
	GameInput.menu_open = true
	GameInput.reset_touch()
	get_tree().paused = true


func close_menu() -> void:
	menu.visible = false
	GameInput.menu_open = false
	get_tree().paused = false


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.6
	_toast.visible = true


func _update_info() -> void:
	if player.in_vehicle:
		_info_label.text = ""
	else:
		_info_label.text = Loc.t(_weapon_key)


func _update_perf() -> void:
	var heat := Loc.t("thermal_na")
	if Perf.thermal_status >= 0:
		heat = Loc.t("thermal_%d" % mini(Perf.thermal_status, 4))
	_perf_label.text = "FPS %d / %d   %.1f ms   GPU %.1f   %s %d%%   RS %.2f   %s: %s" % [
		roundi(Perf.fps), Perf.target_fps(), Perf.frame_ms, Perf.gpu_ms,
		"עומס" if Loc.is_rtl() else "Load", roundi(Perf.load_pct), Perf.render_scale,
		Loc.t("thermal"), heat]


## Anchors a control to a point of the screen (0..1) with a pixel rect around it.
func _place(c: Control, anchor: Vector2, r: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


# ------------------------------------------------------------ layout editor

func _build_edit_bar() -> void:
	_edit_bar = PanelContainer.new()
	_place(_edit_bar, Vector2(0.5, 0.0), Rect2(-430, 110, 860, 150))
	_edit_bar.visible = false
	add_child(_edit_bar)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_edit_bar.add_child(box)
	var hint := Label.new()
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var l := Label.new()
	l.name = "SizeLabel"
	row.add_child(l)
	_edit_slider = HSlider.new()
	_edit_slider.min_value = 0.6
	_edit_slider.max_value = 1.8
	_edit_slider.step = 0.05
	_edit_slider.custom_minimum_size = Vector2(360, 56)
	_edit_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_slider.value_changed.connect(func(v): touch.set_selected_scale(v))
	row.add_child(_edit_slider)
	var done := Button.new()
	done.name = "Done"
	done.custom_minimum_size = Vector2(200, 70)
	done.pressed.connect(_end_edit)
	row.add_child(done)
	touch.edit_selection_changed.connect(func(id):
		_edit_slider.set_value_no_signal(touch.get_button_scale(id)))


func _start_edit() -> void:
	menu.visible = false
	_edit_bar.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	_edit_bar.find_child("Hint", true, false).text = Loc.t("edit_hint")
	_edit_bar.find_child("SizeLabel", true, false).text = Loc.t("selected_size")
	_edit_bar.find_child("Done", true, false).text = Loc.t("done")
	_edit_bar.visible = true
	touch.edit_mode = true
	await get_tree().process_frame
	touch.ignore_rects = [_edit_bar.get_global_rect()]


func _end_edit() -> void:
	_edit_bar.visible = false
	touch.edit_mode = false
	touch.ignore_rects = []
	close_menu()

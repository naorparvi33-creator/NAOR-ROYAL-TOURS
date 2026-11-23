extends CanvasLayer
## Title screen / main menu shown when the game starts (and from the pause menu).
## Behind it a cinematic camera flies slow shots over the living city (people keep
## walking, cars keep driving). Buttons: Continue, New game, Settings, Credits, Quit.

signal game_started(new_game: bool)

const Kit := preload("res://ui/menus/menu_kit.gd")
const SAVE_PATH := "user://save.cfg"
const SHOT_LEN := 15.0
const FADE := 0.9

var main: Node
var active := false

var _cam: Camera3D
var _shot := 0
var _shot_t := 0.0
var _time := 0.0
var _root: Control
var _menu_box: VBoxContainer
var _credits: Control
var _confirm: Control
var _settings: Control
var _fade: ColorRect
var _has_save := false
var _hud_layer_visible := true
var _leaving := false


func _ready() -> void:
	name = "TitleScreen"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_has_save = FileAccess.file_exists(SAVE_PATH)
	_cam = Camera3D.new()
	_cam.name = "TitleCamera"
	_cam.fov = 58.0
	_cam.far = 900.0
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Loc.language_changed.connect(_build)
	_build()
	add_child(_fade)
	_settings = preload("res://ui/settings_menu.gd").new()
	_settings.visible = false
	add_child(_settings)
	_settings.resume_requested.connect(func(): _settings.visible = false)
	_settings.save_requested.connect(func(): main.call("_save_game"))
	_settings.reset_position_requested.connect(func(): main.player.reset_to_spawn())
	_settings.edit_layout_requested.connect(func():
		_settings.visible = false
		start_game(false)
		main.hud.call("_start_edit"))
	# main adds modules from its _ready: wait until the world is in the tree.
	await get_tree().process_frame
	if main:
		main.add_child(_cam)
	show_title()


func show_title() -> void:
	active = true
	_leaving = false
	_time = 0.0
	visible = true
	_has_save = FileAccess.file_exists(SAVE_PATH) or _has_save
	_build()
	_show_page("menu")
	GameInput.menu_open = true
	GameInput.reset_touch()
	get_tree().paused = false
	if main and main.hud:
		_hud_layer_visible = true
		main.hud.visible = false
	_shot = randi() % 3
	_shot_t = 0.0
	_place_camera(0.0)
	_cam.current = true
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 1.2)


## Leaves the title screen. new_game wipes the save and puts the player at the start.
func start_game(new_game: bool) -> void:
	if not active:
		return
	active = false
	if new_game:
		_reset_progress()
	_settings.visible = false
	visible = false
	if main:
		if main.player:
			main.player.rig.camera.current = true
		if main.hud:
			main.hud.visible = _hud_layer_visible
	GameInput.menu_open = false
	GameInput.reset_touch()
	game_started.emit(new_game)


func _reset_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var pl: Node = main.player
	pl.money = 0
	pl.money_changed.emit(0)
	pl.health = 100.0
	pl.health_changed.emit(100.0)
	pl.reset_to_spawn()
	pl.rig.yaw = 180.0
	pl.rig.pitch = -8.0
	get_tree().call_group("new_game_listeners", "on_new_game")
	main.call("_save_game")
	_has_save = true


# ------------------------------------------------------------ UI

func _build() -> void:
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Kit.direction()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	if _fade.get_parent() == self:
		move_child(_fade, -1)
	if _settings and _settings.get_parent() == self:
		move_child(_settings, -1)
		move_child(_fade, -1)

	# Letterbox bars give the fly-over a film look.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -52.0
		bar.offset_bottom = 52.0 if top else 0.0
		_root.add_child(bar)

	# Soft dark gradient behind the menu column (right side in Hebrew).
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.78))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	if Loc.is_rtl():
		gt.fill_from = Vector2(1, 0)
		gt.fill_to = Vector2(0, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.layout_direction = Control.LAYOUT_DIRECTION_LTR    # anchors below are absolute
	shade.anchor_left = 0.45 if Loc.is_rtl() else 0.0
	shade.anchor_right = 1.0 if Loc.is_rtl() else 0.55
	_root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	_root.add_child(margin)
	var cols := HBoxContainer.new()     # first child sits on the right in RTL
	margin.add_child(cols)

	_menu_box = VBoxContainer.new()
	_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_theme_constant_override("separation", 14)
	_menu_box.custom_minimum_size.x = 560
	cols.add_child(_menu_box)
	var title := Kit.label(Loc.t("game_title"), 76, Color(1, 1, 1), Kit.start_align())
	title.add_theme_constant_override("outline_size", 12)
	_menu_box.add_child(title)
	var sub := Kit.label(Loc.t("game_tagline"), 30, Kit.ACCENT, Kit.start_align())
	_menu_box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	_menu_box.add_child(gap)
	var first: Button = null
	if _has_save:
		first = Kit.button(Loc.t("continue"), func(): _go(false), true)
		_menu_box.add_child(first)
	var ng := Kit.button(Loc.t("new_game"), _on_new_game, not _has_save)
	_menu_box.add_child(ng)
	if first == null:
		first = ng
	_menu_box.add_child(Kit.button(Loc.t("settings"), func(): _settings.visible = true))
	_menu_box.add_child(Kit.button(Loc.t("credits"), func(): _show_page("credits")))
	if not OS.has_feature("web"):
		_menu_box.add_child(Kit.button(Loc.t("quit_game"), func():
			main.call("_save_game")
			get_tree().quit()))
	for b in _menu_box.get_children():
		if b is Button:
			(b as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(spacer)

	var ver := Kit.label("v%s" % ProjectSettings.get_setting("application/config/version"), 20, Color(1, 1, 1, 0.45))
	ver.anchor_left = 0.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -46
	ver.offset_bottom = -14
	_root.add_child(ver)

	_credits = _build_credits()
	_root.add_child(_credits)
	_confirm = _build_confirm()
	_root.add_child(_confirm)
	if not Input.get_connected_joypads().is_empty():
		first.call_deferred("grab_focus")


func _build_credits() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	var p := Kit.panel(0.92)
	p.custom_minimum_size = Vector2(1180, 760)
	c.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	box.add_child(Kit.label(Loc.t("credits"), 48, Kit.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	for k in ["cr_textures", "cr_models", "cr_sky", "cr_people", "cr_font", "cr_icu", "cr_audio", "cr_code", "cr_engine"]:
		var head := Kit.label(Loc.t(k), 28, Color(1, 1, 1), Kit.start_align())
		list.add_child(head)
		var body := Kit.label(Loc.t(k + "_d"), 22, Color(1, 1, 1, 0.7), Kit.start_align())
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 1000
		list.add_child(body)
	var back := Kit.button(Loc.t("back"), func(): _show_page("menu"), true, 320)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return c


func _build_confirm() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	var p := Kit.panel(0.94)
	c.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	p.add_child(box)
	box.add_child(Kit.label(Loc.t("new_game_q"), 40, Kit.ACCENT))
	var l := Kit.label(Loc.t("new_game_warn"), 26, Color(1, 1, 1, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 700
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	row.add_child(Kit.button(Loc.t("new_game_yes"), func(): _go(true), true, 320))
	row.add_child(Kit.button(Loc.t("back"), func(): _show_page("menu"), false, 260))
	return c


func _show_page(page: String) -> void:
	if _menu_box == null:
		return
	_menu_box.visible = page == "menu"
	_credits.visible = page == "credits"
	_confirm.visible = page == "confirm"


func _on_new_game() -> void:
	if _has_save:
		_show_page("confirm")
	else:
		_go(true)


func _go(new_game: bool) -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func(): start_game(new_game))
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


# ------------------------------------------------------------ cinematic camera

func _process(delta: float) -> void:
	if not active:
		return
	GameInput.menu_open = true       # keep the player still behind the menu
	_time += delta
	_shot_t += delta
	if _shot_t >= SHOT_LEN:
		_shot_t = 0.0
		_shot = (_shot + 1) % 3
	# Dip to black between shots.
	var edge := minf(_shot_t, SHOT_LEN - _shot_t)
	if not _fade_busy() and not _leaving:
		_fade.color.a = clampf(1.0 - edge / FADE, 0.0, 1.0)
	_place_camera(_shot_t / SHOT_LEN)


func _fade_busy() -> bool:
	return _time < 1.3


func _place_camera(k: float) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	var world: Node = main.world if main else null
	var pitch := 106.0
	if world and "PITCH" in world:
		pitch = float(world.get("PITCH"))
	var pos: Vector3
	var look: Vector3
	match _shot:
		0:
			# High, slow orbit around downtown.
			var centre := Vector3(pitch, 0, -pitch)
			var a := 0.6 + k * 0.5
			pos = centre + Vector3(cos(a) * 170.0, 78.0 - k * 10.0, sin(a) * 170.0)
			look = centre + Vector3(0, 18, 0)
		1:
			# Low glide down an avenue between the blocks.
			var x := pitch * 0.5
			pos = Vector3(x + 2.0, 9.0 + sin(k * PI) * 3.0, lerpf(190.0, -60.0, k))
			look = pos + Vector3(-0.15, -0.12, -1.0) * 40.0
		_:
			# Crane rising over the park toward the skyline.
			pos = Vector3(-30.0 + k * 20.0, lerpf(6.0, 48.0, k), 70.0 - k * 18.0)
			look = Vector3(pitch * 0.6, 10.0 + k * 10.0, -pitch * 0.8)
	_cam.global_position = pos
	if not pos.is_equal_approx(look):
		_cam.look_at(look, Vector3.UP)

extends CanvasLayer
## Photo mode: the world freezes, the HUD disappears and a free camera flies around
## with the same two thumbs as the game (left half = move, right half = look).
## The small bar on top of the screen corner exits, changes the lens and saves a photo.

signal exited

const MOVE_SPEED := 6.0
const LOOK_DEG_PER_PX := 0.12
const MAX_RADIUS := 80.0

var main: Node
var active := false
## Depth of field (focus on what is under the centre); used by world/env/cinematic.gd.
var dof := true

var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _bar: HBoxContainer
var _hint: Label
var _fov_label: Label
var _move_finger := -1
var _move_origin := Vector2.ZERO
var _move := Vector2.ZERO
var _look_finger := -1
var _was_paused := false
var _hud_was_visible := true
var _ui_hidden := false
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	name = "PhotoMode"
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Loc.register({"he": {"photo_dof": "עומק שדה"}, "en": {"photo_dof": "Depth of field"}})
	Loc.language_changed.connect(_build)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	add_child(root)
	# Bar in the top corner where the menu button lives (away from both thumbs).
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 12)
	# Top-left preset: the RTL root mirrors it to the top-right corner in Hebrew.
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_bar.offset_left = 24
	_bar.offset_top = 20
	root.add_child(_bar)
	_bar.add_child(_btn(Loc.t("photo_exit"), exit))
	_bar.add_child(_btn(Loc.t("photo_wide"), func(): _zoom(8.0)))
	_bar.add_child(_btn(Loc.t("photo_tele"), func(): _zoom(-8.0)))
	_bar.add_child(_btn(Loc.t("photo_take"), take_photo))
	var dof_btn := _btn(Loc.t("photo_dof"), func(): dof = not dof)
	dof_btn.toggle_mode = true
	dof_btn.button_pressed = dof
	_bar.add_child(dof_btn)
	_bar.add_child(_btn(Loc.t("photo_hide_ui"), func(): _set_ui_hidden(true)))
	_fov_label = Label.new()
	_fov_label.add_theme_font_size_override("font_size", 24)
	_fov_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fov_label.add_theme_constant_override("outline_size", 6)
	_fov_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_child(_fov_label)
	_hint = Label.new()
	_hint.text = Loc.t("photo_hint")
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -64
	_hint.offset_bottom = -24
	_hint.offset_left = -700
	_hint.offset_right = 700
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.text_direction = Control.TEXT_DIRECTION_RTL if Loc.is_rtl() else Control.TEXT_DIRECTION_LTR
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = -40
	_toast.offset_bottom = 40
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	root.add_child(_toast)
	_update_fov_label()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func enter() -> void:
	if active or main == null:
		return
	var src := get_viewport().get_camera_3d()
	if src == null:
		return
	active = true
	visible = true
	_set_ui_hidden(false)
	_was_paused = get_tree().paused
	get_tree().paused = true
	GameInput.menu_open = true
	GameInput.reset_touch()
	if main.hud:
		_hud_was_visible = main.hud.visible
		main.hud.visible = false
	for n in ["DamageFeedback"]:
		var m: Node = main.get_node_or_null(n)
		if m is CanvasLayer:
			(m as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_cam.fov = src.fov
	_cam.near = 0.05
	_cam.far = src.far
	main.add_child(_cam)
	_cam.global_transform = src.global_transform
	var e := src.global_basis.get_euler()
	_pitch = rad_to_deg(e.x)
	_yaw = rad_to_deg(e.y)
	_cam.current = true
	_update_fov_label()


func exit() -> void:
	if not active:
		return
	active = false
	visible = false
	if _cam:
		_cam.queue_free()
		_cam = null
	if main.player and main.player.rig:
		main.player.rig.camera.current = true
	if main.hud:
		main.hud.visible = _hud_was_visible
	var m: Node = main.get_node_or_null("DamageFeedback")
	if m is CanvasLayer:
		(m as CanvasLayer).visible = true
	get_tree().paused = _was_paused
	GameInput.menu_open = _was_paused
	GameInput.reset_touch()
	exited.emit()


func _zoom(d: float) -> void:
	if _cam:
		_cam.fov = clampf(_cam.fov + d, 20.0, 100.0)
	_update_fov_label()


func _update_fov_label() -> void:
	if _fov_label:
		var mm := 18.0 / tan(deg_to_rad((_cam.fov if _cam else 72.0) * 0.5))
		_fov_label.text = "%d mm" % roundi(mm)


func _set_ui_hidden(h: bool) -> void:
	_ui_hidden = h
	if _bar:
		_bar.visible = not h
		_hint.text = Loc.t("photo_tap_show") if h else Loc.t("photo_hint")


func take_photo() -> void:
	if _cam == null:
		return
	var ambience: Node = main.get_node_or_null("Ambience")
	_bar.visible = false
	_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_bar.visible = not _ui_hidden
	_hint.visible = true
	DirAccess.make_dir_recursive_absolute("user://photos")
	var dt := Time.get_datetime_dict_from_system()
	var path := "user://photos/photo_%04d%02d%02d_%02d%02d%02d.png" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
	var ok := img.save_png(path) == OK
	if ambience and ambience.has_method("play_ui"):
		ambience.play_ui("photo_shutter")
	_show_toast(Loc.t("photo_saved") if ok else Loc.t("photo_failed"))


func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 1.8


# ------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if _ui_hidden:
				_set_ui_hidden(false)
				get_viewport().set_input_as_handled()
				return
			if _bar.visible and _bar.get_global_rect().grow(8).has_point(p):
				return            # the bar buttons handle it
			if p.x < get_viewport().get_visible_rect().size.x * 0.5:
				if _move_finger == -1:
					_move_finger = event.index
					_move_origin = p
					_move = Vector2.ZERO
			elif _look_finger == -1:
				_look_finger = event.index
		else:
			if event.index == _move_finger:
				_move_finger = -1
				_move = Vector2.ZERO
			if event.index == _look_finger:
				_look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == _move_finger:
			var r := 110.0 * get_viewport().get_visible_rect().size.y / 1080.0
			_move = ((event.position - _move_origin) / r).limit_length(1.0)
		elif event.index == _look_finger:
			_look(event.relative * LOOK_DEG_PER_PX * (1080.0 / get_viewport().get_visible_rect().size.y))
	elif event.is_action_pressed("menu"):
		exit()
		get_viewport().set_input_as_handled()


func _look(deg: Vector2) -> void:
	_yaw -= deg.x
	_pitch = clampf(_pitch - deg.y, -85.0, 85.0)


func _process(delta: float) -> void:
	if not active:
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0
	# Back button / menu pulses close photo mode instead of opening the menu.
	if GameInput.consume("menu"):
		exit()
		return
	GameInput.menu_open = true
	if _cam == null:
		return
	var pad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.15)
	if pad_look != Vector2.ZERO:
		_look(pad_look * 120.0 * delta)
	var mv := _move
	var keys := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.15)
	if keys.length() > mv.length():
		mv = keys
	_cam.rotation_degrees = Vector3(_pitch, _yaw, 0)
	if mv.length() > 0.02:
		var b := _cam.global_basis
		var speed := MOVE_SPEED * (2.5 if Input.is_action_pressed("sprint") else 1.0)
		var p := _cam.global_position + (b.x * mv.x + (-b.z) * -mv.y) * speed * delta
		# Stay near the player and above the ground.
		var centre: Vector3 = main.player.global_position + Vector3(0, 1.5, 0)
		var off := p - centre
		if off.length() > MAX_RADIUS:
			p = centre + off.normalized() * MAX_RADIUS
		p.y = maxf(p.y, 0.4)
		_cam.global_position = p

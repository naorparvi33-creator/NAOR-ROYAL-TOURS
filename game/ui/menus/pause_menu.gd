extends CanvasLayer
## Pause menu. The existing menu button / Android back / Esc still go through hud.gd;
## when the HUD opens its settings screen we show this menu first instead:
##   Resume · Settings (the existing settings screen) · Photo mode · Main menu · Quit.

const Kit := preload("res://ui/menus/menu_kit.gd")

var main: Node
var photo: Node             # photo_mode.gd
var title: Node             # title_screen.gd
var _root: Control
var _settings_open := false
var _guard := false


func _ready() -> void:
	name = "PauseMenu"
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Loc.language_changed.connect(_build)
	_build()
	if main and main.hud and main.hud.menu:
		main.hud.menu.visibility_changed.connect(_on_settings_visibility)


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Kit.direction()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := Kit.panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(Kit.label(Loc.t("paused"), 52, Kit.ACCENT))
	var sub := Kit.label(Loc.t("paused_sub"), 24, Color(1, 1, 1, 0.6))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	box.add_child(gap)
	var resume := Kit.button(Loc.t("resume"), _resume, true)
	box.add_child(resume)
	box.add_child(Kit.button(Loc.t("settings"), _open_settings))
	box.add_child(Kit.button(Loc.t("photo_mode"), _photo))
	box.add_child(Kit.button(Loc.t("main_menu"), _main_menu))
	if not OS.has_feature("web"):
		box.add_child(Kit.button(Loc.t("quit_game"), _quit))
	_root.visibility_changed.connect(func():
		if _root.is_visible_in_tree() and not Input.get_connected_joypads().is_empty():
			resume.grab_focus())


## hud.gd shows its settings screen when the menu is requested; we intercept that.
## hud.open_menu() pauses the tree right after showing the screen, so the decision is
## made at the end of the frame (still before anything is drawn).
func _on_settings_visibility() -> void:
	if _guard or main == null:
		return
	var menu: Control = main.hud.menu
	if not menu.visible:
		_settings_open = false
		return
	if _settings_open:
		return                 # opened from our "Settings" button
	_intercept.call_deferred()


func _intercept() -> void:
	var menu: Control = main.hud.menu
	if not menu.visible or _settings_open:
		return
	_guard = true
	menu.visible = false
	if title and title.get("active"):
		main.hud.close_menu()      # nothing to pause on the title screen
	elif photo and photo.get("active"):
		main.hud.close_menu()
		photo.exit()
	elif visible:
		_resume()                  # menu pressed again while paused = resume
	else:
		visible = true
		var amb: Node = main.get_node_or_null("Ambience")
		if amb:
			amb.play_ui("ui_open", -6.0)
	_guard = false


func _resume() -> void:
	visible = false
	main.hud.close_menu()


func _open_settings() -> void:
	visible = false
	_settings_open = true
	main.hud.menu.visible = true


func _photo() -> void:
	visible = false
	main.hud.close_menu()
	if photo:
		photo.enter()


func _main_menu() -> void:
	visible = false
	main.call("_save_game")
	main.hud.close_menu()
	if title:
		title.show_title()


func _quit() -> void:
	main.call("_save_game")
	get_tree().quit()


func _process(_delta: float) -> void:
	# Keep the pause flag in sync if something else closed the HUD menu.
	if visible and not get_tree().paused:
		visible = false

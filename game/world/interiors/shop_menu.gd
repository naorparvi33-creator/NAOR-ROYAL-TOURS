extends CanvasLayer
## Simple touch menu for shops and home: a title, the player's money, big buttons
## (one per item, right-to-left in Hebrew) and a large close button.
## The game pauses while it is open. Items come from a provider callable so the list
## refreshes after every purchase:
##   provider() -> Array of {text, sub, price (-1 = no price), enabled, action: Callable}
## An action may return true to close the menu.

signal closed

var player: Node

var _panel: PanelContainer
var _title: Label
var _money: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _close: Button
var _provider: Callable
var _note: Label
var _note_t := 0.0
var _was_paused := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.06
	_panel.anchor_bottom = 0.94
	_panel.offset_left = -520
	_panel.offset_right = 520
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.075, 0.09, 0.94)
	sb.border_color = Color(1.0, 0.78, 0.35, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 38)
	_money.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	head.add_child(_money)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 26)
	_note.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 34)
	v.add_child(_note)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	_close = _make_button(Color(0.55, 0.16, 0.14))
	_close.custom_minimum_size = Vector2(0, 100)
	_close.pressed.connect(close)
	v.add_child(_close)


func is_open() -> bool:
	return visible


func open(title: String, provider: Callable) -> void:
	_provider = provider
	_title.text = title
	_note.text = ""
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	GameInput.menu_open = true
	GameInput.reset_touch()
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	GameInput.menu_open = false
	GameInput.reset_touch()
	closed.emit()


## Short message under the title (e.g. "not enough money").
func note(text: String) -> void:
	_note.text = text
	_note_t = 2.5


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var rtl := Loc.is_rtl()
	_panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	_close.text = Loc.t("int_close")
	if player:
		_money.text = "$%d" % int(player.money)
	var items: Array = _provider.call() if _provider.is_valid() else []
	for it in items:
		var on: bool = it.get("enabled", true)
		var btn := _make_button(Color(0.16, 0.2, 0.26) if on else Color(0.13, 0.13, 0.14))
		btn.custom_minimum_size = Vector2(0, 104)
		btn.disabled = not on
		var price: int = int(it.get("price", -1))
		var sub: String = str(it.get("sub", ""))
		var t: String = str(it.get("text", ""))
		if price > 0:
			t += "   ·   $%d" % price
		if sub != "":
			t += "\n" + sub
		btn.text = t
		btn.add_theme_font_size_override("font_size", 30 if sub == "" else 27)
		var act: Callable = it.get("action", Callable())
		btn.pressed.connect(func():
			if not act.is_valid():
				return
			var r: Variant = act.call()
			if r is bool and r:
				close()
			elif visible:
				refresh())
		_list.add_child(btn)


func _make_button(col: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var c := col
		if state == "pressed":
			c = col.lightened(0.25)
		elif state == "hover":
			c = col.lightened(0.08)
		sb.bg_color = c
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		if state == "disabled":
			sb.bg_color = Color(c.r, c.g, c.b, 0.7)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	return b


func _process(delta: float) -> void:
	if not visible:
		return
	# Keep the game held while open (the settings menu can open and close on top).
	var hud: Variant = player.get_parent().get("hud") if player and player.get_parent() else null
	var settings_open := false
	if hud != null and hud.get("menu") != null:
		settings_open = (hud.menu as Control).visible
	if not settings_open:
		get_tree().paused = true
		GameInput.menu_open = true
	if GameInput.consume("context"):
		close()
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			_note.text = ""
	if player:
		_money.text = "$%d" % int(player.money)

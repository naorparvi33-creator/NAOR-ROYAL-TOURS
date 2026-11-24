extends Control
## Scope view drawn in code: black tube vignette (shader), fine reticle with posts,
## holdover marks for 100/200/300... m computed from the rifle's ballistics table and
## the current field of view (so they stay correct at 4x, 8x and 12x), horizontal lead
## marks every 2 mrad, rangefinder, breath and ammo arcs, hit marker and the zoom chip.
## Also draws the bullet-cam letterbox, the teleport fade and a small ammo line when
## the sniper is carried but not scoped.
##
## Touch: the zoom chip (left side) cycles the magnification; keeping the left thumb
## still anywhere else on the left half while scoped holds the breath.

var sniper: Node            # sniper.gd
var fade := 0.0
var left_hold := false      # left thumb held still (hold breath)

var _vig: ColorRect
var _vig_mat: ShaderMaterial
var _font: Font
var _left_finger := -1
var _left_start := Vector2.ZERO
var _hit := 0.0
var _hit_kill := false
var _hit_text := ""
var _hit_text_t := 0.0
var _time := 0.0

const AMBER := Color(1.0, 0.62, 0.15)
const RET := Color(0.02, 0.02, 0.02, 0.95)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_vig = ColorRect.new()
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.show_behind_parent = true
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = preload("res://weapons/sniper/scope_vignette.gdshader")
	_vig.material = _vig_mat
	_vig.visible = false
	add_child(_vig)


func flash_hit(kill: bool, text: String) -> void:
	_hit = 1.0
	_hit_kill = kill
	if text != "":
		_hit_text = text
		_hit_text_t = 1.6


func scope_center() -> Vector2:
	return size * 0.5 + (sniper.scope_shift as Vector2)


func scope_radius() -> float:
	return size.y * 0.47


func zoom_chip_rect() -> Rect2:
	var r := 58.0 * size.y / 1080.0
	var c := Vector2(size.x * 0.075, size.y * 0.42)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


func _input(event: InputEvent) -> void:
	if sniper == null or not sniper.scoped or GameInput.menu_open:
		if _left_finger != -1 and event is InputEventScreenTouch and not event.pressed and event.index == _left_finger:
			_left_finger = -1
		left_hold = false
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if zoom_chip_rect().grow(16.0).has_point(event.position):
				sniper.cycle_zoom()
				get_viewport().set_input_as_handled()
				return
			if event.position.x < size.x * 0.45 and _left_finger == -1:
				_left_finger = event.index
				_left_start = event.position
		elif event.index == _left_finger:
			_left_finger = -1
	elif event is InputEventScreenDrag and event.index == _left_finger:
		if event.position.distance_to(_left_start) > size.y * 0.06:
			_left_start = Vector2(INF, INF)     # the thumb started walking: no breath hold
	left_hold = _left_finger != -1 and _left_start.x < INF


func _process(delta: float) -> void:
	_time += delta
	var rd := delta / maxf(Engine.time_scale, 0.01)     # real time (bullet cam slows the game)
	_hit = maxf(_hit - rd * 2.2, 0.0)
	_hit_text_t = maxf(_hit_text_t - rd, 0.0)
	if sniper == null:
		return
	var show_scope: bool = sniper.scope_open > 0.001 and not sniper.bullet_cam_active
	_vig.visible = show_scope
	if show_scope:
		_vig_mat.set_shader_parameter("rect_size", size)
		_vig_mat.set_shader_parameter("center", scope_center())
		_vig_mat.set_shader_parameter("radius", scope_radius())
		_vig_mat.set_shader_parameter("edge", size.y * 0.02)
		_vig_mat.set_shader_parameter("open", sniper.scope_open)
	queue_redraw()


func _draw() -> void:
	if sniper == null:
		return
	if sniper.bullet_cam_active:
		_draw_bullet_cam()
	elif sniper.scope_open > 0.001:
		_draw_scope()
	elif sniper.equipped and not GameInput.menu_open:
		_draw_carry_info()
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))


func _px_per_rad() -> float:
	var half := deg_to_rad(float(sniper.fov_deg)) * 0.5
	return (size.y * 0.5) / tan(half)


func _draw_scope() -> void:
	var c := scope_center()
	var r := scope_radius() * lerpf(0.35, 1.0, float(sniper.scope_open))
	var k := size.y / 1080.0
	var thin := maxf(1.2, 1.6 * k)
	var post := maxf(4.0, 7.0 * k)
	var inner := r * 0.34
	# Heavy posts (left, right, top) guide the eye to the fine centre.
	draw_line(c + Vector2(-r, 0), c + Vector2(-inner, 0), RET, post)
	draw_line(c + Vector2(r, 0), c + Vector2(inner, 0), RET, post)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -inner), RET, post)
	# Fine crosshair.
	var gap := 3.0 * k
	draw_line(c + Vector2(-inner, 0), c + Vector2(-gap, 0), RET, thin)
	draw_line(c + Vector2(inner, 0), c + Vector2(gap, 0), RET, thin)
	draw_line(c + Vector2(0, -inner), c + Vector2(0, -gap), RET, thin)
	draw_line(c + Vector2(0, gap), c + Vector2(0, r * 0.92), RET, thin)
	draw_circle(c, maxf(1.3, 1.6 * k), Color(0.9, 0.1, 0.05, 0.95))
	var ppr := _px_per_rad()
	# Lead / spacing hashes every 2 mrad on the horizontal line.
	var m := 2
	while true:
		var x := tan(m * 0.001) * ppr
		if x > inner - 4.0:
			break
		var h := (7.0 if m % 10 == 0 else 4.0) * k
		draw_line(c + Vector2(x, -h), c + Vector2(x, h), RET, thin)
		draw_line(c + Vector2(-x, -h), c + Vector2(-x, h), RET, thin)
		m += 2
	# Holdover ladder: one mark per 100 m below the zero (100 m = centre).
	var tbl: Dictionary = sniper.table
	var ds: Array = tbl.get("d", [])
	var angs: Array = tbl.get("angle", [])
	var last_y := 0.0
	var last_label_y := -1000.0
	var fs := int(maxf(13.0, 17.0 * k))
	for i in ds.size():
		var d := float(ds[i])
		if d <= 100.5:
			continue
		var y := tan(float(angs[i])) * ppr
		if y > r * 0.9:
			break
		if y - last_y < 3.0 * k:
			continue
		last_y = y
		var big := int(d) % 500 == 0
		var w := (16.0 if big else 9.0) * k
		draw_line(c + Vector2(-w, y), c + Vector2(w, y), RET, thin * (1.4 if big else 1.0))
		if y - last_label_y >= fs * 0.95:
			last_label_y = y
			draw_string(_font, c + Vector2(w + 4.0 * k, y + fs * 0.36), str(int(d / 100.0)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RET)
	_draw_range(c, r, k)
	_draw_breath(c, r, k)
	_draw_ammo(c, r, k)
	_draw_hitmarker(c, k)
	_draw_zoom_chip(k)


func _draw_range(c: Vector2, r: float, k: float) -> void:
	var fs := int(maxf(16.0, 24.0 * k))
	var p := c + Vector2(r * 0.42, r * 0.3)
	var rng: float = sniper.range_m
	var txt := "---- m" if rng < 0.0 else "%d m" % roundi(rng)
	draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AMBER)
	if rng > 0.0:
		var hold: float = sniper.holdover_mark_for(rng)
		draw_string(_font, p + Vector2(0, fs * 1.1), "+%.1f mrad" % hold,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.75), Color(AMBER, 0.85))
	var zs := "%dx" % roundi(float(sniper.zoom))
	draw_string(_font, c + Vector2(-r * 0.62, -r * 0.24), zs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AMBER)
	if sniper.last_shot_text != "":
		draw_string(_font, c + Vector2(r * 0.42, -r * 0.24), sniper.last_shot_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.8), Color(1, 1, 1, 0.9))


func _draw_breath(c: Vector2, r: float, k: float) -> void:
	var a0 := deg_to_rad(118.0)
	var a1 := deg_to_rad(162.0)
	var rr := r - 16.0 * k
	draw_arc(c, rr, a0, a1, 24, Color(1, 1, 1, 0.18), 6.0 * k, true)
	var b: float = sniper.breath
	var col := Color(0.55, 0.85, 1.0, 0.9)
	if sniper.exhausted:
		col = Color(1.0, 0.3, 0.2, 0.9 if fmod(_time, 0.5) < 0.3 else 0.4)
	elif sniper.holding_breath:
		col = Color(0.4, 1.0, 0.6, 0.95)
	if b > 0.01:
		draw_arc(c, rr, a1 - (a1 - a0) * b, a1, 24, col, 6.0 * k, true)
	var fs := int(maxf(13.0, 16.0 * k))
	var lp := c + Vector2(cos(a1), sin(a1)) * (rr - 26.0 * k)
	var label := Loc.t("snp_breath_hold") if sniper.holding_breath else Loc.t("snp_breath")
	draw_string(_font, lp + Vector2(10.0 * k, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.85))


func _draw_ammo(c: Vector2, r: float, k: float) -> void:
	var mag: int = sniper.mag_size
	var ammo: int = sniper.ammo
	var rr := r - 16.0 * k
	for i in mag:
		var a := deg_to_rad(62.0 - i * 6.0)
		var p := c + Vector2(cos(a), sin(a)) * rr
		var col := AMBER if i < ammo else Color(1, 1, 1, 0.2)
		draw_circle(p, 4.5 * k, col)
	var fs := int(maxf(13.0, 17.0 * k))
	var pa := c + Vector2(cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0))) * (rr - 30.0 * k)
	if sniper.reload_k < 1.0:
		draw_string(_font, pa, Loc.t("snp_reloading"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AMBER)
	elif sniper.bolt_k < 1.0:
		draw_arc(pa + Vector2(10 * k, -6 * k), 9.0 * k, -PI * 0.5, -PI * 0.5 + TAU * float(sniper.bolt_k), 20, AMBER, 3.0 * k, true)


func _draw_hitmarker(c: Vector2, k: float) -> void:
	if _hit <= 0.0 and _hit_text_t <= 0.0:
		return
	if _hit > 0.0:
		var col := Color(1.0, 0.2, 0.15, _hit) if _hit_kill else Color(1, 1, 1, _hit)
		var a := 12.0 * k
		var b := 28.0 * k
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * a, c + s * b, Color(0, 0, 0, col.a * 0.6), 5.0 * k)
			draw_line(c + s * a, c + s * b, col, 2.6 * k)
	if _hit_text_t > 0.0:
		var fs := int(maxf(18.0, 30.0 * k))
		var col2 := Color(1.0, 0.85, 0.3, minf(_hit_text_t * 2.0, 1.0))
		draw_string_outline(_font, c + Vector2(-200 * k, -70 * k), _hit_text, HORIZONTAL_ALIGNMENT_CENTER, 400 * k, fs, 6, Color(0, 0, 0, col2.a))
		draw_string(_font, c + Vector2(-200 * k, -70 * k), _hit_text, HORIZONTAL_ALIGNMENT_CENTER, 400 * k, fs, col2)


func _draw_zoom_chip(k: float) -> void:
	var rect := zoom_chip_rect()
	var c := rect.get_center()
	var r := rect.size.x * 0.5
	draw_circle(c, r, Color(0.1, 0.12, 0.14, 0.55))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.8), 3.0 * k, true)
	var fs := int(maxf(16.0, 30.0 * k))
	draw_string(_font, Vector2(c.x - r, c.y + fs * 0.1), "%dx" % roundi(float(sniper.zoom)), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
	draw_string(_font, Vector2(c.x - r, c.y + fs * 0.85), Loc.t("snp_zoom"), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(fs * 0.55), Color(1, 1, 1, 0.8))
	if sniper.show_hint:
		var hs := int(maxf(14.0, 20.0 * k))
		var hp := Vector2(size.x * 0.02, size.y * 0.58)
		for i in 2:
			var line := Loc.t("snp_hint_breath") if i == 0 else Loc.t("snp_hint_cancel")
			draw_string_outline(_font, hp + Vector2(0, i * hs * 1.3), line, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.3, hs, 5, Color.BLACK)
			draw_string(_font, hp + Vector2(0, i * hs * 1.3), line, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.3, hs, Color(1, 1, 1, 0.85))


func _draw_carry_info() -> void:
	var k := size.y / 1080.0
	var fs := int(maxf(16.0, 26.0 * k))
	var txt := "%d/%d   %dx" % [sniper.ammo, sniper.mag_size, roundi(float(sniper.zoom))]
	if sniper.reload_k < 1.0:
		txt = Loc.t("snp_reloading")
	var p := Vector2(size.x * 0.5 - 200 * k, size.y - 112.0 * k)   # above the reserve ammo line (world/interiors)
	draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 400 * k, fs, 6, Color.BLACK)
	draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 400 * k, fs, AMBER)
	_draw_hitmarker(size * 0.5, k)


func _draw_bullet_cam() -> void:
	var bar := size.y * 0.09
	draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK)
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color.BLACK)
	var k := size.y / 1080.0
	var fs := int(maxf(16.0, 26.0 * k))
	var txt := "%d m   %.2f s" % [roundi(float(sniper.cam_distance)), float(sniper.cam_time)]
	draw_string(_font, Vector2(size.x * 0.06, size.y - bar * 0.38), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AMBER)
	draw_string(_font, Vector2(size.x * 0.55, bar * 0.62), Loc.t("snp_skip"), HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.4, int(fs * 0.8), Color(1, 1, 1, 0.7))
	_draw_hitmarker(size * 0.5, k)

extends Control
## Gameplay HUD: health bar, money, mission objective and timer, a waypoint arrow at
## the screen edge, speedometer while driving, mission result banner and the
## "badly hurt" screen. Drawn in code; everything stays clear of the thumb zones.

var player: Node3D
var missions: Node3D

var _objective := ""
var _timer := -1.0
var _banner := ""
var _banner_sub := ""
var _banner_t := 0.0
var _banner_good := true
var _wasted_t := 0.0
var _money_shown := 0.0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	missions.objective_changed.connect(func(t): _objective = t)
	missions.timer_changed.connect(func(s): _timer = s)
	missions.mission_result.connect(func(passed, title, reward):
		_banner = Loc.t("mission_passed") if passed else Loc.t("mission_failed")
		_banner_sub = title + ("   +$%d" % reward if passed else "")
		_banner_good = passed
		_banner_t = 4.0)
	player.died.connect(func():
		_wasted_t = 3.5)
	_money_shown = player.money


func _process(delta: float) -> void:
	_banner_t = maxf(_banner_t - delta, 0.0)
	if _wasted_t > 0.0:
		_wasted_t -= delta
		if _wasted_t <= 0.0:
			player.respawn_after_death()
	_money_shown = move_toward(_money_shown, float(player.money), maxf(absf(player.money - _money_shown) * delta * 3.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var s := size
	var white := Color(1, 1, 1, 0.95)
	var shadow := Color(0, 0, 0, 0.6)

	# Health bar and money (top-left, under the FPS line).
	var hb := Rect2(110, 46, 260, 14)
	draw_rect(hb.grow(2), Color(0, 0, 0, 0.45))
	var hp: float = clampf(player.health / 100.0, 0.0, 1.0)
	var hcol := Color(0.3, 0.85, 0.35).lerp(Color(0.9, 0.2, 0.15), 1.0 - hp)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp, hb.size.y)), hcol)
	_text("$%d" % int(_money_shown), Vector2(390, 60), 30, Color(0.55, 1.0, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 300)

	# Mission objective + timer (top centre: text only, no buttons there).
	if _objective != "":
		var w := minf(s.x * 0.55, 1100.0)
		var r := Rect2(s.x * 0.5 - w * 0.5, 18, w, 54)
		draw_rect(r, Color(0, 0, 0, 0.45))
		_text(_objective, Vector2(r.position.x + 16, r.position.y + 37), 26, white, HORIZONTAL_ALIGNMENT_CENTER, w - 32)
	if _timer >= 0.0:
		var tc := Color(1, 0.35, 0.3) if _timer < 15.0 else white
		_text("%d:%02d" % [int(_timer) / 60, int(_timer) % 60], Vector2(s.x * 0.5 - 100, 112), 38, tc, HORIZONTAL_ALIGNMENT_CENTER, 200)

	# Waypoint arrow / marker.
	var wp: Variant = missions.waypoint()
	if wp != null:
		_draw_waypoint(wp)

	# Speedometer while driving.
	if player.in_vehicle:
		var kmh := int(player.vehicle.speed_kmh())
		_text("%d" % kmh, Vector2(s.x * 0.5 - 120, s.y - 112), 64, white, HORIZONTAL_ALIGNMENT_CENTER, 240)
		_text(Loc.t("kmh"), Vector2(s.x * 0.5 - 120, s.y - 78), 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 240)

	# Mission result banner.
	if _banner_t > 0.0:
		var a := minf(_banner_t, 1.0)
		var col := Color(1.0, 0.82, 0.25, a) if _banner_good else Color(1.0, 0.35, 0.3, a)
		draw_rect(Rect2(0, s.y * 0.3, s.x, 150), Color(0, 0, 0, 0.45 * a))
		_text(_banner, Vector2(0, s.y * 0.3 + 75), 64, col, HORIZONTAL_ALIGNMENT_CENTER, s.x)
		_text(_banner_sub, Vector2(0, s.y * 0.3 + 125), 32, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	# Badly hurt: red fade, then wake up at the hospital.
	if _wasted_t > 0.0:
		var k := clampf((3.5 - _wasted_t) / 1.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.0, 0.0, 0.55 * k))
		_text(Loc.t("wasted"), Vector2(0, s.y * 0.5), 52, Color(1, 0.85, 0.8, k), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif player.health < 35.0:
		# Low health: red vignette pulse.
		var p := 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, 24)), Color(0.8, 0, 0, p))
		draw_rect(Rect2(Vector2(0, s.y - 24), Vector2(s.x, 24)), Color(0.8, 0, 0, p))


func _draw_waypoint(world: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var s := size
	var pos := world + Vector3(0, 1.5, 0)
	var dist := player.global_position.distance_to(world)
	var behind := cam.is_position_behind(pos)
	var sp := cam.unproject_position(pos)
	var center := s * 0.5
	var margin := 90.0
	var onscreen := not behind and sp.x > margin and sp.x < s.x - margin and sp.y > margin and sp.y < s.y - margin
	var col := Color(1.0, 0.85, 0.2, 0.95)
	if onscreen:
		draw_circle(sp, 10.0, col)
		draw_arc(sp, 16.0, 0.0, TAU, 24, col, 3.0, true)
		_text("%d מ'" % int(dist), sp + Vector2(-60, -24), 24, col, HORIZONTAL_ALIGNMENT_CENTER, 120)
		return
	var dir := (sp - center)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	# Clamp to an ellipse inside the screen edge.
	var edge := center + Vector2(dir.x * (s.x * 0.5 - margin), dir.y * (s.y * 0.5 - margin))
	var ang := dir.angle()
	var pts := PackedVector2Array([
		edge + Vector2(28, 0).rotated(ang),
		edge + Vector2(-14, 16).rotated(ang),
		edge + Vector2(-14, -16).rotated(ang)])
	draw_colored_polygon(pts, col)
	_text("%d מ'" % int(dist), edge - dir * 46 + Vector2(-60, 8), 22, col, HORIZONTAL_ALIGNMENT_CENTER, 120)


func _text(t: String, pos: Vector2, fs: int, col: Color, align: HorizontalAlignment, width: float) -> void:
	draw_string_outline(_font, pos, t, align, width, fs, 6, Color(0, 0, 0, col.a * 0.8))
	draw_string(_font, pos, t, align, width, fs, col)

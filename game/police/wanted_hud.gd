extends Control
## Wanted stars, small, in the top-right corner (away from the thumbs and the
## top-centre). Filled stars glow; they blink while the police are searching, and
## pulse when the level goes up. A thin red/blue flicker at the top corners tells
## that a police car with lights is right behind you.

var police: Node

var _font: Font
var _shown := 0.0         # fades the whole row in and out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	var stars: int = police.stars
	_shown = move_toward(_shown, 1.0 if stars > 0 else 0.0, delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if _shown <= 0.0:
		return
	var s := size
	var stars: int = police.stars
	var t := Time.get_ticks_msec() * 0.001
	var searching: bool = police.searching
	var blink := 1.0
	if searching:
		blink = 0.3 if fmod(t, 0.7) < 0.3 else 1.0
	var pulse: float = police.star_flash
	var r := 17.0
	var gap := 42.0
	var y := 50.0
	for i in 5:
		# Rightmost star is the first one.
		var c := Vector2(s.x - 48.0 - i * gap, y)
		var filled := i < stars
		var rr := r * (1.0 + 0.35 * pulse * pulse if filled and i == stars - 1 else 1.0)
		var pts := _star(c, rr)
		var outline := pts.duplicate()
		outline.append(pts[0])
		if filled:
			draw_colored_polygon(_star(c + Vector2(2, 2), rr), Color(0, 0, 0, 0.45 * _shown * blink))
			draw_colored_polygon(pts, Color(1.0, 0.9, 0.5, _shown * blink))
			draw_polyline(outline, Color(0.25, 0.15, 0.0, 0.9 * _shown * blink), 2.0, true)
		else:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.28 * _shown))
			draw_polyline(outline, Color(1, 1, 1, 0.25 * _shown), 1.5, true)
	if searching and stars > 0:
		var txt := "%s  %d" % [Loc.t("police_searching"), ceili(maxf(float(police.search_left), 0.0))]
		var w := 330.0
		var pos := Vector2(s.x - 28.0 - w, y + 46.0)
		draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, w, 22, 5, Color(0, 0, 0, 0.7 * _shown))
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, w, 22, Color(1, 1, 1, 0.85 * _shown * blink))

	# Lights of a police car close behind: soft red / blue glow in the top corners.
	var near := _nearest_lit_car()
	if near < 22.0:
		var k := clampf(1.0 - near / 22.0, 0.0, 1.0) * 0.22
		var red := fmod(t, 0.8) < 0.4
		var col := Color(1, 0.1, 0.05, k) if red else Color(0.1, 0.3, 1.0, k)
		var x := 0.0 if red else s.x - 260.0
		draw_rect(Rect2(x, 0, 260, 10), col)


func _nearest_lit_car() -> float:
	var best := INF
	var pp: Vector3 = police.player.global_position
	for c in get_tree().get_nodes_in_group("police_car"):
		if c.ai and c.health > 0.0:
			best = minf(best, (c as Node3D).global_position.distance_to(pp))
	return best


func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rad := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts

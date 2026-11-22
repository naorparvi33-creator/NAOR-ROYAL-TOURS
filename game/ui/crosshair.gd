extends Control
## Center crosshair that opens up while moving or firing, plus a hit marker.

var player: CharacterBody3D
var _spread := 0.0
var _hit := 0.0
var _hit_target := false
var _gap := 8.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hit(is_target: bool) -> void:
	_hit = 1.0
	_hit_target = is_target


func kick() -> void:
	_spread = minf(_spread + 6.0, 26.0)


func _process(delta: float) -> void:
	var base := 6.0
	if player:
		var v := Vector2(player.velocity.x, player.velocity.z).length()
		base += v * 2.0
		if player.aiming:
			base *= 0.5
	_spread = lerpf(_spread, 0.0, 1.0 - exp(-8.0 * delta))
	_hit = maxf(_hit - delta * 3.5, 0.0)
	_gap = base + _spread
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var gap := _gap
	var col := Color(1, 1, 1, 0.9)
	var line_len := 12.0
	var w := 2.5
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + line_len, 0), col, w)
	draw_line(c - Vector2(gap, 0), c - Vector2(gap + line_len, 0), col, w)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + line_len), col, w)
	draw_line(c - Vector2(0, gap), c - Vector2(0, gap + line_len), col, w)
	draw_circle(c, 2.0, col)
	if _hit > 0.0 and _hit_target:
		var hc := Color(1.0, 0.3, 0.2, _hit)
		var a := 10.0
		var b := 22.0
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * a, c + s * b, hc, 3.5)

extends RefCounted
## Map icons shared by the minimap, the full map and its legend. All vector drawing,
## so they stay sharp at any size and need no textures.

const COL_GIVER := Color(1.0, 0.8, 0.2)
const COL_OBJECTIVE := Color(1.0, 0.86, 0.25)
const COL_TARGET := Color(1.0, 0.25, 0.2)
const COL_ITEM := Color(0.4, 0.95, 0.45)
const COL_CHECK := Color(0.35, 0.9, 1.0)
const COL_SHOP := Color(1.0, 0.6, 0.25)
const COL_CAR := Color(0.85, 0.87, 0.9)
const COL_POLICE_A := Color(0.25, 0.45, 1.0)
const COL_POLICE_B := Color(1.0, 0.2, 0.2)
const COL_CUSTOM := Color(0.85, 0.4, 1.0)
const COL_ROUTE := Color(0.72, 0.42, 1.0)
const COL_PLAYER := Color(1, 1, 1)
const COL_HOSPITAL := Color(1.0, 0.35, 0.4)

## Icon kinds in legend order (loc key = "map_lg_" + kind).
const LEGEND := ["player", "objective", "giver", "target", "item", "checkpoint", "custom", "shop", "car", "police", "hospital", "route"]


static func draw(ci: CanvasItem, font: Font, kind: String, p: Vector2, s: float, t: float, extra := "") -> void:
	var outline := Color(0, 0, 0, 0.75)
	match kind:
		"player":
			draw_arrow(ci, p, -PI * 0.5, s * 1.2)
		"giver":
			ci.draw_circle(p, s + 2.0, outline)
			ci.draw_circle(p, s, COL_GIVER)
			_glyph(ci, font, "!", p, s, Color(0.15, 0.1, 0.0))
		"objective":
			var pulse := fmod(t * 1.2, 1.0)
			ci.draw_arc(p, s * (1.0 + pulse * 1.3), 0.0, TAU, 28, Color(COL_OBJECTIVE, 0.8 * (1.0 - pulse)), 2.5, true)
			ci.draw_circle(p, s + 2.0, outline)
			ci.draw_circle(p, s, COL_OBJECTIVE)
			ci.draw_circle(p, s * 0.42, Color(0.2, 0.15, 0.0))
		"target":
			var pts := PackedVector2Array([p + Vector2(0, -s * 1.25), p + Vector2(s * 1.25, 0), p + Vector2(0, s * 1.25), p + Vector2(-s * 1.25, 0)])
			var big := PackedVector2Array([p + Vector2(0, -s * 1.25 - 2.5), p + Vector2(s * 1.25 + 2.5, 0), p + Vector2(0, s * 1.25 + 2.5), p + Vector2(-s * 1.25 - 2.5, 0)])
			ci.draw_colored_polygon(big, outline)
			ci.draw_colored_polygon(pts, COL_TARGET)
			ci.draw_circle(p, s * 0.3, Color(0.3, 0, 0))
		"item":
			ci.draw_circle(p, s * 0.85 + 2.0, outline)
			ci.draw_circle(p, s * 0.85, COL_ITEM)
			_glyph(ci, font, "$", p, s * 0.85, Color(0.05, 0.2, 0.05))
		"checkpoint":
			ci.draw_circle(p, s + 2.0, outline)
			ci.draw_arc(p, s * 0.8, 0.0, TAU, 24, COL_CHECK, s * 0.4, true)
			if extra != "":
				_glyph(ci, font, extra, p, s * 0.75, Color.WHITE)
		"custom":
			# Map pin.
			var tip := p
			var head := p + Vector2(0, -s * 1.6)
			ci.draw_colored_polygon(PackedVector2Array([tip, head + Vector2(-s * 0.75, s * 0.35), head + Vector2(s * 0.75, s * 0.35)]), outline)
			ci.draw_circle(head, s + 2.0, outline)
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -2), head + Vector2(-s * 0.65, s * 0.4), head + Vector2(s * 0.65, s * 0.4)]), COL_CUSTOM)
			ci.draw_circle(head, s, COL_CUSTOM)
			ci.draw_circle(head, s * 0.4, Color.WHITE)
		"shop":
			var r := Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0)
			ci.draw_rect(r.grow(2.0), outline)
			ci.draw_rect(r, COL_SHOP)
			# Basket.
			var w := s * 0.12 + 1.0
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.62, -s * 0.1), p + Vector2(s * 0.62, -s * 0.1),
				p + Vector2(s * 0.42, s * 0.6), p + Vector2(-s * 0.42, s * 0.6)]), Color(0.25, 0.1, 0.0))
			ci.draw_arc(p + Vector2(0, -s * 0.1), s * 0.38, PI, TAU, 10, Color(0.25, 0.1, 0.0), w)
		"car":
			var r := Rect2(p - Vector2(s * 0.45, s * 0.75), Vector2(s * 0.9, s * 1.5))
			ci.draw_rect(r.grow(1.5), outline)
			ci.draw_rect(r, COL_CAR)
		"police":
			var on := fmod(t * 3.0, 1.0) < 0.5
			ci.draw_circle(p, s * 0.8 + 2.0, outline)
			ci.draw_circle(p, s * 0.8, COL_POLICE_A if on else COL_POLICE_B)
		"hospital":
			var r := Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0)
			ci.draw_rect(r.grow(2.0), outline)
			ci.draw_rect(r, Color.WHITE)
			ci.draw_rect(Rect2(p - Vector2(s * 0.22, s * 0.7), Vector2(s * 0.44, s * 1.4)), COL_HOSPITAL)
			ci.draw_rect(Rect2(p - Vector2(s * 0.7, s * 0.22), Vector2(s * 1.4, s * 0.44)), COL_HOSPITAL)
		"route":
			ci.draw_line(p - Vector2(s * 1.3, 0), p + Vector2(s * 1.3, 0), outline, s * 0.8)
			ci.draw_line(p - Vector2(s * 1.2, 0), p + Vector2(s * 1.2, 0), COL_ROUTE, s * 0.5)


## Player arrow pointing at `angle` (screen radians, 0 = right).
static func draw_arrow(ci: CanvasItem, p: Vector2, angle: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(s, 0), Vector2(-s * 0.7, s * 0.65), Vector2(-s * 0.35, 0), Vector2(-s * 0.7, -s * 0.65)])
	var big := PackedVector2Array()
	var inner := PackedVector2Array()
	for q in pts:
		big.append(p + (q * 1.25 + Vector2(-s * 0.08, 0)).rotated(angle))
		inner.append(p + q.rotated(angle))
	ci.draw_colored_polygon(big, Color(0, 0, 0, 0.8))
	ci.draw_colored_polygon(inner, COL_PLAYER)


static func _glyph(ci: CanvasItem, font: Font, g: String, p: Vector2, s: float, col: Color) -> void:
	var fs := int(maxf(s * 1.45, 10.0))
	ci.draw_string(font, Vector2(p.x - s * 2.0, p.y + fs * 0.36), g, HORIZONTAL_ALIGNMENT_CENTER, s * 4.0, fs, col)

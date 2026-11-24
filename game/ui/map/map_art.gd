extends Node2D
## The static part of the map, drawn ONCE in world units (1 unit = 1 metre, x -> x, z -> y).
## The minimap and the full map only move / rotate / scale this node every frame, so the
## draw commands stay cached and nothing is rebuilt while playing.

const COL_OUTSIDE := Color(0.13, 0.16, 0.14)
const COL_ROAD := Color(0.2, 0.21, 0.23)
const COL_WALK := Color(0.52, 0.52, 0.5)
const COL_OUTER := Color(0.27, 0.27, 0.3)
const COL_GRASS := Color(0.27, 0.5, 0.27)
const COL_PATH := Color(0.62, 0.58, 0.48)
const COL_DASH := Color(0.85, 0.78, 0.4, 0.8)
const COL_ZEBRA := Color(0.9, 0.9, 0.9, 0.55)
const COL_LOW := Color(0.8, 0.76, 0.7)
const COL_HIGH := Color(0.5, 0.56, 0.7)
const COL_SHOP := Color(0.9, 0.62, 0.35)

var pitch := 106.0
var road_w := 16.0
var block := 90.0
var walk_w := 4.0
var rings := 2
## [{pos: Vector3, size: Vector3}] building footprints.
var buildings: Array = []
## [{pos: Vector2, name: String}]
var shops: Array = []


func _draw() -> void:
	var outer_edge := pitch * (rings + 1.5)
	draw_rect(Rect2(-outer_edge * 1.6, -outer_edge * 1.6, outer_edge * 3.2, outer_edge * 3.2), COL_OUTSIDE)
	var city_edge := pitch * (rings + 0.5) + road_w * 0.5
	draw_rect(Rect2(-city_edge, -city_edge, city_edge * 2.0, city_edge * 2.0), COL_ROAD)
	var half := block * 0.5
	for i in range(-rings - 1, rings + 2):
		for j in range(-rings - 1, rings + 2):
			var c := Vector2(i * pitch, j * pitch)
			var outer := absi(i) > rings or absi(j) > rings
			var r := Rect2(c - Vector2(half, half), Vector2(block, block))
			if outer:
				draw_rect(r, COL_OUTER)
				draw_rect(r.grow(-walk_w), COL_OUTER.darkened(0.25))
				continue
			draw_rect(r, COL_WALK)
			if i == 0 and j == 0:
				_draw_park(c, half)
	# Building footprints, darker / bluer when taller.
	for b in buildings:
		var p: Vector3 = b["pos"]
		var s: Vector3 = b["size"]
		var k := clampf((s.y - 8.0) / 50.0, 0.0, 1.0)
		var col := COL_LOW.lerp(COL_HIGH, k)
		var r := Rect2(p.x - s.x * 0.5, p.z - s.z * 0.5, s.x, s.z)
		draw_rect(r, col)
		draw_rect(r.grow(-1.6), col.lightened(0.08))
		draw_rect(r, col.darkened(0.35), false, 0.8)
	for sh in shops:
		var sp: Vector2 = sh["pos"]
		var r := Rect2(sp - Vector2(7, 5.5), Vector2(14, 11))
		draw_rect(r, COL_SHOP)
		draw_rect(r, COL_SHOP.darkened(0.4), false, 0.8)
	_draw_markings(city_edge)


func _draw_park(c: Vector2, half: float) -> void:
	var inner := half - walk_w
	draw_rect(Rect2(c - Vector2(inner, inner), Vector2(inner * 2.0, inner * 2.0)), COL_GRASS)
	# Lighter patches and paths so the park reads at a glance.
	draw_circle(c + Vector2(-18, 14), 12.0, COL_GRASS.lightened(0.08))
	draw_circle(c + Vector2(20, -16), 9.0, COL_GRASS.darkened(0.12))
	draw_line(c + Vector2(-inner, 0), c + Vector2(inner, 0), COL_PATH, 2.5)
	draw_line(c + Vector2(0, -inner), c + Vector2(0, inner), COL_PATH, 2.5)
	draw_arc(c, 16.0, 0.0, TAU, 40, COL_PATH, 2.5)


func _draw_markings(city_edge: float) -> void:
	var dashes := PackedVector2Array()
	var zebra := PackedVector2Array()
	var lo := -city_edge
	var hi := city_edge
	var roads: Array[float] = []
	for k in range(-rings - 1, rings + 1):
		roads.append((k + 0.5) * pitch)
	for rc in roads:
		var t := lo
		while t < hi - 4.0:
			# No centre dashes inside the intersections.
			var inside := false
			for other in roads:
				if absf(t + 2.0 - other) < road_w * 0.5 + 1.0:
					inside = true
					break
			if not inside:
				dashes.append(Vector2(rc, t))
				dashes.append(Vector2(rc, t + 4.0))
				dashes.append(Vector2(t, rc))
				dashes.append(Vector2(t + 4.0, rc))
			t += 9.0
	# Zebra crossings on the four arms of every intersection.
	var hw := road_w * 0.5
	for x in roads:
		for z in roads:
			var o := Vector2(x, z)
			for s in [-1.0, 1.0]:
				var k := -hw + 1.2
				while k < hw - 1.0:
					var a := o + Vector2(k, s * (hw + 1.2))
					zebra.append(a)
					zebra.append(a + Vector2(0, s * 2.6))
					var b := o + Vector2(s * (hw + 1.2), k)
					zebra.append(b)
					zebra.append(b + Vector2(s * 2.6, 0))
					k += 1.8
	if dashes.size() > 1:
		draw_multiline(dashes, COL_DASH, 0.7)
	if zebra.size() > 1:
		draw_multiline(zebra, COL_ZEBRA, 0.9)

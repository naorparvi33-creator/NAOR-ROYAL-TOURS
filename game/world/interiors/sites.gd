extends RefCounted
## Geometry and furnishing of every enterable building. Each build_* function works in
## the site's local frame (see carver.gd), carves the building, furnishes the rooms and
## returns the spots the module turns into interactions:
##   {"use": {name: [local position, label key]}, "clerks": [[pos, rot, model]], "spawn": pos, ...}

const Kit := preload("res://world/interiors/kit.gd")
const T := 0.3
const H0 := 4.2
const DOOR_H := 2.5

var cv: Variant           # carver
var kit: Variant          # kit for the current site
var root: Node3D


func _start(c: Variant, r: Node3D) -> void:
	cv = c
	root = r
	kit = Kit.new(r)


## Room shell inside a cell: floor, plaster lining on the side and back walls, ceiling.
func _room(x0: float, x1: float, z1: float, floor_mat: Material, wall := Color(0.96, 0.94, 0.9), h := H0, lining_sides := true) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var dz := z1 - T
	kit.box(floor_mat, Vector3(cx, 0.015, T + dz * 0.5), Vector3(w, 0.03, dz))
	var pl: Material = Kit.mat("plaster", wall)
	kit.box(pl, Vector3(cx, h * 0.5, z1 - 0.02), Vector3(w, h, 0.04))
	if lining_sides:
		kit.box(pl, Vector3(x0 + 0.02, h * 0.5, T + dz * 0.5), Vector3(0.04, h, dz))
		kit.box(pl, Vector3(x1 - 0.02, h * 0.5, T + dz * 0.5), Vector3(0.04, h, dz))
	kit.box(Kit.mat("plaster", Color(0.98, 0.98, 0.97)), Vector3(cx, h - 0.02, T + dz * 0.5), Vector3(w, 0.04, dz))
	# Skirting board.
	var sk: Material = Kit.mat("wood", Color(0.35, 0.28, 0.22))
	kit.box(sk, Vector3(cx, 0.06, z1 - 0.05), Vector3(w, 0.1, 0.02))


## Awning over a shop front (fabric strip with a valance).
func _awning(x0: float, x1: float, col: Color) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.05, 1.5)
	mi.mesh = bm
	mi.material_override = Kit.mat("fabric", col)
	mi.transform = Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(cx, 3.35, -0.7))
	mi.visibility_range_end = 150.0
	root.add_child(mi)
	var v := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(w, 0.3, 0.04)
	v.mesh = vm
	v.material_override = Kit.mat("fabric", col.darkened(0.15))
	v.position = Vector3(cx, 3.0, -1.42)
	v.visibility_range_end = 150.0
	root.add_child(v)


## Facade sign board with text (readable from the street).
func _board(text: String, cx: float, y: float, w: float, bg: Color, fg: Color, font := 120, glow := false) -> void:
	var bm: Material = Kit.mat("glow" if glow else "plastic", bg)
	kit.box(bm, Vector3(cx, y, -0.08), Vector3(w, 0.9, 0.12))
	kit.box(Kit.mat("metal", Color(0.2, 0.2, 0.2)), Vector3(cx, y, -0.02), Vector3(w + 0.1, 1.0, 0.04))
	kit.sign(text, Vector3(cx, y, -0.15), PI, font, fg, Color(0, 0, 0, 0.55))


## Big floating marker above an entrance so the place can be found from a distance.
func _marker(text: String, pos: Vector3, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.018
	l.outline_size = 16
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	l.visibility_range_begin = 14.0
	l.visibility_range_end = 260.0
	l.no_depth_test = false
	root.add_child(l)
	return l


# ------------------------------------------------------------------ safehouse

## Ground-floor apartment with a garage next to it. width 18.
func build_safehouse(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 9.0
	var gx0 := cx - 9.0
	var gx1 := gx0 + 6.4
	var ax0 := gx1 + 0.4
	var ax1 := cx + 9.0
	cv.fill([{"x0": gx0, "x1": gx1, "z1": depth, "y0": 0.0, "y1": H0}, {"x0": ax0, "x1": ax1, "z1": depth, "y0": 0.0, "y1": H0}])
	# Garage front: wide door opening.
	var gc := (gx0 + gx1) * 0.5
	cv.front_wall(gx0, gx1, 0.0, H0, [{"x0": gc - 1.9, "x1": gc + 1.9, "y0": 0.0, "y1": 3.0}])
	# Apartment front: door and a big window.
	var door_x := ax0 + 2.0
	var win0 := ax0 + 4.2
	cv.front_wall(ax0, ax1, 0.0, H0, [
		{"x0": door_x - 0.6, "x1": door_x + 0.6, "y0": 0.0, "y1": DOOR_H},
		{"x0": win0, "x1": win0 + 3.4, "y0": 0.9, "y1": 2.8, "glass": true},
		{"x0": ax1 - 2.6, "x1": ax1 - 1.0, "y0": 1.0, "y1": 2.8, "glass": true}])

	# --- garage
	var conc: Material = Kit.mat("concrete", Color(0.62, 0.62, 0.6))
	kit.box(conc, Vector3(gc, 0.015, T + (depth - T) * 0.5), Vector3(6.4, 0.03, depth - T))
	var gwall: Material = Kit.mat("plaster", Color(0.78, 0.78, 0.76))
	kit.box(gwall, Vector3(gc, H0 - 0.02, T + (depth - T) * 0.5), Vector3(6.4, 0.04, depth - T))
	kit.box(gwall, Vector3(gx0 + 0.02, H0 * 0.5, T + (depth - T) * 0.5), Vector3(0.04, H0, depth - T))
	kit.box(gwall, Vector3(gx1 - 0.02, H0 * 0.5, T + (depth - T) * 0.5), Vector3(0.04, H0, depth - T))
	kit.box(gwall, Vector3(gc, H0 * 0.5, depth - 0.02), Vector3(6.4, H0, 0.04))
	kit.box(Kit.mat("plastic", Color(0.85, 0.65, 0.1)), Vector3(gc, 0.033, 1.2), Vector3(3.4, 0.004, 0.12))
	kit.box(Kit.mat("plastic", Color(0.05, 0.05, 0.05, 1)), Vector3(gc + 0.3, 0.032, 5.0), Vector3(1.2, 0.004, 0.8))
	kit.model("steel_frame_shelves_02", Vector3(gx0 + 0.45, 0.03, depth - 1.2), PI * 0.5, 1.0, Vector3(0.5, 2.1, 0.6))
	kit.model("steel_frame_shelves_02", Vector3(gx0 + 0.45, 0.03, depth - 2.0), PI * 0.5, 1.0, Vector3(0.5, 2.1, 0.6))
	kit.box(Kit.mat("wood", Color(0.3, 0.25, 0.2)), Vector3(gx1 - 0.05, 1.6, depth - 2.2), Vector3(0.04, 1.2, 2.4))
	kit.box(Kit.mat("wood", Color(0.5, 0.35, 0.25)), Vector3(gx1 - 0.5, 0.45, depth - 1.2), Vector3(0.9, 0.9, 1.8), true)
	kit.ceiling_panel(Vector3(gc, H0 - 0.05, 4.5), Vector2(1.6, 0.3))
	kit.light(Vector3(gc, 3.4, 4.8), Color(0.95, 0.93, 0.88), 1.2, 8.0)

	# --- apartment: living room / kitchen (front), bedroom behind a partition.
	_room(ax0, ax1, depth, Kit.mat("floor_wood", Color(0.86, 0.72, 0.56)), Color(0.95, 0.92, 0.86))
	var wall: Material = Kit.mat("plaster", Color(0.95, 0.92, 0.86))
	var pz := 5.4                                   # partition wall
	kit.box(wall, Vector3(ax0 + 2.6, H0 * 0.5, pz), Vector3(5.2, H0, 0.14), true)
	kit.box(wall, Vector3(ax1 - 2.0, H0 * 0.5, pz), Vector3(4.0, H0, 0.14), true)
	kit.box(wall, Vector3(ax0 + 6.1, (DOOR_H + H0) * 0.5, pz), Vector3(1.8, H0 - DOOR_H, 0.14))
	kit.box(Kit.mat("wood", Color(0.55, 0.4, 0.28)), Vector3(ax0 + 6.1, DOOR_H + 0.03, pz), Vector3(1.8, 0.06, 0.18))
	# Living room.
	kit.rug(Vector3(ax0 + 6.0, 0, 2.9), 3.2, 2.2, Color(0.55, 0.22, 0.18))
	kit.model("sofa_02", Vector3(ax0 + 6.0, 0.03, 4.4), PI, 1.15, Vector3(2.1, 0.8, 0.95))
	kit.model("side_table_01", Vector3(ax0 + 6.0, 0.03, 2.9), 0.0, 1.3, Vector3(0.7, 0.7, 0.6))
	kit.tv(Vector3(ax0 + 6.0, 0.0, 0.75), PI)
	kit.plant(Vector3(ax1 - 0.6, 0, 4.6))
	kit.frame(Vector3(ax1 - 0.06, 2.0, 3.0), 1.2, 0.8, PI * 0.5, Color(0.75, 0.5, 0.3))
	kit.kitchen(Vector3(ax0 + 0.36, 0, 2.6), 3.6, -PI * 0.5)
	kit.table(Vector3(ax0 + 2.6, 0, 3.5), 1.0, 1.0, 0.76, Color(0.75, 0.6, 0.45), true)
	kit.model("GreenChair_01", Vector3(ax0 + 2.6, 0.03, 4.35), PI, 0.85)
	kit.model("GreenChair_01", Vector3(ax0 + 2.6, 0.03, 2.65), 0.0, 0.85)
	kit.ceiling_panel(Vector3(ax0 + 5.5, H0 - 0.05, 2.8), Vector2(0.9, 0.9))
	kit.light(Vector3(ax0 + 5.5, 3.5, 2.8), Color(1.0, 0.84, 0.64), 1.6, 9.0)
	# Bedroom.
	kit.bed(Vector3(ax0 + 3.0, 0.0, depth - 1.15), 0.0, Color(0.22, 0.32, 0.5))
	for sx in [-1.25, 1.25]:
		kit.box(Kit.mat("wood", Color(0.5, 0.36, 0.25)), Vector3(ax0 + 3.0 + sx, 0.28, depth - 0.35), Vector3(0.5, 0.56, 0.45), true)
		kit.cyl(Kit.mat("glow", Color(1.0, 0.85, 0.6)), Vector3(ax0 + 3.0 + sx, 0.75, depth - 0.35), 0.1, 0.25, 10, 0.06)
	kit.wardrobe(Vector3(ax1 - 1.4, 0.0, depth - 0.36), 0.0)
	kit.rug(Vector3(ax0 + 3.0, 0, 6.5), 2.6, 1.2, Color(0.85, 0.8, 0.7))
	kit.frame(Vector3(ax0 + 3.0, 2.4, depth - 0.06), 1.6, 0.6, 0.0, Color(0.3, 0.45, 0.4))
	kit.light(Vector3(ax0 + 4.5, 3.4, 7.2), Color(1.0, 0.8, 0.6), 1.1, 7.0)
	kit.ceiling_panel(Vector3(ax0 + 4.5, H0 - 0.05, 7.2), Vector2(0.7, 0.7))
	# Outside: house number, small sign, door frame and a wall lamp.
	kit.box(Kit.mat("wood", Color(0.3, 0.2, 0.14)), Vector3(door_x, DOOR_H + 0.08, 0.15), Vector3(1.45, 0.16, T + 0.06))
	kit.sign("הבית שלך · 12", Vector3(door_x, DOOR_H + 0.45, -0.03), PI, 64, Color(1, 0.95, 0.8))
	kit.box(Kit.mat("glow", Color(1.0, 0.85, 0.55)), Vector3(door_x + 0.95, 2.3, -0.08), Vector3(0.16, 0.26, 0.12))
	kit.sign("חניה פרטית", Vector3(gc, 3.4, -0.03), PI, 64, Color(1, 1, 1))
	kit.commit()
	_marker("בית", Vector3(door_x, 6.0, -1.0), Color(0.5, 1.0, 0.55))
	return {
		"use": {
			"bed": [Vector3(ax0 + 3.0, 0.9, depth - 2.6), "ctx_sleep"],
			"wardrobe": [Vector3(ax1 - 1.4, 1.0, depth - 1.3), "ctx_wardrobe"],
			"garage": [Vector3(gc, 1.0, 0.0), "ctx_garage_open"],
		},
		"garage_door": Vector3(gc, 0.0, T * 0.5),
		"garage_box": AABB(Vector3(gx0 + 0.3, 0.0, T + 0.3), Vector3(gx1 - gx0 - 0.6, 3.0, depth - T - 0.6)),
		"garage_car": Vector3(gc, 0.3, 4.9),
		"door": Vector3(door_x, 0.2, 1.4),
		"clerks": [],
		"lot_clear": [gx0 - 1.0, ax1 + 1.0],
		"garage_lane": [gc - 3.5, gc + 3.5],
	}


# ------------------------------------------------------------------ gun shop

func build_gunshop(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 9.0
	var x0 := cx - 6.0
	var x1 := cx + 6.0
	cv.fill([{"x0": x0, "x1": x1, "z1": depth, "y0": 0.0, "y1": H0}])
	var door_x := cx + 0.5
	cv.front_wall(x0, x1, 0.0, H0, [
		{"x0": door_x - 0.8, "x1": door_x + 0.8, "y0": 0.0, "y1": DOOR_H},
		{"x0": x0 + 1.0, "x1": door_x - 1.4, "y0": 0.8, "y1": 2.7, "glass": true},
		{"x0": door_x + 1.4, "x1": x1 - 1.0, "y0": 0.8, "y1": 2.7, "glass": true}])
	# Security bars in the windows.
	var bar: Material = Kit.mat("metal", Color(0.1, 0.1, 0.1))
	for x in range(int(x0 + 1.2), int(x1 - 0.8)):
		if absf(float(x) + 0.0 - door_x) < 1.5:
			continue
		kit.box(bar, Vector3(float(x) + 0.0, 1.75, -0.06), Vector3(0.03, 1.9, 0.03))
	_room(x0, x1, depth, Kit.mat("tiles", Color(0.35, 0.36, 0.38)), Color(0.55, 0.5, 0.45))
	kit.display_counter(Vector3(cx - 1.0, 0, 5.0), 6.0, cv.glass_material(), 0.0)
	kit.register(Vector3(cx + 2.9, 1.0, 5.0), PI)
	kit.box(Kit.mat("wood", Color(0.18, 0.16, 0.15)), Vector3(cx + 2.9, 0.5, 5.0), Vector3(1.6, 1.0, 0.7), true)
	kit.gun_wall(Vector3(cx - 1.0, 0, depth - 0.1), 7.0, 0.0)
	kit.product_shelf(Vector3(x1 - 0.3, 0, 4.5), 3.6, PI * 0.5, 9,
		[Color(0.3, 0.35, 0.22), Color(0.45, 0.3, 0.15), Color(0.6, 0.15, 0.1), Color(0.2, 0.2, 0.2), Color(0.7, 0.6, 0.3)])
	kit.lockers(Vector3(x0 + 0.3, 0, 5.5), 4, -PI * 0.5, Color(0.25, 0.28, 0.22))
	kit.frame(Vector3(x0 + 0.06, 2.2, 2.4), 0.8, 1.0, -PI * 0.5, Color(0.95, 0.95, 0.9))
	kit.box(Kit.mat("plastic", Color(0.8, 0.1, 0.1)), Vector3(x0 + 0.085, 2.25, 2.4), Vector3(0.004, 0.36, 0.36))
	kit.box(Kit.mat("plastic", Color(0.95, 0.95, 0.9)), Vector3(x0 + 0.087, 2.25, 2.4), Vector3(0.004, 0.2, 0.2))
	kit.box(Kit.mat("plastic", Color(0.8, 0.1, 0.1)), Vector3(x0 + 0.089, 2.25, 2.4), Vector3(0.004, 0.08, 0.08))
	kit.light(Vector3(cx, 3.5, 4.5), Color(1.0, 0.86, 0.7), 1.6, 10.0)
	kit.ceiling_panel(Vector3(cx - 2.5, H0 - 0.05, 4.0), Vector2(1.4, 0.3))
	kit.ceiling_panel(Vector3(cx + 2.5, H0 - 0.05, 4.0), Vector2(1.4, 0.3))
	_board("נשק ותחמושת", cx, 3.55, 8.0, Color(0.1, 0.1, 0.1), Color(0.95, 0.25, 0.2), 120)
	kit.box(Kit.mat("glow", Color(1.0, 0.2, 0.15)), Vector3(door_x + 1.1, 2.75, -0.08), Vector3(0.9, 0.3, 0.06))
	kit.sign("פתוח", Vector3(door_x + 1.1, 2.75, -0.13), PI, 48, Color(1, 1, 1))
	kit.commit()
	_marker("נשק", Vector3(door_x, 6.2, -1.0), Color(1.0, 0.45, 0.35))
	return {
		"use": {"gunshop": [Vector3(cx - 1.0, 1.0, 3.8), "ctx_gunshop"]},
		"clerks": [[Vector3(cx - 1.0, 0.03, 6.2), 0.0, "ped_03"]],
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


# ------------------------------------------------------------------ clothing store

func build_clothes(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 10.0
	var x0 := cx - 7.0
	var x1 := cx + 7.0
	cv.fill([{"x0": x0, "x1": x1, "z1": depth, "y0": 0.0, "y1": H0}])
	var door_x := cx
	cv.front_wall(x0, x1, 0.0, H0, [
		{"x0": door_x - 0.9, "x1": door_x + 0.9, "y0": 0.0, "y1": 2.7},
		{"x0": x0 + 0.8, "x1": door_x - 1.2, "y0": 0.4, "y1": 3.1, "glass": true},
		{"x0": door_x + 1.2, "x1": x1 - 0.8, "y0": 0.4, "y1": 3.1, "glass": true}])
	_room(x0, x1, depth, Kit.mat("floor_wood", Color(0.95, 0.88, 0.78)), Color(0.98, 0.97, 0.95))
	# Shop window displays.
	kit.box(Kit.mat("wood", Color(0.9, 0.9, 0.88)), Vector3(cx - 4.0, 0.15, 1.0), Vector3(4.6, 0.3, 1.2), true)
	kit.box(Kit.mat("wood", Color(0.9, 0.9, 0.88)), Vector3(cx + 4.0, 0.15, 1.0), Vector3(4.6, 0.3, 1.2), true)
	kit.mannequin(Vector3(cx - 5.2, 0.3, 1.0), Color(0.75, 0.1, 0.12), Color(0.12, 0.12, 0.15))
	kit.mannequin(Vector3(cx - 2.8, 0.3, 1.0), Color(0.95, 0.95, 0.92), Color(0.3, 0.4, 0.62), 0.3)
	kit.mannequin(Vector3(cx + 2.8, 0.3, 1.0), Color(0.15, 0.3, 0.2), Color(0.55, 0.45, 0.3), -0.3)
	kit.mannequin(Vector3(cx + 5.2, 0.3, 1.0), Color(0.1, 0.1, 0.12), Color(0.1, 0.1, 0.12))
	# Racks, shelves, mirror, fitting rooms, counter.
	kit.clothes_rack(Vector3(cx - 3.5, 0, 4.2), 2.6, 0.0, 1)
	kit.clothes_rack(Vector3(cx - 3.5, 0, 6.0), 2.6, 0.0, 2)
	kit.clothes_rack(Vector3(cx + 0.6, 0, 4.4), 2.2, PI * 0.5, 3)
	kit.model("wooden_display_shelves_01", Vector3(x0 + 0.35, 0.03, 4.0), 0.0, 1.0, Vector3(0.4, 1.55, 1.1))
	kit.model("wooden_display_shelves_01", Vector3(x0 + 0.35, 0.03, 5.3), 0.0, 1.0, Vector3(0.4, 1.55, 1.1))
	kit.model("wooden_display_shelves_01", Vector3(x0 + 0.35, 0.03, 6.6), 0.0, 1.0, Vector3(0.4, 1.55, 1.1))
	kit.box(Kit.mat("metal", Color(0.85, 0.9, 0.95)), Vector3(cx - 1.2, 1.3, depth - 0.06), Vector3(1.0, 2.0, 0.02))
	kit.box(Kit.mat("wood", Color(0.3, 0.25, 0.2)), Vector3(cx - 1.2, 1.3, depth - 0.05), Vector3(1.1, 2.1, 0.01))
	for k in 2:
		var fx := x1 - 1.0 - k * 1.6
		kit.box(Kit.mat("wood", Color(0.85, 0.82, 0.78)), Vector3(fx - 0.78, 1.2, depth - 0.8), Vector3(0.05, 2.4, 1.5), true)
		kit.curtain(Vector3(fx, 0, depth - 1.55), 1.5, 0.0, Color(0.55, 0.15, 0.2))
	kit.counter(Vector3(cx + 3.6, 0, 6.6), 2.6, 0.0, Color(0.92, 0.9, 0.86), Color(0.25, 0.25, 0.26))
	kit.register(Vector3(cx + 4.2, 1.04, 6.6), PI)
	kit.plant(Vector3(x1 - 0.5, 0, 2.4))
	kit.light(Vector3(cx, 3.5, 4.5), Color(1.0, 0.92, 0.82), 1.7, 11.0)
	for px in [-4.0, 0.0, 4.0]:
		kit.ceiling_panel(Vector3(cx + px, H0 - 0.05, 4.5), Vector2(1.6, 0.3))
	_awning(x0 + 0.5, x1 - 0.5, Color(0.12, 0.12, 0.14))
	_board("אופנה עירונית", cx, 3.82, 7.0, Color(0.98, 0.98, 0.98), Color(0.1, 0.1, 0.1), 110)
	kit.commit()
	_marker("בגדים", Vector3(door_x, 6.4, -1.0), Color(0.6, 0.8, 1.0))
	return {
		"use": {"clothes": [Vector3(cx + 3.6, 1.0, 5.6), "ctx_clothes"]},
		"clerks": [[Vector3(cx + 3.6, 0.03, 7.5), 0.0, "ped_05"]],
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


# ------------------------------------------------------------------ restaurant

func build_restaurant(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 10.0
	var x0 := cx - 7.0
	var x1 := cx + 7.0
	cv.fill([{"x0": x0, "x1": x1, "z1": depth, "y0": 0.0, "y1": H0}])
	var door_x := cx - 3.5
	cv.front_wall(x0, x1, 0.0, H0, [
		{"x0": door_x - 0.8, "x1": door_x + 0.8, "y0": 0.0, "y1": DOOR_H},
		{"x0": door_x + 1.2, "x1": x1 - 0.8, "y0": 0.8, "y1": 2.9, "glass": true},
		{"x0": x0 + 0.6, "x1": door_x - 1.1, "y0": 0.8, "y1": 2.9, "glass": true}])
	_room(x0, x1, depth, Kit.mat("big_tiles", Color(0.82, 0.78, 0.7)), Color(0.98, 0.9, 0.78))
	# Counter and the kitchen behind it.
	var kz := 6.8
	kit.counter(Vector3(cx + 1.0, 0, kz), 9.0, 0.0, Color(0.75, 0.15, 0.12), Color(0.85, 0.85, 0.82))
	kit.register(Vector3(cx - 1.5, 1.04, kz), PI)
	kit.register(Vector3(cx + 2.5, 1.04, kz), PI)
	var steel: Material = Kit.mat("metal", Color(0.78, 0.79, 0.8))
	kit.box(steel, Vector3(cx + 1.0, 0.45, depth - 0.45), Vector3(9.0, 0.9, 0.8), true)
	kit.box(Kit.mat("plastic", Color(0.08, 0.08, 0.08)), Vector3(cx - 1.0, 0.92, depth - 0.45), Vector3(1.6, 0.04, 0.7))
	kit.box(Kit.mat("metal", Color(0.85, 0.55, 0.2)), Vector3(cx + 1.4, 0.86, depth - 0.45), Vector3(0.8, 0.06, 0.5))
	kit.box(steel, Vector3(cx - 1.0, 3.3, depth - 0.5), Vector3(2.2, 0.6, 0.9))
	kit.box(steel, Vector3(cx + 4.4, 0.95, depth - 0.45), Vector3(1.0, 1.9, 0.8), true)
	# Menu board above the counter.
	kit.box(Kit.mat("plastic", Color(0.08, 0.08, 0.09)), Vector3(cx + 2.4, 3.0, depth - 0.06), Vector3(3.6, 1.5, 0.06))
	kit.sign("תפריט", Vector3(cx + 2.4, 3.5, depth - 0.1), PI, 72, Color(1.0, 0.8, 0.3))
	kit.sign("פלאפל $15\nבורגר $25\nארוחה משפחתית $45", Vector3(cx + 2.4, 2.75, depth - 0.1), PI, 40, Color(1, 1, 1))
	# Seating.
	for i in 3:
		var tx := x0 + 1.8 + i * 3.0
		var tz := 3.2 if i != 0 else 4.0
		kit.table(Vector3(tx, 0, tz), 1.0, 1.0, 0.76, Color(0.9, 0.88, 0.85), true)
		kit.model("GreenChair_01", Vector3(tx, 0.03, tz + 0.85), PI, 0.85)
		kit.model("GreenChair_01", Vector3(tx, 0.03, tz - 0.85), 0.0, 0.85)
	kit.box(Kit.mat("fabric", Color(0.6, 0.1, 0.1)), Vector3(x1 - 0.45, 0.25, 3.0), Vector3(0.7, 0.5, 3.4), true)
	kit.box(Kit.mat("fabric", Color(0.6, 0.1, 0.1)), Vector3(x1 - 0.12, 0.8, 3.0), Vector3(0.2, 0.8, 3.4))
	kit.table(Vector3(x1 - 1.3, 0, 3.0), 0.8, 2.6, 0.74, Color(0.9, 0.88, 0.85))
	kit.light(Vector3(cx, 3.4, 4.5), Color(1.0, 0.82, 0.6), 1.8, 11.0)
	for px in [-4.5, -1.5, 1.5, 4.5]:
		kit.cyl(Kit.mat("glow", Color(1.0, 0.8, 0.5)), Vector3(cx + px, 3.6, 3.2), 0.22, 0.25, 12, 0.1)
		kit.cyl(Kit.mat("metal", Color(0.1, 0.1, 0.1)), Vector3(cx + px, 3.9, 3.2), 0.01, 0.6, 4)
	_awning(x0 + 0.5, x1 - 0.5, Color(0.75, 0.12, 0.1))
	_board("בורגר ופלאפל", cx, 3.85, 7.5, Color(1.0, 0.82, 0.25), Color(0.55, 0.05, 0.02), 120, true)
	kit.commit()
	_marker("אוכל", Vector3(door_x, 6.4, -1.0), Color(1.0, 0.8, 0.3))
	return {
		"use": {"food": [Vector3(cx - 1.5, 1.0, kz - 1.0), "ctx_food"]},
		"clerks": [[Vector3(cx - 1.5, 0.03, kz + 0.9), 0.0, "ped_02"], [Vector3(cx + 1.0, 0.03, depth - 1.3), 0.0, "ped_07"]],
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


# ------------------------------------------------------------------ hospital

func build_hospital(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 11.0
	var x0 := cx - 7.5
	var x1 := cx + 7.5
	cv.fill([{"x0": x0, "x1": x1, "z1": depth, "y0": 0.0, "y1": H0}])
	var door_x := cx
	cv.front_wall(x0, x1, 0.0, H0, [
		{"x0": door_x - 1.5, "x1": door_x + 1.5, "y0": 0.0, "y1": 2.8},
		{"x0": x0 + 0.8, "x1": door_x - 2.0, "y0": 0.8, "y1": 3.0, "glass": true},
		{"x0": door_x + 2.0, "x1": x1 - 0.8, "y0": 0.8, "y1": 3.0, "glass": true}])
	_room(x0, x1, depth, Kit.mat("big_tiles", Color(0.92, 0.93, 0.94)), Color(0.93, 0.96, 0.97))
	# Sliding glass doors (open) and an entrance canopy.
	var glass: Material = cv.glass_material()
	kit.box(glass, Vector3(door_x - 2.2, 1.4, 0.4), Vector3(1.5, 2.8, 0.04))
	kit.box(glass, Vector3(door_x + 2.2, 1.4, 0.4), Vector3(1.5, 2.8, 0.04))
	kit.box(Kit.mat("plaster", Color(0.95, 0.95, 0.95)), Vector3(door_x, 3.2, -1.4), Vector3(5.0, 0.25, 2.8))
	for sx in [-2.3, 2.3]:
		kit.cyl(Kit.mat("metal", Color(0.85, 0.85, 0.85)), Vector3(door_x + sx, 1.55, -2.6), 0.08, 3.1, 10)
	# Reception, waiting area, treatment beds.
	kit.counter(Vector3(cx + 2.5, 0, 5.2), 4.0, 0.0, Color(0.85, 0.88, 0.9), Color(0.3, 0.5, 0.6))
	kit.desk(Vector3(cx + 2.5, 0, 6.3), PI)
	for i in 4:
		kit.model("GreenChair_01", Vector3(x0 + 1.2 + i * 0.8, 0.03, 2.0), 0.0, 0.85)
	kit.plant(Vector3(x0 + 0.6, 0, 1.0))
	for k in 2:
		var bx := x0 + 1.6 + k * 2.6
		kit.hospital_bed(Vector3(bx, 0, depth - 1.3), 0.0)
		kit.curtain(Vector3(bx + 1.3, 0, depth - 1.3), 2.4, PI * 0.5, Color(0.55, 0.75, 0.78))
	kit.box(Kit.mat("metal", Color(0.8, 0.8, 0.82)), Vector3(x1 - 0.4, 0.9, depth - 1.0), Vector3(0.6, 1.8, 0.6), true)
	kit.box(Kit.mat("glow", Color(0.9, 0.15, 0.12)), Vector3(x1 - 0.06, 2.4, 3.0), Vector3(0.02, 0.6, 0.18))
	kit.box(Kit.mat("glow", Color(0.9, 0.15, 0.12)), Vector3(x1 - 0.06, 2.4, 3.0), Vector3(0.02, 0.18, 0.6))
	kit.light(Vector3(cx - 2.5, 3.5, 5.0), Color(0.92, 0.96, 1.0), 1.6, 10.0)
	kit.light(Vector3(cx + 3.0, 3.5, 5.0), Color(0.92, 0.96, 1.0), 1.4, 9.0)
	for px in [-5.0, -2.0, 1.0, 4.0]:
		kit.ceiling_panel(Vector3(cx + px, H0 - 0.05, 5.0), Vector2(1.2, 0.6))
	# Signs: white board with red letters and a glowing red cross; ER sign over the door.
	_board("בית חולים העיר", cx - 1.0, 4.75, 9.0, Color(0.98, 0.98, 0.98), Color(0.8, 0.05, 0.05), 120)
	var red: Material = Kit.mat("glow", Color(0.95, 0.08, 0.06))
	kit.box(red, Vector3(cx + 4.6, 4.75, -0.16), Vector3(0.75, 0.22, 0.06))
	kit.box(red, Vector3(cx + 4.6, 4.75, -0.16), Vector3(0.22, 0.75, 0.06))
	kit.sign("מיון · כניסה", Vector3(door_x, 3.0, -2.82), PI, 60, Color(1, 0.2, 0.15))
	kit.commit()
	_marker("בית חולים", Vector3(door_x, 6.6, -1.0), Color(1.0, 0.4, 0.4))
	return {
		"use": {"hospital": [Vector3(cx + 2.5, 1.0, 4.2), "ctx_hospital"]},
		"clerks": [[Vector3(cx + 2.5, 0.03, 7.0), 0.0, "ped_06"]],
		"spawn": Vector3(door_x, 0.3, -2.0),
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


# ------------------------------------------------------------------ police station

func build_police(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 11.0
	var x0 := cx - 7.5
	var x1 := cx + 7.5
	cv.fill([{"x0": x0, "x1": x1, "z1": depth, "y0": 0.0, "y1": H0}])
	var door_x := cx + 2.0
	cv.front_wall(x0, x1, 0.0, H0, [
		{"x0": door_x - 0.9, "x1": door_x + 0.9, "y0": 0.0, "y1": DOOR_H},
		{"x0": x0 + 1.0, "x1": x0 + 4.0, "y0": 1.0, "y1": 2.8, "glass": true},
		{"x0": x0 + 5.0, "x1": door_x - 1.4, "y0": 1.0, "y1": 2.8, "glass": true}])
	_room(x0, x1, depth, Kit.mat("tiles", Color(0.7, 0.72, 0.74)), Color(0.86, 0.9, 0.95))
	# Front desk with a glass screen.
	kit.counter(Vector3(cx - 1.0, 0, 5.5), 5.0, 0.0, Color(0.15, 0.22, 0.4), Color(0.75, 0.75, 0.75))
	kit.box(cv.glass_material(), Vector3(cx - 1.0, 1.55, 5.5), Vector3(5.0, 1.0, 0.03))
	kit.desk(Vector3(cx - 2.5, 0, 7.0), PI)
	kit.desk(Vector3(cx + 0.5, 0, 7.0), PI)
	kit.lockers(Vector3(x1 - 0.3, 0, 6.5), 5, PI * 0.5, Color(0.2, 0.28, 0.45))
	kit.lockers(Vector3(x0 + 0.3, 0, 8.0), 4, -PI * 0.5, Color(0.2, 0.28, 0.45))
	# Waiting bench and a wanted board with "posters" (plain coloured silhouettes, no photos).
	kit.box(Kit.mat("wood", Color(0.4, 0.3, 0.22)), Vector3(x0 + 2.5, 0.45, 1.2), Vector3(3.0, 0.08, 0.5), true)
	kit.box(Kit.mat("metal", Color(0.2, 0.2, 0.2)), Vector3(x0 + 2.5, 0.22, 1.2), Vector3(2.8, 0.44, 0.06))
	kit.box(Kit.mat("wood", Color(0.55, 0.4, 0.25)), Vector3(x0 + 0.06, 2.0, 3.5), Vector3(0.04, 1.2, 2.4))
	for k in 3:
		var pz2 := 2.75 + k * 0.75
		kit.frame(Vector3(x0 + 0.1, 2.0, pz2), 0.5, 0.7, -PI * 0.5, Color(0.85, 0.8, 0.65))
		kit.box(Kit.mat("plastic", Color(0.22, 0.22, 0.24)), Vector3(x0 + 0.124, 2.12, pz2), Vector3(0.004, 0.2, 0.16))
		kit.box(Kit.mat("plastic", Color(0.22, 0.22, 0.24)), Vector3(x0 + 0.124, 1.86, pz2), Vector3(0.004, 0.22, 0.36))
	kit.light(Vector3(cx, 3.5, 5.0), Color(0.9, 0.94, 1.0), 1.6, 11.0)
	for px in [-4.0, 0.0, 4.0]:
		kit.ceiling_panel(Vector3(cx + px, H0 - 0.05, 5.0), Vector2(1.6, 0.3))
	_board("תחנת משטרה", cx - 2.0, 3.75, 8.0, Color(0.08, 0.2, 0.55), Color(1, 1, 1), 120)
	kit.box(Kit.mat("glow", Color(0.2, 0.4, 1.0)), Vector3(door_x - 0.5, 2.85, -0.12), Vector3(0.5, 0.18, 0.18))
	kit.box(Kit.mat("glow", Color(1.0, 0.15, 0.15)), Vector3(door_x + 0.5, 2.85, -0.12), Vector3(0.5, 0.18, 0.18))
	kit.commit()
	_marker("משטרה", Vector3(door_x, 6.4, -1.0), Color(0.5, 0.7, 1.0))
	return {
		"use": {"police": [Vector3(cx - 1.0, 1.0, 4.4), "ctx_police"]},
		"clerks": [[Vector3(cx - 1.0, 0.03, 6.2), 0.0, "ped_04"]],
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


# ------------------------------------------------------------------ apartment tower

## Lobby with mailboxes and an elevator; a real stairwell goes up to the roof.
func build_tower(c: Variant, r: Node3D, cx: float) -> Dictionary:
	_start(c, r)
	var depth := 8.4
	var x0 := cx - 5.2
	var sx0 := cx + 0.8           # stair column
	var x1 := cx + 4.6
	var top: float = cv.top
	cv.fill([{"x0": x0, "x1": sx0, "z1": depth, "y0": 0.0, "y1": H0}, {"x0": sx0, "x1": x1, "z1": depth, "y0": 0.0, "y1": top + 5.0}])
	var door_x := cx - 2.0
	cv.front_wall(x0, sx0, 0.0, H0, [
		{"x0": door_x - 0.8, "x1": door_x + 0.8, "y0": 0.0, "y1": 2.6},
		{"x0": x0 + 0.6, "x1": door_x - 1.1, "y0": 0.6, "y1": 3.0, "glass": true}])
	cv.front_wall(sx0, x1, 0.0, H0, [{"x0": sx0 + 0.5, "x1": x1 - 0.5, "y0": 1.2, "y1": 3.0, "glass": true}])
	cv.front_wall(sx0, x1, H0, top, [], false)
	# Lobby.
	_room(x0, sx0, depth, Kit.mat("big_tiles", Color(0.85, 0.82, 0.76)), Color(0.92, 0.9, 0.86), H0, false)
	var pl: Material = Kit.mat("plaster", Color(0.92, 0.9, 0.86))
	kit.box(pl, Vector3(x0 + 0.02, H0 * 0.5, (T + depth) * 0.5), Vector3(0.04, H0, depth - T))
	kit.mailboxes(Vector3(x0 + 0.22, 0, 4.2), 6, 4, -PI * 0.5)
	kit.elevator(Vector3(cx - 2.2, 0, depth - 0.1), 0.0)
	kit.model("sofa_02", Vector3(cx - 0.2, 0.03, 1.4), 0.0, 1.0, Vector3(1.85, 0.75, 0.85))
	kit.plant(Vector3(x0 + 0.6, 0, 1.0))
	kit.plant(Vector3(x0 + 0.6, 0, depth - 0.8))
	kit.rug(Vector3(door_x, 0, 2.0), 1.6, 2.4, Color(0.3, 0.25, 0.4))
	kit.light(Vector3(cx - 2.0, 3.5, 4.2), Color(1.0, 0.86, 0.68), 1.5, 9.0)
	kit.ceiling_panel(Vector3(cx - 2.0, H0 - 0.05, 4.2), Vector2(0.8, 0.8))
	# Stairwell.
	var levels: Array[float] = [0.0]
	var y := H0
	while y < top - 0.1:
		levels.append(y)
		y += 3.3
	levels.append(top)
	_stairwell(sx0, x1, depth, levels)
	# Rooftop: elevator hut, sandbags for a sniping spot, a few crates.
	var hut_x0 := sx0 - 3.4
	var hut_x1 := sx0 - 1.0
	var hut_z := 3.2
	cv.facade_box(Vector3((hut_x0 + hut_x1) * 0.5, top + 1.35, hut_z), Vector3(hut_x1 - hut_x0, 2.7, 2.4), true)
	kit.elevator(Vector3(hut_x1 + 0.03, top, hut_z), -PI * 0.5)
	kit.sandbags(Vector3(x0 + 2.4, top, 0.75), 3.2, 0.0)
	kit.crate(Vector3(x0 + 0.9, top, 2.2), 0.8, 0.3)
	kit.crate(Vector3(x0 + 0.9, top + 0.8, 2.2), 0.6, 0.8)
	kit.box(Kit.mat("fabric", Color(0.3, 0.32, 0.25)), Vector3(x0 + 1.6, top + 0.04, 1.55), Vector3(1.0, 0.06, 1.6))
	kit.sign("גג · נקודת צליפה", Vector3((hut_x0 + hut_x1) * 0.5, top + 2.2, hut_z - 1.22), PI, 48, Color(1, 0.9, 0.6))
	# Facade: building name over the door.
	_board("מגדל השחר", door_x + 0.3, 3.6, 4.6, Color(0.2, 0.18, 0.16), Color(1.0, 0.85, 0.55), 100)
	kit.commit()
	_marker("גג", Vector3(door_x, top + 4.0, -1.0), Color(1.0, 0.9, 0.5))
	return {
		"use": {
			"lift_up": [Vector3(cx - 2.2, 1.0, depth - 1.0), "ctx_lift_up"],
			"lift_down": [Vector3(hut_x1 + 0.8, top + 1.0, hut_z), "ctx_lift_down"],
		},
		"lift_top": Vector3(hut_x1 + 0.55, top + 0.2, hut_z),
		"lift_bottom": Vector3(cx - 2.2, 0.2, depth - 1.4),
		"roof": top,
		"clerks": [],
		"lot_clear": [x0 - 0.5, x1 + 0.5],
	}


## Switchback stairs in the column x0..x1 (z from the front wall to depth).
func _stairwell(x0: float, x1: float, depth: float, levels: Array[float]) -> void:
	var concrete: Material = Kit.mat("concrete", Color(0.72, 0.71, 0.68))
	var lining: Material = Kit.mat("plaster", Color(0.9, 0.9, 0.87))
	var rail: Material = Kit.mat("metal", Color(0.15, 0.15, 0.16))
	var top: float = levels[levels.size() - 1]
	var lane := (x1 - x0 - 0.2) * 0.5
	var l2 := x0 + lane * 0.5            # flights going up toward the front
	var l1 := x1 - lane * 0.5            # flights going up toward the back
	var zf := T
	var zf1 := zf + 1.4
	var zb0 := depth - 1.4
	var h := top
	var cz := (zf + depth) * 0.5
	# Lining (stairwell walls) and floor.
	kit.box(lining, Vector3(x1 - 0.02, h * 0.5, cz), Vector3(0.04, h, depth - zf))
	kit.box(lining, Vector3((x0 + x1) * 0.5, h * 0.5, depth - 0.02), Vector3(x1 - x0, h, 0.04))
	kit.box(lining, Vector3(x0 + 0.02, (H0 + h) * 0.5, cz), Vector3(0.04, h - H0, depth - zf))
	kit.box(lining, Vector3((x0 + x1) * 0.5, (H0 + h) * 0.5, zf + 0.02), Vector3(x1 - x0, h - H0, 0.04))
	kit.box(concrete, Vector3((x0 + x1) * 0.5, 0.015, cz), Vector3(x1 - x0, 0.03, depth - zf))
	# Centre divider between the two lanes, up to railing height on the roof.
	kit.box(lining, Vector3(x0 + lane + 0.1, (h + 1.05) * 0.5, (zf1 + zb0) * 0.5), Vector3(0.2, h + 1.05, zb0 - zf1), true)
	for k in levels.size() - 1:
		var ya: float = levels[k]
		var yc: float = levels[k + 1]
		var yb := (ya + yc) * 0.5
		_flight(concrete, l1, lane, zf1, ya, zb0, yb)
		_landing(concrete, x0, x1, zb0, depth, yb)
		_flight(concrete, l2, lane, zb0, yb, zf1, yc)
		_landing(concrete, x0, x1, zf, zf1, yc)
		# A wall light on every landing.
		kit.box(Kit.mat("glow", Color(1.0, 0.9, 0.7)), Vector3(x1 - 0.06, yb + 2.0, depth - 0.7), Vector3(0.06, 0.18, 0.4))
	kit.light(Vector3((x0 + x1) * 0.5, h * 0.5, cz), Color(1.0, 0.88, 0.7), 2.0, maxf(h * 0.7, 10.0))
	# Railings around the opening on the roof.
	var ry := top + 0.525
	kit.box(rail, Vector3((x0 + lane + 0.2 + x1) * 0.5, ry, zf1), Vector3(x1 - x0 - lane - 0.2, 1.05, 0.06), true)
	kit.box(rail, Vector3(x0 + 0.03, ry, (zf1 + depth) * 0.5), Vector3(0.06, 1.05, depth - zf1), true)
	kit.box(rail, Vector3(x1 - 0.03, ry, (zf1 + depth) * 0.5), Vector3(0.06, 1.05, depth - zf1), true)
	kit.box(rail, Vector3((x0 + x1) * 0.5, ry, depth - 0.03), Vector3(x1 - x0, 1.05, 0.06), true)


func _flight(m: Material, cx: float, w: float, za: float, ya: float, zb: float, yb: float) -> void:
	var rise := yb - ya
	var n := maxi(roundi(absf(rise) / 0.18), 1)
	var sr := rise / float(n)
	var run := (zb - za) / float(n)
	for i in n:
		kit.box(m, Vector3(cx, ya + sr * (i + 0.5), za + run * (i + 0.5)), Vector3(w, absf(sr), absf(run)))
	# Sloped slab under the steps (visual) and a smooth ramp for walking (collision).
	var dz := zb - za
	var v := Vector3(0, rise, dz).normalized()
	var x := Vector3.RIGHT
	var y := v.cross(x)
	if y.y < 0.0:
		y = -y
		x = -x
	var b := Basis(x, y, v)
	var length := Vector3(0, rise, dz).length()
	var mid := Vector3(cx, (ya + yb) * 0.5, (za + zb) * 0.5)
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.16, length)
	kit.mesh(m, slab, Transform3D(b, mid - y * (absf(sr) * 0.5 + 0.06)))
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.12, length + 0.1)
	col.shape = bs
	col.transform = Transform3D(b, mid - y * 0.06)
	kit.body.add_child(col)


func _landing(m: Material, x0: float, x1: float, za: float, zb: float, y: float) -> void:
	if y < 0.05:
		return
	kit.box(m, Vector3((x0 + x1) * 0.5, y - 0.1, (za + zb) * 0.5), Vector3(x1 - x0, 0.2, absf(zb - za)), true)

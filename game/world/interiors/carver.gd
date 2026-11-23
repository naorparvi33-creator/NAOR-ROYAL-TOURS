extends RefCounted
## Turns one of the city's solid box buildings into a shell with hollow rooms on its
## street side, without touching city.gd:
##  1. the building's triangles are cut out of its block's merged facade mesh and its
##     collision box is removed;
##  2. the volume is rebuilt from boxes around the hollow "cells" (same facade material,
##     tint and window seed, so the outside looks exactly as before);
##  3. site code then adds the front walls (doors, real shop windows), the interior and
##     the furniture in the cell's local frame.
## Local frame of a site: x runs along the street face, y up from the sidewalk, z goes
## into the building (z = 0 is the outer face).

const T := 0.3          # wall thickness
const H0 := 4.2         # ground floor height (= building.gdshader ground_floor_h)

var city: Node3D
var body: StaticBody3D

# Current site.
var origin := Vector3.ZERO
var u := Vector3.RIGHT          # along the face (local +x)
var d := Vector3.BACK           # into the building (local +z)
var length := 0.0
var depth := 0.0
var top := 0.0                  # height above the sidewalk
var top_world := 0.0
var m := 0
var color := Color.WHITE
var b: Dictionary = {}

var _mi: MeshInstance3D = null
var _add: SurfaceTool
var _glass_mat: StandardMaterial3D


func _init(c: Node3D) -> void:
	city = c
	body = StaticBody3D.new()
	body.name = "InteriorsStatic"
	city.add_child(body)
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.albedo_color = Color(0.55, 0.68, 0.72, 0.28)
	_glass_mat.roughness = 0.05
	_glass_mat.metallic = 0.3
	_glass_mat.metallic_specular = 0.9
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


## Street faces of a building record from city._buildings: array of outward normals.
func street_faces(rec: Dictionary) -> Array:
	var out: Array = []
	var c: Variant = city
	var half: float = c.BLOCK * 0.5
	var pos: Vector3 = rec["pos"]
	var size: Vector3 = rec["size"]
	var block: Vector3 = rec["block"]
	for face in 4:
		var n := Vector3(1, 0, 0).rotated(Vector3.UP, -face * PI * 0.5).round()
		var wall := pos + n * absf((size * 0.5).dot(n))
		if absf((wall - block).dot(n)) >= half - 6.0:
			out.append(n)
	return out


## Starts a site on face `n` (outward normal) of building `rec`.
func begin(rec: Dictionary, n: Vector3) -> void:
	b = rec
	var c: Variant = city
	var curb: float = c.CURB_H
	var pos: Vector3 = rec["pos"]
	var size: Vector3 = rec["size"]
	d = -n
	u = Vector3.UP.cross(d)
	length = absf(size.dot(u))
	depth = absf(size.dot(d))
	top = size.y
	top_world = curb + top
	m = int(rec["m"])
	origin = Vector3(pos.x, curb, pos.z) + n * depth * 0.5
	_remove_collision(pos, size)
	_cut_mesh(pos, size)
	_add = SurfaceTool.new()
	_add.begin(Mesh.PRIMITIVE_TRIANGLES)


func to_world(p: Vector3) -> Vector3:
	return origin + u * p.x + Vector3.UP * p.y + d * p.z


func dir_world(v: Vector3) -> Vector3:
	return u * v.x + Vector3.UP * v.y + d * v.z


## Basis of the local frame (x = along the face, z = into the building).
func basis() -> Basis:
	return Basis(u, Vector3.UP, d)


func _wsize(s: Vector3) -> Vector3:
	return (u * s.x).abs() + Vector3(0, s.y, 0) + (d * s.z).abs()


## Box in the facade material (local centre and size). plain = no painted windows.
func facade_box(center: Vector3, size: Vector3, plain := false, collide := true) -> void:
	var c: Variant = city
	var wc := to_world(center)
	var ws := _wsize(size)
	c._add_box(_add, wc, ws, color, 1.0 if plain else 0.0, top_world)
	if collide:
		collision_box(center, size)


func collision_box(center: Vector3, size: Vector3) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = _wsize(size)
	col.shape = bs
	col.position = to_world(center)
	body.add_child(col)
	return col


## Rebuilds the building around hollow cells. Each cell: {x0, x1, z1 (depth), y0, y1}.
## Cells must be sorted by x0 and not overlap.
func fill(cells: Array) -> void:
	var hl := length * 0.5
	var front := 0.0
	for cell in cells:
		front = maxf(front, float(cell["z1"]))
	# Rear part: full width, full height.
	if depth - front > 0.01:
		facade_box(Vector3(0, top * 0.5, (front + depth) * 0.5), Vector3(length, top, depth - front))
	var x := -hl
	for cell in cells:
		var x0: float = cell["x0"]
		var x1: float = cell["x1"]
		var z1: float = cell["z1"]
		var y0: float = cell["y0"]
		var y1: float = minf(float(cell["y1"]), top)
		if x0 - x > 0.01:
			facade_box(Vector3((x + x0) * 0.5, top * 0.5, front * 0.5), Vector3(x0 - x, top, front))
		var w := x1 - x0
		var cx := (x0 + x1) * 0.5
		if y0 > 0.01:
			facade_box(Vector3(cx, y0 * 0.5, z1 * 0.5), Vector3(w, y0, z1))
		if top - y1 > 0.01:
			facade_box(Vector3(cx, (y1 + top) * 0.5, z1 * 0.5), Vector3(w, top - y1, z1))
		if front - z1 > 0.01:
			facade_box(Vector3(cx, top * 0.5, (z1 + front) * 0.5), Vector3(w, top, front - z1))
		x = x1
	if hl - x > 0.01:
		facade_box(Vector3((x + hl) * 0.5, top * 0.5, front * 0.5), Vector3(hl - x, top, front))
	# Parapet around the roof (also a railing for the rooftop) and two rooftop units.
	var pt := 0.3
	var ph := 1.0
	var y := top + ph * 0.5
	facade_box(Vector3(0, y, pt * 0.5), Vector3(length, ph, pt), true)
	facade_box(Vector3(0, y, depth - pt * 0.5), Vector3(length, ph, pt), true)
	facade_box(Vector3(-hl + pt * 0.5, y, depth * 0.5), Vector3(pt, ph, depth - pt * 2.0), true)
	facade_box(Vector3(hl - pt * 0.5, y, depth * 0.5), Vector3(pt, ph, depth - pt * 2.0), true)
	if depth - front > 6.0:
		var rz := (front + depth) * 0.5
		facade_box(Vector3(-hl * 0.4, top + 0.7, rz), Vector3(2.5, 1.4, 2.0), true)
		facade_box(Vector3(hl * 0.45, top + 0.7, rz + 1.0), Vector3(2.0, 1.4, 2.4), true)


## Front wall of a cell at z = 0..T between x0 and x1, y0..y1, with openings:
## {x0, x1, y0, y1, glass: bool}. Doors are openings without glass. Returns nothing.
func front_wall(x0: float, x1: float, y0: float, y1: float, openings: Array, plain := true) -> void:
	var edges: Array[float] = [x0, x1]
	for o in openings:
		edges.append(float(o["x0"]))
		edges.append(float(o["x1"]))
	edges.sort()
	for i in edges.size() - 1:
		var a: float = edges[i]
		var e: float = edges[i + 1]
		if e - a < 0.005:
			continue
		var mid := (a + e) * 0.5
		var hole: Variant = null
		for o in openings:
			if mid > float(o["x0"]) and mid < float(o["x1"]):
				hole = o
		if hole == null:
			facade_box(Vector3(mid, (y0 + y1) * 0.5, T * 0.5), Vector3(e - a, y1 - y0, T), plain)
			continue
		var h: Dictionary = hole
		var hy0: float = h["y0"]
		var hy1: float = h["y1"]
		if hy0 - y0 > 0.005:
			facade_box(Vector3(mid, (y0 + hy0) * 0.5, T * 0.5), Vector3(e - a, hy0 - y0, T), plain)
		if y1 - hy1 > 0.005:
			facade_box(Vector3(mid, (hy1 + y1) * 0.5, T * 0.5), Vector3(e - a, y1 - hy1, T), plain)
	# Glass panes and slim dark frames in the window openings.
	for o in openings:
		if not o.get("glass", false):
			continue
		var ox0: float = o["x0"]
		var ox1: float = o["x1"]
		var oy0: float = o["y0"]
		var oy1: float = o["y1"]
		var gw := ox1 - ox0
		var gh := oy1 - oy0
		var gc := Vector3((ox0 + ox1) * 0.5, (oy0 + oy1) * 0.5, T * 0.5)
		var mi := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(gw, gh, 0.02)
		mi.mesh = qm
		mi.material_override = _glass_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(basis(), to_world(gc))
		mi.visibility_range_end = 140.0
		city.add_child(mi)
		collision_box(gc, Vector3(gw, gh, 0.1))


## Glass material (shared) for other see-through parts.
func glass_material() -> StandardMaterial3D:
	return _glass_mat


## Commits the rebuilt facade into the block mesh.
func finish() -> void:
	if _mi == null:
		return
	var mesh: ArrayMesh = _mi.mesh
	var c: Variant = city
	var facades: Array = c._facades
	var mat: Material = facades[m]
	var add_arrays := _add.commit_to_arrays()
	var surfaces: Array = []
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var smat: Material = mesh.surface_get_material(s)
		if smat == mat:
			arr = _concat(arr, add_arrays)
			add_arrays = []
		surfaces.append([arr, smat])
	if not add_arrays.is_empty():
		surfaces.append([add_arrays, mat])
	mesh.clear_surfaces()
	for s in surfaces:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s[0])
		mesh.surface_set_material(mesh.get_surface_count() - 1, s[1])
	_mi = null


# ------------------------------------------------------------ internals

func _remove_collision(pos: Vector3, size: Vector3) -> void:
	var c: Variant = city
	var st: StaticBody3D = c._static
	for ch in st.get_children():
		if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
			var cs := ch as CollisionShape3D
			if cs.position.distance_to(pos) < 0.05 and ((cs.shape as BoxShape3D).size - size).length() < 0.05:
				st.remove_child(cs)
				cs.queue_free()


## Removes every triangle of the building (walls, cornice, rooftop units) from its
## block mesh and remembers its tint / window seed.
func _cut_mesh(pos: Vector3, size: Vector3) -> void:
	_mi = null
	var box := AABB(pos - size * 0.5, size).grow(0.3)
	box.size.y += 3.0
	for ch in city.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi := ch as MeshInstance3D
		if mi.material_override != null or not (mi.mesh is ArrayMesh):
			continue
		if not mi.get_aabb().intersects(box):
			continue
		var mesh: ArrayMesh = mi.mesh
		var found := false
		var surfaces: Array = []
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var kept := _filter(arr, box)
			if kept.size() > 1:
				found = true
				if kept[1] is Color:
					color = kept[1]
			surfaces.append([kept[0], mesh.surface_get_material(s)])
		if not found:
			continue
		mesh.clear_surfaces()
		for s in surfaces:
			var arr: Array = s[0]
			if (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 0:
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, s[1])
		_mi = mi
		return


## Returns [arrays without the triangles inside box, (wall colour if any removed)].
func _filter(arr: Array, box: AABB) -> Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := idx.size() if idx.size() > 0 else verts.size()
	var keep := PackedInt32Array()
	var removed := false
	var wall_col: Variant = null
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var t := 0
	while t < count:
		var i0 := idx[t] if idx.size() > 0 else t
		var i1 := idx[t + 1] if idx.size() > 0 else t + 1
		var i2 := idx[t + 2] if idx.size() > 0 else t + 2
		var cen := (verts[i0] + verts[i1] + verts[i2]) / 3.0
		if box.has_point(cen):
			removed = true
			if wall_col == null and cols.size() > i0 and uvs.size() > i0 and uvs[i0].x < 0.5:
				wall_col = cols[i0]
		else:
			keep.append(i0)
			keep.append(i1)
			keep.append(i2)
		t += 3
	if not removed:
		return [arr]
	# Rebuild as a non-indexed surface with only the kept vertices.
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX or arr[k] == null:
			continue
		out[k] = _pick(arr[k], keep, verts.size())
	if wall_col == null:
		return [out, true]
	return [out, wall_col]


func _pick(src: Variant, keep: PackedInt32Array, nverts: int) -> Variant:
	if src is PackedVector3Array:
		var a := PackedVector3Array()
		a.resize(keep.size())
		for i in keep.size():
			a[i] = src[keep[i]]
		return a
	if src is PackedVector2Array:
		var a := PackedVector2Array()
		a.resize(keep.size())
		for i in keep.size():
			a[i] = src[keep[i]]
		return a
	if src is PackedColorArray:
		var a := PackedColorArray()
		a.resize(keep.size())
		for i in keep.size():
			a[i] = src[keep[i]]
		return a
	if src is PackedFloat32Array:
		var stride: int = int((src as PackedFloat32Array).size() / maxi(nverts, 1))
		var a := PackedFloat32Array()
		a.resize(keep.size() * stride)
		for i in keep.size():
			for s in stride:
				a[i * stride + s] = src[keep[i] * stride + s]
		return a
	return src


func _concat(a: Array, add: Array) -> Array:
	if add.is_empty():
		return a
	if a[Mesh.ARRAY_INDEX] != null:
		return _concat(_filter_all(a), add)
	if add[Mesh.ARRAY_INDEX] != null:
		return _concat(a, _filter_all(add))
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX:
			continue
		var x: Variant = a[k]
		var y: Variant = add[k]
		if x == null and y == null:
			continue
		if x == null or y == null:
			# Only keep channels both sides have.
			continue
		var r: Variant = x.duplicate()
		r.append_array(y)
		out[k] = r
	return out


func _filter_all(arr: Array) -> Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX or arr[k] == null:
			continue
		out[k] = _pick(arr[k], idx, verts.size())
	return out

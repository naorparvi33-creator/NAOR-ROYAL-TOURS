extends Node3D
## Park fountain on a stone plaza: a round stone basin with a two-tier centre
## piece, animated water (ripples, fresnel, sun glints) and falling / rising water
## made of scrolling translucent sheets. Three draw calls, range-limited.

const BASIN_R := 3.3
const DRAW_RANGE := 140.0


func _ready() -> void:
	var stone := Mats.pbr("concrete", 1.2, Color(0.93, 0.88, 0.8), 0.8)

	# Plaza (slightly raised disc), basin and centre piece share the stone material.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(st, [Vector2(7.5, 0.0), Vector2(7.4, 0.05), Vector2(0.0, 0.05)], 48)
	# Basin wall: outside, rounded rim, inside, floor.
	_lathe(st, [Vector2(BASIN_R + 0.05, 0.0), Vector2(BASIN_R + 0.05, 0.45), Vector2(BASIN_R - 0.05, 0.6),
		Vector2(BASIN_R - 0.35, 0.6), Vector2(BASIN_R - 0.42, 0.5), Vector2(BASIN_R - 0.42, 0.1), Vector2(0.0, 0.1)], 40)
	# Centre column and upper bowl.
	_lathe(st, [Vector2(0.0, 0.1), Vector2(0.38, 0.1), Vector2(0.3, 0.3), Vector2(0.2, 0.5), Vector2(0.18, 1.3),
		Vector2(0.3, 1.45), Vector2(1.15, 1.6), Vector2(1.2, 1.72), Vector2(1.05, 1.72), Vector2(0.3, 1.62),
		Vector2(0.12, 1.75), Vector2(0.1, 2.25), Vector2(0.18, 2.35), Vector2(0.0, 2.45)], 24)
	_add(_commit(st, stone), true)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BASIN_R
	cyl.height = 0.6
	col.shape = cyl
	col.position = Vector3(0, 0.3, 0)
	body.add_child(col)
	var col2 := CollisionShape3D.new()
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = 0.4
	cyl2.height = 2.4
	col2.shape = cyl2
	col2.position = Vector3(0, 1.2, 0)
	body.add_child(col2)
	add_child(body)

	# Water surfaces (basin + upper bowl).
	var water := ShaderMaterial.new()
	water.shader = preload("res://world/water.gdshader")
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_disc(st, 0.48, BASIN_R - 0.42, 0.2, 40)
	_disc(st, 1.66, 1.07, 0.32, 24)
	_add(_commit(st, water), false)

	# Falling sheet from the bowl rim, a central jet and a splash ring.
	var falls := ShaderMaterial.new()
	falls.shader = preload("res://world/water_fall.gdshader")
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sheet(st, 1.2, 1.36, 1.7, 0.48, 32)        # curtain from the upper bowl
	_sheet(st, 0.05, 0.22, 2.45, 3.1, 8)         # jet rising from the top
	_sheet(st, 0.24, 0.05, 3.1, 2.45, 8)         # jet falling back
	_sheet(st, 1.36, 1.55, 0.7, 0.48, 32)        # splash where the curtain lands
	_add(_commit(st, falls), false)


func _add(mesh: Mesh, shadows: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DRAW_RANGE
	mi.visibility_range_end_margin = 10.0
	add_child(mi)


func _commit(st: SurfaceTool, mat: Material) -> ArrayMesh:
	st.set_material(mat)
	return st.commit()


## Surface of revolution from a (radius, height) profile; normals from the profile.
func _lathe(st: SurfaceTool, prof: Array, n: int) -> void:
	for j in prof.size() - 1:
		var a: Vector2 = prof[j]
		var b: Vector2 = prof[j + 1]
		var e := b - a
		var pn := Vector2(e.y, -e.x).normalized()   # outward in (r, y)
		for i in n:
			var t0 := TAU * i / n
			var t1 := TAU * (i + 1) / n
			var d0 := Vector3(cos(t0), 0, sin(t0))
			var d1 := Vector3(cos(t1), 0, sin(t1))
			var p := [d0 * a.x + Vector3(0, a.y, 0), d1 * a.x + Vector3(0, a.y, 0),
				d1 * b.x + Vector3(0, b.y, 0), d0 * b.x + Vector3(0, b.y, 0)]
			var nn := [d0 * pn.x + Vector3(0, pn.y, 0), d1 * pn.x + Vector3(0, pn.y, 0),
				d1 * pn.x + Vector3(0, pn.y, 0), d0 * pn.x + Vector3(0, pn.y, 0)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nn[k])
				st.set_uv(Vector2(float(i) / n * 8.0, a.y))
				st.add_vertex(p[k])


func _disc(st: SurfaceTool, y: float, r: float, uv_id: float, n: int) -> void:
	for i in n:
		var t0 := TAU * i / n
		var t1 := TAU * (i + 1) / n
		var p := [Vector3(0, y, 0), Vector3(cos(t1) * r, y, sin(t1) * r), Vector3(cos(t0) * r, y, sin(t0) * r)]
		for k in 3:
			var q: Vector3 = p[k]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q.x, q.z))
			st.set_uv2(Vector2(uv_id, q.length() / r))
			st.add_vertex(q)


## A ring-shaped sheet of water from radius r0 at height y0 to r1 at y1.
## UV.y runs along the flow (0 at the source), UV.x around.
func _sheet(st: SurfaceTool, r0: float, r1: float, y0: float, y1: float, n: int) -> void:
	var rows := 4
	for j in rows:
		var s0 := float(j) / rows
		var s1 := float(j + 1) / rows
		# Falling water accelerates: bulge outward along a parabola.
		var ra := lerpf(r0, r1, sqrt(s0))
		var rb := lerpf(r0, r1, sqrt(s1))
		var ya := lerpf(y0, y1, s0 * s0)
		var yb := lerpf(y0, y1, s1 * s1)
		for i in n:
			var t0 := TAU * i / n
			var t1 := TAU * (i + 1) / n
			var d0 := Vector3(cos(t0), 0, sin(t0))
			var d1 := Vector3(cos(t1), 0, sin(t1))
			var p := [d0 * ra + Vector3(0, ya, 0), d1 * ra + Vector3(0, ya, 0), d1 * rb + Vector3(0, yb, 0), d0 * rb + Vector3(0, yb, 0)]
			var uv := [Vector2(float(i) / n * 6.0, s0), Vector2(float(i + 1) / n * 6.0, s0),
				Vector2(float(i + 1) / n * 6.0, s1), Vector2(float(i) / n * 6.0, s1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(((p[k] as Vector3) * Vector3(1, 0, 1)).normalized())
				st.set_uv(uv[k])
				st.add_vertex(p[k])

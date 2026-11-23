class_name Props
## Procedural street furniture meshes (each is one ArrayMesh, drawn with MultiMesh).
## All face +X toward the road by default; the city rotates each instance.

## Tall coastal fan-crowned palm: a gently curved, ringed trunk that flares at the
## foot, a shaggy "skirt" of dead fronds under the crown and 15 living fronds.
## Each frond is two strips folded along the rib (a V seen from the end), arching up
## and then drooping under its weight, so the crown reads as 3D from every side.
## Vertex colour carries baked occlusion + flex for world/foliage.gdshader. ~380 tris.
static func palm(seed_value: int, bark: Material, fronds: Material) -> ArrayMesh:
	var lite := low_detail()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := rng.randf_range(8.5, 12.5)
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.5, 1.4)
	var mesh := ArrayMesh.new()

	# ---- trunk: 14 rings x 9 sides along a curve, ring texture (1 tile per metre).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8 if not lite else 5
	var sides := 6 if not lite else 5
	var top_r := 0.16
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var c0 := _curve(t0, height, lean)
		var c1 := _curve(t1, height, lean)
		var r0 := _trunk_r(t0, top_r)
		var r1 := _trunk_r(t1, top_r)
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [c0 + d0 * r0, c0 + d1 * r0, c1 + d1 * r1, c1 + d0 * r1]
			var n := [d0, d1, d1, d0]
			var uv := [Vector2(float(s) / sides, -t0 * height), Vector2(float(s + 1) / sides, -t0 * height),
				Vector2(float(s + 1) / sides, -t1 * height), Vector2(float(s) / sides, -t1 * height)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n[k])
				st.set_uv(uv[k])
				st.add_vertex(p[k])
	st.generate_tangents()
	st.set_material(bark)
	st.commit(mesh)

	# ---- crown
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := _curve(1.0, height, lean)
	# Dead-frond skirt: brown fronds hanging straight down around the crown base.
	var dead := rng.randi_range(5, 7) if not lite else 4
	for f in dead:
		var a := TAU * f / dead + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		var tint := Color(0.78, 0.62, 0.4).lerp(Color(0.62, 0.5, 0.34), rng.randf())
		_frond(st, top + Vector3(0, -0.15, 0) + dir * 0.12, dir, deg_to_rad(rng.randf_range(-80.0, -65.0)),
			rng.randf_range(1.6, 2.3), 0.55, 0.15, deg_to_rad(20.0), tint, 0.55, 2)
	# Living fronds: upper ones point up, lower ones droop. Golden-angle spiral.
	var count := 15 if not lite else 11
	for f in count:
		var k := float(f) / (count - 1)        # 0 = top / young, 1 = bottom / old
		var a := f * 2.39996 + rng.randf_range(-0.12, 0.12)
		var dir := Vector3(cos(a), 0, sin(a))
		var elev := deg_to_rad(lerpf(62.0, -18.0, k) + rng.randf_range(-8.0, 8.0))
		var length := rng.randf_range(3.2, 4.0) * lerpf(0.75, 1.0, minf(k * 2.0, 1.0))
		var droop := lerpf(0.55, 1.25, k)
		var ao := lerpf(1.08, 0.72, k)
		var tint := Color(ao, ao, ao * 0.95)
		if rng.randf() < 0.12:
			tint = Color(ao * 1.1, ao * 1.02, ao * 0.7)   # a yellowing frond
		_frond(st, top + Vector3(0, 0.1 - k * 0.25, 0), dir, elev, length, 1.15, droop,
			deg_to_rad(rng.randf_range(28.0, 38.0)), tint, 1.0, 4 if not lite else 3)
	st.generate_tangents()
	st.set_material(fronds)
	st.commit(mesh)
	return mesh


## True on the low preset and in the browser build (auto): builders then make
## lighter meshes. Read once while the city is generated.
static func low_detail() -> bool:
	var p := str(Settings.get_value("quality_preset"))
	return p == "low" or (p == "auto" and OS.has_feature("web"))


static func _trunk_r(t: float, top_r: float) -> float:
	# Flared foot, slim waist, slight swelling under the crown.
	return top_r + 0.2 * exp(-t * 22.0) + 0.04 * (1.0 - t) + 0.035 * smoothstep(0.85, 1.0, t)


## One frond: a rib curve from `root` that starts at elevation `elev` along `dir`,
## bends down with `droop`, and two leaf strips folded up by `fold` on each side.
static func _frond(st: SurfaceTool, root: Vector3, dir: Vector3, elev: float, length: float,
		width: float, droop: float, fold: float, tint: Color, flex_scale: float, n_seg: int) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	var p := root
	var ang := elev
	var step := length / n_seg
	for i in n_seg + 1:
		pts.append(p)
		var tdir := (dir * cos(ang) + Vector3.UP * sin(ang)).normalized()
		tans.append(tdir)
		p += tdir * step
		ang -= droop * 0.8 / n_seg * (1.0 + float(i) / n_seg)
	for half in [-1.0, 1.0]:
		for i in n_seg:
			var q: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			var nrm: Array[Vector3] = []
			var flex: Array[float] = []
			for j in [i, i + 1]:
				var t := float(j) / n_seg
				var w := width * 0.5 * (0.35 + 0.65 * sin(minf(t * 1.25, 1.0) * PI * 0.5)) * (1.0 - t * 0.25)
				# Leaflets fold up from the rib (V shape) and the fold flattens at the tip.
				var up := tans[j].cross(side).normalized() * -1.0
				var f := fold * (1.0 - t * 0.5)
				var out: Vector3 = (side * half * cos(f) + up * sin(f)).normalized()
				q.append(pts[j])
				q.append(pts[j] + out * w)
				uvs.append(Vector2(t, 0.5))
				uvs.append(Vector2(t, 0.5 - half * 0.5))
				var nn := (up * 0.7 + out * 0.3 + Vector3.UP * 0.4).normalized()
				nrm.append(nn)
				nrm.append(nn)
				flex.append(t * flex_scale)
				flex.append(minf(t + 0.25, 1.0) * flex_scale)
			# q: 0 = rib i, 1 = edge i, 2 = rib i+1, 3 = edge i+1
			for k in [0, 2, 3, 0, 3, 1]:
				var o := lerpf(0.78, 1.0, float(i) / n_seg)
				st.set_color(Color(tint.r * o, tint.g * o, tint.b * o, flex[k]))
				st.set_normal(nrm[k])
				st.set_uv(uvs[k])
				st.add_vertex(q[k])


static func _curve(t: float, height: float, lean: Vector3) -> Vector3:
	# Leans out low on the trunk and straightens toward the crown (phototropism).
	var bend := lean * (1.0 - pow(1.0 - t, 2.0))
	return Vector3(0, t * height, 0) + bend + Vector3(sin(t * 5.0) * 0.06, 0, cos(t * 4.0) * 0.05) - Vector3(0, 0, 0.05)


static func street_lamp(metal: Material, glass: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st, _cyl(0.16, 0.2, 0.6), Transform3D(Basis(), Vector3(0, 0.3, 0)))       # base
	_append(st, _cyl(0.06, 0.09, 7.0), Transform3D(Basis(), Vector3(0, 3.5, 0)))      # pole
	_append(st, _box(Vector3(1.8, 0.08, 0.08)), Transform3D(Basis(), Vector3(0.9, 6.9, 0)))  # arm
	_append(st, _box(Vector3(0.6, 0.14, 0.3)), Transform3D(Basis(), Vector3(1.75, 6.85, 0))) # head
	st.set_material(metal)
	var mesh := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st, _box(Vector3(0.5, 0.04, 0.24)), Transform3D(Basis(), Vector3(1.75, 6.77, 0)))
	st.set_material(glass)
	st.commit(mesh)
	return mesh


static func traffic_light(metal: Material, red: Material, off: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st, _cyl(0.07, 0.09, 5.6), Transform3D(Basis(), Vector3(0, 2.8, 0)))
	_append(st, _box(Vector3(4.2, 0.1, 0.1)), Transform3D(Basis(), Vector3(2.1, 5.5, 0)))
	_append(st, _box(Vector3(0.32, 0.95, 0.3)), Transform3D(Basis(), Vector3(3.9, 5.0, 0)))
	_append(st, _box(Vector3(0.25, 0.55, 0.2)), Transform3D(Basis(), Vector3(0, 3.0, 0.15)))  # pedestrian signal
	st.set_material(metal)
	var mesh := st.commit()
	# Lamps face -Z (oncoming traffic on that road).
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st, _sphere(0.1), Transform3D(Basis(), Vector3(3.9, 5.3, -0.14)))
	st.set_material(red)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st, _sphere(0.1), Transform3D(Basis(), Vector3(3.9, 5.0, -0.14)))
	_append(st, _sphere(0.1), Transform3D(Basis(), Vector3(3.9, 4.7, -0.14)))
	st.set_material(off)
	st.commit(mesh)
	return mesh


static func _append(st: SurfaceTool, m: Mesh, xf: Transform3D) -> void:
	st.append_from(m, 0, xf)


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s

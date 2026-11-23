class_name Props
## Procedural street furniture meshes (each is one ArrayMesh, drawn with MultiMesh).
## All face +X toward the road by default; the city rotates each instance.

static func palm(seed_value: int, bark: Material, fronds: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := rng.randf_range(7.5, 11.0)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var mesh := ArrayMesh.new()

	# Trunk: stacked tapered segments following a gentle curve.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	var sides := 8
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var c0 := _curve(t0, height, lean)
		var c1 := _curve(t1, height, lean)
		var r0 := lerpf(0.24, 0.15, t0)
		var r1 := lerpf(0.24, 0.15, t1)
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [c0 + d0 * r0, c0 + d1 * r0, c1 + d1 * r1, c1 + d0 * r1]
			var n := [d0, d1, d1, d0]
			var uv := [Vector2(float(s) / sides, t0 * height), Vector2(float(s + 1) / sides, t0 * height),
				Vector2(float(s + 1) / sides, t1 * height), Vector2(float(s) / sides, t1 * height)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n[k])
				st.set_uv(uv[k])
				st.add_vertex(p[k])
	st.generate_tangents()
	st.set_material(bark)
	st.commit(mesh)

	# Crown: drooping fronds, each a curved strip of quads.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := _curve(1.0, height, lean)
	var count := 13
	for f in count:
		var a := TAU * f / count + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP).normalized()
		var length := rng.randf_range(3.2, 4.2)
		var rise := rng.randf_range(0.2, 0.9)
		var width := 0.9
		var pts: Array[Vector3] = []
		var n_seg := 5
		for i in n_seg + 1:
			var t := float(i) / n_seg
			# Up first, then arching down under its own weight.
			var y := rise * sin(t * PI * 0.6) - t * t * 2.2
			pts.append(top + dir * length * t + Vector3(0, y, 0))
		for i in n_seg:
			var t0 := float(i) / n_seg
			var t1 := float(i + 1) / n_seg
			var w0 := width * (1.0 - t0 * 0.5)
			var w1 := width * (1.0 - t1 * 0.5)
			var tilt := Vector3.UP * 0.25
			var q := [pts[i] - side * w0 * 0.5 + tilt * w0, pts[i + 1] - side * w1 * 0.5 + tilt * w1,
				pts[i + 1] + side * w1 * 0.5 + tilt * w1, pts[i] + side * w0 * 0.5 + tilt * w0]
			var uvs := [Vector2(t0, 1), Vector2(t1, 1), Vector2(t1, 0), Vector2(t0, 0)]
			var nrm := (dir * 0.4 + Vector3.UP).normalized()
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nrm)
				st.set_uv(uvs[k])
				st.add_vertex(q[k])
	st.generate_tangents()
	st.set_material(fronds)
	st.commit(mesh)
	return mesh


static func _curve(t: float, height: float, lean: Vector3) -> Vector3:
	return Vector3(0, t * height, 0) + lean * t * t


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

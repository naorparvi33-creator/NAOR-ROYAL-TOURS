class_name CarMesh
## Procedural sedan body built by lofting rounded cross-sections along the car,
## plus a glass greenhouse, bumpers, lights and mirrors. Faces +Z.
## Returns one mesh with a few surfaces (paint, glass, trim, lights).

const L := 4.4
const W := 1.8


static func build(paint: Color) -> ArrayMesh:
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = paint
	paint_mat.metallic = 0.55
	paint_mat.roughness = 0.22
	paint_mat.clearcoat_enabled = true
	paint_mat.clearcoat = 0.8
	paint_mat.clearcoat_roughness = 0.1
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.065, 0.08)
	glass.metallic = 0.4
	glass.roughness = 0.04
	var trim := Mats.plain(Color(0.06, 0.06, 0.065), 0.55)
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(0.95, 0.95, 0.9)
	head.emission_enabled = true
	head.emission = Color(1, 0.97, 0.85)
	head.emission_energy_multiplier = 1.5
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.7, 0.03, 0.03)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.03)
	tail.emission_energy_multiplier = 1.2

	var mesh := ArrayMesh.new()
	_body(mesh, paint_mat)
	_greenhouse(mesh, glass, paint_mat)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(W * 0.96, 0.16, 0.18), Vector3(0, 0.42, L * 0.5 - 0.02))    # front bumper
	_box(st, Vector3(W * 0.96, 0.16, 0.18), Vector3(0, 0.42, -L * 0.5 + 0.02))   # rear bumper
	_box(st, Vector3(W * 0.6, 0.12, 0.04), Vector3(0, 0.6, L * 0.5 + 0.02))      # grille
	for sx in [-1.0, 1.0]:
		_box(st, Vector3(0.05, 0.08, 0.16), Vector3(sx * (W * 0.5 + 0.03), 1.03, 0.62))   # mirrors
		_box(st, Vector3(0.04, 0.06, L * 0.7), Vector3(sx * (W * 0.5 - 0.005), 0.5, 0.0))  # side skirt
	st.generate_normals()
	st.set_material(trim)
	st.commit(mesh)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		_box(st, Vector3(0.36, 0.1, 0.06), Vector3(sx * 0.6, 0.74, L * 0.5 - 0.06))
	st.generate_normals()
	st.set_material(head)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		_box(st, Vector3(0.34, 0.1, 0.06), Vector3(sx * 0.62, 0.82, -L * 0.5 + 0.04))
	st.generate_normals()
	st.set_material(tail)
	st.commit(mesh)
	return mesh


## Height of the shoulder line along the car (u = -1 rear .. +1 front).
static func _top(u: float) -> float:
	if u > 0.45:
		return lerpf(0.9, 0.7, smoothstep(0.45, 1.0, u))        # hood slopes to the nose
	if u < -0.75:
		return lerpf(0.97, 0.8, smoothstep(-0.75, -1.0, u))     # trunk lid to tail
	return lerpf(0.97, 0.9, smoothstep(-0.2, 0.45, u))


static func _width(u: float) -> float:
	return W * (1.0 - 0.06 * pow(absf(u), 6.0))


static func _body(mesh: ArrayMesh, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations := 26
	var ring := 20
	var bottom := 0.34
	var rings: Array = []
	for i in stations + 1:
		var u := -1.0 + 2.0 * float(i) / stations
		var z := u * L * 0.5
		var top := _top(u)
		var hw := _width(u) * 0.5
		var hh := (top - bottom) * 0.5
		var cy := bottom + hh
		var pts: Array[Vector3] = []
		for k in ring:
			var a := TAU * float(k) / ring
			var c := cos(a)
			var s := sin(a)
			# Superellipse: a rounded rectangle cross-section.
			var x := hw * signf(c) * pow(absf(c), 0.35)
			var y := cy + hh * signf(s) * pow(absf(s), 0.45)
			pts.append(Vector3(x, y, z))
		rings.append(pts)
	for i in stations:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in ring:
			var k2 := (k + 1) % ring
			_quad(st, a[k], a[k2], b[k2], b[k])
	# End caps.
	for end in [0, stations]:
		var pts: Array = rings[end]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		for k in ring:
			var k2 := (k + 1) % ring
			if end == 0:
				_tri(st, c, pts[k2], pts[k])
			else:
				_tri(st, c, pts[k], pts[k2])
	st.generate_normals()
	st.set_material(mat)
	st.commit(mesh)


static func _greenhouse(mesh: ArrayMesh, glass: Material, paint: Material) -> void:
	var y0 := 0.95
	var y1 := 1.42
	var b := [Vector3(-0.8, y0, -1.2), Vector3(0.8, y0, -1.2), Vector3(0.8, y0, 0.85), Vector3(-0.8, y0, 0.85)]
	var t := [Vector3(-0.64, y1, -0.85), Vector3(0.64, y1, -0.85), Vector3(0.64, y1, 0.2), Vector3(-0.64, y1, 0.2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var k2 := (k + 1) % 4
		_quad(st, b[k], b[k2], t[k2], t[k])
	st.generate_normals()
	st.set_material(glass)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, t[0], t[1], t[2], t[3])
	st.generate_normals()
	st.set_material(paint)
	st.commit(mesh)


static func wheel_mesh() -> ArrayMesh:
	var tire := CylinderMesh.new()
	tire.top_radius = 0.34
	tire.bottom_radius = 0.34
	tire.height = 0.24
	tire.radial_segments = 18
	tire.rings = 1
	var rim := CylinderMesh.new()
	rim.top_radius = 0.22
	rim.bottom_radius = 0.22
	rim.height = 0.25
	rim.radial_segments = 14
	rim.rings = 1
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(tire, 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
	st.set_material(Mats.plain(Color(0.05, 0.05, 0.05), 0.9))
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(rim, 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
	st.set_material(Mats.plain(Color(0.7, 0.7, 0.72), 0.3, 0.9))
	st.commit(mesh)
	return mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _box(st: SurfaceTool, s: Vector3, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = s
	st.append_from(bm, 0, Transform3D(Basis(), pos))

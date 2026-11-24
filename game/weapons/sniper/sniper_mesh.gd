extends RefCounted
## Procedural bolt-action sniper rifle, one mesh with two materials (2 draw calls).
## Same frame as weapons/rifle_mesh.gd: origin at the pistol grip, muzzle toward -Z,
## so the character's hand IK holds it without changes.

static func build(spec: Dictionary) -> ArrayMesh:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = spec["color"]
	metal.roughness = 0.38
	metal.metallic = 0.7
	var stock := StandardMaterial3D.new()
	stock.albedo_color = spec["stock"]
	stock.roughness = 0.62
	var barrel: float = spec["barrel"]
	var mesh := ArrayMesh.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.05, 0.06, 0.3), Vector3(0, 0.055, -0.12))                     # receiver
	_cyl(st, 0.012, barrel, Vector3(0, 0.06, -0.27 - barrel * 0.5))                   # barrel
	_cyl(st, 0.02, 0.07, Vector3(0, 0.06, -0.3 - barrel))                             # muzzle brake
	_cyl(st, 0.008, 0.06, Vector3(0.04, 0.07, -0.05), Vector3(0, 0, PI * 0.5))       # bolt handle
	_sphere(st, 0.014, Vector3(0.07, 0.07, -0.05))                                    # bolt knob
	_box(st, Vector3(0.024, 0.03, 0.04), Vector3(0, 0.095, -0.2))                     # front ring
	_box(st, Vector3(0.024, 0.03, 0.04), Vector3(0, 0.095, -0.02))                    # rear ring
	_cyl(st, 0.02, 0.3, Vector3(0, 0.125, -0.11))                                     # scope tube
	_cyl(st, 0.03, 0.07, Vector3(0, 0.125, -0.29))                                    # objective bell
	_cyl(st, 0.025, 0.05, Vector3(0, 0.125, 0.06))                                    # eyepiece
	_cyl(st, 0.016, 0.03, Vector3(0, 0.16, -0.11), Vector3(PI * 0.5, 0, 0))           # elevation turret
	_cyl(st, 0.016, 0.03, Vector3(0.03, 0.125, -0.11), Vector3(0, 0, PI * 0.5))       # windage turret
	_box(st, Vector3(0.012, 0.012, 0.16), Vector3(0.02, -0.0, -0.42), Vector3(0.15, 0, 0))   # bipod leg (folded)
	_box(st, Vector3(0.012, 0.012, 0.16), Vector3(-0.02, -0.0, -0.42), Vector3(0.15, 0, 0))
	_box(st, Vector3(0.028, 0.07, 0.07), Vector3(0, -0.02, -0.12), Vector3(-0.15, 0, 0))     # magazine
	st.set_material(metal)
	st.commit(mesh)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.06, 0.06, 0.36), Vector3(0, 0.035, -0.42))                    # fore-end
	_box(st, Vector3(0.05, 0.08, 0.3), Vector3(0, 0.03, 0.18))                       # stock
	_box(st, Vector3(0.04, 0.035, 0.18), Vector3(0, 0.085, 0.18))                    # cheek rest
	_box(st, Vector3(0.055, 0.15, 0.03), Vector3(0, 0.01, 0.34))                     # butt pad
	_box(st, Vector3(0.035, 0.1, 0.045), Vector3(0, -0.04, 0.0), Vector3(0.3, 0, 0))   # grip
	_box(st, Vector3(0.01, 0.03, 0.06), Vector3(0, -0.01, -0.04))                    # trigger guard
	st.set_material(stock)
	st.commit(mesh)
	return mesh


static func _box(st: SurfaceTool, s: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = s
	st.append_from(b, 0, Transform3D(Basis.from_euler(rot), pos))


## Cylinder lying along Z unless rot is given.
static func _cyl(st: SurfaceTool, r: float, h: float, pos: Vector3, rot := Vector3(PI * 0.5, 0, 0)) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	st.append_from(c, 0, Transform3D(Basis.from_euler(rot), pos))


static func _sphere(st: SurfaceTool, r: float, pos: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	st.append_from(s, 0, Transform3D(Basis(), pos))

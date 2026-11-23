class_name RifleMesh
## Procedural assault rifle merged into one mesh with two materials (2 draw calls).
## Origin is the pistol grip; the muzzle points toward -Z.

static func build() -> MeshInstance3D:
	var metal := Mats.plain(Color(0.07, 0.07, 0.075), 0.35, 0.7)
	var polymer := Mats.plain(Color(0.12, 0.115, 0.1), 0.6)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.055, 0.085, 0.34), Vector3(0, 0.05, -0.1))                  # receiver
	_cyl(st, 0.011, 0.2, Vector3(0, 0.06, -0.6))                                   # barrel
	_cyl(st, 0.017, 0.06, Vector3(0, 0.06, -0.72))                                 # muzzle brake
	_box(st, Vector3(0.03, 0.16, 0.07), Vector3(0, -0.06, -0.15), Vector3(-0.2, 0, 0))  # magazine
	_box(st, Vector3(0.03, 0.025, 0.12), Vector3(0, 0.105, -0.08))                 # optic mount
	_cyl(st, 0.022, 0.15, Vector3(0, 0.135, -0.08))                                # optic
	st.set_material(metal)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.06, 0.07, 0.26), Vector3(0, 0.055, -0.38))                  # handguard
	_box(st, Vector3(0.045, 0.1, 0.26), Vector3(0, 0.015, 0.2))                    # stock
	_box(st, Vector3(0.05, 0.13, 0.04), Vector3(0, 0.0, 0.33))                     # butt pad
	_box(st, Vector3(0.034, 0.1, 0.045), Vector3(0, -0.04, 0.0), Vector3(0.3, 0, 0))  # grip
	st.set_material(polymer)
	st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


static func _box(st: SurfaceTool, s: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = s
	st.append_from(b, 0, Transform3D(Basis.from_euler(rot), pos))


## Cylinder lying along Z.
static func _cyl(st: SurfaceTool, r: float, h: float, pos: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	st.append_from(c, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos))


## Compact pistol, origin at the grip, muzzle toward -Z.
static func build_pistol() -> MeshInstance3D:
	var metal := Mats.plain(Color(0.06, 0.06, 0.065), 0.35, 0.7)
	var polymer := Mats.plain(Color(0.1, 0.1, 0.1), 0.6)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.032, 0.035, 0.19), Vector3(0, 0.045, -0.06))     # slide
	_cyl(st, 0.008, 0.02, Vector3(0, 0.045, -0.16))                     # muzzle
	st.set_material(metal)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.03, 0.03, 0.16), Vector3(0, 0.018, -0.05))       # frame
	_box(st, Vector3(0.03, 0.11, 0.045), Vector3(0, -0.035, 0.01), Vector3(0.25, 0, 0))   # grip
	_box(st, Vector3(0.008, 0.03, 0.04), Vector3(0, -0.005, -0.03))     # trigger guard
	st.set_material(polymer)
	st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

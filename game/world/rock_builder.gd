class_name RockBuilder
## Natural-looking boulder: a sphere pushed in and out by 3D noise, flattened at
## the bottom. The rock material uses world triplanar mapping, so no UVs are needed.

static func build(seed_value: int, mat: Material) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.1
	noise.fractal_octaves = 3
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 8
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var stretch := Vector3(1.0 + (seed_value % 3) * 0.2, 0.7, 1.0)
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v * 1.3) * 0.35
		v = v * d * stretch
		v.y = maxf(v.y, -0.25)   # flat bottom so it sits on the ground
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(tmp, 0)
	st.generate_normals()
	st.set_material(mat)
	return st.commit()

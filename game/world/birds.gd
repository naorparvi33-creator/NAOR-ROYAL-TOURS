extends MultiMeshInstance3D
## Gulls circling over the city: one MultiMesh (one draw call) of tiny 6-triangle
## birds. The shader flies them: each bird follows its own loop around its flock
## centre, flaps, glides and banks. Nothing runs on the CPU after _ready.

const FLOCKS := [
	[Vector3(0, 26, 0), 9],          # over the park
	[Vector3(170, 38, -140), 7],
	[Vector3(-150, 32, 120), 6],
	[Vector3(-60, 45, -230), 5],
]


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/birds.gdshader")
	var mesh := _bird_mesh()
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var total := 0
	for f in FLOCKS:
		total += int(f[1])
	mm.instance_count = total
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var i := 0
	for f in FLOCKS:
		var c: Vector3 = f[0]
		var flock_phase := rng.randf() * TAU
		for k in int(f[1]):
			mm.set_instance_transform(i, Transform3D(Basis(), c + Vector3(0, rng.randf_range(-3, 3), 0)))
			# phase along the loop, loop radius, angular speed, flap phase
			mm.set_instance_custom_data(i, Color(flock_phase + k * 0.35 + rng.randf_range(-0.1, 0.1),
				rng.randf_range(14.0, 26.0), rng.randf_range(0.16, 0.24), rng.randf() * TAU))
			i += 1
	multimesh = mm
	custom_aabb = AABB(Vector3(-400, -10, -400), Vector3(800, 100, 800))


func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Bird flies toward +Z. Body, two inner wings and two outer wing tips (UV.x = 0
	# on the body, 1 at the wing tips: the shader bends the wings by it).
	var white := Color(0.92, 0.92, 0.9)
	var grey := Color(0.55, 0.57, 0.6)
	var tip := Color(0.15, 0.15, 0.17)
	var tris := [
		[Vector3(0, 0, 0.32), Vector3(0.06, 0, -0.1), Vector3(-0.06, 0, -0.1), white, 0.0],
		[Vector3(0.06, 0, -0.1), Vector3(0, 0, -0.32), Vector3(-0.06, 0, -0.1), white, 0.0],
	]
	for s in [-1.0, 1.0]:
		tris.append([Vector3(s * 0.05, 0, 0.12), Vector3(s * 0.32, 0, 0.06), Vector3(s * 0.05, 0, -0.08), grey, 0.5])
		tris.append([Vector3(s * 0.32, 0, 0.06), Vector3(s * 0.6, 0, -0.08), Vector3(s * 0.05, 0, -0.08), tip, 1.0])
	for t in tris:
		for k in 3:
			var p: Vector3 = t[k]
			st.set_color(t[3])
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(absf(p.x) / 0.6, 0))
			st.add_vertex(p)
	return st.commit()

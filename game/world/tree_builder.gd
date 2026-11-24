class_name TreeBuilder
## Broadleaf street / park tree (think fig, plane or oak): a slightly crooked trunk
## that forks into 3-5 limbs, and a rounded crown made of ~70 leaf-cluster cards.
## Cards are grouped in clumps around the limb ends; every vertex gets a "volume"
## normal pointing out of the crown and baked occlusion (dark inside / underneath),
## which is what makes a cheap card tree read as a solid, sunlit canopy.
## Vertex colour: rgb = occlusion * tint, a = flex (see world/foliage.gdshader).
## ~130 triangles of bark + 90-140 of leaves.

## `shape` 0 = round spreading crown, 1 = taller oval crown (street tree).
static func build(seed_value: int, bark: Material, leaves: Material, shape := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tall := shape == 1
	var lite := Props.low_detail()
	var height := rng.randf_range(7.0, 9.5) if not tall else rng.randf_range(7.5, 9.0)
	var fork := height * rng.randf_range(0.32, 0.42)
	var crown_c := Vector3(rng.randf_range(-0.3, 0.3), height * (0.62 if not tall else 0.64), rng.randf_range(-0.3, 0.3))
	var crown_r := Vector3(3.3, 2.5, 3.3) if not tall else Vector3(2.6, 2.6, 2.6)
	crown_r *= rng.randf_range(0.9, 1.1)
	var trunk_r := 0.2 if not tall else 0.15
	var mesh := ArrayMesh.new()

	# ---- wood
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(rng.randf_range(-0.2, 0.2), fork, rng.randf_range(-0.2, 0.2))
	_limb(st, Vector3.ZERO, Vector3(0, fork * 0.5, 0) + top * 0.3, top, trunk_r * 1.25, trunk_r, 6, 3)
	var ends: Array[Vector3] = []
	var limbs := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	for i in limbs:
		var a := a0 + TAU * i / limbs + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var end := crown_c + out * crown_r.x * rng.randf_range(0.45, 0.7) + Vector3(0, rng.randf_range(-0.2, 1.0), 0)
		var mid := top.lerp(end, 0.5) + Vector3(0, -0.2, 0) + out * 0.3
		_limb(st, top, mid, end, trunk_r * 0.7, trunk_r * 0.25, 4, 2)
		ends.append(end)
	st.generate_normals()
	st.generate_tangents()
	st.set_material(bark)
	st.commit(mesh)

	# ---- crown: clumps around limb ends + filler clumps on the crown shell.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clumps: Array[Vector3] = []
	for e in ends:
		clumps.append(e)
	var extra := (8 if not tall else 6) if not lite else 4
	for i in extra:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		clumps.append(crown_c + d * crown_r * rng.randf_range(0.55, 0.8))
	clumps.append(crown_c + Vector3(0, crown_r.y * 0.7, 0))   # cap
	for cp in clumps:
		var n_cards := (5 if not tall else 4) if not lite else 3
		var size := rng.randf_range(1.8, 2.4) * (1.0 if not tall else 0.95)
		for k in n_cards:
			var c: Vector3 = cp + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.5), rng.randf_range(-0.6, 0.6))
			# Card plane: random, but biased to face out of the crown.
			var outward := ((c - crown_c) / crown_r).normalized()
			var nrm := (outward + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.6, 0.9), rng.randf_range(-0.9, 0.9))).normalized()
			_leaf_card(st, c, nrm, size, crown_c, crown_r, rng.randf() * TAU)
	st.generate_tangents()
	st.set_material(leaves)
	st.commit(mesh)
	return mesh


## Low shrub ball (for planters and park borders): ~12 cards around a centre.
static func shrub(seed_value: int, leaves: Material, radius := 0.6, cards := 12) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cc := Vector3(0, radius * 0.75, 0)
	var cr := Vector3(radius, radius * 0.8, radius)
	for k in cards:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		var c := cc + d * cr * 0.45
		var nrm := (d + Vector3(rng.randf_range(-0.8, 0.8), 0.5, rng.randf_range(-0.8, 0.8))).normalized()
		_leaf_card(st, c, nrm, radius * 1.5, cc, cr, rng.randf() * TAU)
	st.generate_tangents()
	st.set_material(leaves)
	return st.commit()


static func _leaf_card(st: SurfaceTool, c: Vector3, plane_n: Vector3, size: float,
		crown_c: Vector3, crown_r: Vector3, spin: float) -> void:
	var u := plane_n.cross(Vector3.UP if absf(plane_n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := plane_n.cross(u).normalized()
	var r := Basis(plane_n, spin)
	u = r * u
	v = r * v
	var h := size * 0.5
	var p := [c - u * h - v * h, c + u * h - v * h, c + u * h + v * h, c - u * h + v * h]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		var q: Vector3 = p[k]
		var rel: Vector3 = (q - crown_c) / crown_r
		var dist := clampf(rel.length(), 0.0, 1.3)
		# Occlusion: inner and lower leaves are darker; the sunlit top is brightest.
		var o := clampf(0.42 + dist * 0.45 + rel.y * 0.18, 0.35, 1.1)
		var n := (rel.normalized() * 0.85 + Vector3.UP * 0.35).normalized()
		st.set_color(Color(o, o, o * 0.97, clampf(dist, 0.2, 1.0)))
		st.set_normal(n)
		st.set_uv(uv[k])
		st.add_vertex(q)


## Tapered tube along a quadratic curve a -> b (control) -> c.
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, r0: float, r1: float, sides: int, segs: int) -> void:
	var prev: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var p := a.lerp(b, t).lerp(b.lerp(c, t), t)
		var tan := (b - a).lerp(c - b, t).normalized()
		var side := tan.cross(Vector3.FORWARD if absf(tan.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(tan).normalized()
		var rr := lerpf(r0, r1, t)
		var ring: Array[Vector3] = []
		for s in sides:
			var ang := TAU * s / sides
			ring.append(p + (side * cos(ang) + up * sin(ang)) * rr)
		if i > 0:
			for s in sides:
				var s1 := (s + 1) % sides
				var v0 := float(i - 1) / segs * 2.0
				var v1 := float(i) / segs * 2.0
				var u0 := float(s) / sides
				var u1 := float(s + 1) / sides
				var quad := [prev[s], prev[s1], ring[s1], ring[s]]
				var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
				for k in [0, 2, 1, 0, 3, 2]:
					st.set_uv(uvs[k])
					st.add_vertex(quad[k])
		prev = ring

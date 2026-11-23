class_name PineBuilder
## Builds a low-poly but realistic-looking pine: a tapered bark trunk plus whorls of
## drooping branch cards (alpha-tested needle texture). Each card is doubled
## (flat + vertical) so the tree has volume from every angle. ~600 triangles.

static func build(seed_value: int, bark: Material, needles: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := rng.randf_range(9.0, 15.0)
	var trunk_r := height * 0.022
	var mesh := ArrayMesh.new()

	# ---- trunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var rings := 4
	for i in rings:
		var t0 := float(i) / rings
		var t1 := float(i + 1) / rings
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var p := [
				_ring(a0, t0, height, trunk_r), _ring(a1, t0, height, trunk_r),
				_ring(a1, t1, height, trunk_r), _ring(a0, t1, height, trunk_r)]
			var uv := [Vector2(float(s) / sides, t0 * height * 0.5), Vector2(float(s + 1) / sides, t0 * height * 0.5),
				Vector2(float(s + 1) / sides, t1 * height * 0.5), Vector2(float(s) / sides, t1 * height * 0.5)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3(p[k].x, 0, p[k].z).normalized())
				st.set_uv(uv[k])
				st.add_vertex(p[k])
	st.generate_tangents()
	st.set_material(bark)
	st.commit(mesh)

	# ---- branch cards
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := height * rng.randf_range(0.18, 0.28)
	var y := start
	while y < height - 0.4:
		var t := (y - start) / (height - start)       # 0 at lowest whorl, 1 at the tip
		var count := 5 if t < 0.7 else 4
		var base_a := rng.randf() * TAU
		for b in count:
			var a := base_a + TAU * b / count + rng.randf_range(-0.3, 0.3)
			var length := (pow(1.0 - t, 0.85) * height * 0.26 + 0.35) * rng.randf_range(0.85, 1.1)
			var droop := deg_to_rad(lerpf(-28.0, -8.0, t) + rng.randf_range(-6.0, 6.0))
			var dir := Vector3(cos(a), 0, sin(a))
			dir = dir.rotated(dir.cross(Vector3.UP).normalized(), -droop).normalized()
			var root := Vector3(0, y, 0) + Vector3(cos(a), 0, sin(a)) * trunk_r * (1.0 - t)
			_card(st, root, dir, length, length * 0.55, false)
			_card(st, root, dir, length, length * 0.45, true)
		y += rng.randf_range(0.38, 0.55) * (1.0 - t * 0.35)
	# Tip: two small crossed vertical cards.
	for k in 2:
		var d := Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5))
		_card_vertical_tip(st, Vector3(0, height - 0.9, 0), d, 1.4)
	st.generate_tangents()
	st.set_material(needles)
	st.commit(mesh)
	return mesh


static func _ring(a: float, t: float, height: float, r: float) -> Vector3:
	var rr := r * (1.0 - t * 0.85)
	return Vector3(cos(a) * rr, t * height, sin(a) * rr)


## A quad that starts at the trunk and extends along dir. "vertical" rotates the card
## around the branch axis so it is seen from the side.
static func _card(st: SurfaceTool, root: Vector3, dir: Vector3, length: float, width: float, vertical: bool) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	var across := side
	if vertical:
		across = side.cross(dir).normalized()
	var tip := root + dir * length
	var p := [root - across * width * 0.5, tip - across * width * 0.5, tip + across * width * 0.5, root + across * width * 0.5]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	# Soft "spherical" normals: outward from the trunk and up. Foliage then shades
	# like a volume instead of flat paper cards.
	for k in [0, 1, 2, 0, 2, 3]:
		var n := (Vector3(p[k].x, 0, p[k].z).normalized() * 0.8 + Vector3.UP * 0.6).normalized()
		st.set_normal(n)
		st.set_uv(uv[k])
		st.add_vertex(p[k])


static func _card_vertical_tip(st: SurfaceTool, base: Vector3, d: Vector3, h: float) -> void:
	var w := h * 0.35
	var p := [base - d * w, base + d * w, base + d * w * 0.1 + Vector3(0, h, 0), base - d * w * 0.1 + Vector3(0, h, 0)]
	var uv := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal((d * 0.3 + Vector3.UP).normalized())
		st.set_uv(uv[k])
		st.add_vertex(p[k])

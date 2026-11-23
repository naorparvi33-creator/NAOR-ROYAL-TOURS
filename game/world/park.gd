extends Node3D
## Central park block: lawn (ground shader), training course, small house,
## practice targets, crates to pick up, shade trees, palms, pines, rocks, hedges,
## flower beds, a fountain plaza, gulls overhead and leaves blowing in the wind.

const PARK_HALF := 41.0
const CURB := 0.0
const FOUNTAIN := Vector3(-22, 0, 22)

var _static: StaticBody3D


func _ready() -> void:
	_static = StaticBody3D.new()
	_static.name = "Park"
	add_child(_static)
	_build_course()
	_build_house(Vector3(-24, 0, -18))
	_build_targets()
	_build_pickups()
	_build_trees()
	_build_rocks()
	_build_hedges()
	var fountain := preload("res://world/fountain.gd").new()
	fountain.position = FOUNTAIN
	add_child(fountain)
	add_child(preload("res://world/birds.gd").new())
	add_child(preload("res://world/blowing_leaves.gd").new())


func _block(size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	_static.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = pos
	col.rotation.y = rot_y
	_static.add_child(col)


# ------------------------------------------------------------ course

func _build_course() -> void:
	var concrete := Mats.pbr("concrete", 2.0, Color(0.72, 0.71, 0.68))
	var painted := Mats.pbr("concrete", 2.0, Color(1.0, 0.72, 0.45))
	var planks := Mats.pbr("planks", 1.5)
	var z := -10.0
	# Small step (auto step-up), vault box (auto vault), climb wall, too-high wall.
	_block(Vector3(3, 0.3, 1.5), Vector3(-6, 0.15, z), concrete)
	_block(Vector3(3, 1.0, 0.8), Vector3(-2, 0.5, z), painted)
	_block(Vector3(3, 2.0, 2.0), Vector3(2.5, 1.0, z), concrete)
	_block(Vector3(3, 3.6, 1.0), Vector3(7, 1.8, z), concrete)
	# Stairs: 10 steps of 0.2 m.
	for i in 10:
		_block(Vector3(2.4, 0.2 * (i + 1), 0.4), Vector3(14, 0.1 * (i + 1), -4 - i * 0.4), concrete)
	_block(Vector3(2.4, 2.0, 3.0), Vector3(14, 1.0, -9.5), concrete)
	# Ramp.
	var ramp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3, 0.3, 8)
	ramp.mesh = bm
	ramp.material_override = planks
	var t := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(16)), Vector3(-12, 1.0, -4))
	ramp.transform = t
	_static.add_child(ramp)
	var rc := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = bm.size
	rc.shape = rs
	rc.transform = t
	_static.add_child(rc)
	# Wooden barriers to test sprint + vault chains.
	for i in 4:
		_block(Vector3(1.5, 0.9, 0.5), Vector3(-2, 0.45, -24 - i * 6), planks)


func _build_house(origin: Vector3) -> void:
	var wall := Mats.pbr("plaster", 2.5, Color(1.0, 0.97, 0.9))
	var roof := Mats.pbr("roof", 2.0)
	var base := Mats.pbr("concrete", 2.0, Color(0.8, 0.8, 0.8))
	var w := 8.0
	var d := 6.0
	var h := 3.0
	_block(Vector3(w + 0.4, 0.25, d + 0.4), origin + Vector3(0, 0.12, 0), base)
	_block(Vector3(w, h, 0.25), origin + Vector3(0, h * 0.5, -d * 0.5), wall)
	_block(Vector3(0.25, h, d), origin + Vector3(-w * 0.5, h * 0.5, 0), wall)
	_block(Vector3(0.25, h, d), origin + Vector3(w * 0.5, h * 0.5, 0), wall)
	# Front wall with a doorway.
	_block(Vector3(3.2, h, 0.25), origin + Vector3(-2.4, h * 0.5, d * 0.5), wall)
	_block(Vector3(3.2, h, 0.25), origin + Vector3(2.4, h * 0.5, d * 0.5), wall)
	_block(Vector3(1.6, 0.8, 0.25), origin + Vector3(0, h - 0.4, d * 0.5), wall)
	# Pitched tiled roof (two slopes).
	for s in [-1.0, 1.0]:
		var slope := deg_to_rad(28.0)
		var half := d * 0.5 + 0.5
		var slope_len := half / cos(slope)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w + 0.8, 0.12, slope_len)
		mi.mesh = bm
		mi.material_override = roof
		mi.transform = Transform3D(Basis(Vector3.RIGHT, s * slope),
			origin + Vector3(0, h + tan(slope) * half * 0.5, s * half * 0.5))
		_static.add_child(mi)
	# Gable ends.
	for s in [-1.0, 1.0]:
		var gable := _gable_mesh(d + 0.2, tan(deg_to_rad(28.0)) * (d * 0.5 + 0.1))
		var gi := MeshInstance3D.new()
		gi.mesh = gable
		gi.material_override = wall
		gi.position = origin + Vector3(s * w * 0.5, h, 0)
		_static.add_child(gi)


func _gable_mesh(width: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(0, 0, -width * 0.5), Vector3(0, 0, width * 0.5), Vector3(0, height, 0)]
	for side in [1.0, -1.0]:
		var order := [0, 1, 2] if side > 0 else [0, 2, 1]
		for i in order:
			st.set_normal(Vector3(side, 0, 0))
			st.add_vertex(p[i] + Vector3(side * 0.12, 0, 0))
	return st.commit()


func _build_targets() -> void:
	var script := preload("res://world/target.gd")
	var stand := Mats.pbr("planks", 1.0)
	var dists := [10.0, 20.0, 30.0]
	for i in dists.size():
		var body := StaticBody3D.new()
		body.set_script(script)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.88, 0.8)
		m.roughness = 0.95
		body.setup(m)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 1.8, 0.04)
		mi.mesh = bm
		mi.material_override = m
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		col.shape = bs
		body.add_child(col)
		body.position = Vector3(5.0 + dists[i], 1.0, 14.0 + i * 4.0)
		add_child(body)
		# Wooden posts holding the target.
		for sx in [-0.25, 0.25]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.06, 1.1, 0.06)
			post.mesh = pm
			post.material_override = stand
			post.position = body.position + Vector3(sx, -0.45, -0.06)
			add_child(post)
		var label := Label3D.new()
		label.text = "%d m" % int(dists[i])
		label.font_size = 64
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = body.position + Vector3(0, 1.4, 0)
		add_child(label)


func _build_pickups() -> void:
	var crate := Mats.pbr("planks", 0.6, Color(0.9, 0.85, 0.75))
	var spots := [Vector3(4, 0, 4), Vector3(-6, 0, 8), Vector3(14, 2.0, -9.5), Vector3(-24, 0.25, -18), Vector3(25, 0, -25)]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.45, 0.45)
	for p in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = crate
		mi.position = p + Vector3(0, 0.23, 0)
		mi.add_to_group("pickup")
		add_child(mi)


## Park planting: a ring of broadleaf shade trees inside the hedge, groups of tall
## palms and broadleaf trees on the lawn, and a few pines. Every kind is a MultiMesh
## (two draw calls: bark + leaves), quality.gd range-culls them with the park.
func _build_trees() -> void:
	var bark := Mats.pbr_uv("bark", 1.0, Color(0.9, 0.85, 0.8), 0.95)
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var needles := Mats.foliage("res://assets/foliage/pine_branch.png")
	var leaves := Mats.foliage("res://assets/foliage/leaf_cluster.png")
	var palm_bark := Mats.pbr_uv("palmbark", 1.0, Color(0.95, 0.9, 0.85), 0.95)
	palm_bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fronds := Mats.foliage("res://assets/foliage/palm_frond.png")
	# 0, 1: broadleaf shade trees, 2: palm, 3: pine. Few kinds = few draw calls; scale,
	# rotation and the per-tree tint in foliage.gdshader hide the repetition.
	var kinds: Array[ArrayMesh] = [
		TreeBuilder.build(71, bark, leaves, 0), TreeBuilder.build(83, bark, leaves, 0),
		Props.palm(911, palm_bark, fronds), PineBuilder.build(107, bark, needles)]
	var per: Array = []
	for k in kinds:
		per.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var trunk_body := StaticBody3D.new()
	add_child(trunk_body)
	var placed: Array[Vector3] = []

	# Shade-tree avenue just inside the hedge.
	var ring := 35.5
	for side in 4:
		var out := Vector3(1, 0, 0).rotated(Vector3.UP, -side * PI * 0.5)
		var along := out.cross(Vector3.UP)
		var t := -30.0
		while t <= 30.0:
			var p := out * ring + along * (t + rng.randf_range(-1.0, 1.0))
			if _tree_ok(p, placed, 6.0):
				_add_tree(per, rng.randi_range(0, 1), p, rng.randf_range(0.85, 1.1), rng, trunk_body, 0.3)
				placed.append(p)
			t += 10.0
	# Lawn groups: palms in threes, broadleaf pairs and a few pines.
	var tries := 0
	var groups := 0
	while groups < 9 and tries < 400:
		tries += 1
		var c := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))
		if not _tree_ok(c, placed, 9.0):
			continue
		groups += 1
		var palms := groups % 3 != 0
		var n := 3 if palms else 2
		for i in n:
			var p := c + Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			if not _tree_ok(p, placed, 2.2):
				continue
			var kind := 2 if palms else rng.randi_range(0, 1)
			if not palms and groups == 9:
				kind = 3
			_add_tree(per, kind, p, rng.randf_range(0.8, 1.2), rng, trunk_body, 0.25)
			placed.append(p)
	for k in kinds.size():
		_multimesh(kinds[k], per[k], GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


## Free spot for a tree: off the training course, the house, the fountain plaza,
## the path from the start point and the shooting lanes, and not too close to others.
func _tree_ok(p: Vector3, placed: Array[Vector3], min_gap: float) -> bool:
	if absf(p.x) > 37.5 or absf(p.z) > 37.5:
		return false
	if absf(p.x) < 18.0 and p.z < 2.0 and p.z > -50.0:
		return false
	if p.distance_to(Vector3(-24, 0, -18)) < 8.0 or p.distance_to(Vector3(0, 0, 30)) < 6.0:
		return false
	if p.distance_to(FOUNTAIN) < 8.5:
		return false
	if absf(p.x - 2.0) < 4.0 and p.z > 0.0:
		return false
	if p.x > 3.0 and p.x < 38.0 and p.z > 11.0 and p.z < 25.0:
		return false   # practice targets and their firing line
	for q in placed:
		if q.distance_to(p) < min_gap:
			return false
	return true


func _add_tree(per: Array, kind: int, p: Vector3, s: float, rng: RandomNumberGenerator, body: StaticBody3D, r: float) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
	(per[kind] as Array).append(Transform3D(b, p))
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = r * s
	cs.height = 4.0
	col.shape = cs
	col.position = p + Vector3(0, 2.0, 0)
	body.add_child(col)


# ------------------------------------------------------------ hedges and flowers

## Clipped hedges around the lawn (gaps at the corners and in the middle of each
## side so the park stays open), and flower beds by the entrances and the fountain.
## Purely visual (no collision) so walking and driving in the park are unchanged.
func _build_hedges() -> void:
	var hedge_mat := StandardMaterial3D.new()
	hedge_mat.albedo_texture = load("res://assets/foliage/hedge_albedo.png")
	hedge_mat.vertex_color_use_as_albedo = true
	hedge_mat.vertex_color_is_srgb = true
	hedge_mat.uv1_triplanar = true
	hedge_mat.uv1_world_triplanar = true
	hedge_mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
	hedge_mat.roughness = 0.85
	hedge_mat.normal_enabled = true
	hedge_mat.normal_texture = load("res://assets/textures/grass_normal.jpg")
	hedge_mat.backlight_enabled = true
	hedge_mat.backlight = Color(0.12, 0.16, 0.05)
	var leaves := Mats.foliage("res://assets/foliage/leaf_cluster.png")
	var seg_len := 2.0
	var box := _hedge_box(Vector3(seg_len, 1.0, 0.9))
	box.surface_set_material(0, hedge_mat)
	var fringe := _hedge_fringe(seg_len, 1.0, 0.9, leaves)
	var xfs: Array = []
	var edge := 39.3
	for side in 4:
		var out := Vector3(1, 0, 0).rotated(Vector3.UP, -side * PI * 0.5)
		var along := out.cross(Vector3.UP)
		var basis := Basis(Vector3.UP, -side * PI * 0.5 + PI * 0.5)
		var t := -edge + 4.0
		while t < edge - 4.0:
			var gap := absf(t) < 6.0 or (side == 1 and absf(t + 2.0) < 7.0)
			if not gap:
				xfs.append(Transform3D(basis, out * edge + along * (t + seg_len * 0.5)))
			t += seg_len
	_multimesh(box, xfs, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_multimesh(fringe, xfs, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# Flower beds: low mixed bedding plants on dark mulch.
	var flowers := Mats.foliage("res://assets/foliage/flower_card.png")
	var bed_card := _crossed(0.75, 0.4, flowers)
	var mulch := Mats.pbr("dirt", 1.5, Color(0.45, 0.36, 0.3))
	var beds := [[FOUNTAIN + Vector3(0, 0, 0), 9.6, 1.4], [Vector3(-2, 0, 36.5), 3.0, 1.2],
		[Vector3(9, 0, 36.5), 3.0, 1.2], [Vector3(36.5, 0, 0), 3.0, 1.2], [Vector3(-36.5, 0, 0), 3.0, 1.2],
		[Vector3(0, 0, -36.5), 3.0, 1.2]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var plants: Array = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bd in beds:
		var c: Vector3 = bd[0]
		var r: float = bd[1]
		var w: float = bd[2]
		if r > 5.0:
			# Ring bed around the fountain plaza.
			_ring_strip(st, c + Vector3(0, 0.03, 0), r - w * 0.5, r + w * 0.5, 40)
			for i in 110:
				var a := TAU * i / 110.0 + rng.randf_range(-0.03, 0.03)
				var rr := r + rng.randf_range(-w * 0.35, w * 0.35)
				plants.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)),
					c + Vector3(cos(a) * rr, 0.02, sin(a) * rr)))
		else:
			_ring_strip(st, c + Vector3(0, 0.03, 0), 0.0, r, 18)
			for i in 26:
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * (r - 0.4)
				plants.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25)),
					c + Vector3(cos(a) * rr, 0.02, sin(a) * rr)))
	mulch.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bed_mi := MeshInstance3D.new()
	bed_mi.mesh = st.commit()
	bed_mi.material_override = mulch
	bed_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bed_mi.visibility_range_end = 90.0
	add_child(bed_mi)
	_multimesh(bed_card, plants, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


## A hedge segment: box with slightly rounded top edges and darker base (vertex colour).
func _hedge_box(size: Vector3) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = 2
	bm.subdivide_height = 2
	bm.subdivide_depth = 1
	var arr := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		# Pull the top edges in a little (clipped hedges are rounded on top).
		if v.y > size.y * 0.49:
			v.z *= 0.82
		v.y += size.y * 0.5
		verts[i] = v
		var o := lerpf(0.5, 1.05, clampf(v.y / size.y, 0.0, 1.0))
		cols[i] = Color(o, o, o)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Leaf cards poking out of the top and sides of a hedge segment (ragged silhouette).
func _hedge_fringe(length: float, h: float, depth: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 7:
		var x := -length * 0.5 + (i + 0.5) * length / 7.0
		for s in [-1.0, 0.0, 1.0]:
			var c := Vector3(x + rng.randf_range(-0.1, 0.1), h * (0.92 if s == 0.0 else 0.75), s * depth * 0.42)
			var n := Vector3(rng.randf_range(-0.3, 0.3), 1.0 if s == 0.0 else 0.4, s * 0.9).normalized()
			TreeBuilder._leaf_card(st, c, n, 0.55, Vector3(0, h * 0.5, 0), Vector3(length, h, depth), rng.randf() * TAU)
	st.generate_tangents()
	st.set_material(mat)
	return st.commit()


func _crossed(w: float, h: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var d := Vector3(cos(k * PI / 3.0), 0, sin(k * PI / 3.0)) * (w * 0.5)
		var p := [-d, d, d + Vector3(0, h, 0), -d + Vector3(0, h, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			var top: float = 1.0 - uv[i].y
			var o := lerpf(0.6, 1.05, top)
			st.set_color(Color(o, o, o, top))
			st.set_normal((Vector3.UP + d.normalized().cross(Vector3.UP) * 0.3).normalized())
			st.set_uv(uv[i])
			st.add_vertex(p[i])
	st.set_material(mat)
	return st.commit()


## Flat ring (r0 = 0 gives a disc) on the ground, world-triplanar textured.
func _ring_strip(st: SurfaceTool, c: Vector3, r0: float, r1: float, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p := [c + Vector3(cos(a0) * r0, 0, sin(a0) * r0), c + Vector3(cos(a1) * r0, 0, sin(a1) * r0),
			c + Vector3(cos(a1) * r1, 0, sin(a1) * r1), c + Vector3(cos(a0) * r1, 0, sin(a0) * r1)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p[k])


func _build_rocks() -> void:
	var rock := Mats.pbr("rock", 1.5, Color(0.92, 0.9, 0.86))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for v in 3:
		var mesh := RockBuilder.build(v + 1, rock)
		var xfs: Array = []
		for i in 6:
			var p := Vector3(rng.randf_range(-38, 38), -0.1, rng.randf_range(-38, 38))
			if absf(p.x) < 18.0 and p.z < 2.0 and p.z > -50.0:
				continue
			var s := rng.randf_range(0.35, 1.1)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		_multimesh(mesh, xfs, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


## In stage 3 each world chunk gets its own MultiMesh so far chunks can be culled.
func _multimesh(mesh: Mesh, xfs: Array, shadows: GeometryInstance3D.ShadowCastingSetting) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = shadows
	add_child(mmi)

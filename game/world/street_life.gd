extends Node3D
## Street-level life on the city blocks (not the park): shade trees in raised
## concrete planters with shrubs at their feet, fire hydrants, newspaper boxes and
## bus stops. Built once in code; cheap on the phone:
##  * all hard street furniture of a 2 x 2 block chunk is ONE merged, vertex-coloured
##    mesh (one draw call per chunk, range-culled),
##  * trees are one MultiMesh per chunk (bark + leaves = two draw calls; core/quality.gd
##    range-culls every MultiMesh under the city),
##  * furniture casts no shadows (small items; saves shadow-pass draws),
##  * colliders only for planters, hydrants and shelters.
## Positions avoid the palms / lamps of city.gd (every 11 m from t = -33) and the trash
## cans and utility boxes of street_dressing.gd.

const CHUNK := 2.0           # blocks per chunk side (matches core/quality.gd)
const TREE_T := [-27.5, -5.5, 5.5, 27.5]
const FURNITURE_RANGE := {"low": 120.0, "medium": 190.0, "high": 260.0}

var _rng := RandomNumberGenerator.new()
var _chunks := {}            # Vector2i -> {"st": SurfaceTool, "trees": Array}
var _body: StaticBody3D
var _avoid: Array[Vector3] = []
var _furniture: Array[GeometryInstance3D] = []


func _ready() -> void:
	name = "StreetLife"
	_rng.seed = 7781
	var city: Node = get_parent()
	if city == null or not ("PITCH" in city):
		return
	var pitch: float = city.get("PITCH")
	var half: float = float(city.get("BLOCK")) * 0.5
	var curb: float = city.get("CURB_H")
	var rings: int = city.get("RINGS")
	# Street dressing props already on the sidewalks.
	for c in city.get_children():
		if c is Node3D and c.scene_file_path != "":
			var f := c.scene_file_path
			if f.contains("trash_can") or f.contains("utility_box") or f.contains("bench"):
				_avoid.append((c as Node3D).global_position)
	_body = StaticBody3D.new()
	_body.name = "StreetLifeBody"
	add_child(_body)

	for i in range(-rings, rings + 1):
		for j in range(-rings, rings + 1):
			if i == 0 and j == 0:
				continue   # the park has its own planting
			var center := Vector3(i * pitch, curb, j * pitch)
			var key := Vector2i(roundi(center.x / (pitch * CHUNK)), roundi(center.z / (pitch * CHUNK)))
			if not _chunks.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				_chunks[key] = {"st": st, "trees": []}
			var ch: Dictionary = _chunks[key]
			for side in 4:
				var out := Vector3(1, 0, 0).rotated(Vector3.UP, -side * PI * 0.5)
				var along := out.cross(Vector3.UP)
				var face_yaw := atan2(out.x, out.z)
				var face := Basis(Vector3.UP, face_yaw)   # local +Z toward the road
				var bus_side := _rng.randf() < 0.3
				for t in TREE_T:
					if bus_side and absf(t - 16.5) < 4.0:
						continue
					if _rng.randf() < 0.1:
						continue
					var p: Vector3 = center + out * (half - 1.25) + along * (float(t) + _rng.randf_range(-0.4, 0.4))
					if _blocked(p, 1.4):
						continue
					_planter(ch["st"], p, face_yaw)
					var s := _rng.randf_range(0.85, 1.05)
					(ch["trees"] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), p + Vector3(0, 0.4, 0)))
					_box_col(p + Vector3(0, 0.22, 0), Vector3(1.5, 0.45, 1.5), face)
				# Fire hydrant near one end of the side.
				if _rng.randf() < 0.75:
					var tt := 38.5 if _rng.randf() < 0.5 else -38.5
					var p := center + out * (half - 0.55) + along * tt
					if not _blocked(p, 0.8):
						_hydrant(ch["st"], p, face_yaw + _rng.randf_range(-0.4, 0.4))
						_box_col(p + Vector3(0, 0.35, 0), Vector3(0.3, 0.7, 0.3), face)
				# A row of newspaper / free-magazine boxes.
				if _rng.randf() < 0.45:
					var tt := _rng.randf_range(-14.0, -9.0) if _rng.randf() < 0.5 else _rng.randf_range(31.0, 35.0)
					var p := center + out * (half - 0.6) + along * tt
					if not _blocked(p, 1.6):
						var n := _rng.randi_range(2, 3)
						for k in n:
							var q := p + along * (k - (n - 1) * 0.5) * 0.52
							_news_box(ch["st"], q, face_yaw, k)
				# Bus stop shelter, facing the road.
				if bus_side:
					var p := center + out * (half - 1.1) + along * 16.5
					if not _blocked(p, 2.0):
						_bus_stop(ch["st"], p, face_yaw)
						_box_col(p + face * Vector3(0, 1.2, -0.55), Vector3(3.6, 2.4, 0.15), face)

	var furn_mat := StandardMaterial3D.new()
	furn_mat.vertex_color_use_as_albedo = true
	furn_mat.vertex_color_is_srgb = true
	furn_mat.roughness = 0.55
	furn_mat.metallic = 0.15
	var bark := Mats.pbr_uv("bark", 1.0, Color(0.9, 0.85, 0.8), 0.95)
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaves := Mats.foliage("res://assets/foliage/leaf_cluster.png")
	var tree := TreeBuilder.build(4242, bark, leaves, 1)
	# Shrubs at the foot of every street tree go into the tree's leaf surface (no extra draw).
	var shrub := TreeBuilder.shrub(99, leaves, 0.5, 8)
	var leaf_st := SurfaceTool.new()
	leaf_st.create_from(tree, 1)
	for d in [Vector2(-0.35, 0.3), Vector2(0.35, -0.3)]:
		leaf_st.append_from(shrub, 0, Transform3D(Basis(Vector3.UP, d.x * 4.0), Vector3(d.x, 0.0, d.y)))
	var street_tree := ArrayMesh.new()
	var wood := SurfaceTool.new()
	wood.create_from(tree, 0)
	wood.set_material(bark)
	wood.commit(street_tree)
	leaf_st.set_material(leaves)
	leaf_st.commit(street_tree)

	for key in _chunks:
		var ch: Dictionary = _chunks[key]
		var st: SurfaceTool = ch["st"]
		st.set_material(furn_mat)
		var mesh := st.commit()
		if mesh.get_surface_count() > 0:
			var mi := MeshInstance3D.new()
			mi.name = "Furniture_%d_%d" % [key.x, key.y]
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # small: not worth shadow draws
			add_child(mi)
			_furniture.append(mi)
		var trees: Array = ch["trees"]
		if trees.size() > 0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = street_tree
			mm.instance_count = trees.size()
			for k in trees.size():
				mm.set_instance_transform(k, trees[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "StreetTrees_%d_%d" % [key.x, key.y]
			mmi.multimesh = mm
			add_child(mmi)
	_apply_range.call_deferred()
	Settings.changed.connect(func(k: String) -> void:
		if k in ["quality_preset", "draw_distance", "battery_saver"]:
			_apply_range())


func _apply_range() -> void:
	var q := get_tree().root.find_child("Quality", true, false) if is_inside_tree() else null
	var preset := str(q.get("effective")) if q else "medium"
	var r: float = FURNITURE_RANGE.get(preset, 190.0)
	if Settings.get_value("battery_saver"):
		r = minf(r, 120.0)
	for g in _furniture:
		g.visibility_range_end = r
		g.visibility_range_end_margin = 10.0


func _blocked(p: Vector3, r: float) -> bool:
	for a in _avoid:
		if Vector2(a.x - p.x, a.z - p.z).length() < r:
			return true
	_avoid.append(p)
	return false


func _box_col(pos: Vector3, size: Vector3, b: Basis) -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.transform = Transform3D(b, pos)
	_body.add_child(col)


# ------------------------------------------------------------ meshes (merged)

func _prim(st: SurfaceTool, m: PrimitiveMesh, xf: Transform3D, c: Color) -> void:
	var arr := m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	for i in idx:
		st.set_color(c)
		st.set_normal((nb * n[i]).normalized())
		st.add_vertex(xf * v[i])


func _box(st: SurfaceTool, size: Vector3, xf: Transform3D, c: Color) -> void:
	var b := BoxMesh.new()
	b.size = size
	_prim(st, b, xf, c)


func _cyl(st: SurfaceTool, rt: float, rb: float, h: float, xf: Transform3D, c: Color, seg := 10) -> void:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = mini(seg, 8)
	m.rings = 1
	_prim(st, m, xf, c)


func _planter(st: SurfaceTool, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var stone := Color(0.56, 0.54, 0.5)
	var dark := Color(0.46, 0.44, 0.41)
	# Four walls with a slightly lighter coping, dark mulch inside.
	for k in 4:
		var d := Vector3(1, 0, 0).rotated(Vector3.UP, k * PI * 0.5)
		var size := Vector3(0.14, 0.45, 1.5)
		var xf := Transform3D(b * Basis(Vector3.UP, k * PI * 0.5), p + b * (d * 0.68) + Vector3(0, 0.225, 0))
		_box(st, size, xf, dark)
		_box(st, Vector3(0.2, 0.05, 1.56), Transform3D(xf.basis, xf.origin + Vector3(0, 0.25, 0)), stone)
	_box(st, Vector3(1.3, 0.04, 1.3), Transform3D(b, p + Vector3(0, 0.38, 0)), Color(0.2, 0.15, 0.11))


func _hydrant(st: SurfaceTool, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var red := Color(0.72, 0.1, 0.07) if _rng.randf() < 0.7 else Color(0.85, 0.65, 0.1)
	var cap := Color(0.82, 0.8, 0.76)
	_cyl(st, 0.14, 0.15, 0.06, Transform3D(b, p + Vector3(0, 0.03, 0)), red)
	_cyl(st, 0.1, 0.11, 0.5, Transform3D(b, p + Vector3(0, 0.31, 0)), red)
	_cyl(st, 0.125, 0.125, 0.05, Transform3D(b, p + Vector3(0, 0.55, 0)), red)
	_cyl(st, 0.03, 0.11, 0.1, Transform3D(b, p + Vector3(0, 0.62, 0)), cap)
	for s in [-1.0, 1.0]:
		var nb := b * Basis(Vector3(0, 0, 1), PI * 0.5)
		_cyl(st, 0.045, 0.045, 0.1, Transform3D(nb, p + b * Vector3(s * 0.13, 0.4, 0)), cap, 8)
	_cyl(st, 0.06, 0.06, 0.08, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), p + b * Vector3(0, 0.38, 0.12)), cap, 8)


func _news_box(st: SurfaceTool, p: Vector3, yaw: float, k: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var cols := [Color(0.1, 0.25, 0.6), Color(0.75, 0.1, 0.08), Color(0.1, 0.45, 0.25), Color(0.9, 0.75, 0.15), Color(0.85, 0.85, 0.82)]
	var c: Color = cols[(k + _rng.randi_range(0, 4)) % cols.size()]
	var legs := Color(0.15, 0.15, 0.16)
	for sx in [-0.18, 0.18]:
		_box(st, Vector3(0.04, 0.4, 0.38), Transform3D(b, p + b * Vector3(sx, 0.2, 0)), legs)
	_box(st, Vector3(0.46, 0.62, 0.42), Transform3D(b, p + Vector3(0, 0.71, 0)), c)
	# Window (dark glass) facing the sidewalk and a sloped top.
	_box(st, Vector3(0.36, 0.26, 0.02), Transform3D(b, p + b * Vector3(0, 0.82, -0.215)), Color(0.08, 0.09, 0.1))
	_box(st, Vector3(0.3, 0.14, 0.01), Transform3D(b, p + b * Vector3(0, 0.82, -0.222)), Color(0.85, 0.82, 0.75))
	_box(st, Vector3(0.48, 0.04, 0.44), Transform3D(b * Basis(Vector3.RIGHT, 0.12), p + Vector3(0, 1.04, 0)), c.darkened(0.2))


func _bus_stop(st: SurfaceTool, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var frame := Color(0.2, 0.22, 0.24)
	var roof := Color(0.82, 0.84, 0.86)
	# +Z (local) faces the road; the back panel is on -Z.
	for sx in [-1.7, 1.7]:
		for sz in [-0.55, 0.45]:
			_box(st, Vector3(0.07, 2.4, 0.07), Transform3D(b, p + b * Vector3(sx, 1.2, sz)), frame)
	_box(st, Vector3(3.7, 0.08, 1.4), Transform3D(b * Basis(Vector3.RIGHT, -0.05), p + b * Vector3(0, 2.45, -0.05)), roof)
	_box(st, Vector3(3.6, 0.06, 0.08), Transform3D(b, p + b * Vector3(0, 2.4, 0.62)), frame)
	# Back panel: smoky glass look + a bright lit advert on one end.
	_box(st, Vector3(2.3, 1.7, 0.03), Transform3D(b, p + b * Vector3(-0.6, 1.25, -0.55)), Color(0.35, 0.42, 0.45))
	_box(st, Vector3(1.0, 1.7, 0.1), Transform3D(b, p + b * Vector3(1.15, 1.25, -0.55)), Color(0.95, 0.6, 0.25))
	_box(st, Vector3(0.9, 1.55, 0.11), Transform3D(b, p + b * Vector3(1.15, 1.25, -0.55)), Color(0.98, 0.92, 0.8))
	# Bench.
	_box(st, Vector3(2.0, 0.05, 0.4), Transform3D(b, p + b * Vector3(-0.5, 0.46, -0.3)), Color(0.55, 0.36, 0.2))
	for sx in [-1.3, 0.3]:
		_box(st, Vector3(0.05, 0.45, 0.35), Transform3D(b, p + b * Vector3(sx, 0.22, -0.3)), frame)
	# Route sign pole at the kerb.
	_cyl(st, 0.035, 0.035, 2.6, Transform3D(b, p + b * Vector3(2.2, 1.3, 0.7)), frame, 6)
	_box(st, Vector3(0.45, 0.32, 0.04), Transform3D(b, p + b * Vector3(2.2, 2.45, 0.7)), Color(0.1, 0.35, 0.65))

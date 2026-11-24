extends Node3D
## Long-distance sniper range outside the city (beyond the -Z edge).
##  * firing line with a roofed shooting bench at FIRING_LINE, shooting toward -Z
##  * steel silhouettes at 100, 200 ... 1000 m, fanned out left and right so none hides
##    another, each with its distance written above it
##  * its own terrain: grass plain, dirt firing lane, side berms, a high backstop hill,
##    pines and rocks
##  * teleport markers: one in the city park, one at the firing line (context button)

signal target_hit(target: Node, offset: Vector2)

const FIRING_LINE := Vector3(0, 0, -800)
const PARK_MARKER := Vector3(3, 0, 37)
const DISTANCES := [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
const AREA_MIN_Z := -2300.0
const AREA_MAX_Z := -372.0

var module: Node        # sniper.gd
var targets: Array = []
var _static: StaticBody3D


func _ready() -> void:
	_static = StaticBody3D.new()
	_static.name = "RangeStatic"
	add_child(_static)
	_build_ground()
	_build_berms()
	_build_firing_line()
	_build_targets()
	_build_vegetation()
	_add_marker(PARK_MARKER, "ctx_range_go", true)
	_add_marker(FIRING_LINE + Vector3(5, 0, 3), "ctx_range_back", false)


func contains(p: Vector3) -> bool:
	return p.z < AREA_MAX_Z - 200.0 and p.z > AREA_MIN_Z and absf(p.x) < 700.0


## Where the player stands when arriving.
func arrival_point() -> Vector3:
	return FIRING_LINE + Vector3(0, 0.2, 1.0)


func target_at(d: int) -> Node:
	for t in targets:
		if int(t.distance_m) == d:
			return t
	return null


# ------------------------------------------------------------ terrain

func _build_ground() -> void:
	var size_z := AREA_MAX_Z - AREA_MIN_Z
	var mid_z := (AREA_MAX_Z + AREA_MIN_Z) * 0.5
	_plane(Vector2(1600, size_z), Vector3(0, 0, mid_z), Mats.pbr("grass", 5.0, Color(0.85, 0.88, 0.7)))
	_plane(Vector2(170, 1090), Vector3(0, 0.012, FIRING_LINE.z - 545.0), Mats.pbr("dirt", 4.0, Color(0.95, 0.9, 0.82)))
	# Invisible walls so nobody walks off into the void.
	var walls := [
		[Vector3(0, 10, AREA_MAX_Z - 340.0), Vector3(400, 20, 1)],
		[Vector3(0, 10, -1900.0), Vector3(400, 20, 1)],
		[Vector3(-160, 10, -1300.0), Vector3(1, 20, 1300)],
		[Vector3(160, 10, -1300.0), Vector3(1, 20, 1300)],
	]
	for w in walls:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		col.shape = bs
		col.position = w[0]
		_static.add_child(col)


func _plane(s: Vector2, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = s
	pm.material = mat
	mi.mesh = pm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_berms() -> void:
	var dirt: StandardMaterial3D = Mats.pbr("dirt", 6.0, Color(0.82, 0.74, 0.62)).duplicate()
	dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Side berms along the lane and a tall backstop behind the 1000 m line.
	_prism(st, Vector3(-135, 0, -1320), Vector3(22, 7, 1100))
	_prism(st, Vector3(135, 0, -1320), Vector3(22, 7, 1100))
	_prism(st, Vector3(0, 0, -1880), Vector3(420, 34, 70), true)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = dirt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for b in [[Vector3(-135, 3.5, -1320), Vector3(14, 7, 1100)], [Vector3(135, 3.5, -1320), Vector3(14, 7, 1100)],
			[Vector3(0, 17, -1880), Vector3(420, 34, 40)]]:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		col.shape = bs
		col.position = b[0]
		_static.add_child(col)


## A mound with a flat top, long along Z (or along X when across).
func _prism(st: SurfaceTool, c: Vector3, s: Vector3, across := false) -> void:
	var hw := s.x * 0.5
	var hl := s.z * 0.5
	var top := hw * 0.3
	if across:
		hw = s.z * 0.5
		hl = s.x * 0.5
		top = hw * 0.25
	var prof := [Vector2(-hw, 0), Vector2(-top, s.y), Vector2(top, s.y), Vector2(hw, 0)]
	for i in 3:
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		var q := [Vector3(a.x, a.y, -hl), Vector3(b.x, b.y, -hl), Vector3(b.x, b.y, hl), Vector3(a.x, a.y, hl)]
		for j in 4:
			if across:
				q[j] = Vector3(q[j].z, q[j].y, q[j].x)
			q[j] += c
		_quad(st, q, across)
	# End caps.
	for end in [-1.0, 1.0]:
		var cap: Array = []
		for pt in prof:
			var v := Vector3(pt.x, pt.y, end * hl)
			if across:
				v = Vector3(v.z, v.y, v.x)
			cap.append(v + c)
		var order := [0, 1, 2, 0, 2, 3] if (end > 0.0) != across else [0, 2, 1, 0, 3, 2]
		for idx in order:
			st.add_vertex(cap[idx])


func _quad(st: SurfaceTool, q: Array, flip: bool) -> void:
	for idx in ([0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]):
		st.add_vertex(q[idx])


func _build_firing_line() -> void:
	var concrete := Mats.pbr("concrete", 2.0, Color(0.75, 0.74, 0.7))
	var wood := Mats.pbr("planks", 1.5)
	var metal := Mats.plain(Color(0.2, 0.21, 0.22), 0.5, 0.6)
	var o := FIRING_LINE
	_box(Vector3(18, 0.15, 9), o + Vector3(0, 0.075, 1.5), concrete, true)
	for x in [-8.5, 8.5]:
		for z in [-2.5, 5.5]:
			_box(Vector3(0.2, 3.2, 0.2), o + Vector3(x, 1.75, z), metal, true)
	_box(Vector3(18.6, 0.12, 9.4), o + Vector3(0, 3.4, 1.5), metal, false)
	# Shooting benches.
	for x in [-5.0, 0.0, 5.0]:
		_box(Vector3(1.6, 0.06, 0.8), o + Vector3(x + 1.6, 0.85, -1.2), wood, true)
		_box(Vector3(0.1, 0.8, 0.6), o + Vector3(x + 1.0, 0.45, -1.2), wood, false)
		_box(Vector3(0.1, 0.8, 0.6), o + Vector3(x + 2.2, 0.45, -1.2), wood, false)
	# Distance posts down the centre line (targets sit at least 20 mrad off it).
	var white := Mats.plain(Color(0.92, 0.92, 0.9), 0.7)
	for d in DISTANCES:
		_box(Vector3(0.18, 0.7, 0.18), o + Vector3(0, 0.35, -float(d)), white, false)
	var sign := Label3D.new()
	sign.text = Loc.t("snp_range_title")
	sign.font_size = 96
	sign.pixel_size = 0.008
	sign.outline_size = 16
	sign.position = o + Vector3(0, 4.2, 5.8)
	sign.rotation.y = PI
	add_child(sign)


func _box(s: Vector3, pos: Vector3, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s
		col.shape = bs
		col.position = pos
		_static.add_child(col)


func _build_targets() -> void:
	var script := preload("res://weapons/sniper/range_target.gd")
	var post_mat := Mats.plain(Color(0.25, 0.24, 0.22), 0.6, 0.4)
	var mark := QuadMesh.new()
	mark.size = Vector2(0.05, 0.05)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.12, 0.1, 0.09)
	mm.roughness = 1.0
	mark.material = mm
	var left := 0
	var right := 0
	for i in DISTANCES.size():
		var d := float(DISTANCES[i])
		# Fan the plates out: 20, 32, 44 ... mrad left and right of the centre line.
		var side := -1.0 if i % 2 == 0 else 1.0
		var j := left if side < 0.0 else right
		if side < 0.0:
			left += 1
		else:
			right += 1
		var ang := 0.02 + 0.012 * j
		var x := side * d * tan(ang)
		var w := 0.45 + d * 0.0011
		var body_h := w * 1.25
		var hinge_y := 0.45 + body_h
		var base := Vector3(x, 0, FIRING_LINE.z - d)
		var hinge := Node3D.new()
		hinge.position = base + Vector3(0, hinge_y, 0)
		add_child(hinge)
		var plate := StaticBody3D.new()
		plate.set_script(script)
		plate.collision_layer = 1
		plate.collision_mask = 0
		hinge.add_child(plate)
		plate.build(w, mark)
		plate.distance_m = d
		plate.hinge = hinge
		plate.plate_hit.connect(func(t, off): target_hit.emit(t, off))
		targets.append(plate)
		# Frame: two posts and a crossbar at the hinge.
		var post_h := hinge_y + w * 0.5
		for sx in [-1.0, 1.0]:
			var p := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.06 + d * 0.00006, post_h, 0.06 + d * 0.00006)
			p.mesh = pm
			p.material_override = post_mat
			p.position = base + Vector3(sx * (w * 0.5 + 0.12), post_h * 0.5, -0.1)
			add_child(p)
		var bar := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(w + 0.3, 0.05 + d * 0.00005, 0.05)
		bar.mesh = bmesh
		bar.material_override = post_mat
		bar.position = base + Vector3(0, hinge_y + 0.02, -0.1)
		add_child(bar)
		var label := Label3D.new()
		label.text = str(int(d))
		label.font_size = 96
		label.pixel_size = 0.0012 + d * 0.000018
		label.outline_size = 18
		label.modulate = Color(1.0, 0.92, 0.3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = base + Vector3(0, post_h + 0.6 + label.pixel_size * 60.0, 0)
		add_child(label)


func _build_vegetation() -> void:
	var bark := Mats.pbr_uv("bark", 1.0, Color(0.9, 0.85, 0.8), 0.95)
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var needles := Mats.foliage("res://assets/foliage/pine_branch.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var xfs: Array = [[], []]
	for i in 110:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(150, 420), 0, rng.randf_range(-1950, -620))
		var s := rng.randf_range(1.2, 2.4)
		xfs[i % 2].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	for i in 40:
		var p := Vector3(rng.randf_range(-420, 420), 30.0 + rng.randf_range(-3, 2), rng.randf_range(-1905, -1870))
		var s := rng.randf_range(1.4, 2.6)
		xfs[i % 2].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	for v in 2:
		_multimesh(PineBuilder.build(500 + v * 13, bark, needles), xfs[v], 900.0)
	var rock := Mats.pbr("rock", 1.5, Color(0.92, 0.9, 0.86))
	for v in 2:
		var rx: Array = []
		for i in 14:
			var side := -1.0 if i % 2 == 0 else 1.0
			var p := Vector3(side * rng.randf_range(95, 125), -0.15, rng.randf_range(-1800, -760))
			var s := rng.randf_range(0.8, 2.2)
			rx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		_multimesh(RockBuilder.build(v + 7, rock), rx, 700.0)


func _multimesh(mesh: Mesh, xfs: Array, range_end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end
	add_child(mmi)


# ------------------------------------------------------------ markers

func _add_marker(pos: Vector3, label_key: String, to_range: bool) -> void:
	var m := Node3D.new()
	m.set_script(preload("res://weapons/sniper/range_marker.gd"))
	m.position = pos
	m.set_meta("ctx_label", label_key)
	m.module = module
	m.to_range = to_range
	add_child(m)

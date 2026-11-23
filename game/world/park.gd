extends Node3D
## Central park block: lawn (ground shader), training course, small house,
## practice targets, crates to pick up, pine trees and rocks.

const PARK_HALF := 41.0
const CURB := 0.0

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


func _build_trees() -> void:
	var bark := Mats.pbr_uv("bark", 1.0, Color(0.9, 0.85, 0.8), 0.95)
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var needles := Mats.foliage("res://assets/foliage/pine_branch.png")
	var variants: Array[ArrayMesh] = []
	for v in 3:
		variants.append(PineBuilder.build(100 + v * 7, bark, needles))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var per_variant: Array = [[], [], []]
	var trunk_body := StaticBody3D.new()
	add_child(trunk_body)
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 2000:
		tries += 1
		var p := Vector3(rng.randf_range(-37, 37), 0, rng.randf_range(-37, 37))
		if absf(p.x) < 18.0 and p.z < 2.0 and p.z > -50.0:
			continue  # keep the training course clear
		if p.distance_to(Vector3(-24, 0, -18)) < 8.0 or p.distance_to(Vector3(0, 0, 30)) < 6.0:
			continue
		if absf(p.x) < 4.0 and p.z > 0.0:
			continue
		var s := rng.randf_range(0.8, 1.15)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		per_variant[placed % 3].append(Transform3D(b, p))
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.3 * s
		cs.height = 4.0
		col.shape = cs
		col.position = p + Vector3(0, 2.0, 0)
		trunk_body.add_child(col)
		placed += 1
	for v in 3:
		_multimesh(variants[v], per_variant[v], GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


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

extends Node3D
## Stage-1 test ground (400 x 400 m). Everything is generated in code:
## a traversal course (step / vault / climb), stairs, a small house,
## practice targets, crates to pick up and MultiMesh trees and rocks.
## The real streamed open world arrives in stage 3.

const SIZE := 400.0

var sun: DirectionalLight3D
var _mats := {}
var _static: StaticBody3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_static = StaticBody3D.new()
	_static.name = "Course"
	add_child(_static)
	_build_course()
	_build_house(Vector3(-14, 0, -18))
	_build_targets()
	_build_pickups()
	_build_vegetation()
	Settings.changed.connect(_on_setting)
	_apply_shadows()


func _on_setting(key: String) -> void:
	if key in ["shadows", "battery_saver"]:
		_apply_shadows()


func _apply_shadows() -> void:
	sun.shadow_enabled = Perf.shadows_enabled()


# ------------------------------------------------------------ environment

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.48, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.88)
	sky_mat.ground_horizon_color = Color(0.6, 0.66, 0.7)
	sky_mat.ground_bottom_color = Color(0.25, 0.28, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY  # sky is static: render it once into a cubemap
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.9)
	# One sun shadow with a short range: cheap on mobile.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 1.0
	add_child(sun)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/ground_grid.gdshader")
	pm.material = mat
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	add_child(body)
	# Invisible walls at the edge so the player cannot walk off the test ground.
	for i in 4:
		var wall := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(SIZE, 20, 1)
		wall.shape = bs
		wall.rotation.y = i * PI * 0.5
		wall.position = Vector3(0, 10, -SIZE * 0.5).rotated(Vector3.UP, i * PI * 0.5)
		body.add_child(wall)


func _mat(key: String, c: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


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
	var concrete := _mat("concrete", Color(0.62, 0.6, 0.56))
	var orange := _mat("orange", Color(0.9, 0.5, 0.2))
	var blue := _mat("blue", Color(0.3, 0.45, 0.7))
	var z := -10.0
	# Small step (auto step-up), vault box (auto vault), climb wall, too-high wall.
	_block(Vector3(3, 0.3, 1.5), Vector3(-6, 0.15, z), concrete)
	_block(Vector3(3, 1.0, 0.8), Vector3(-2, 0.5, z), orange)
	_block(Vector3(3, 2.0, 2.0), Vector3(2.5, 1.0, z), blue)
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
	ramp.material_override = orange
	var t := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(16)), Vector3(-12, 1.0, -4))
	ramp.transform = t
	_static.add_child(ramp)
	var rc := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = bm.size
	rc.shape = rs
	rc.transform = t
	_static.add_child(rc)
	# Long crates line to test sprint + vault chains.
	for i in 4:
		_block(Vector3(1.5, 0.9, 0.8), Vector3(-2, 0.45, -24 - i * 6), orange)


func _build_house(origin: Vector3) -> void:
	var wall := _mat("wall", Color(0.85, 0.82, 0.74))
	var roof := _mat("roof", Color(0.55, 0.3, 0.25))
	var w := 8.0
	var d := 6.0
	var h := 3.0
	_block(Vector3(w, h, 0.25), origin + Vector3(0, h * 0.5, -d * 0.5), wall)
	_block(Vector3(0.25, h, d), origin + Vector3(-w * 0.5, h * 0.5, 0), wall)
	_block(Vector3(0.25, h, d), origin + Vector3(w * 0.5, h * 0.5, 0), wall)
	# Front wall with a doorway.
	_block(Vector3(3.2, h, 0.25), origin + Vector3(-2.4, h * 0.5, d * 0.5), wall)
	_block(Vector3(3.2, h, 0.25), origin + Vector3(2.4, h * 0.5, d * 0.5), wall)
	_block(Vector3(1.6, 0.8, 0.25), origin + Vector3(0, h - 0.4, d * 0.5), wall)
	_block(Vector3(w + 0.6, 0.25, d + 0.6), origin + Vector3(0, h + 0.12, 0), roof)


func _build_targets() -> void:
	var script := preload("res://world/target.gd")
	var dists := [15.0, 30.0, 50.0, 80.0]
	for i in dists.size():
		var body := StaticBody3D.new()
		body.set_script(script)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.92, 0.86)
		body.setup(m)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 1.8, 0.1)
		mi.mesh = bm
		mi.material_override = m
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		col.shape = bs
		body.add_child(col)
		body.position = Vector3(-8 + i * 5.0, 0.9, 10 + dists[i])
		add_child(body)
		var label := Label3D.new()
		label.text = "%d m" % int(dists[i])
		label.font_size = 64
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = body.position + Vector3(0, 1.4, 0)
		add_child(label)


func _build_pickups() -> void:
	var crate := _mat("crate", Color(0.55, 0.4, 0.22))
	var spots := [Vector3(4, 0, 4), Vector3(-6, 0, 8), Vector3(14, 2.0, -9.5), Vector3(-14, 0, -18), Vector3(20, 0, 20)]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.45, 0.45)
	for p in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = crate
		mi.position = p + Vector3(0, 0.23, 0)
		mi.add_to_group("pickup")
		add_child(mi)


func _build_vegetation() -> void:
	# MultiMesh: hundreds of trees and rocks in very few draw calls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.material = _mat("trunk", Color(0.36, 0.26, 0.18))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.6
	crown.height = 4.5
	crown.radial_segments = 7
	crown.rings = 1
	crown.material = _mat("leaf", Color(0.2, 0.36, 0.18))
	var rock := SphereMesh.new()
	rock.radius = 0.7
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	rock.material = _mat("rock", Color(0.5, 0.5, 0.48))

	var count := 220
	var trees: Array[Transform3D] = []
	var trunk_body := StaticBody3D.new()
	add_child(trunk_body)
	while trees.size() < count:
		var p := Vector3(rng.randf_range(-190, 190), 0, rng.randf_range(-190, 190))
		if p.length() < 35.0:
			continue  # keep the training area clear
		var s := rng.randf_range(0.8, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		trees.append(Transform3D(b, p))
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.25 * s
		cs.height = 3.0 * s
		col.shape = cs
		col.position = p + Vector3(0, 1.5 * s, 0)
		trunk_body.add_child(col)
	var trunk_xf: Array[Transform3D] = []
	var crown_xf: Array[Transform3D] = []
	for t in trees:
		var s := t.basis.get_scale().x
		trunk_xf.append(t.translated(Vector3(0, 1.5 * s, 0)))
		crown_xf.append(t.translated(Vector3(0, 4.6 * s, 0)))
	_multimesh(trunk, trunk_xf)
	_multimesh(crown, crown_xf)

	var rocks: Array[Transform3D] = []
	for i in 160:
		var p := Vector3(rng.randf_range(-190, 190), -0.15, rng.randf_range(-190, 190))
		if p.length() < 20.0:
			continue
		var s := rng.randf_range(0.4, 1.3)
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), p))
	_multimesh(rock, rocks)


## In stage 3 each world chunk gets its own MultiMesh so far chunks can be culled.
func _multimesh(mesh: Mesh, xfs: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

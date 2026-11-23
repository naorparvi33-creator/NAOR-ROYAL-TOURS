extends MultiMeshInstance3D
## Dry leaves and bits of paper skittering along the ground in the wind, around the
## camera. One MultiMesh, one draw call; the shader moves, tumbles and wraps every
## piece inside a box that follows the camera. Off with the grass setting (low preset)
## and in battery saver.

const COUNT := 60


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/blowing_leaves.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A slightly folded leaf (two triangles bent along the middle).
	var p := [Vector3(-0.035, 0, -0.045), Vector3(0, 0.01, -0.06), Vector3(0.035, 0, 0.045), Vector3(0, 0.01, 0.06)]
	for k in [0, 1, 3, 1, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(p[k].x + 0.5, p[k].z + 0.5))
		st.add_vertex(p[k])
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var cols := [Color(0.36, 0.25, 0.12), Color(0.45, 0.33, 0.15), Color(0.3, 0.21, 0.11), Color(0.42, 0.34, 0.14),
		Color(0.34, 0.33, 0.2), Color(0.75, 0.74, 0.7)]
	for i in COUNT:
		var s := rng.randf_range(0.8, 1.5)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(rng.randf() * 36.0, 0, rng.randf() * 36.0)))
		var c: Color = cols[rng.randi() % cols.size()]
		if c.r > 0.85:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.6, 1, 1.3)), Vector3(rng.randf() * 36.0, 0, rng.randf() * 36.0)))
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, Color(rng.randf_range(0.6, 1.6), rng.randf() * TAU, rng.randf_range(2.0, 7.0), rng.randf()))
	multimesh = mm
	custom_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 6, 40))
	Settings.changed.connect(func(k: String) -> void:
		if k in ["grass", "battery_saver"]:
			_apply())
	_apply()


func _apply() -> void:
	visible = bool(Settings.get_value("grass")) and not Settings.get_value("battery_saver")


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and visible:
		var p := cam.global_position
		global_position = Vector3(p.x, 0.0, p.z)   # keeps the culling box on the camera

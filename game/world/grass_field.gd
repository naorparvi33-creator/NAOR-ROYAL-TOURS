extends MultiMeshInstance3D
## Grass around the player: one MultiMesh of crossed cards on a grid that follows
## the camera in whole grid steps (the shader keeps each clump fixed in the world).

const SPACING := 0.55
const RADIUS := 20.0

var follow: Node3D


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/grass.gdshader")
	mat.set_shader_parameter("card", preload("res://assets/foliage/grass_card.png"))
	mat.set_shader_parameter("spacing", SPACING)
	# No lawn on the fountain plaza and its flower ring (world/park.gd).
	var f: Vector3 = preload("res://world/park.gd").FOUNTAIN
	mat.set_shader_parameter("clear_spots", PackedVector4Array([Vector4(f.x, f.z, 10.3, 0), Vector4(0, 0, -1, 0),
		Vector4(0, 0, -1, 0), Vector4(0, 0, -1, 0)]))
	var mesh := _crossed_cards(0.9, 0.42)
	mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var pts: Array[Vector3] = []
	var n := int(RADIUS / SPACING)
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var p := Vector3(x * SPACING, 0, z * SPACING)
			if p.length() <= RADIUS:
				pts.append(p)
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	multimesh = mm
	# The shader moves vertices, so give culling a safe box.
	custom_aabb = AABB(Vector3(-RADIUS - 1, -1, -RADIUS - 1), Vector3(RADIUS * 2 + 2, 3, RADIUS * 2 + 2))
	Settings.changed.connect(func(k):
		if k in ["grass", "battery_saver"]:
			_apply())
	_apply()


func _apply() -> void:
	visible = bool(Settings.get_value("grass")) and not Settings.get_value("battery_saver")


func _process(_delta: float) -> void:
	if follow == null:
		return
	var p := follow.global_position
	global_position = Vector3(snappedf(p.x, SPACING), 0.0, snappedf(p.z, SPACING))


func _crossed_cards(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var d := Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5)) * (w * 0.5)
		var p := [-d, d, d + Vector3(0, h, 0), -d + Vector3(0, h, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(p[i])
	return st.commit()

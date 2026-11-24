extends StaticBody3D
## Steel silhouette plate on the sniper range. Swings back on its hinge and rings
## when hit, keeps the last few impact marks (so you can see your grouping) and
## reports where the bullet landed relative to the centre of the chest.

signal plate_hit(target: Node, offset: Vector2)

var distance_m := 100.0
var width := 0.6
var center_local := Vector3.ZERO       # chest centre (aim point) in local space
var _zone := "body"
var _offset := Vector2.ZERO            # metres: x right, y up
var _swing := 0.0
var _swing_v := 0.0
var _flash := 0.0
var _mat: StandardMaterial3D
var _base := Color(0.92, 0.9, 0.86)
var _marks: Array[MeshInstance3D] = []
var _mark_i := 0
var hinge: Node3D


func is_range_target() -> bool:
	return true


func last_zone() -> String:
	return _zone


func last_offset() -> Vector2:
	return _offset


func aim_point() -> Vector3:
	return global_transform * center_local


## Builds the plate: body rectangle, head and a painted centre ring.
func build(w: float, mark_mesh: Mesh) -> void:
	width = w
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base
	_mat.roughness = 0.55
	_mat.metallic = 0.3
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.85, 0.18, 0.1)
	ring_mat.roughness = 0.6
	var body_h := w * 1.25
	var head := w * 0.42
	_part(Vector3(w, body_h, 0.03), Vector3(0, -body_h * 0.5, 0), _mat)
	_part(Vector3(head, head, 0.03), Vector3(0, head * 0.5 + 0.01, 0), _mat)
	center_local = Vector3(0, -body_h * 0.45, 0.02)
	# Painted ring: a thin flat cylinder facing the shooter (+Z).
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = w * 0.17
	cm.bottom_radius = w * 0.17
	cm.height = 0.004
	cm.radial_segments = 20
	cm.rings = 1
	ring.mesh = cm
	ring.material_override = ring_mat
	ring.rotation.x = PI * 0.5
	ring.position = center_local
	add_child(ring)
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = mark_mesh
		mi.visible = false
		mi.scale = Vector3.ONE * clampf(w * 0.08, 0.04, 0.1) / 0.05
		add_child(mi)
		_marks.append(mi)
	set_process(false)


func _part(s: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = s
	col.shape = bs
	col.position = pos
	add_child(col)


func on_hit(point: Vector3, _damage := 0.0, _dir := Vector3.ZERO, _bullet := true) -> void:
	var lp := global_transform.affine_inverse() * point
	_offset = Vector2(lp.x - center_local.x, lp.y - center_local.y)
	var head_y := 0.0
	_zone = "head" if lp.y > head_y else ("center" if _offset.length() <= width * 0.17 else "body")
	var mi := _marks[_mark_i]
	_mark_i = (_mark_i + 1) % _marks.size()
	mi.position = Vector3(lp.x, lp.y, 0.022)
	mi.visible = true
	_flash = 1.0
	_swing_v += 3.2
	set_process(true)
	plate_hit.emit(self, _offset)


func _process(delta: float) -> void:
	# Damped spring on the hinge.
	_swing_v += (-_swing * 28.0 - _swing_v * 3.0) * delta
	_swing += _swing_v * delta
	if hinge:
		hinge.rotation.x = -_swing * 0.6
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_mat.albedo_color = _base.lerp(Color(1.0, 0.45, 0.15), _flash)
	if _flash <= 0.0 and absf(_swing) < 0.002 and absf(_swing_v) < 0.01:
		if hinge:
			hinge.rotation.x = 0.0
		set_process(false)

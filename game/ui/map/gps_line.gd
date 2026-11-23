extends MeshInstance3D
## Cheap 3D GPS ribbon laid on the road surface along the route (right-hand lane).
## One ImmediateMesh strip, rebuilt only when the route changes; no shadows, no lights.

const HEIGHT := 0.06
const WIDTH := 1.5
const LANE_OFFSET := 3.2
const MAX_LEN := 280.0

var _im := ImmediateMesh.new()
var _mat := ShaderMaterial.new()


func _ready() -> void:
	mesh = _im
	_mat.shader = preload("res://ui/map/gps_line.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	top_level = true
	visible = false


## route: map polyline (Vector2 x, z). The first point is the player, the last the destination.
func set_route(route: PackedVector2Array) -> void:
	_im.clear_surfaces()
	# Road part only: from the road entry point to the road exit point.
	if route.size() < 4:
		return
	var pts := PackedVector2Array()
	for i in range(1, route.size() - 1):
		pts.append(route[i])
	# Cut to MAX_LEN metres.
	var cut := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if acc + seg >= MAX_LEN:
			cut.append(pts[i - 1].lerp(pts[i], (MAX_LEN - acc) / maxf(seg, 0.001)))
			break
		cut.append(pts[i])
		acc += seg
	if cut.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var along := 0.0
	for i in cut.size():
		var p := cut[i]
		var d_in := (p - cut[i - 1]).normalized() if i > 0 else (cut[1] - p).normalized()
		var d_out := (cut[i + 1] - p).normalized() if i < cut.size() - 1 else d_in
		var dir := (d_in + d_out).normalized()
		if dir.length() < 0.1:
			dir = d_out
		var right := Vector2(-dir.y, dir.x)
		# Miter so the lane offset stays constant around corners.
		var miter := 1.0 / maxf(right.dot(Vector2(-d_in.y, d_in.x)), 0.5)
		var c := p + right * LANE_OFFSET * miter
		if i > 0:
			along += cut[i - 1].distance_to(p)
		var l := c - right * WIDTH * 0.5 * miter
		var r := c + right * WIDTH * 0.5 * miter
		_im.surface_set_uv(Vector2(along, 0.0))
		_im.surface_add_vertex(Vector3(l.x, HEIGHT, l.y))
		_im.surface_set_uv(Vector2(along, 1.0))
		_im.surface_add_vertex(Vector3(r.x, HEIGHT, r.y))
	_im.surface_end()

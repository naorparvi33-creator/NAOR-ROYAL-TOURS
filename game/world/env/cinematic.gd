extends Node
## Cinematic look (feature module, registered in world/main.gd after day_night):
##  * colour grading: a procedural 3D LUT (world/env/color_grade.gd) blended between a
##    golden-hour grade, a teal-orange day grade, a night grade and an overcast grade
##    by the time of day and weather. Rebaked on a worker thread only when the blend
##    visibly changed (every few seconds at most), uploaded to the Environment LUT;
##  * bloom tuned for the sun, bright sky and night emissives (medium / high);
##  * film finish on a canvas layer under the HUD: vignette + grain (medium, no screen
##    read) or chromatic aberration + grain + vignette (high, one screen copy);
##  * sun glare with an occlusion ray (medium / high);
##  * soft contact shadows under cars and people (one MultiMesh, every preset);
##  * depth of field while aiming and in photo mode (Mobile renderer, medium / high);
##  * camera shake on explosions (on top of vehicle_fx's positional shake);
##  * letterbox bars while story dialogue plays.
## Low preset and battery saver keep only the LUT and the contact shadows.

const Grade := preload("res://world/env/color_grade.gd")
const GRADE_TICK := 0.5
const MAX_BLOBS := 64
const BLOB_RANGE := 70.0

var main: Node

var tier := "medium"
var _dn: Node
var _env: Environment
var _sun: DirectionalLight3D
var _web := false

# Colour grading
var _lut: ImageTexture3D
var _lut_n := 24
var _baked := {}
var _pending := {}
var _task := -1
var _task_result: Array[Image] = []
var _grade_t := 0.0

# Post / overlays
var _layer: CanvasLayer
var _post: ColorRect
var _post_mat: ShaderMaterial
var _flare: ColorRect
var _flare_mat: ShaderMaterial
var _flare_vis := 0.0
var _flare_occ := 0.0
var _flare_t := 0.0
var _bars: Array[ColorRect] = []
var _letterbox := 0.0
var _campaign_ui: Node

# Contact shadows
var _blobs: MultiMeshInstance3D
var _ground_y := {}   # instance id -> ground height
var _ray_i := 0

# Depth of field
var _dof: CameraAttributesPractical
var _dof_cam: Camera3D
var _focus := 20.0
var _photo: Node


func _ready() -> void:
	name = "Cinematic"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	_lut_n = 16 if _web else 24
	_dn = get_tree().get_first_node_in_group("day_night")
	var world: Node = main.world if main else null
	if world:
		_sun = world.get("sun") as DirectionalLight3D
		for c in world.get_children():
			if c is WorldEnvironment:
				_env = (c as WorldEnvironment).environment
	_setup_environment()
	_build_overlays()
	_build_blobs()
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_amount = 0.06
	Settings.changed.connect(_on_setting)
	var q: Node = main.get_node_or_null("Quality") if main else null
	if q and q.has_signal("preset_applied"):
		q.preset_applied.connect(func(_p): _apply_tier())
	get_tree().node_added.connect(_on_node_added)
	for v in get_tree().get_nodes_in_group("vehicle"):
		_on_node_added(v)
	_apply_tier()
	_update_grade(true)


func _on_setting(key: String) -> void:
	if key in ["quality_preset", "battery_saver", "shadows"]:
		_apply_tier()


func _resolve_tier() -> String:
	var q: Node = main.get_node_or_null("Quality") if main else null
	var t := str(q.get("effective")) if q and "effective" in q else "medium"
	if Settings.get_value("battery_saver"):
		t = "low"
	return t


func _apply_tier() -> void:
	tier = _resolve_tier()
	if _post:
		_post.visible = tier != "low"
		_post.material = _post_mat
		var shader: Shader = preload("res://world/env/post_screen.gdshader") if tier == "high" and not _web \
			else preload("res://world/env/post_overlay.gdshader")
		if _post_mat.shader != shader:
			_post_mat.shader = shader
	if _sun:
		# Crisp near shadows: less light-size blur, small biases (the shadow range is set
		# by quality.gd per preset).
		_sun.light_angular_distance = 0.0 if tier == "low" else 0.35
		_sun.shadow_bias = 0.03
		_sun.shadow_normal_bias = 0.9
		_sun.shadow_blur = 0.8 if tier == "high" else 1.0
		_sun.directional_shadow_fade_start = 0.75
	_apply_glow()


# ------------------------------------------------------------ environment

func _setup_environment() -> void:
	if _env == null:
		return
	# Filmic AgX with a little more punch; the LUT does the look, so the plain
	# brightness/contrast/saturation adjustment stays neutral.
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_agx_contrast = 1.22
	_env.tonemap_agx_white = 10.0
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.0
	_env.adjustment_saturation = 1.0
	_lut = ImageTexture3D.new()
	var params := _grade_params()
	_lut.create(Image.FORMAT_RGB8, _lut_n, _lut_n, _lut_n, false, Grade.bake(params, _lut_n))
	_baked = params
	_env.adjustment_color_correction = _lut


func _apply_glow() -> void:
	if _env == null:
		return
	var night: float = _dn.get("night") if _dn else 0.0
	# Low: bloom only at night (lamps / windows), as before. Medium / high: always on,
	# with a high threshold by day so only the sun, the sky near it and hot specular
	# highlights bloom.
	var on: bool = (tier != "low" or night > 0.05) and not Settings.get_value("battery_saver")
	if _env.glow_enabled != on:
		_env.glow_enabled = on
	if not on:
		return
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if night < 0.5 else Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_normalized = false
	_env.set_glow_level(0, 0.0)
	_env.set_glow_level(1, 0.6)
	_env.set_glow_level(2, 1.0)
	_env.set_glow_level(3, 0.8 if tier == "high" else 0.0)
	_env.set_glow_level(4, 0.5 if tier == "high" else 1.0)
	_env.set_glow_level(5, 0.0)
	_env.glow_hdr_threshold = lerpf(1.15, 0.85, night)
	_env.glow_hdr_scale = 2.0
	_env.glow_hdr_luminance_cap = 12.0
	_env.glow_strength = 1.0
	_env.glow_bloom = lerpf(0.02, 0.0, night)
	_env.glow_intensity = lerpf(0.5, 0.75, night)


# ------------------------------------------------------------ colour grading

func _grade_params() -> Dictionary:
	var e: float = _dn.get("sun_height") if _dn else 0.5
	var night: float = _dn.get("night") if _dn else 0.0
	var oc := 0.0
	if _dn and _dn.get("weather"):
		oc = float(_dn.weather.get("overcast"))
	var golden := smoothstep(-0.1, 0.05, e) * (1.0 - smoothstep(0.22, 0.5, e))
	var day := smoothstep(0.15, 0.45, e)
	var w := {
		"golden": golden * (1.0 - night) * (1.0 - oc),
		"day": day * (1.0 - oc) + 0.001,
		"night": night,
		"overcast": oc * (1.0 - night * 0.5),
	}
	return Grade.blend(w)


func _update_grade(force := false) -> void:
	if _lut == null:
		return
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_result.size() == _lut_n:
			_lut.update(_task_result)
			_baked = _pending
		return
	var p := _grade_params()
	if not force and Grade.distance(p, _baked) < 0.006:
		return
	_pending = p
	if _web:
		# The browser build may not have threads: bake small and inline.
		_lut.update(Grade.bake(p, _lut_n))
		_baked = p
		return
	_task_result = []
	_task = WorkerThreadPool.add_task(_bake_task.bind(p), false, "color_grade")


func _bake_task(p: Dictionary) -> void:
	_task_result = Grade.bake(p, _lut_n)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# ------------------------------------------------------------ overlays

func _build_overlays() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "FilmLayer"
	_layer.layer = 1   # above the 3D view, under damage feedback (9) and the HUD (10)
	add_child(_layer)
	_post = ColorRect.new()
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = preload("res://world/env/post_overlay.gdshader")
	_post.material = _post_mat
	_layer.add_child(_post)
	_flare = ColorRect.new()
	_flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_mat = ShaderMaterial.new()
	_flare_mat.shader = preload("res://world/env/lens_flare.gdshader")
	_flare.material = _flare_mat
	_flare.visible = false
	_layer.add_child(_flare)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.visible = false
		_layer.add_child(b)
		_bars.append(b)


func _process(delta: float) -> void:
	var paused := get_tree().paused
	_grade_t -= delta
	if _grade_t <= 0.0:
		_grade_t = GRADE_TICK
		_update_grade()
		_apply_glow()
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	if _post and _post.visible:
		_post_mat.set_shader_parameter("aspect", aspect)
		var ca := 0.0025
		_post_mat.set_shader_parameter("aberration", ca)
	_update_flare(delta, aspect)
	_update_letterbox(delta, vs)
	_update_dof(delta)
	if not paused:
		_update_blobs()


func _update_flare(delta: float, aspect: float) -> void:
	var want := 0.0
	var cam := get_viewport().get_camera_3d()
	if tier != "low" and _dn and cam and _sun and _sun.visible:
		var sd: Vector3 = _dn.get("sun_dir")
		var oc := float(_dn.weather.get("overcast")) if _dn.get("weather") else 0.0
		var far := cam.global_position + sd * 1000.0
		if sd.y > -0.02 and not cam.is_position_behind(far):
			var sp := cam.unproject_position(far)
			var vs := get_viewport().get_visible_rect().size
			var uv := sp / vs
			var edge := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
			if edge > -0.08:
				_flare_t -= delta
				if _flare_t <= 0.0:
					_flare_t = 0.1
					var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + sd * 600.0, 1)
					var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
					_flare_occ = 0.0 if hit.is_empty() else 1.0
				var low := 1.0 - smoothstep(0.1, 0.6, sd.y)
				want = (1.0 - _flare_occ) * smoothstep(-0.08, 0.06, edge) * (1.0 - oc) * lerpf(0.55, 1.0, low)
				want *= smoothstep(-0.02, 0.04, sd.y)
				_flare_mat.set_shader_parameter("sun_uv", uv)
				var warm := Color(1.0, 0.62, 0.32).lerp(Color(1.0, 0.85, 0.65), smoothstep(0.1, 0.5, sd.y))
				_flare_mat.set_shader_parameter("tint", warm)
	_flare_vis = move_toward(_flare_vis, want, delta * 3.0)
	_flare.visible = _flare_vis > 0.005
	if _flare.visible:
		_flare_mat.set_shader_parameter("intensity", _flare_vis)
		_flare_mat.set_shader_parameter("aspect", aspect)


func _update_letterbox(delta: float, vs: Vector2) -> void:
	if _campaign_ui == null or not is_instance_valid(_campaign_ui):
		_campaign_ui = null
		var c: Node = main.get_node_or_null("Campaign") if main else null
		if c == null and main:
			for n in main.get_children():
				if "ui" in n and n.get("ui") is Node and "talking" in n.get("ui"):
					c = n
					break
		if c and "ui" in c:
			_campaign_ui = c.get("ui")
	var talking: bool = _campaign_ui != null and bool(_campaign_ui.get("talking"))
	var photo := _photo_active()
	_letterbox = move_toward(_letterbox, 1.0 if talking and not photo else 0.0, delta * 2.5)
	var h := vs.y * 0.075 * smoothstep(0.0, 1.0, _letterbox)
	for i in 2:
		var b := _bars[i]
		b.visible = h > 0.5
		if b.visible:
			b.position = Vector2(0, 0 if i == 0 else vs.y - h)
			b.size = Vector2(vs.x, h)


# ------------------------------------------------------------ depth of field

func _photo_active() -> bool:
	if _photo == null and main:
		_photo = main.get_node_or_null("PhotoMode")
	return _photo != null and bool(_photo.get("active"))


func _update_dof(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != _dof_cam:
		if _dof_cam and is_instance_valid(_dof_cam) and _dof_cam.attributes == _dof:
			_dof_cam.attributes = null
		_dof_cam = cam
	if cam == null:
		return
	var rig: Node = main.player.rig if main and main.player else null
	var photo := _photo_active() and bool(_photo.get("dof"))
	var aiming: bool = rig != null and cam == rig.get("camera") and bool(rig.get("aiming"))
	var use: bool = (photo or aiming) and tier != "low" and not _web
	if not use:
		if cam.attributes == _dof:
			cam.attributes = null
		return
	# Focus on what is under the crosshair.
	var c := get_viewport().get_visible_rect().size * 0.5
	var from := cam.project_ray_origin(c)
	var to := from + cam.project_ray_normal(c) * 800.0
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var d := 400.0 if hit.is_empty() else from.distance_to(hit["position"])
	_focus = lerpf(_focus, d, 1.0 - exp(-8.0 * delta))
	if photo:
		_dof.dof_blur_far_enabled = true
		_dof.dof_blur_far_distance = _focus * 1.25 + 1.0
		_dof.dof_blur_far_transition = maxf(_focus * 1.5, 4.0)
		_dof.dof_blur_near_enabled = _focus > 4.0
		_dof.dof_blur_near_distance = maxf(_focus * 0.5, 0.5)
		_dof.dof_blur_near_transition = maxf(_focus * 0.35, 0.5)
		_dof.dof_blur_amount = 0.08
	else:
		# Aiming: the background past the target softens a little.
		_dof.dof_blur_far_enabled = true
		_dof.dof_blur_far_distance = _focus + 25.0
		_dof.dof_blur_far_transition = 60.0
		_dof.dof_blur_near_enabled = false
		_dof.dof_blur_amount = 0.05
	if cam.attributes != _dof:
		cam.attributes = _dof


# ------------------------------------------------------------ camera shake

func _on_node_added(n: Node) -> void:
	if n.has_signal("exploded") and not n.is_connected("exploded", _on_exploded.bind(n)):
		n.connect("exploded", _on_exploded.bind(n))


func _on_exploded(n: Node) -> void:
	var rig: Node = main.player.rig if main and main.player else null
	if rig == null or not rig.has_method("add_shake") or not (n is Node3D):
		return
	var d := (n as Node3D).global_position.distance_to(main.player.global_position)
	rig.add_shake(clampf(1.2 - d / 40.0, 0.0, 1.0))


# ------------------------------------------------------------ contact shadows

func _build_blobs() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/env/contact_shadow.gdshader")
	mat.render_priority = -1
	pm.material = mat
	mm.mesh = pm
	mm.instance_count = MAX_BLOBS
	mm.visible_instance_count = 0
	_blobs = MultiMeshInstance3D.new()
	_blobs.name = "ContactShadows"
	_blobs.multimesh = mm
	_blobs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blobs.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(_blobs)


func _update_blobs() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or main == null or main.player == null:
		return
	var cp := cam.global_position
	var list: Array = []   # [node, half_w, half_l, core, dark, yaw_basis_node]
	var pl: Node3D = main.player
	if pl.visible and not bool(pl.get("in_vehicle")):
		list.append([pl, 0.6, 0.6, 0.15, 0.6])
	for v in get_tree().get_nodes_in_group("vehicle"):
		var vn := v as Node3D
		if vn == null or not vn.is_visible_in_tree():
			continue
		if vn.global_position.distance_squared_to(cp) > BLOB_RANGE * BLOB_RANGE:
			continue
		var moto := str(vn.get("vtype")) == "moto"
		var sz := Vector2(0.6, 1.4) if moto else Vector2(1.35, 2.75)
		var spec: Variant = vn.get("spec")
		if not moto and spec is Dictionary and (spec as Dictionary).has("W"):
			sz = Vector2(float(spec["W"]) * 0.5 + 0.45, float(spec["L"]) * 0.5 + 0.5)
		list.append([vn, sz.x, sz.y, 0.6 if not moto else 0.3, 0.75])
	var peds: Node = main.peds
	if peds and "_peds" in peds:
		for p in peds.get("_peds"):
			var n: Node3D = (p as Dictionary).get("node")
			if n and n.visible and n.global_position.distance_squared_to(cp) < 45.0 * 45.0:
				list.append([n, 0.6, 0.6, 0.15, 0.55])
	var mm := _blobs.multimesh
	var count := mini(list.size(), MAX_BLOBS)
	var space := cam.get_world_3d().direct_space_state
	# A few ground rays per frame (round robin) to find the surface under each one.
	for k in 4:
		if count == 0:
			break
		_ray_i = (_ray_i + 1) % count
		var n: Node3D = list[_ray_i][0]
		var o := n.global_position
		var q := PhysicsRayQueryParameters3D.create(o + Vector3(0, 0.6, 0), o + Vector3(0, -3.0, 0), 1)
		if n is CollisionObject3D:
			q.exclude = [(n as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		_ground_y[n.get_instance_id()] = float(hit["position"].y) if not hit.is_empty() else o.y
	var night: float = _dn.get("night") if _dn else 0.0
	for i in count:
		var e: Array = list[i]
		var n: Node3D = e[0]
		var o := n.global_position
		var gy: float = _ground_y.get(n.get_instance_id(), o.y)
		if o.y - gy > 2.5:
			gy = o.y - 2.5   # airborne: keep it near
		var air := clampf((o.y - gy - 1.2) / 2.0, 0.0, 1.0) if e[3] > 0.2 else clampf((o.y - gy - 0.1) / 1.5, 0.0, 1.0)
		var fwd := n.global_basis.z
		fwd.y = 0.0
		var yaw := atan2(fwd.x, fwd.z) if fwd.length_squared() > 0.001 else 0.0
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(e[1] * 2.0, 1.0, e[2] * 2.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(o.x, gy + 0.035, o.z)))
		mm.set_instance_custom_data(i, Color(e[3], 0, 0, float(e[4]) * (1.0 - air) * lerpf(1.0, 0.8, night)))
	mm.visible_instance_count = count
	if _ground_y.size() > 300:
		_ground_y.clear()

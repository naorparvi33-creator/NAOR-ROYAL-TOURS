extends Node
## Graphics quality presets (Low / Medium / High / Auto) and the per-block culling
## that keeps the city cheap to draw on a phone.
##
## Settings it owns (other modules may read them):
##   "quality_preset"  "auto" | "low" | "medium" | "high" | "custom"
##   "npc_density"     0.3 .. 1.5, multiplier for pedestrians and traffic
## A preset writes grass / shadows / render_scale_max / draw_distance / npc_density;
## changing one of those by hand turns the preset into "custom".
##
## Culling (applied once after the city is built, refreshed on setting changes):
##   * every block mesh gets visibility_range_end = draw distance (+ half a block),
##   * the city-wide prop MultiMeshes (palms, lamps, traffic lights) are split into
##     one MultiMesh per 2 x 2 blocks, so far and off-screen parts are skipped entirely,
##   * prop range follows the preset (props are small: no need to draw them at 600 m).
## Pedestrian count follows npc_density.

signal preset_applied(preset: String)

const PRESETS := {
	"low": {"grass": false, "shadows": false, "render_scale_max": 0.75, "draw_distance": 300.0,
		"npc_density": 0.6, "shadow_dist": 30.0, "prop_range": 110.0},
	"medium": {"grass": true, "shadows": true, "render_scale_max": 0.9, "draw_distance": 450.0,
		"npc_density": 1.0, "shadow_dist": 42.0, "prop_range": 170.0},
	"high": {"grass": true, "shadows": true, "render_scale_max": 1.0, "draw_distance": 650.0,
		"npc_density": 1.3, "shadow_dist": 60.0, "prop_range": 240.0},
}
const MANAGED := ["grass", "shadows", "render_scale_max", "draw_distance", "npc_density"]
const MAX_PEDS := 16
const CHUNK_BLOCKS := 2.0

var main: Node
## The preset actually in use ("auto" resolves to low / medium / high).
var effective := "medium"
var _applying := false
var _blocks: Array[GeometryInstance3D] = []      # building meshes (one per block)
var _outer: Array[GeometryInstance3D] = []       # skyline ring: never range-culled
var _props: Array[GeometryInstance3D] = []       # per-block prop chunks
var _peds_reserve: Array = []
var _base_peds := -1
var _auto_low_time := 0.0
var _auto_checked := 0.0
var stats := {}


func _ready() -> void:
	name = "Quality"
	process_mode = Node.PROCESS_MODE_ALWAYS
	effective = _resolve(str(Settings.get_value("quality_preset")))
	if str(Settings.get_value("quality_preset")) != "custom":
		_write_preset(effective)
	Settings.changed.connect(_on_setting)
	# Wait one frame so the city, street dressing and pedestrians all exist.
	await get_tree().process_frame
	_chunk_world()
	_apply_world()
	_apply_npc_density()


## "auto": pick by device. The browser build and unknown phone GPUs start at low/medium;
## high-end Adreno 7xx / Mali-G7xx / Immortalis (e.g. Galaxy S23 Ultra) and desktops get high.
func _resolve(preset: String) -> String:
	if PRESETS.has(preset):
		return preset
	if preset == "custom":
		return effective
	if OS.has_feature("web"):
		return "low"
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if OS.has_feature("mobile"):
		for hi in ["adreno (tm) 7", "adreno (tm) 8", "adreno 7", "adreno 8", "immortalis", "mali-g71", "mali-g72", "mali-g78", "xclipse"]:
			if gpu.contains(hi):
				return "high"
		return "medium"
	if gpu.contains("llvmpipe") or gpu.contains("swiftshader") or gpu.contains("software"):
		return "low"
	return "high"


func current_values() -> Dictionary:
	return PRESETS[effective]


func _write_preset(p: String) -> void:
	var v: Dictionary = PRESETS[p]
	_applying = true
	for k in MANAGED:
		Settings.set_value(k, v[k])
	_applying = false
	preset_applied.emit(p)


func _on_setting(key: String) -> void:
	if _applying:
		return
	if key == "quality_preset":
		var p := str(Settings.get_value("quality_preset"))
		if p != "custom":
			effective = _resolve(p)
			_write_preset(effective)
			_refresh_menu()
		_apply_world()
		_apply_npc_density()
	elif key in MANAGED:
		if str(Settings.get_value("quality_preset")) != "custom":
			_applying = true
			Settings.set_value("quality_preset", "custom")
			_applying = false
			_refresh_menu()
		_apply_world()
		if key == "npc_density":
			_apply_npc_density()
	elif key == "battery_saver":
		_apply_world()


## The settings screen shows the values a preset just wrote.
func _refresh_menu() -> void:
	if main and main.hud and main.hud.menu and main.hud.menu.has_method("_build"):
		main.hud.menu.call_deferred("_build")


# ------------------------------------------------------------ world culling

func _chunk_world() -> void:
	var world: Node3D = main.world if main else null
	if world == null:
		return
	var pitch := float(world.get("PITCH")) if "PITCH" in world else 106.0
	var rings := int(world.get("RINGS")) if "RINGS" in world else 2
	var grass: Node = world.get("grass") if "grass" in world else null
	var playable := pitch * (rings + 0.5)
	var split := 0
	var draws_before := 0
	for c in world.get_children():
		if c == grass:
			continue
		if c is MultiMeshInstance3D:
			var mmi := c as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or mm.instance_count < 8:
				continue
			var ab := _instance_bounds(mmi)
			if ab.size.x < pitch * 1.5 and ab.size.z < pitch * 1.5:
				_props.append(mmi)       # already small (park trees etc.)
				continue
			draws_before += 1
			split += _split_multimesh(mmi, pitch)
		elif c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var ab := mi.global_transform * mi.get_aabb()
			if ab.size.x > pitch * 1.2 or ab.size.z > pitch * 1.2:
				continue                 # ground plane, sidewalk slab
			var centre := ab.get_center()
			if absf(centre.x) > playable or absf(centre.z) > playable:
				_outer.append(mi)
			else:
				_blocks.append(mi)
	# The park (and anything else that builds its own small MultiMeshes) under the city.
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		if n.get_parent() != world and n != grass and not _props.has(n):
			_props.append(n)
	stats = {"blocks": _blocks.size(), "outer": _outer.size(), "prop_chunks": split, "prop_meshes_split": draws_before}


## Bounds of the instance origins (works without a GPU, unlike get_aabb()).
func _instance_bounds(mmi: MultiMeshInstance3D) -> AABB:
	var mm := mmi.multimesh
	var ab := AABB(mm.get_instance_transform(0).origin, Vector3.ZERO)
	for i in mm.instance_count:
		ab = ab.expand(mm.get_instance_transform(i).origin)
	return ab


## Replaces one city-wide MultiMesh with one MultiMesh per 2 x 2 block cell.
func _split_multimesh(src: MultiMeshInstance3D, pitch: float) -> int:
	var mm := src.multimesh
	var cells := {}
	for i in mm.instance_count:
		var xf := src.global_transform * mm.get_instance_transform(i)
		# 2 x 2 blocks per chunk: enough to cull far / off-screen parts of the city
		# without multiplying draw calls.
		var key := Vector2i(roundi(xf.origin.x / (pitch * CHUNK_BLOCKS)), roundi(xf.origin.z / (pitch * CHUNK_BLOCKS)))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(i)
	var parent := src.get_parent()
	for key in cells:
		var idx: Array = cells[key]
		var nm := MultiMesh.new()
		nm.transform_format = mm.transform_format
		nm.use_colors = mm.use_colors
		nm.use_custom_data = mm.use_custom_data
		nm.mesh = mm.mesh
		nm.instance_count = idx.size()
		for j in idx.size():
			var i: int = idx[j]
			nm.set_instance_transform(j, mm.get_instance_transform(i))
			if mm.use_colors:
				nm.set_instance_color(j, mm.get_instance_color(i))
			if mm.use_custom_data:
				nm.set_instance_custom_data(j, mm.get_instance_custom_data(i))
		var n := MultiMeshInstance3D.new()
		n.name = "%s_%d_%d" % [src.name, key.x, key.y]
		n.multimesh = nm
		n.transform = src.transform
		n.cast_shadow = src.cast_shadow
		n.material_override = src.material_override
		n.layers = src.layers
		parent.add_child(n)
		_props.append(n)
	src.queue_free()
	return cells.size()


func _apply_world() -> void:
	var v := current_values()
	var dd := float(Settings.get_value("draw_distance"))
	var prop := minf(float(v["prop_range"]), dd)
	if str(Settings.get_value("quality_preset")) == "custom":
		prop = clampf(dd * 0.4, 110.0, 260.0)
	if Settings.get_value("battery_saver"):
		prop = minf(prop, 110.0)
		dd = minf(dd, 350.0)
	for g in _blocks:
		if is_instance_valid(g):
			g.visibility_range_end = dd + 60.0
			g.visibility_range_end_margin = 10.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for g in _props:
		if is_instance_valid(g):
			g.visibility_range_end = prop + 110.0   # chunk centre to its far edge
			g.visibility_range_end_margin = 10.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var world: Node = main.world if main else null
	if world and "sun" in world and world.sun is DirectionalLight3D:
		(world.sun as DirectionalLight3D).directional_shadow_max_distance = float(v["shadow_dist"])


# ------------------------------------------------------------ people

## Hides or adds pedestrians so the crowd follows npc_density. Uses the pedestrian
## manager's pool (people are parked in a reserve rather than freed).
func _apply_npc_density() -> void:
	var peds: Node = main.peds if main else null
	if peds == null or not ("_peds" in peds):
		return
	var list: Array = peds.get("_peds")
	var normal: Array = []
	for p in list:
		if not p.get("special", false):
			normal.append(p)
	if _base_peds < 0:
		_base_peds = normal.size()
	var want := clampi(roundi(_base_peds * float(Settings.get_value("npc_density"))), 2, MAX_PEDS)
	while normal.size() > want:
		var p: Dictionary = normal.pop_back()
		list.erase(p)
		_park_ped(p, true)
		_peds_reserve.append(p)
	while normal.size() < want:
		var p: Dictionary
		if not _peds_reserve.is_empty():
			p = _peds_reserve.pop_back()
			list.append(p)
			_park_ped(p, false)
		elif peds.has_method("_make_ped") and "MODELS" in peds:
			var models: Array = peds.get("MODELS")
			p = peds.call("_make_ped", models[(normal.size() * 3 + 1) % models.size()])
		else:
			break
		if peds.has_method("_respawn"):
			peds.call("_respawn", p)
		normal.append(p)


func _park_ped(p: Dictionary, parked: bool) -> void:
	var n: Node3D = p.get("node")
	var b: CollisionObject3D = p.get("body")
	if n:
		n.visible = not parked
	if b:
		b.collision_layer = 0 if parked else 4


# ------------------------------------------------------------ auto adapt

func _process(delta: float) -> void:
	if str(Settings.get_value("quality_preset")) != "auto" or get_tree().paused:
		return
	_auto_checked += delta
	if _auto_checked < 1.0:
		return
	_auto_checked = 0.0
	# Auto steps down one preset after 12 s of missed frames at the lowest resolution.
	var struggling := Perf.fps > 0.0 and Perf.fps < Perf.target_fps() * 0.8 and Perf.render_scale <= Perf.SCALE_MIN + 0.01
	_auto_low_time = _auto_low_time + 1.0 if struggling else maxf(_auto_low_time - 2.0, 0.0)
	if _auto_low_time >= 12.0 and effective != "low":
		_auto_low_time = 0.0
		effective = "medium" if effective == "high" else "low"
		_write_preset(effective)
		_apply_world()
		_apply_npc_density()
		_refresh_menu()

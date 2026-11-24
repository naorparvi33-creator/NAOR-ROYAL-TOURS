extends Node
## Frame rate cap, dynamic render resolution and heat monitoring.
## Goal: a steady frame rate without heating the phone. We never render more
## frames than the cap, and the 3D resolution drops (0.7..max) when the GPU is busy.

signal stats_updated

const SCALE_MIN := 0.7
const EVAL_INTERVAL := 0.5

var render_scale := 1.0
var fps := 0.0
var frame_ms := 0.0
var gpu_ms := 0.0
var cpu_ms := 0.0
var load_pct := 0.0
## Android thermal status: -1 unknown, 0 none, 1 light, 2 moderate, 3 severe, 4+ critical.
var thermal_status := -1
var thermal_headroom := -1.0

var _vp_rid: RID
var _acc_time := 0.0
var _acc_frames := 0
var _acc_gpu := 0.0
var _acc_cpu := 0.0
var _thermal_timer := 0.0
var _power_manager: Variant = null
var _thermal_checked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	Settings.changed.connect(_on_setting_changed)
	apply()


func _on_setting_changed(key: String) -> void:
	if key in ["fps_cap", "battery_saver", "dynamic_res", "render_scale_max"]:
		apply()


func target_fps() -> int:
	if Settings.get_value("battery_saver"):
		return 30
	return int(Settings.get_value("fps_cap"))


func max_scale() -> float:
	var m := float(Settings.get_value("render_scale_max"))
	if Settings.get_value("battery_saver"):
		m = minf(m, 0.8)
	# Heat protection: when the phone reports severe heat we cap resolution.
	if thermal_status >= 3:
		m = minf(m, SCALE_MIN)
	return clampf(m, SCALE_MIN, 1.0)


func shadows_enabled() -> bool:
	return bool(Settings.get_value("shadows")) and not Settings.get_value("battery_saver")


func apply() -> void:
	Engine.max_fps = target_fps()
	render_scale = clampf(render_scale, SCALE_MIN, max_scale())
	if not Settings.get_value("dynamic_res"):
		render_scale = max_scale()
	_set_scale(render_scale)


func _set_scale(s: float) -> void:
	render_scale = s
	get_viewport().scaling_3d_scale = s


func _process(delta: float) -> void:
	_acc_time += delta
	_acc_frames += 1
	_acc_gpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	_acc_cpu += RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) \
		+ Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if _acc_time >= EVAL_INTERVAL:
		_evaluate()
	_thermal_timer -= delta
	if _thermal_timer <= 0.0:
		_thermal_timer = 3.0
		_poll_thermal()


func _evaluate() -> void:
	var n := float(_acc_frames)
	fps = n / _acc_time
	frame_ms = _acc_time * 1000.0 / n
	gpu_ms = _acc_gpu / n
	cpu_ms = _acc_cpu / n
	_acc_time = 0.0
	_acc_frames = 0
	_acc_gpu = 0.0
	_acc_cpu = 0.0

	var budget := 1000.0 / float(target_fps())
	var busy := maxf(gpu_ms, cpu_ms)
	load_pct = clampf(busy / budget * 100.0, 0.0, 999.0)

	if Settings.get_value("dynamic_res"):
		var missing_frames := fps < float(target_fps()) * 0.92
		var s := render_scale
		if gpu_ms > budget * 0.85 or (missing_frames and gpu_ms >= cpu_ms):
			s -= 0.05
		elif gpu_ms < budget * 0.6 and not missing_frames:
			s += 0.025  # rise slowly so the image does not pump up and down
		s = clampf(s, SCALE_MIN, max_scale())
		if not is_equal_approx(s, render_scale):
			_set_scale(s)
	stats_updated.emit()


func _poll_thermal() -> void:
	if OS.get_name() != "Android":
		return
	if not _thermal_checked:
		_thermal_checked = true
		# Android API through JNI (no plugin needed): PowerManager thermal status.
		if Engine.has_singleton("AndroidRuntime"):
			var rt = Engine.get_singleton("AndroidRuntime")
			var activity = rt.getActivity()
			if activity:
				_power_manager = activity.getSystemService("power")
	if _power_manager == null:
		return
	var prev := thermal_status
	thermal_status = int(_power_manager.getCurrentThermalStatus())
	var h = _power_manager.getThermalHeadroom(10)
	thermal_headroom = float(h) if h != null else -1.0
	if prev != thermal_status:
		apply()

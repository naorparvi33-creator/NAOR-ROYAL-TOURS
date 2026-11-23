extends Node
## Persistent user settings (user://settings.cfg). Every change is saved right away,
## so nothing is lost if Android kills the app in the background.

signal changed(key: String)

const PATH := "user://settings.cfg"

const DEFAULTS := {
	# graphics
	"fps_cap": 60,              # 60 / 90 / 120
	"battery_saver": false,     # forces 30 FPS and lower render scale
	"dynamic_res": true,
	"render_scale_max": 1.0,    # dynamic resolution moves between 0.7 and this
	"shadows": true,
	"grass": true,
	"draw_distance": 400.0,
	"show_perf": true,
	# controls
	"layout_preset": "two_thumbs",   # two_thumbs / four_fingers
	"sens_look": 1.0,
	"sens_ads": 0.7,
	"sens_scope": 0.45,
	"invert_y": false,
	"gyro_mode": 0,             # 0 off, 1 ADS only, 2 always
	"gyro_sens": 1.0,
	"auto_fire": false,
	"aim_assist": 0.5,          # 0 = off .. 1 = strong
	"btn_scale": 1.0,
	"btn_opacity": 0.55,
	# general
	"language": "he",
	"first_run_done": false,
}

var values: Dictionary = {}
## Per-button overrides made in the layout editor: id -> {"pos": Vector2 (0..1), "scale": float}
var layout_overrides: Dictionary = {}


func _ready() -> void:
	values = DEFAULTS.duplicate(true)
	_load()
	if not values["first_run_done"]:
		# First launch: the two-thumb layout is chosen automatically.
		values["layout_preset"] = "two_thumbs"
		values["first_run_done"] = true
		save()
	Loc.set_language(values["language"])


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v: Variant) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	if key == "language":
		Loc.set_language(v)
	if key == "layout_preset":
		layout_overrides.clear()  # a new preset starts from its own default positions
	save()
	changed.emit(key)


func set_layout_override(id: String, pos: Vector2, scale: float) -> void:
	layout_overrides[id] = {"pos": pos, "scale": scale}
	save()
	changed.emit("layout")


func reset_layout() -> void:
	layout_overrides.clear()
	save()
	changed.emit("layout")


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	for id in layout_overrides:
		cfg.set_value("layout", id, layout_overrides[id])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in DEFAULTS:
		if cfg.has_section_key("settings", k):
			values[k] = cfg.get_value("settings", k)
	if cfg.has_section("layout"):
		for id in cfg.get_section_keys("layout"):
			layout_overrides[id] = cfg.get_value("layout", id)

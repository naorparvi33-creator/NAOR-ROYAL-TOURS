extends Node
## Day/night cycle and weather (feature module, registered in world/main.gd).
##  * A clock runs a full day in `dn_day_minutes` real minutes (default 24).
##  * The city's DirectionalLight3D follows the sun on a tilted orbit; at night the same
##    light becomes a dim blue moon light (one directional light, no shadows at night).
##  * The sky is a shader (sky.gdshader): the photo by day, turned so its sun follows the
##    light, a gradient with a glow at dawn/dusk, stars and a moon at night, grey overcast
##    in bad weather. Its uniforms change at most once a second, so the ambient cubemap
##    is only rebuilt when the sky really changed.
##  * Fog, ambient light and exposure follow the time of day and the weather.
##  * city_lights.gd: street lamps, lit windows and the player's car headlights.
##  * weather.gd: clear / cloudy / rain / storm, rain particles, wet roads, sound.
## Other modules can find this node in the "day_night" group and read `hour`,
## `night`, `is_night()` and `weather.state`.

signal hour_changed(hour: int)

const PHOTO_SUN := Vector3(0.374, 0.743, -0.555)   # sun direction in the sky photo (city.gd)
const ORBIT_TILT := 0.733                           # 42 deg: noon elevation 48 deg like the photo
const LIGHT_TICK := 0.1
const SKY_TICK := 1.0

# Key frames by sun height (sin of elevation).
const KE := [-0.35, -0.12, -0.02, 0.06, 0.2, 0.45, 0.75]
# A low sun is golden, not orange: a saturated orange key turned every white shirt and
# pale wall into a glowing peach patch.
const K_SUN_COL := [Color(1, 0.45, 0.24), Color(1, 0.45, 0.24), Color(1.0, 0.5, 0.26), Color(1.0, 0.66, 0.4),
	Color(1.0, 0.8, 0.6), Color(1.0, 0.9, 0.76), Color(1.0, 0.95, 0.86)]
const K_SUN_E := [0.0, 0.0, 0.0, 1.1, 2.3, 2.5, 2.5]
const K_TOP := [Color(0.008, 0.013, 0.035), Color(0.016, 0.028, 0.065), Color(0.07, 0.1, 0.22),
	Color(0.2, 0.3, 0.52), Color(0.26, 0.42, 0.72), Color(0.3, 0.5, 0.85), Color(0.3, 0.5, 0.85)]
# Night horizon: the glow of the city's own lights on the haze, so rooftops and palms
# stand out as silhouettes instead of melting into a black sky.
const K_HOR := [Color(0.07, 0.055, 0.07), Color(0.1, 0.08, 0.11), Color(0.6, 0.32, 0.2),
	Color(0.95, 0.62, 0.4), Color(0.85, 0.78, 0.7), Color(0.75, 0.8, 0.88), Color(0.75, 0.8, 0.88)]
const K_FOG := [Color(0.04, 0.038, 0.058), Color(0.055, 0.052, 0.08), Color(0.36, 0.26, 0.24),
	Color(0.78, 0.58, 0.44), Color(0.84, 0.74, 0.62), Color(0.74, 0.78, 0.84), Color(0.72, 0.78, 0.86)]
# How strongly the distance haze glows toward the sun, by sun height.
const K_SCATTER := [0.0, 0.0, 0.15, 0.55, 0.45, 0.25, 0.18]
const K_GLOW := [0.0, 0.12, 0.9, 1.0, 0.45, 0.08, 0.0]

const LOC := {
	"he": {
		"dn_day_minutes": "אורך יממה (דקות)",
		"dn_start_hour": "שעה ביום",
		"dn_paused": "עצירת השעון",
		"weather_on": "מזג אוויר משתנה",
		"weather_clear": "בהיר",
		"weather_cloudy": "מעונן",
		"weather_rain": "גשם",
		"weather_storm": "סערה",
	},
	"en": {
		"dn_day_minutes": "Day length (minutes)",
		"dn_start_hour": "Time of day",
		"dn_paused": "Freeze the clock",
		"weather_on": "Changing weather",
		"weather_clear": "Clear",
		"weather_cloudy": "Cloudy",
		"weather_rain": "Rain",
		"weather_storm": "Storm",
	},
}

var main: Node
## Hours since midnight (0..24).
var hour := 10.0
## Sun height: sin of the sun's elevation (-1..1).
var sun_height := 0.5
## 0 = daylight .. 1 = lamps and windows fully on.
var night := 0.0
var sun_dir := Vector3.UP
var weather: Node
var lights: Node

var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _clock_ui: CanvasLayer
var _light_t := 0.0
var _sky_t := 0.0
var _last_hour := -1
var _sky_cache := {}
var _noon_dir := Vector3.FORWARD
var _east := Vector3.RIGHT


func _ready() -> void:
	add_to_group("day_night")
	Loc.register(LOC)
	Settings.register_defaults({
		"dn_day_minutes": 24.0,
		"dn_start_hour": 17.0,
		"dn_paused": false,
		"weather_on": true,
		"dn_look_v": 0,
	})
	# One-time move of the untouched old default (10:00) to the warm late afternoon.
	if int(Settings.get_value("dn_look_v")) < 1:
		if is_equal_approx(float(Settings.get_value("dn_start_hour")), 10.0):
			Settings.set_value("dn_start_hour", 17.0)
		Settings.set_value("dn_look_v", 1)
	hour = clampf(float(Settings.get_value("dn_start_hour")), 0.0, 23.99)
	Settings.changed.connect(_on_setting)

	var s := Vector3(PHOTO_SUN.x, 0.0, PHOTO_SUN.z).normalized()
	_east = Vector3.UP.cross(s).normalized()
	_noon_dir = (Vector3.UP * cos(ORBIT_TILT) + s * sin(ORBIT_TILT)).normalized()

	var world: Node = main.world if main else null
	if world:
		_sun = world.get("sun") as DirectionalLight3D
		for c in world.get_children():
			if c is WorldEnvironment:
				_env = (c as WorldEnvironment).environment
	if _env and _env.sky:
		var old: Material = _env.sky.sky_material
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = preload("res://world/env/sky.gdshader")
		if old is PanoramaSkyMaterial:
			_sky_mat.set_shader_parameter("panorama", (old as PanoramaSkyMaterial).panorama)
		else:
			_sky_mat.set_shader_parameter("panorama", load("res://assets/sky/sky.jpg"))
		_env.sky.sky_material = _sky_mat
		# The sky changes slowly: spread cubemap updates over several frames.
		_env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		_env.glow_enabled = false
		_env.glow_intensity = 0.6
		_env.glow_strength = 0.9
		_env.glow_bloom = 0.0
		_env.glow_hdr_threshold = 1.1
		_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	weather = preload("res://world/env/weather.gd").new()
	weather.dn = self
	add_child(weather)
	lights = preload("res://world/env/city_lights.gd").new()
	lights.dn = self
	add_child(lights)
	_clock_ui = preload("res://world/env/env_clock.gd").new()
	_clock_ui.dn = self
	add_child(_clock_ui)

	# The settings menu was built before this module registered its rows: rebuild it.
	if main and main.get("hud") and main.hud.get("menu") and main.hud.menu.has_method("_build"):
		main.hud.menu._build()
	_update_all()


func _on_setting(key: String) -> void:
	if key == "dn_start_hour":
		set_hour(float(Settings.get_value("dn_start_hour")))
	elif key == "battery_saver":
		_update_all()


## Jumps the clock (also used by tests and other modules).
func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_update_all()


func is_night() -> bool:
	return night > 0.5


func _update_all() -> void:
	_compute_sun()
	_apply_light()
	_sky_cache.clear()
	_apply_sky()
	if lights:
		lights.refresh()


func _process(delta: float) -> void:
	if not Settings.get_value("dn_paused"):
		var day_sec := maxf(float(Settings.get_value("dn_day_minutes")), 1.0) * 60.0
		hour = fposmod(hour + delta * 24.0 / day_sec, 24.0)
	var h := int(hour)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)

	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = LIGHT_TICK
		_compute_sun()
		_apply_light()
	_sky_t -= delta
	if _sky_t <= 0.0:
		_sky_t = SKY_TICK
		_apply_sky()
	# Lightning flash: cheap per-frame brightness kick (no cubemap update).
	if _env:
		_env.adjustment_brightness = 1.0 + weather.flash * 1.6


func _compute_sun() -> void:
	var t := (hour - 6.0) / 12.0 * PI
	sun_dir = (_east * cos(t) + _noon_dir * sin(t)).normalized()
	sun_height = sun_dir.y
	var base := 1.0 - smoothstep(-0.12, 0.08, sun_height)
	# A dark storm switches the lights on early.
	var storm := clampf((weather.overcast - 0.6) * 1.5, 0.0, 0.6) * (1.0 - smoothstep(0.3, 0.6, sun_height)) if weather else 0.0
	night = clampf(maxf(base, storm), 0.0, 1.0)


func _key(vals: Array) -> Variant:
	var e := sun_height
	if e <= KE[0]:
		return vals[0]
	for i in range(1, KE.size()):
		if e <= KE[i]:
			var k := smoothstep(0.0, 1.0, (e - KE[i - 1]) / (KE[i] - KE[i - 1]))
			return lerp(vals[i - 1], vals[i], k)
	return vals[vals.size() - 1]


func _apply_light() -> void:
	if _sun == null or _env == null:
		return
	var oc: float = weather.overcast
	var rain: float = weather.rain
	var e := sun_height
	var sun_e: float = _key(K_SUN_E)
	var moon_e := 0.32 * (1.0 - smoothstep(-0.12, -0.03, e))
	var use_moon := e < -0.03
	var dir := -sun_dir if use_moon else sun_dir
	_sun.basis = Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	if use_moon:
		_sun.light_color = Color(0.55, 0.66, 1.0)
		_sun.light_energy = moon_e * (1.0 - oc * 0.8)
	else:
		var sc: Color = _key(K_SUN_COL)
		_sun.light_color = sc.lerp(Color(0.85, 0.88, 0.95), oc * 0.6)
		_sun.light_energy = sun_e * (1.0 - oc * 0.85)
	var want_shadow: bool = Perf.shadows_enabled() and not use_moon and _sun.light_energy > 0.15 and oc < 0.8
	if _sun.shadow_enabled != want_shadow:
		_sun.shadow_enabled = want_shadow
	_sun.visible = _sun.light_energy > 0.005

	# Ambient: the sky's own light by day, a fixed blue tone at night (a black night
	# sky would make everything pitch dark).
	var day := smoothstep(-0.1, 0.15, e)
	# By day part of the fill is a fixed neutral-cool tone: the sky cubemap alone is orange
	# at golden hour, which turned every shadow the same brown as the sunlit walls. Warm sun
	# against cooler shade is what gives the frame its depth.
	var golden := smoothstep(-0.05, 0.08, e) * (1.0 - smoothstep(0.25, 0.55, e)) * (1.0 - oc)
	_env.ambient_light_color = Color(0.11, 0.13, 0.22).lerp(Color(0.42, 0.44, 0.5), day * (1.0 - oc * 0.7))
	_env.ambient_light_sky_contribution = lerpf(0.25, lerpf(0.8, 0.6, golden), day)
	_env.ambient_light_energy = lerpf(0.75, 1.0, day)
	# Exposed for the faces and the shade, not the sky: AgX rolls the bright sky off softly.
	_env.tonemap_exposure = lerpf(1.35, 1.5, day) + oc * 0.12

	var fog: Color = _key(K_FOG)
	var grey := Color(0.55, 0.57, 0.6) * lerpf(0.08, 1.0, day)
	fog = fog.lerp(grey * (1.0 - rain * 0.35), oc * 0.8)
	_env.fog_light_color = fog
	# Clear air near the camera; the haze only builds up over the long street views.
	_env.fog_density = 0.0015 + oc * 0.0026 + rain * 0.006
	# Aerial perspective: distance haze takes the sky's colour and glows toward the sun.
	_env.fog_sun_scatter = float(_key(K_SCATTER)) * (1.0 - oc)
	_env.fog_aerial_perspective = 0.6
	# Bloom is tuned per quality preset by world/env/cinematic.gd.


func _apply_sky() -> void:
	if _sky_mat == null:
		return
	var e := sun_height
	var oc: float = weather.overcast
	var rain: float = weather.rain
	var day := smoothstep(-0.12, 0.3, e)
	var glow: float = _key(K_GLOW)
	var hor: Color = _key(K_HOR)
	var fog: Color = _key(K_FOG)
	var cloud := Color(0.56, 0.58, 0.62) * (0.03 + 0.97 * day) * (1.0 - rain * 0.45)
	cloud = cloud.lerp(hor * 0.7, glow * 0.25)
	var phi_now := atan2(sun_dir.x, sun_dir.z)
	var phi_photo := atan2(PHOTO_SUN.x, PHOTO_SUN.z)
	var vals := {
		# Quantised so slow changes only rebuild the cubemap every few seconds.
		"pano_rot": snappedf(wrapf(phi_now - phi_photo, -PI, PI), 0.01),
		"photo_mix": snappedf(smoothstep(0.08, 0.4, e), 0.01),
		"photo_energy": snappedf(lerpf(0.55, 1.0, smoothstep(0.1, 0.5, e)), 0.01),
		"sky_top": _snap_col(_key(K_TOP)),
		"sky_horizon": _snap_col(hor),
		"ground_col": _snap_col(fog * 0.55),
		"glow_col": _snap_col(Color(1.0, 0.45, 0.2).lerp(Color(1.0, 0.7, 0.45), smoothstep(0.0, 0.15, e))),
		"glow": snappedf(glow * (1.0 - oc * 0.8), 0.01),
		"sun_dir": sun_dir.snappedf(0.005),
		"sun_disc": snappedf((1.0 - smoothstep(0.1, 0.3, e)) * (1.0 - oc), 0.01),
		"moon_dir": (-sun_dir).snappedf(0.005),
		"moon": snappedf(1.0 - smoothstep(-0.15, 0.05, e), 0.01),
		"stars": snappedf(1.0 - smoothstep(-0.2, -0.02, e), 0.01),
		"overcast": snappedf(oc, 0.01),
		"sun_glare": snappedf(smoothstep(-0.06, 0.02, e) * (1.0 - oc), 0.01),
		"haze_col": _snap_col(fog.lerp(hor, 0.35)),
		"haze": snappedf(lerpf(0.25, 0.6, day) * (1.0 - oc * 0.5), 0.01),
		"cloud_col": _snap_col(cloud),
	}
	for k in vals:
		if not _sky_cache.has(k) or _sky_cache[k] != vals[k]:
			_sky_cache[k] = vals[k]
			_sky_mat.set_shader_parameter(k, vals[k])


func _snap_col(c: Color) -> Color:
	return Color(snappedf(c.r, 0.004), snappedf(c.g, 0.004), snappedf(c.b, 0.004))


## "HH:MM" of the in-game clock.
func clock_text() -> String:
	var m := int(hour * 60.0)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]

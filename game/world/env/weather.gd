extends Node3D
## Weather states that change over time: clear -> cloudy -> rain -> storm and back.
## Publishes smooth values that day_night.gd / city_lights.gd read:
##   overcast (0..1)  grey sky, weaker sun, denser fog
##   rain     (0..1)  rain particles, rain sound
##   wet      (0..1)  wet roads and sidewalks (rises while it rains, dries slowly)
##   flash    (0..1)  lightning in a storm
## Rain is one GPUParticles3D box that follows the camera (plus a few splashes),
## so the cost does not depend on the size of the city.

signal state_changed(state: String)

# state: [overcast, rain]
const STATES := {
	"clear": [0.0, 0.0],
	"cloudy": [0.72, 0.0],
	"rain": [0.88, 0.65],
	"storm": [1.0, 1.0],
}
const NEXT := {
	"clear": {"clear": 0.35, "cloudy": 0.65},
	"cloudy": {"clear": 0.4, "rain": 0.45, "cloudy": 0.15},
	"rain": {"cloudy": 0.45, "storm": 0.25, "rain": 0.3},
	"storm": {"rain": 0.7, "cloudy": 0.3},
}
const RAIN_DROPS := 2600

var dn: Node
var state := "clear"
var overcast := 0.0
var rain := 0.0
var wet := 0.0
var flash := 0.0

var _rng := RandomNumberGenerator.new()
var _next_change := 0.0
var _drops: GPUParticles3D
var _splash: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _thunder_snd: AudioStreamPlayer
var _strike_t := 0.0
var _thunder_delay := -1.0
var _flash_t := 0.0
var _drop_mat: StandardMaterial3D
var _splash_mat: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	_next_change = _rng.randf_range(150.0, 300.0)
	_drops = _make_drops()
	add_child(_drops)
	_splash = _make_splash()
	add_child(_splash)
	_rain_snd = AudioStreamPlayer.new()
	var rs: AudioStreamWAV = load("res://assets/audio/rain_loop.wav")
	_rain_snd.stream = rs
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)
	_thunder_snd = AudioStreamPlayer.new()
	_thunder_snd.stream = load("res://assets/audio/thunder.wav")
	add_child(_thunder_snd)
	Settings.changed.connect(func(k: String):
		if k == "weather_on" and not Settings.get_value("weather_on"):
			set_state("clear"))


## Changes the weather (smooth transition). Used by the cycle, tests and other modules.
func set_state(s: String, instant := false) -> void:
	if not STATES.has(s):
		return
	state = s
	_next_change = _rng.randf_range(150.0, 360.0)
	if instant:
		overcast = STATES[s][0]
		rain = STATES[s][1]
		wet = clampf(rain * 1.2, 0.0, 1.0)
	state_changed.emit(s)


func _pick_next() -> String:
	var table: Dictionary = NEXT[state]
	var r := _rng.randf()
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return "clear"


func _process(delta: float) -> void:
	if Settings.get_value("weather_on"):
		_next_change -= delta
		if _next_change <= 0.0:
			set_state(_pick_next())
	var target: Array = STATES[state]
	overcast = move_toward(overcast, float(target[0]), delta / 35.0)
	# Rain starts only once the sky is grey enough, and stops first.
	var want_rain: float = float(target[1]) if overcast > 0.6 else 0.0
	rain = move_toward(rain, want_rain, delta / 20.0)
	if rain > 0.05:
		wet = minf(wet + delta * rain / 35.0, 1.0)
	else:
		wet = maxf(wet - delta / 160.0, 0.0)
	_update_fx(delta)
	_update_storm(delta)


func _update_fx(delta: float) -> void:
	var on := rain > 0.01
	if _drops.emitting != on:
		_drops.emitting = on
		_splash.emitting = on
	if on:
		_drops.amount_ratio = clampf(rain, 0.05, 1.0)
		_splash.amount_ratio = clampf(rain, 0.05, 1.0)
		var cam := get_viewport().get_camera_3d()
		if cam:
			var p := cam.global_position
			var fwd := -cam.global_basis.z
			fwd.y = 0.0
			# Box a little ahead of the camera so most drops are on screen.
			_drops.global_position = p + fwd.normalized() * 8.0 + Vector3(0, 12.0, 0)
			var ground := 0.02
			if dn.main and dn.main.player:
				# Player origin is at the feet (in a car it sits 0.5 m above the car origin).
				ground = dn.main.player.global_position.y + 0.02
				if dn.main.player.get("in_vehicle"):
					ground -= 0.9
			_splash.global_position = Vector3(p.x, maxf(ground, 0.02), p.z) + fwd.normalized() * 6.0
		# Unshaded drops: dim them at night so they do not glow.
		var b := lerpf(1.0, 0.22, float(dn.night)) * (1.0 + flash * 2.0)
		_drop_mat.albedo_color = Color(0.72 * b, 0.76 * b, 0.82 * b, 0.4)
		_splash_mat.albedo_color = Color(0.8 * b, 0.84 * b, 0.9 * b, 0.22)
	# Sound: louder with heavier rain, muffled inside a car.
	var sfx := float(Settings.get_value("sfx_volume"))
	var in_car: bool = dn.main != null and dn.main.player != null and bool(dn.main.player.get("in_vehicle"))
	var vol := rain * sfx * (0.45 if in_car else 0.8)
	if vol > 0.005:
		if not _rain_snd.playing:
			_rain_snd.play(_rng.randf() * 4.0)
		_rain_snd.volume_db = linear_to_db(vol)
	elif _rain_snd.playing:
		_rain_snd.stop()


func _update_storm(delta: float) -> void:
	if state == "storm" and rain > 0.6:
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = _rng.randf_range(9.0, 26.0)
			_flash_t = 0.45
			_thunder_delay = _rng.randf_range(0.4, 2.8)
	if _flash_t > 0.0:
		_flash_t -= delta
		# Two or three quick flickers.
		var k := _flash_t / 0.45
		flash = clampf(k * (0.6 + 0.4 * sin(_flash_t * 70.0)), 0.0, 1.0)
	else:
		flash = 0.0
	if _thunder_delay >= 0.0:
		_thunder_delay -= delta
		if _thunder_delay < 0.0:
			_thunder_snd.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")) * 0.9, 0.0001))
			_thunder_snd.pitch_scale = _rng.randf_range(0.85, 1.1)
			_thunder_snd.play()


func _make_drops() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = RAIN_DROPS
	p.lifetime = 1.1
	p.preprocess = 1.1
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 45, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1.5, 22)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 19.0
	pm.initial_velocity_max = 23.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.026, 0.8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.albedo_color = Color(0.72, 0.76, 0.82, 0.4)
	m.disable_receive_shadows = true
	q.material = m
	_drop_mat = m
	p.draw_pass_1 = q
	return p


func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 0.28
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 6, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 0.0, 14)
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -9.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_color = Color(0.8, 0.84, 0.9, 0.22)
	q.material = m
	_splash_mat = m
	p.draw_pass_1 = q
	return p

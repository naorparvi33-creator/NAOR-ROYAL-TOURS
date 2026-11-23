extends Node3D
## Night lighting for the city, driven by day_night.gd (`dn.night`, 0..1):
##  * Street lamp heads glow (the shared lamp glass material becomes emissive).
##    Real OmniLights only for the few lamps nearest the camera: a small pool that is
##    re-assigned a few times per second, fading in so nothing pops. No shadows.
##  * Building windows and shop fronts light up (building.gdshader `night_lights`), with
##    fewer lit flats late at night (`lit_ratio`).
##  * One SpotLight3D headlight on the car the player drives.
##  * Wet sidewalks while it rains (weather.gd sets `dn.weather.wet`).

const POOL := 4
const LAMP_HEAD := Vector3(1.75, 6.55, 0.0)   # lamp glass in props.gd street_lamp(), local
const REASSIGN := 0.35
# Flats with lights on, by hour of the day.
const LIT_HOURS := [0.0, 2.0, 5.0, 6.5, 9.0, 17.0, 19.0, 22.5, 24.0]
const LIT_RATIO := [0.22, 0.13, 0.1, 0.26, 0.15, 0.24, 0.38, 0.36, 0.22]

var dn: Node

var _lamp_pos := PackedVector3Array()
var _lamp_mat: StandardMaterial3D
var _pavers: StandardMaterial3D
var _pavers_col := Color.WHITE
var _facades: Array[ShaderMaterial] = []
var _ground: ShaderMaterial
var _pool: Array[OmniLight3D] = []
var _pool_lamp: Array[int] = []
var _pool_fade: Array[float] = []
var _headlight: SpotLight3D
var _t := 0.0
var _last_night := -1.0
var _last_ratio := -1.0
var _last_wet := -1.0


func _ready() -> void:
	var world: Node = dn.main.world if dn.main else null
	if world:
		var lamps: Variant = world.get("_lamps")
		if lamps is Array:
			for xf in lamps:
				_lamp_pos.append((xf as Transform3D) * LAMP_HEAD)
		var fac: Variant = world.get("_facades")
		if fac is Array:
			for m in fac:
				if m is ShaderMaterial:
					_facades.append(m)
		for c in world.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
				var mat: Material = ((c as MeshInstance3D).mesh as PlaneMesh).material
				if mat is ShaderMaterial and (mat as ShaderMaterial).shader == preload("res://world/ground.gdshader"):
					_ground = mat
	# Same cached instances city.gd used (Mats caches by parameters).
	_lamp_mat = Mats.plain(Color(0.9, 0.9, 0.85), 0.2)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.8, 0.52)
	_lamp_mat.emission_energy_multiplier = 0.0
	_pavers = Mats.pbr("pavers", 2.0, Color(0.92, 0.92, 0.92))
	_pavers_col = _pavers.albedo_color

	for i in POOL:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.omni_range = 19.0
		# Steeper falloff: a bright pool under each lamp that fades into the dark street,
		# instead of an even wash over the whole block.
		l.omni_attenuation = 1.8
		l.light_energy = 0.0
		l.light_specular = 0.6
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 32.0
		l.distance_fade_length = 10.0
		l.visible = false
		add_child(l)
		_pool.append(l)
		_pool_lamp.append(-1)
		_pool_fade.append(0.0)

	_make_headlight()


func _make_headlight() -> void:
	_headlight = SpotLight3D.new()
	_headlight.light_color = Color(1.0, 0.95, 0.85)
	_headlight.spot_range = 42.0
	_headlight.spot_angle = 30.0
	_headlight.spot_angle_attenuation = 0.8
	_headlight.spot_attenuation = 0.9
	_headlight.light_energy = 0.0
	_headlight.shadow_enabled = false
	_headlight.visible = false
	add_child(_headlight)


## Re-applies everything at once (after a time jump).
func refresh() -> void:
	_last_night = -1.0
	_last_ratio = -1.0
	_apply_materials()
	_t = 0.0


func _apply_materials() -> void:
	var n: float = dn.night
	if absf(n - _last_night) > 0.004:
		_last_night = n
		_lamp_mat.emission_energy_multiplier = n * 7.0
		for m in _facades:
			m.set_shader_parameter("night_lights", n)
	var ratio := _lit_ratio(dn.hour)
	if absf(ratio - _last_ratio) > 0.004:
		_last_ratio = ratio
		for m in _facades:
			m.set_shader_parameter("lit_ratio", ratio)
	var wet: float = dn.weather.wet if dn.weather else 0.0
	if absf(wet - _last_wet) > 0.004:
		_last_wet = wet
		if _ground:
			_ground.set_shader_parameter("wetness", wet)
		_pavers.roughness = lerpf(1.0, 0.45, wet)
		_pavers.albedo_color = _pavers_col * lerpf(1.0, 0.68, wet)
		_pavers.albedo_color.a = 1.0


func _lit_ratio(h: float) -> float:
	for i in range(1, LIT_HOURS.size()):
		if h <= LIT_HOURS[i]:
			var a: float = LIT_HOURS[i - 1]
			var b: float = LIT_HOURS[i]
			return lerpf(LIT_RATIO[i - 1], LIT_RATIO[i], (h - a) / (b - a))
	return LIT_RATIO[0]


func _process(delta: float) -> void:
	var n: float = dn.night
	_t -= delta
	if _t <= 0.0:
		_t = REASSIGN
		_apply_materials()
		if n > 0.02:
			_assign_lamps()
	# Lamp lights fade in after being moved to a new lamp.
	for i in POOL:
		var l := _pool[i]
		if n <= 0.02 or _pool_lamp[i] < 0:
			l.visible = false
			continue
		_pool_fade[i] = minf(_pool_fade[i] + delta * 2.5, 1.0)
		l.light_energy = 10.0 * n * _pool_fade[i]
		l.visible = true
	_update_headlight(n)


func _assign_lamps() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _lamp_pos.is_empty():
		return
	# Lamps around a point a little ahead of the camera: the lit pools that matter are in view.
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var p := cam.global_position + fwd.normalized() * 10.0
	# Nearest POOL lamps (simple insertion; ~400 lamps, a few times per second).
	var best: Array[int] = []
	var best_d: Array[float] = []
	for i in _lamp_pos.size():
		var d := p.distance_squared_to(_lamp_pos[i])
		if best.size() == POOL and d >= best_d[POOL - 1]:
			continue
		var k := best.size()
		while k > 0 and best_d[k - 1] > d:
			k -= 1
		best.insert(k, i)
		best_d.insert(k, d)
		if best.size() > POOL:
			best.resize(POOL)
			best_d.resize(POOL)
	# Keep lights that are still on a wanted lamp; move the others.
	var free: Array[int] = []
	for i in POOL:
		var at := best.find(_pool_lamp[i])
		if at >= 0:
			best.remove_at(at)
		else:
			free.append(i)
	for i in free:
		if best.is_empty():
			_pool_lamp[i] = -1
			continue
		var lamp: int = best.pop_front()
		_pool_lamp[i] = lamp
		_pool_fade[i] = 0.0
		_pool[i].global_position = _lamp_pos[lamp] + Vector3(0, -0.25, 0)


func _update_headlight(n: float) -> void:
	var player: Node = dn.main.player if dn.main else null
	var car: Node3D = null
	if player and player.get("in_vehicle") and player.get("vehicle") is Node3D:
		car = player.vehicle
	if not is_instance_valid(_headlight):
		_make_headlight()   # it was freed together with a destroyed car
	var on: bool = car != null and is_instance_valid(car) and (n > 0.15 or float(dn.weather.rain) > 0.3)
	if not on:
		if _headlight.visible:
			_headlight.visible = false
		return
	if _headlight.get_parent() != car:
		_headlight.reparent(car, false)
		# Car faces +Z (car_mesh.gd); a spot light shines along its -Z.
		_headlight.transform = Transform3D(Basis.looking_at(Vector3(0, -0.1, 1)), Vector3(0, 0.75, 2.1))
	_headlight.visible = true
	_headlight.light_energy = 5.0 * maxf(n, 0.6)


func _exit_tree() -> void:
	# The headlight may live under a car; take it back so it is freed with us.
	if is_instance_valid(_headlight) and _headlight.get_parent() != self:
		_headlight.queue_free()

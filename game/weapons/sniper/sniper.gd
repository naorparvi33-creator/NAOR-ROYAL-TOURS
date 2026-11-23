extends Node
## Sniper module: three bolt-action rifles with real projectile ballistics.
##  * Rifles are in the normal weapon cycle (weapons/weapon_basic.gd WEAPONS, "sniper" key);
##    this module fires them instead of the hitscan code.
##  * Scope: own first-person camera at the eye, zoom 4x / 8x / 12x (switch inside the scope
##    with the swap button or the zoom chip), breathing sway, hold breath (keep the left
##    thumb still, or the jump button), recoil and bolt cycling.
##  * Two control modes (setting "sniper_scope_mode"):
##      0 = hold fire to scope, release to shoot (two thumbs, default); tap the aim button
##          while holding to cancel the shot
##      1 = aim button toggles the scope, fire button shoots
##  * Reticle holdover marks come from the same ballistics as the bullets (ballistics.gd).
##  * Optional slow-motion bullet cam for long or decisive shots ("sniper_bullet_cam").
##  * Hits on people: head / body / limb. Hit marker and sound.
##  * Long-distance range with targets at 100..1000 m (shooting_range.gd), reached from a
##    marker in the park.

const Ballistics := preload("res://weapons/sniper/ballistics.gd")
const Rifles := preload("res://weapons/sniper/rifles.gd")
const SniperMesh := preload("res://weapons/sniper/sniper_mesh.gd")
const BASE_FOV := 60.0           # vertical field of view at 1x
const SCOPE_IN_FOV := 46.0
const EYE_STAND := 1.56
const EYE_CROUCH := 1.06
const BREATH_HOLD_MAX := 4.5     # seconds of steady aim
const BREATH_RECOVER := 3.0      # seconds to refill from empty
const EXHAUST_TIME := 2.5
const RANGEFINDER_MAX := 2500.0
const PED_FAR_RANGE := 900.0     # people stay visible this far while scoped
const SOUND_SPEED := 343.0

var main: Node

# ---- state read by the scope overlay
var equipped := false
var scoped := false
var scope_open := 0.0
var zoom := 4.0
var fov_deg := BASE_FOV
var table: Dictionary = {}
var range_m := -1.0
var breath := 1.0
var holding_breath := false
var exhausted := false
var ammo := 5
var mag_size := 5
var bolt_k := 1.0
var reload_k := 1.0
var last_shot_text := ""
var scope_shift := Vector2.ZERO
var show_hint := false
var bullet_cam_active := false
var cam_distance := 0.0
var cam_time := 0.0
var in_range_area := false

var player: CharacterBody3D
var weapon: Node
var rig: Node3D
var bullets: Node3D
var shooting_range: Node3D
var overlay: Control
var scope_cam: Camera3D
var cine_cam: Camera3D

var _layer: CanvasLayer
var _scaler: Node
var _rifle_id := ""
var _spec: Dictionary = {}
var _tables := {}
var _meshes := {}
var _zoom_i := {}
var _ammo_by := {}
var _orig_mesh: Mesh = null
var _fire_prev := false
var _hold_active := false
var _hold_cancel := false
var _hold_set_aim := false
var _scoped_time := 0.0
var _bolt_t := 0.0
var _bolt_sound_t := -1.0
var _reload_t := 0.0
var _breath_toggle := false
var _exhaust_t := 0.0
var _heart_t := 0.0
var _sway_t := 0.0
var _sway_amp := 0.0
var _sway := Vector2.ZERO
var _kick := 0.0
var _kick_v := 0.0
var _eye := EYE_STAND
var _zoom_smooth := 4.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _tick := 0
var _scope_count := 0
var _hint_t := 0.0
var _equip_hint_done := false
var _cam_id := -1
var _cam_impact: Dictionary = {}
var _cam_hold := 0.0
var _cam_origin := Vector3.ZERO
var _cam_dir := Vector3.FORWARD
var _teleporting := false
var _env: Environment
var _env_fog := 0.0
var _far_peds := false
var _snd := {}
var _streams := {}


## Moves the look input between GameInput (pad stick) and the camera rig, so the scope
## turns slower at higher zoom.
class LookScaler extends Node:
	var factor := 1.0

	func _process(_d: float) -> void:
		if factor != 1.0:
			GameInput.add_look(GameInput.consume_look() * factor)


## Runs after the camera rig so the scope camera uses this frame's yaw / pitch.
class LateDriver extends Node:
	var owner_module: Node

	func _process(delta: float) -> void:
		owner_module.late_process(delta)


func _init() -> void:
	process_physics_priority = -10      # before the player and the hitscan weapon read input


func _ready() -> void:
	_register_strings()
	Settings.register_defaults({"sniper_scope_mode": 0, "sniper_bullet_cam": true})
	if main and main.hud and main.hud.menu and main.hud.menu.has_method("_build"):
		main.hud.menu.call_deferred("_build")      # show this module's settings rows
	_rng.randomize()
	_noise.seed = 4242
	_noise.frequency = 0.6
	player = main.player
	weapon = player.weapon
	rig = player.rig
	if player.model and player.model.rifle is MeshInstance3D:
		_orig_mesh = (player.model.rifle as MeshInstance3D).mesh

	for id in Rifles.RIFLES:
		var r: Dictionary = Rifles.RIFLES[id]
		_tables[id] = Ballistics.holdover_table(float(r["v0"]), float(r["k"]))
		_zoom_i[id] = 1
		_ammo_by[id] = int(r["mag"])

	bullets = preload("res://weapons/sniper/bullets.gd").new()
	bullets.exclude.append(player.get_rid())
	add_child(bullets)
	bullets.impact.connect(_on_impact)

	shooting_range = preload("res://weapons/sniper/shooting_range.gd").new()
	shooting_range.module = self
	add_child(shooting_range)

	scope_cam = Camera3D.new()
	scope_cam.near = 0.1
	scope_cam.far = 2600.0
	scope_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	scope_cam.top_level = true
	add_child(scope_cam)
	cine_cam = Camera3D.new()
	cine_cam.near = 0.05
	cine_cam.far = 2600.0
	cine_cam.fov = 40.0
	cine_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cine_cam.top_level = true
	add_child(cine_cam)

	_layer = CanvasLayer.new()
	_layer.layer = 9            # under the HUD (layer 10) so the touch buttons stay on top
	add_child(_layer)
	overlay = preload("res://weapons/sniper/scope_overlay.gd").new()
	overlay.sniper = self
	_layer.add_child(overlay)

	var driver := LateDriver.new()
	driver.owner_module = self
	driver.process_priority = 100
	add_child(driver)
	_scaler = LookScaler.new()
	_scaler.name = "SniperLookScaler"
	call_deferred("_install_scaler")

	for s in ["sniper_shot", "sniper_bolt", "hit_tick", "steel_ding", "breath_in", "breath_out", "heartbeat"]:
		_streams[s] = load("res://weapons/sniper/audio/%s.wav" % s)
	for ch in ["shot", "bolt", "ui", "ding", "breath", "heart"]:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_snd[ch] = p

	var envs: Array = main.world.find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		_env = (envs[0] as WorldEnvironment).environment
		_env_fog = _env.fog_density
	weapon.weapon_changed.connect(func(_k): _sync_weapon())


func _install_scaler() -> void:
	var root := get_tree().root
	root.add_child(_scaler)
	root.move_child(_scaler, GameInput.get_index() + 1)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_scaler):
		_scaler.queue_free()


# ------------------------------------------------------------ strings

func _register_strings() -> void:
	Loc.register({
		"he": {
			"weapon_sniper_light": "רובה צלפים קל (750 מ'/ש')",
			"weapon_sniper_medium": "רובה צלפים (850 מ'/ש')",
			"weapon_sniper_heavy": "רובה צלפים כבד (950 מ'/ש')",
			"sniper_scope_mode": "צליפה: כוונת וירי",
			"scope_mode_hold": "החזק לכוונת, שחרר לירי",
			"scope_mode_sep": "כפתורים נפרדים",
			"sniper_bullet_cam": "מצלמת קליע בהילוך איטי",
			"snp_hold": "החזקה mrad",
			"snp_breath": "נשימה",
			"snp_breath_hold": "עוצר נשימה",
			"snp_reloading": "טוען...",
			"snp_zoom": "זום",
			"snp_skip": "לחיצה על ירי מדלגת",
			"snp_hint_breath": "אגודל שמאל לחוץ ובלי לזוז = עצירת נשימה",
			"snp_hint_cancel": "לחיצה על כוונת = ביטול הירייה",
			"snp_hint_sep": "כפתור הכוונת פותח סקופ, ירי יורה",
			"snp_equip_hold": "צלף: החזק ירי לכוונת, שחרר כדי לירות",
			"snp_equip_sep": "צלף: כוונת לסקופ, ירי כדי לירות",
			"snp_head": "ראש!",
			"snp_body": "פלג גוף",
			"snp_limb": "גפה",
			"snp_kill": "חוסל",
			"snp_center": "מרכז!",
			"snp_plate": "פגיעה",
			"snp_high": "גבוה",
			"snp_low": "נמוך",
			"snp_left": "שמאלה",
			"snp_right": "ימינה",
			"snp_cm": "ס״מ",
			"snp_m": "מ׳",
			"snp_range_title": "מטווח צלפים · 100-1000 מ'",
			"snp_range_welcome": "מטווח צלפים: מטרות כל 100 מ' עד 1000 מ'",
			"snp_marker_range": "מטווח צלפים",
			"snp_marker_city": "חזרה לעיר",
			"ctx_range_go": "למטווח",
			"ctx_range_back": "לעיר",
		},
		"en": {
			"weapon_sniper_light": "Light sniper rifle (750 m/s)",
			"weapon_sniper_medium": "Sniper rifle (850 m/s)",
			"weapon_sniper_heavy": "Heavy sniper rifle (950 m/s)",
			"sniper_scope_mode": "Sniper: scope and fire",
			"scope_mode_hold": "Hold to scope, release to fire",
			"scope_mode_sep": "Separate buttons",
			"sniper_bullet_cam": "Slow-motion bullet cam",
			"snp_hold": "hold mrad",
			"snp_breath": "Breath",
			"snp_breath_hold": "Holding breath",
			"snp_reloading": "Reloading...",
			"snp_zoom": "zoom",
			"snp_skip": "Tap fire to skip",
			"snp_hint_breath": "Keep the left thumb down and still = hold breath",
			"snp_hint_cancel": "Tap aim = cancel the shot",
			"snp_hint_sep": "Aim opens the scope, fire shoots",
			"snp_equip_hold": "Sniper: hold fire to scope, release to shoot",
			"snp_equip_sep": "Sniper: aim for the scope, fire to shoot",
			"snp_head": "Headshot!",
			"snp_body": "Body",
			"snp_limb": "Limb",
			"snp_kill": "Kill",
			"snp_center": "Centre!",
			"snp_plate": "Hit",
			"snp_high": "high",
			"snp_low": "low",
			"snp_left": "left",
			"snp_right": "right",
			"snp_cm": "cm",
			"snp_m": "m",
			"snp_range_title": "Sniper range · 100-1000 m",
			"snp_range_welcome": "Sniper range: targets every 100 m out to 1000 m",
			"snp_marker_range": "Sniper range",
			"snp_marker_city": "Back to the city",
			"ctx_range_go": "Range",
			"ctx_range_back": "City",
		},
	})


# ------------------------------------------------------------ weapon selection

func _current_rifle_id() -> String:
	if player.in_vehicle:
		return ""
	var w: Dictionary = weapon.WEAPONS[weapon.current]
	return str(w.get("sniper", ""))


func _sync_weapon() -> void:
	var id := _current_rifle_id()
	if id == _rifle_id:
		return
	if _rifle_id != "":
		_ammo_by[_rifle_id] = ammo
	_rifle_id = id
	equipped = id != ""
	var mi: MeshInstance3D = player.model.rifle if player.model and player.model.rifle is MeshInstance3D else null
	if not equipped:
		if mi and _orig_mesh:
			mi.mesh = _orig_mesh
		return
	_spec = Rifles.RIFLES[id]
	table = _tables[id]
	mag_size = int(_spec["mag"])
	ammo = int(_ammo_by.get(id, mag_size))
	zoom = float(_spec["zooms"][int(_zoom_i[id])])
	_bolt_t = 0.0
	_reload_t = 0.0 if ammo > 0 else float(_spec["reload"])
	if not _meshes.has(id):
		_meshes[id] = SniperMesh.build(_spec)
	if mi:
		mi.mesh = _meshes[id]
	if not _equip_hint_done and main.hud and main.hud.has_method("toast"):
		_equip_hint_done = true
		var sep := int(Settings.get_value("sniper_scope_mode")) == 1
		main.hud.toast(Loc.t("snp_equip_sep" if sep else "snp_equip_hold"))


## Index of a sniper rifle in the weapon list (or -1).
func weapon_index(id: String) -> int:
	for i in weapon.WEAPONS.size():
		if str(weapon.WEAPONS[i].get("sniper", "")) == id:
			return i
	return -1


func select_rifle(id: String) -> void:
	var i := weapon_index(id)
	if i < 0 or weapon.current == i:
		return
	weapon.current = i
	player.model.set_weapon(int(weapon.WEAPONS[i]["kind"]))
	weapon.weapon_changed.emit(weapon.WEAPONS[i]["key"])


func cycle_zoom() -> void:
	if not equipped:
		return
	var zs: Array = _spec["zooms"]
	_zoom_i[_rifle_id] = (int(_zoom_i[_rifle_id]) + 1) % zs.size()
	zoom = float(zs[int(_zoom_i[_rifle_id])])
	_play("ui", "sniper_bolt", -18.0, 2.2)


# ------------------------------------------------------------ physics: input, firing

func _physics_process(delta: float) -> void:
	if player == null or shooting_range == null:
		return
	_tick += 1
	_sync_weapon()
	_timers(delta)
	if _tick % 30 == 0:
		_check_range_area()
	if not equipped or GameInput.menu_open:
		if scoped:
			_set_scoped(false)
		_fire_prev = GameInput.is_firing()
		_hold_active = false
		return

	var firing := GameInput.is_firing()
	var pressed := firing and not _fire_prev
	var released := not firing and _fire_prev
	_fire_prev = firing

	if bullet_cam_active:
		if pressed:
			_end_bullet_cam()
		_hold_active = false
	elif int(Settings.get_value("sniper_scope_mode")) == 0:
		if pressed:
			_hold_active = true
			_hold_cancel = false
			_hold_set_aim = not player.aiming
			player.aiming = true
		if _hold_active and firing and not player.aiming:
			_hold_cancel = true        # aim button tapped while holding: no shot
		if released and _hold_active:
			_hold_active = false
			if not _hold_cancel and _scoped_time >= 0.15:
				shoot()
			if _hold_set_aim:
				player.aiming = false
	elif pressed:
		shoot()

	if player.aiming != scoped:
		_set_scoped(player.aiming)
	if scoped:
		_scoped_time += delta
		if GameInput.consume("swap"):
			cycle_zoom()
		if GameInput.consume("jump"):
			_breath_toggle = not _breath_toggle
		if _tick % 4 == 0:
			_rangefinder()
	_update_breath(delta)


func _timers(delta: float) -> void:
	if _bolt_t > 0.0:
		_bolt_t = maxf(_bolt_t - delta, 0.0)
	if _bolt_sound_t >= 0.0:
		_bolt_sound_t -= delta
		if _bolt_sound_t < 0.0:
			_play("bolt", "sniper_bolt", -4.0, float(_spec.get("pitch", 1.0)) if not _spec.is_empty() else 1.0)
	if _reload_t > 0.0:
		_reload_t = maxf(_reload_t - delta, 0.0)
		if _reload_t <= 0.0 and equipped:
			ammo = mag_size
			_play("bolt", "sniper_bolt", -2.0, 0.85)
	if equipped:
		bolt_k = 1.0 - _bolt_t / maxf(float(_spec["bolt"]), 0.01)
		reload_k = 1.0 - _reload_t / maxf(float(_spec["reload"]), 0.01)
	else:
		bolt_k = 1.0
		reload_k = 1.0


func _set_scoped(on: bool) -> void:
	scoped = on
	_scoped_time = 0.0
	if not on:
		_breath_toggle = false
		if holding_breath:
			holding_breath = false
			_play("breath", "breath_out", -6.0)
		range_m = -1.0
	else:
		_scope_count += 1
		_zoom_smooth = zoom
		if _scope_count <= 3:
			_hint_t = 6.0
	_set_far_peds(on)
	if main.hud and main.hud.crosshair:
		main.hud.crosshair.visible = not on and not player.in_vehicle
	_apply_camera()


func _apply_camera() -> void:
	if bullet_cam_active:
		cine_cam.make_current()
		player.model.visible = not player.in_vehicle
	elif scoped:
		scope_cam.make_current()
		player.model.visible = false
	else:
		rig.camera.make_current()
		player.model.visible = not player.in_vehicle


func _update_breath(delta: float) -> void:
	if exhausted:
		_exhaust_t -= delta
		breath = minf(breath + delta / (BREATH_RECOVER * 1.6), 1.0)
		if _exhaust_t <= 0.0:
			exhausted = false
	var want: bool = scoped and not exhausted and breath > 0.0 and (_breath_toggle or overlay.left_hold)
	if want and not holding_breath:
		_play("breath", "breath_in", -8.0)
		_heart_t = 0.6
	elif holding_breath and not want:
		_play("breath", "breath_out", -8.0)
		_breath_toggle = false
	holding_breath = want
	if holding_breath:
		breath -= delta / BREATH_HOLD_MAX
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 0.9 if breath > 0.35 else 0.6
			_play("heart", "heartbeat", -10.0 if breath > 0.35 else -4.0)
		if breath <= 0.0:
			breath = 0.0
			holding_breath = false
			_breath_toggle = false
			exhausted = true
			_exhaust_t = EXHAUST_TIME
			_play("breath", "breath_out", -2.0, 0.9)
	elif not exhausted:
		breath = minf(breath + delta / BREATH_RECOVER, 1.0)


func _rangefinder() -> void:
	var space := player.get_world_3d().direct_space_state
	var o := scope_cam.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - scope_cam.global_basis.z * RANGEFINDER_MAX, 1 | 4, [player.get_rid()])
	var res := space.intersect_ray(q)
	range_m = -1.0 if res.is_empty() else o.distance_to(res["position"])


## Holdover in mrad (aim this much higher) for a distance, from the rifle's table.
func holdover_mark_for(d: float) -> float:
	var ds: Array = table.get("d", [])
	var angs: Array = table.get("angle", [])
	if ds.is_empty():
		return 0.0
	if d <= float(ds[0]):
		return float(angs[0]) * d / float(ds[0]) * 1000.0
	for i in range(1, ds.size()):
		if d <= float(ds[i]):
			var f := (d - float(ds[i - 1])) / (float(ds[i]) - float(ds[i - 1]))
			return lerpf(float(angs[i - 1]), float(angs[i]), f) * 1000.0
	return float(angs[angs.size() - 1]) * 1000.0


## Fires the current rifle from the scope (or from the hip in the separate-button mode).
func shoot() -> bool:
	if not equipped or _bolt_t > 0.0 or _reload_t > 0.0:
		return false
	if ammo <= 0:
		_reload_t = float(_spec["reload"])
		return false
	var origin: Vector3
	var dir: Vector3
	var right: Vector3
	if scoped:
		origin = scope_cam.global_position
		dir = -scope_cam.global_basis.z
		right = scope_cam.global_basis.x
	else:
		var ray: Array = rig.aim_ray()
		origin = ray[0]
		dir = ray[1]
		var s := deg_to_rad(1.4)
		right = dir.cross(Vector3.UP).normalized()
		dir = dir.rotated(Vector3.UP, _rng.randf_range(-s, s)).rotated(right, _rng.randf_range(-s, s))
	var launch := dir.rotated(right.normalized(), float(table["zero"]))
	var v0: float = _spec["v0"]
	var k: float = _spec["k"]
	var id: int = bullets.fire(origin + dir * 0.25, launch * v0, k, float(_spec["damage"]))
	ammo -= 1
	_bolt_t = float(_spec["bolt"])
	_bolt_sound_t = 0.32
	if ammo <= 0:
		_reload_t = float(_spec["reload"]) + _bolt_t
		_bolt_sound_t = -1.0
	_play("shot", "sniper_shot", 0.0, float(_spec["pitch"]) * _rng.randf_range(0.96, 1.04))
	var muzzle := player.global_position + Vector3(0, 1.45, 0)
	get_tree().call_group("panic_listeners", "on_gunshot", muzzle)
	weapon.fired.emit()
	# Recoil: a sharp kick in the scope that settles, plus a little muzzle climb.
	var kick: float = _spec["kick"]
	_kick_v += deg_to_rad(kick) * 14.0
	var f := maxf(_scaler.factor if _scaler else 1.0, 0.05)
	GameInput.add_look(Vector2(_rng.randf_range(-0.12, 0.12), -kick * 0.12) / f)
	_maybe_bullet_cam(id, origin + dir * 0.25, launch * v0, k)
	return true


# ------------------------------------------------------------ impacts

func _on_impact(info: Dictionary) -> void:
	if int(info["id"]) == _cam_id:
		_cam_impact = info
	var dist: float = info["distance"]
	last_shot_text = "%d m · %.2f s" % [roundi(dist), float(info["time"])]
	var kind: String = info["kind"]
	match kind:
		"ped":
			var zone: String = info["zone"]
			var txt := Loc.t("snp_" + zone)
			if info["killed"]:
				txt = "%s %s" % [Loc.t("snp_kill"), txt] if zone != "head" else txt
			overlay.flash_hit(bool(info["killed"]), "%s · %d %s" % [txt, roundi(dist), Loc.t("snp_m")])
			_play("ui", "hit_tick", -2.0 if info["killed"] else -6.0, 0.8 if info["killed"] else 1.0)
			weapon.hit.emit(true)
		"target":
			var t: Node = info["collider"]
			var off: Vector2 = t.last_offset()
			var zone2: String = info["zone"]
			var head := Loc.t("snp_center") if zone2 == "center" else (Loc.t("snp_head") if zone2 == "head" else Loc.t("snp_plate"))
			var txt2 := "%s · %s%d %s" % [head, _offset_text(off) + " · " if _offset_text(off) != "" else "", int(t.distance_m), Loc.t("snp_m")]
			overlay.flash_hit(zone2 == "center", txt2)
			_play("ui", "hit_tick", -8.0)
			# The ring of the steel comes back at the speed of sound.
			var delay := dist / SOUND_SPEED
			var vol := clampf(-2.0 - dist * 0.012, -18.0, 0.0)
			get_tree().create_timer(delay, true, false, true).timeout.connect(func():
				_play("ding", "steel_ding", vol, _rng.randf_range(0.95, 1.05)))
			weapon.hit.emit(true)
		"object":
			overlay.flash_hit(false, "")
			_play("ui", "hit_tick", -10.0, 1.2)
			weapon.hit.emit(true)
		_:
			weapon.hit.emit(false)


func _offset_text(off: Vector2) -> String:
	var parts: Array[String] = []
	var cm_y := roundi(off.y * 100.0)
	var cm_x := roundi(off.x * 100.0)
	if absi(cm_y) >= 2:
		parts.append("%d %s %s" % [absi(cm_y), Loc.t("snp_cm"), Loc.t("snp_high") if cm_y > 0 else Loc.t("snp_low")])
	if absi(cm_x) >= 2:
		parts.append("%d %s %s" % [absi(cm_x), Loc.t("snp_cm"), Loc.t("snp_right") if cm_x > 0 else Loc.t("snp_left")])
	return ", ".join(parts)


# ------------------------------------------------------------ bullet cam

## Looks ahead along the trajectory; long or decisive shots get the slow-motion camera.
func _maybe_bullet_cam(id: int, origin: Vector3, vel: Vector3, k: float) -> void:
	if not bool(Settings.get_value("sniper_bullet_cam")) or bullet_cam_active:
		return
	var hit := predict_hit(origin, vel, k)
	if hit.is_empty():
		return
	var c: Object = hit["collider"]
	var d: float = hit["distance"]
	var ped_shot := c != null and "ped" in c and str((c.ped as Dictionary).get("state", "")) != "dead" and d >= 70.0
	var far_target := c != null and c.has_method("is_range_target") and d >= 450.0
	if not ped_shot and not far_target:
		return
	_cam_id = id
	_cam_impact = {}
	_cam_hold = 0.0
	_cam_origin = origin
	_cam_dir = vel.normalized()
	cam_distance = 0.0
	cam_time = 0.0
	bullet_cam_active = true
	# Whole flight lasts ~1.8 s of real time.
	Engine.time_scale = clampf(float(hit["time"]) / 1.8, 0.04, 0.6)
	_apply_camera()


## First thing the bullet would hit if nothing moves: {collider, point, distance, time}.
func predict_hit(origin: Vector3, vel: Vector3, k: float) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var pos := origin
	var v := vel
	var t := 0.0
	var ex: Array[RID] = [player.get_rid()]
	while t < Ballistics.MAX_TIME:
		var start := pos
		for i in 4:
			var r := Ballistics.step(pos, v, k, Ballistics.STEP)
			pos = r[0]
			v = r[1]
		t += Ballistics.STEP * 4.0
		var q := PhysicsRayQueryParameters3D.create(start, pos, 1 | 4, ex)
		var res := space.intersect_ray(q)
		if not res.is_empty():
			return {"collider": res["collider"], "point": res["position"],
				"distance": origin.distance_to(res["position"]), "time": t}
		if pos.y < -20.0:
			break
	return {}


func _end_bullet_cam() -> void:
	bullet_cam_active = false
	_cam_id = -1
	Engine.time_scale = 1.0
	_apply_camera()


func _update_bullet_cam(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	var st: Variant = bullets.bullet_state(_cam_id)
	if st != null:
		var p: Vector3 = st[0]
		var v: Vector3 = st[1]
		var f := v.normalized()
		var side := f.cross(Vector3.UP).normalized()
		cam_distance = _cam_origin.distance_to(p)
		cam_time += delta
		var cp := p - f * 1.6 + side * 0.32 + Vector3.UP * 0.14
		cine_cam.global_transform = Transform3D(Basis.looking_at((p + f * 6.0 - cp).normalized(), Vector3.UP), cp)
		return
	# Bullet arrived: a short look at the impact, then back to normal speed.
	if _cam_hold == 0.0:
		Engine.time_scale = 0.3
	_cam_hold += real
	if not _cam_impact.is_empty():
		var ip: Vector3 = _cam_impact["point"]
		var side2 := _cam_dir.cross(Vector3.UP).normalized()
		var a := _cam_hold * 0.5
		var cp2 := ip - _cam_dir * 3.2 * cos(a) + side2 * (1.2 + 2.0 * sin(a)) + Vector3.UP * 0.6
		cine_cam.global_transform = Transform3D(Basis.looking_at((ip - cp2).normalized(), Vector3.UP), cp2)
	if _cam_hold > 1.3 or _cam_impact.is_empty() and _cam_hold > 0.2:
		_end_bullet_cam()


# ------------------------------------------------------------ late process: cameras, sway

func late_process(delta: float) -> void:
	if player == null:
		return
	var rd := delta / maxf(Engine.time_scale, 0.01)
	_hint_t = maxf(_hint_t - rd, 0.0)
	show_hint = _hint_t > 0.0
	scope_open = move_toward(scope_open, 1.0 if scoped else 0.0, rd * 7.0)
	_scaler.factor = (4.0 / _zoom_smooth) if scoped else 1.0
	if bullet_cam_active:
		_update_bullet_cam(delta)
	if not scoped:
		return
	GameInput.aim_state = 2
	_zoom_smooth = lerpf(_zoom_smooth, zoom, 1.0 - exp(-14.0 * rd))
	if absf(_zoom_smooth - zoom) < 0.01:
		_zoom_smooth = zoom
	var target_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(BASE_FOV) * 0.5) / _zoom_smooth))
	var e := ease(scope_open, 0.5)
	fov_deg = lerpf(SCOPE_IN_FOV, target_fov, e)
	scope_cam.fov = fov_deg

	# Breathing sway (figure-eight), muscle tremor, movement and stance.
	_sway_t += delta
	var amp := 0.0016 * float(_spec["sway"])
	if player.crouching:
		amp *= 0.55
	var hv := Vector2(player.velocity.x, player.velocity.z).length()
	amp *= 1.0 + minf(hv, 5.0) * 0.55
	if holding_breath:
		amp *= 0.1
	elif exhausted:
		amp *= 2.2
	_sway_amp = lerpf(_sway_amp, amp, 1.0 - exp(-3.0 * delta))
	var br := TAU * _sway_t / 4.2
	var tremor := Vector2(_noise.get_noise_1d(_sway_t * 1.3), _noise.get_noise_1d(_sway_t * 1.3 + 77.0))
	_sway = (Vector2(sin(br * 0.5) * 0.6, sin(br)) + tremor * 0.45) * _sway_amp
	# Recoil spring.
	_kick_v += (-_kick * 90.0 - _kick_v * 13.0) * delta
	_kick += _kick_v * delta

	var eye_target := EYE_CROUCH if player.crouching else EYE_STAND
	_eye = lerpf(_eye, eye_target, 1.0 - exp(-10.0 * delta))
	var base: Vector3 = player.get_global_transform_interpolated().origin
	var pitch := deg_to_rad(float(rig.pitch)) + _sway.y + _kick
	var yaw := deg_to_rad(float(rig.yaw)) + _sway.x
	scope_cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), base + Vector3(0, _eye, 0))
	var vlocal: Vector3 = scope_cam.global_basis.inverse() * player.velocity
	var k := overlay.size.y / 1080.0
	scope_shift = scope_shift.lerp(Vector2(-vlocal.x, vlocal.y) * 9.0 * k + Vector2(0, _kick * 900.0 * k), 1.0 - exp(-8.0 * delta))


# ------------------------------------------------------------ people far away

func _set_far_peds(on: bool) -> void:
	if on == _far_peds or main.peds == null:
		return
	_far_peds = on
	for c in main.peds.get_children():
		if not c.has_method("animate"):
			continue
		for g in c.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = PED_FAR_RANGE if on else 120.0


# ------------------------------------------------------------ range

func teleport(to_range: bool) -> void:
	if _teleporting or player.in_vehicle:
		return
	_teleporting = true
	var tw := create_tween()
	tw.tween_property(overlay, "fade", 1.0, 0.3)
	tw.tween_callback(_do_teleport.bind(to_range))
	tw.tween_interval(0.2)
	tw.tween_property(overlay, "fade", 0.0, 0.45)
	tw.tween_callback(func(): _teleporting = false)


func _do_teleport(to_range: bool) -> void:
	if player.in_vehicle:
		return
	if scoped:
		player.aiming = false
		_set_scoped(false)
	var pos: Vector3 = shooting_range.arrival_point() if to_range else shooting_range.PARK_MARKER + Vector3(0, 0.3, 4.0)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	rig.yaw = 0.0 if to_range else 180.0
	rig.pitch = -2.0
	if to_range:
		if not equipped:
			select_rifle("medium")
		if main.hud and main.hud.has_method("toast"):
			main.hud.toast(Loc.t("snp_range_welcome"))
	_check_range_area()


func _check_range_area() -> void:
	var inside: bool = shooting_range.contains(player.global_position)
	if inside == in_range_area:
		return
	in_range_area = inside
	if _env:
		_env.fog_density = _env_fog * 0.2 if inside else _env_fog
	rig.camera.far = maxf(float(Settings.get_value("draw_distance")), 1900.0) if inside else float(Settings.get_value("draw_distance"))


# ------------------------------------------------------------ sound

func _play(channel: String, sound: String, db := 0.0, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(channel)
	if p == null or not _streams.has(sound):
		return
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")), 0.0001)) + db
	p.pitch_scale = pitch
	p.play()

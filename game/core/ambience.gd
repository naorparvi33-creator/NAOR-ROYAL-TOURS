extends Node
## City soundscape and small audio polish. Every sound comes from
## tools/audiogen/make_polish_sounds.py (procedural, free to use).
##  * ambience: distant traffic hum, birds in the park, wind (stronger up high),
##    muffled inside buildings and cars;
##  * footsteps for the player and nearby pedestrians, by surface (pavement / grass / indoor);
##  * weapon handling: switch and reload sounds;
##  * UI clicks on every button in the game;
##  * combat music: a tense layer that fades in while fighting / wanted and ducks the calm
##    street music of Sfx (the car radio is left alone).

const STEP_POOL := 8
const PED_STEP_RANGE := 16.0
const COMBAT_HOLD := 7.0

var main: Node
## 0..1, how intense the music is right now (read by other modules if they like).
var intensity := 0.0
## Footsteps played so far (handy for tests / debugging).
var steps_played := 0

var _streams := {}
var _amb := {}                 # key -> AudioStreamPlayer
var _amb_target := {"city": 0.0, "birds": 0.0, "wind": 0.0}
var _action: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _player_step := 0.0
var _player_last := Vector3.ZERO
var _ped_steps := {}           # instance id -> [last pos, distance]
var _env_timer := 0.0
var _indoor := false
var _combat_t := 0.0
var _last_hp := 100.0
var _wanted_node: Object = null
var _wanted_scan := 0.0


func _ready() -> void:
	name = "Ambience"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in ["amb_city", "amb_birds", "amb_wind", "music_action", "weapon_reload", "weapon_switch",
			"ui_click", "ui_open", "photo_shutter"]:
		_streams[k] = load("res://assets/audio/%s.wav" % k)
	for surf in ["pave", "grass", "indoor"]:
		for i in 3:
			_streams["step_%s_%d" % [surf, i + 1]] = load("res://assets/audio/step_%s_%d.wav" % [surf, i + 1])
	for k in ["city", "birds", "wind"]:
		var p := AudioStreamPlayer.new()
		p.stream = _looped(_streams["amb_" + k])
		p.volume_db = -80.0
		add_child(p)
		p.play(randf() * 5.0)
		_amb[k] = p
	_action = AudioStreamPlayer.new()
	_action.stream = _looped(_streams["music_action"])
	_action.volume_db = -80.0
	add_child(_action)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	for i in STEP_POOL:
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 3.0
		a.max_distance = 30.0
		a.attenuation_filter_cutoff_hz = 8000.0
		add_child(a)
		_pool.append(a)
	add_to_group("panic_listeners")
	get_tree().node_added.connect(_on_node_added)
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		_hook_button(b)
	await get_tree().process_frame
	_hook_player()


func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	return s


func _hook_player() -> void:
	var pl: Node = main.player if main else null
	if pl == null:
		return
	_player_last = (pl as Node3D).global_position
	_last_hp = float(pl.health)
	pl.health_changed.connect(func(hp: float):
		if hp < _last_hp - 0.5:
			_combat_t = COMBAT_HOLD + 2.0
		_last_hp = hp)
	var w: Node = pl.weapon
	if w:
		w.weapon_changed.connect(func(_k): play_at("weapon_switch", (pl as Node3D).global_position + Vector3(0, 1.2, 0), -4.0))
		w.fired.connect(func(): _combat_t = COMBAT_HOLD)
		# Reload sounds for weapons that have a reload (added by other modules).
		for sig in ["reloaded", "reload_started", "reloading", "reload"]:
			if w.has_signal(sig):
				w.connect(sig, func(_a = null, _b = null): play_reload())
				break


# ------------------------------------------------------------ public helpers

func play_reload() -> void:
	var pl: Node3D = main.player if main else null
	if pl:
		play_at("weapon_reload", pl.global_position + Vector3(0, 1.2, 0), -2.0)


func click() -> void:
	play_ui("ui_click", -6.0)


func play_ui(key: String, db := 0.0) -> void:
	if not _streams.has(key):
		return
	_ui.stream = _streams[key]
	_ui.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")) * 0.8, 0.0001)) + db
	_ui.play()


func play_at(key: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(key):
		return
	var a := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % STEP_POOL
	a.stream = _streams[key]
	a.global_position = pos
	a.volume_db = linear_to_db(maxf(float(Settings.get_value("sfx_volume")), 0.0001)) + db
	a.pitch_scale = pitch * randf_range(0.93, 1.07)
	a.play()


## Called by weapons through the "panic_listeners" group for every gunshot.
func on_gunshot(_pos: Vector3) -> void:
	_combat_t = COMBAT_HOLD


# ------------------------------------------------------------ UI clicks

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_hook_button(n)
	elif n is TabContainer:
		(n as TabContainer).tab_changed.connect(func(_i): click())


func _hook_button(b: BaseButton) -> void:
	if b.has_meta("_click"):
		return
	b.set_meta("_click", true)
	b.pressed.connect(click)


# ------------------------------------------------------------ per frame

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	var pl: Node3D = main.player if main else null
	if pl == null:
		return
	_footsteps_player(pl)
	_footsteps_peds(pl)


func _process(delta: float) -> void:
	var pl: Node3D = main.player if main else null
	_env_timer -= delta
	if _env_timer <= 0.0 and pl:
		_env_timer = 0.25
		_update_ambience_targets(pl)
	var sv := float(Settings.get_value("sfx_volume"))
	for k in _amb:
		var p: AudioStreamPlayer = _amb[k]
		var cur := db_to_linear(p.volume_db)
		var want: float = _amb_target[k] * sv
		cur = move_toward(cur, want, delta * 0.5)
		p.volume_db = linear_to_db(maxf(cur, 0.0001))
	_update_music(delta)


func _update_ambience_targets(pl: Node3D) -> void:
	var pos := pl.global_position
	var world: Node = main.world
	var half := 45.0
	if world and "BLOCK" in world:
		half = float(world.get("BLOCK")) * 0.5
	var park := 1.0 - smoothstep(half * 0.7, half * 1.4, maxf(absf(pos.x), absf(pos.z)))
	_indoor = _roof_above(pl)
	var in_car := bool(pl.get("in_vehicle"))
	var muffle := 0.35 if _indoor else (0.45 if in_car else 1.0)
	var height := clampf((pos.y - 4.0) / 30.0, 0.0, 1.0)
	_amb_target["city"] = (0.55 - park * 0.3 + height * 0.1) * muffle
	_amb_target["birds"] = (0.15 + park * 0.65) * (1.0 - height * 0.6) * (0.15 if _indoor or in_car else 1.0)
	_amb_target["wind"] = (0.12 + height * 0.55) * muffle


func _roof_above(pl: Node3D) -> bool:
	var space := pl.get_world_3d().direct_space_state
	var from := pl.global_position + Vector3(0, 1.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 7.0, 0), 1, [(pl as CollisionObject3D).get_rid()])
	return not space.intersect_ray(q).is_empty()


func surface_at(pos: Vector3, indoor := false) -> String:
	if indoor:
		return "indoor"
	var world: Node = main.world if main else null
	var inner := 41.0
	if world and "BLOCK" in world and "WALK_W" in world:
		inner = float(world.get("BLOCK")) * 0.5 - float(world.get("WALK_W"))
	if absf(pos.x) < inner and absf(pos.z) < inner and pos.y < 1.0:
		return "grass"
	return "pave"


func _footsteps_player(pl: Node3D) -> void:
	if bool(pl.get("in_vehicle")) or not (pl as CharacterBody3D).is_on_floor():
		_player_last = pl.global_position
		return
	var p := pl.global_position
	var moved := Vector2(p.x - _player_last.x, p.z - _player_last.z).length()
	_player_last = p
	if moved > 1.0:
		return                     # teleport / respawn
	var v := (pl as CharacterBody3D).velocity
	var speed := Vector2(v.x, v.z).length()
	if speed < 0.5:
		_player_step = 0.55        # first step comes quickly
		return
	_player_step += moved
	var stride := lerpf(0.62, 1.25, clampf(speed / 7.6, 0.0, 1.0))
	if _player_step >= stride:
		_player_step = 0.0
		var crouch := bool(pl.get("crouching"))
		var db := lerpf(-12.0, -2.0, clampf(speed / 7.6, 0.0, 1.0)) - (6.0 if crouch else 0.0)
		_step_sound(surface_at(p, _indoor), p, db)


func _footsteps_peds(pl: Node3D) -> void:
	var peds: Node = main.peds
	if peds == null or not ("_peds" in peds):
		return
	var cam := get_viewport().get_camera_3d()
	var ear := cam.global_position if cam else pl.global_position
	var seen := {}
	for p in peds.get("_peds"):
		var st := str(p.get("state", ""))
		if st != "walk" and st != "flee":
			continue
		var n: Node3D = p.get("node")
		if n == null or not n.visible:
			continue
		var pos := n.global_position
		if pos.distance_squared_to(ear) > PED_STEP_RANGE * PED_STEP_RANGE:
			continue
		var id := n.get_instance_id()
		seen[id] = true
		var rec: Array = _ped_steps.get(id, [pos, 0.0])
		var last: Vector3 = rec[0]
		var moved := Vector2(pos.x - last.x, pos.z - last.z).length()
		rec[0] = pos
		if moved < 0.5:
			rec[1] = float(rec[1]) + moved
		var stride := 1.15 if st == "flee" else 0.7
		if float(rec[1]) >= stride:
			rec[1] = 0.0
			_step_sound(surface_at(pos), pos, -11.0 if st == "walk" else -5.0)
		_ped_steps[id] = rec
	for id in _ped_steps.keys():
		if not seen.has(id):
			_ped_steps.erase(id)


func _step_sound(surface: String, pos: Vector3, db: float) -> void:
	steps_played += 1
	play_at("step_%s_%d" % [surface, randi_range(1, 3)], pos + Vector3(0, 0.05, 0), db)


# ------------------------------------------------------------ music intensity

func _wanted_level() -> int:
	if _wanted_node == null or not is_instance_valid(_wanted_node):
		_wanted_node = null
		_wanted_scan -= get_process_delta_time()
		if _wanted_scan > 0.0 or main == null:
			return 0
		_wanted_scan = 2.0
		var candidates: Array = [main.player]
		candidates.append_array(main.get_children())
		for c in candidates:
			for prop in ["wanted_level", "wanted", "stars"]:
				if c != null and prop in c and typeof(c.get(prop)) in [TYPE_INT, TYPE_FLOAT]:
					_wanted_node = c
					break
			if _wanted_node:
				break
		if _wanted_node == null:
			return 0
	for prop in ["wanted_level", "wanted", "stars"]:
		if prop in _wanted_node:
			return int(_wanted_node.get(prop))
	return 0


func _update_music(delta: float) -> void:
	if not get_tree().paused:
		_combat_t = maxf(_combat_t - delta, 0.0)
	var target := 0.0
	if _combat_t > 0.0:
		target = 1.0 if _combat_t > 1.5 else 0.6
	var wanted := _wanted_level()
	if wanted > 0:
		target = maxf(target, clampf(0.55 + wanted * 0.15, 0.0, 1.0))
	var ms: Node = main.missions if main else null
	if ms and "_time_left" in ms and float(ms.get("_time_left")) > 0.0:
		target = maxf(target, 0.35)
	# Rise quickly, settle slowly.
	intensity = move_toward(intensity, target, delta * (0.8 if target > intensity else 0.12))
	var mv := float(Settings.get_value("music_volume"))
	var in_car := main != null and main.player != null and bool(main.player.get("in_vehicle"))
	var act := intensity * (0.4 if in_car else 1.0)
	if act > 0.005:
		if not _action.playing:
			_action.play()
		_action.volume_db = linear_to_db(maxf(mv * 0.6 * act, 0.0001))
	elif _action.playing:
		_action.stop()
	# Duck the calm street track of Sfx (it is muted anyway while the radio plays).
	var calm: Variant = Sfx.get("_music")
	if calm is AudioStreamPlayer and not in_car:
		(calm as AudioStreamPlayer).volume_db = linear_to_db(maxf(mv * 0.55 * (1.0 - intensity * 0.85), 0.0001))

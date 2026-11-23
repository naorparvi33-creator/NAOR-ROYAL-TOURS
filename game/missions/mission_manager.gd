extends Node3D
## Generic mission system. Glowing pillars around the city start missions; each mission
## is a short list of steps (get in a car, reach a point, kill a target, collect items,
## drive through checkpoints) with an optional time limit and a cash reward.
## New missions are added by appending to MISSIONS and, if needed, a new step type.

signal objective_changed(text: String)
signal timer_changed(seconds: float)          # < 0 hides the timer
signal mission_result(passed: bool, title: String, reward: int)

const MISSIONS := [
	{"id": "delivery", "title": "משלוח דחוף", "giver": Vector3(-8, 0.15, 43), "reward": 500, "time": 80.0,
		"intro": "לקוח מחכה לחבילה בצד השני של העיר. קח רכב ותגיע לפני שנגמר הזמן."},
	{"id": "hit", "title": "חוזה חיסול", "giver": Vector3(43, 0.15, -8), "reward": 1000, "time": 150.0,
		"intro": "המטרה מסומנת באדום. מצא אותה וחסל אותה לפני שתיעלם."},
	{"id": "cash", "title": "איסוף כסף", "giver": Vector3(-43, 0.15, 8), "reward": 600, "time": 160.0,
		"intro": "חמש שקיות כסף מפוזרות בעיר. אסוף את כולן לפני שמישהו אחר יגיע אליהן."},
	{"id": "race", "title": "מרוץ צ'קפוינטים", "giver": Vector3(8, 0.15, -43), "reward": 800, "time": 85.0,
		"intro": "היכנס לרכב ועבור בכל נקודות הביקורת לפי הסדר."},
]

var player: Node3D
var city: Node3D
var peds: Node3D
var active := -1
var _time_left := -1.0
var _step := ""
var _target_pos := Vector3.ZERO
var _target_ped: Dictionary = {}
var _items: Array = []
var _checkpoints: Array = []
var _cp_index := 0
var _givers: Array = []
var _beam: MeshInstance3D
var _target_marker: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in MISSIONS.size():
		var m: Dictionary = MISSIONS[i]
		var g := _make_beam(Color(1.0, 0.8, 0.2, 0.35), 1.0, 30.0)
		g.position = m["giver"] + Vector3(0, 0.2, 0)
		add_child(g)
		var label := Label3D.new()
		label.text = m["title"]
		label.font_size = 72
		label.pixel_size = 0.012
		label.outline_size = 16
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 3.2, 0)
		label.no_depth_test = true
		g.add_child(label)
		_givers.append(g)
	_beam = _make_beam(Color(0.3, 1.0, 0.4, 0.35), 2.0, 60.0)
	_beam.visible = false
	add_child(_beam)
	_target_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 0.0
	cone.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.15, 0.1)
	mat.no_depth_test = true
	cone.material = mat
	_target_marker.mesh = cone
	_target_marker.visible = false
	add_child(_target_marker)
	peds.ped_killed.connect(_on_ped_killed)
	player.died.connect(func():
		if active >= 0:
			_finish(false))


func _make_beam(c: Color, radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 20
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = c
	cyl.material = mat
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := MeshInstance3D.new()
	holder.add_child(mi)
	mi.position.y = height * 0.5
	return holder


## The point the HUD arrow points at (or null when nothing to show).
func waypoint() -> Variant:
	if active < 0:
		return null
	if _step == "kill" and not _target_ped.is_empty():
		return (_target_ped["node"] as Node3D).global_position
	if _step in ["reach", "race", "collect", "car"]:
		return _target_pos
	return null


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var pp := player.global_position
	if active < 0:
		for i in _givers.size():
			var g: Node3D = _givers[i]
			if Vector2(pp.x - g.global_position.x, pp.z - g.global_position.z).length() < 1.8:
				_start(i)
				break
		return
	if _time_left >= 0.0:
		_time_left -= delta
		timer_changed.emit(_time_left)
		if _time_left <= 0.0:
			_finish(false)
			return
	match _step:
		"car":
			if player.in_vehicle:
				_set_reach(_target_pos, "סע לנקודת המסירה המסומנת")
		"reach":
			_beam.global_position = _target_pos
			if pp.distance_to(_target_pos) < 5.0 and (not MISSIONS[active]["id"] == "delivery" or player.in_vehicle):
				_finish(true)
		"kill":
			if not _target_ped.is_empty():
				var n: Node3D = _target_ped["node"]
				_target_marker.global_position = n.global_position + Vector3(0, 2.4 + sin(Time.get_ticks_msec() * 0.005) * 0.1, 0)
		"collect":
			_items = _items.filter(func(it): return is_instance_valid(it) and it.is_in_group("pickup"))
			if _items.is_empty():
				_finish(true)
			else:
				_target_pos = (_items[0] as Node3D).global_position
				objective_changed.emit("אסוף את שקיות הכסף (%d נותרו)" % _items.size())
		"race":
			if not player.in_vehicle:
				objective_changed.emit("חזור לרכב!")
			elif pp.distance_to(_target_pos) < 7.0:
				_cp_index += 1
				Sfx.play_ui("money")
				if _cp_index >= _checkpoints.size():
					_finish(true)
				else:
					_target_pos = _checkpoints[_cp_index]
					_beam.global_position = _target_pos
					objective_changed.emit("נקודת ביקורת %d מתוך %d" % [_cp_index + 1, _checkpoints.size()])
			else:
				objective_changed.emit("נקודת ביקורת %d מתוך %d" % [_cp_index + 1, _checkpoints.size()])


func _start(i: int) -> void:
	active = i
	var m: Dictionary = MISSIONS[i]
	for g in _givers:
		g.visible = false
	Sfx.play_ui("mission_start")
	_time_left = m["time"]
	objective_changed.emit(m["title"] + ": " + m["intro"])
	match m["id"]:
		"delivery":
			_target_pos = _sidewalk_point(2)
			_step = "car" if not player.in_vehicle else "reach"
			if _step == "car":
				objective_changed.emit("היכנס לרכב כלשהו (חפש רכב חונה ליד המדרכה)")
			else:
				_set_reach(_target_pos, "סע לנקודת המסירה המסומנת")
		"hit":
			var at := _sidewalk_point(2)
			_target_ped = peds.add_special("ped_03", at)
			_target_marker.visible = true
			_step = "kill"
			objective_changed.emit("חסל את המטרה המסומנת באדום")
		"cash":
			_items.clear()
			for k in 5:
				var bag := CashBag.new()
				bag.value = 100
				add_child(bag)
				bag.global_position = _sidewalk_point(1 + k % 2)
				_items.append(bag)
			_step = "collect"
		"race":
			_checkpoints.clear()
			var c: Variant = city
			var p: float = c.PITCH
			# A loop around the central blocks along the roads.
			for pt in [Vector2(0.5, -0.5), Vector2(1.5, -0.5), Vector2(1.5, 0.5), Vector2(1.5, 1.5),
					Vector2(0.5, 1.5), Vector2(-0.5, 1.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]:
				_checkpoints.append(Vector3(pt.x * p, 0, pt.y * p))
			_cp_index = 0
			_target_pos = _checkpoints[0]
			_beam.global_position = _target_pos
			_beam.visible = true
			_step = "race"


func _set_reach(pos: Vector3, text: String) -> void:
	_target_pos = pos
	_beam.global_position = pos
	_beam.visible = true
	_step = "reach"
	objective_changed.emit(text)


func _on_ped_killed(p: Dictionary) -> void:
	if _step == "kill" and p == _target_ped:
		_finish(true)


func _finish(passed: bool) -> void:
	var m: Dictionary = MISSIONS[active]
	var reward: int = m["reward"] if passed else 0
	if passed:
		player.add_money(reward)
		Sfx.play_ui("mission_done")
	else:
		Sfx.play_ui("mission_fail")
	mission_result.emit(passed, m["title"], reward)
	# Clean up.
	_beam.visible = false
	_target_marker.visible = false
	if not _target_ped.is_empty():
		var tp := _target_ped
		_target_ped = {}
		get_tree().create_timer(20.0).timeout.connect(func(): peds.remove_special(tp))
	for it in _items:
		if is_instance_valid(it):
			it.queue_free()
	_items.clear()
	active = -1
	_step = ""
	_time_left = -1.0
	timer_changed.emit(-1.0)
	objective_changed.emit("")
	# Mission pillars come back after a short break.
	get_tree().create_timer(4.0).timeout.connect(func():
		for g in _givers:
			g.visible = true)


## A random sidewalk point `rings_away` blocks from the player.
func _sidewalk_point(rings_away: int) -> Vector3:
	var c: Variant = city
	var p: float = c.PITCH
	var rings: int = c.RINGS
	var pp := player.global_position
	var bi := clampi(roundi(pp.x / p) + (rings_away if _rng.randf() < 0.5 else -rings_away), -rings, rings)
	var bj := clampi(roundi(pp.z / p) + _rng.randi_range(-1, 1), -rings, rings)
	if bi == 0 and bj == 0:
		bi = 1
	var half: float = float(c.BLOCK) * 0.5 - 2.6
	var side := _rng.randi() % 4
	var t := _rng.randf_range(-half * 0.7, half * 0.7)
	var local: Vector3 = [Vector3(t, 0, -half), Vector3(half, 0, t), Vector3(-t, 0, half), Vector3(-half, 0, -t)][side]
	return Vector3(bi * p, float(c.CURB_H), bj * p) + local


## Cash bag pickup used by the cash run mission.
class CashBag extends Node3D:
	var value := 100

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.45
		mi.mesh = sm
		mi.material_override = Mats.plain(Color(0.25, 0.4, 0.2), 0.8)
		mi.position.y = 0.25
		add_child(mi)
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.35
		cyl.height = 8.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.4, 1.0, 0.4, 0.3)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cyl.material = mat
		beam.mesh = cyl
		beam.position.y = 4.0
		add_child(beam)
		add_to_group("pickup")

	func collect(player: Node) -> void:
		player.add_money(value)
		queue_free()

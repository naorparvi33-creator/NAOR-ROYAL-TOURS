extends Node3D
## Roll-up garage door: rolls up into a drum under the lintel. Opens with the context
## button on foot, and by itself when the player drives up to it.

signal moved(open: bool)

var width := 3.6
var height := 3.0
var player: Node3D
var open := false
var _k := 0.0                   # 0 closed .. 1 open
var _panel: MeshInstance3D
var _col: CollisionShape3D
var _body: StaticBody3D
var _auto_t := 0.0


func _ready() -> void:
	var drum := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(width + 0.2, 0.42, 0.45)
	drum.mesh = dm
	drum.material_override = Mats.plain(Color(0.32, 0.33, 0.35), 0.5, 0.5)
	drum.position = Vector3(0, height + 0.21, 0.32)
	drum.visibility_range_end = 120.0
	add_child(drum)
	_panel = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(width, height, 0.06)
	_panel.mesh = pm
	var mat := Mats.pbr("panels", 0.6, Color(0.72, 0.74, 0.76), 0.6)
	_panel.material_override = mat
	_panel.visibility_range_end = 150.0
	add_child(_panel)
	_body = StaticBody3D.new()
	_col = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.25)
	_col.shape = bs
	_col.position = Vector3(0, height * 0.5, 0)
	_body.add_child(_col)
	add_child(_body)
	_apply()


func toggle() -> void:
	set_open(not open)


func set_open(on: bool) -> void:
	if on == open:
		return
	open = on
	Sfx.play_3d("car_door", global_position + Vector3(0, 1.5, 0), -4.0, 0.55)
	moved.emit(open)


func _process(delta: float) -> void:
	var target := 1.0 if open else 0.0
	if not is_equal_approx(_k, target):
		_k = move_toward(_k, target, delta / 2.2)
		_apply()
	# Drive up to it and it opens (and closes again behind you once you are away).
	_auto_t -= delta
	if _auto_t <= 0.0 and player:
		_auto_t = 0.25
		var dist := player.global_position.distance_to(global_position)
		if bool(player.get("in_vehicle")) and dist < 13.0:
			set_open(true)


func _apply() -> void:
	var h := lerpf(height, 0.12, _k)
	_panel.scale = Vector3(1, h / height, 1)
	_panel.position = Vector3(0, height - h * 0.5, 0)
	_col.disabled = _k > 0.35

extends Node
## Stage-1 placeholder weapon so the fire buttons can be tested.
## Hitscan from the screen center with light recoil and pooled impact marks.
## Stage 2 replaces this with real projectile ballistics for sniper rifles.

signal fired
signal hit(is_target: bool)
signal weapon_changed(name_key: String)

const WEAPONS := [
	{"key": "weapon_rifle", "rate": 9.0, "recoil": 0.35, "spread": 0.6, "auto": true},
	{"key": "weapon_pistol", "rate": 4.0, "recoil": 0.7, "spread": 0.3, "auto": false},
]
const RANGE := 400.0
const POOL := 14

var player: CharacterBody3D
var current := 0
var _cooldown := 0.0
var _was_firing := false
var _pool: Array[MeshInstance3D] = []
var _pool_i := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.3)
	mesh.material = mat
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if GameInput.consume("swap"):
		current = (current + 1) % WEAPONS.size()
		weapon_changed.emit(WEAPONS[current]["key"])
	var w: Dictionary = WEAPONS[current]
	var firing := GameInput.is_firing()
	var trigger: bool = firing and (w["auto"] or not _was_firing)
	_was_firing = firing
	if trigger and _cooldown <= 0.0:
		_cooldown = 1.0 / float(w["rate"])
		_shoot(w)


func _shoot(w: Dictionary) -> void:
	var ray: Array = player.rig.aim_ray()
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0
	var spread := deg_to_rad(float(w["spread"]) * (1.8 if moving else 1.0) * (0.5 if player.aiming else 1.0))
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	dir = dir.rotated(dir.cross(Vector3.UP).normalized(), _rng.randf_range(-spread, spread))
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE, 1, [player.get_rid()])
	var res := space.intersect_ray(q)
	# Moderate recoil: kicks the camera up a little, with slight random sideways drift.
	var r := float(w["recoil"]) * (0.6 if player.aiming else 1.0)
	GameInput.add_look(Vector2(_rng.randf_range(-0.25, 0.25) * r, -r))
	fired.emit()
	if res.is_empty():
		return
	var mi := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	mi.global_position = res["position"]
	mi.visible = true
	var collider: Object = res["collider"]
	var is_target := collider != null and collider.has_method("on_hit")
	if is_target:
		collider.on_hit(res["position"])
	hit.emit(is_target)

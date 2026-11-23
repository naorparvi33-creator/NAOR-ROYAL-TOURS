extends Node
## Player weapons: fists (melee), pistol and assault rifle.
## Guns are hitscan from the screen centre with light recoil; hitting a person
## sprays blood, headshots deal triple damage, and gunfire makes nearby people panic.
## (Stage 2 adds real projectile ballistics for sniper rifles.)

signal fired
signal hit(is_target: bool)
signal weapon_changed(name_key: String)

const WEAPONS := [
	{"key": "weapon_fists", "kind": 0, "rate": 2.6, "damage": 34.0, "range": 1.8, "recoil": 0.0, "spread": 0.0, "auto": true, "sound": "punch"},
	{"key": "weapon_pistol", "kind": 1, "rate": 4.0, "damage": 40.0, "range": 250.0, "recoil": 0.9, "spread": 0.35, "auto": false, "sound": "gun_pistol"},
	{"key": "weapon_rifle", "kind": 2, "rate": 9.0, "damage": 30.0, "range": 400.0, "recoil": 0.38, "spread": 0.6, "auto": true, "sound": "gun_rifle"},
]
const HIT_MASK := 1 | 4      # world + people
const POOL := 14

var player: CharacterBody3D
var current := 2
var _cooldown := 0.0
var _was_firing := false
var _pool: Array[MeshInstance3D] = []
var _pool_i := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.06)
	mesh.material = mat
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)
	player.model.set_weapon(WEAPONS[current]["kind"])


func weapon_key() -> String:
	return WEAPONS[current]["key"]


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if player.in_vehicle:
		_was_firing = false
		return
	if GameInput.consume("swap"):
		current = (current + 1) % WEAPONS.size()
		player.model.set_weapon(WEAPONS[current]["kind"])
		weapon_changed.emit(WEAPONS[current]["key"])
	var w: Dictionary = WEAPONS[current]
	var firing := GameInput.is_firing()
	var trigger: bool = firing and (w["auto"] or not _was_firing)
	_was_firing = firing
	if trigger and _cooldown <= 0.0:
		_cooldown = 1.0 / float(w["rate"])
		if w["kind"] == 0:
			_punch(w)
		else:
			_shoot(w)


func _punch(w: Dictionary) -> void:
	player.model.punch()
	var fwd: Vector3 = -player.model.global_basis.z
	var origin: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	q.shape = sphere
	q.transform = Transform3D(Basis(), origin + fwd * 0.9)
	q.collision_mask = 4
	q.exclude = [player.get_rid()]
	var res := space.intersect_shape(q, 4)
	fired.emit()
	for r in res:
		var c: Object = r["collider"]
		if c and c.has_method("on_hit"):
			c.on_hit(origin + fwd * 0.7, float(w["damage"]), fwd, false)
			Sfx.play_3d("punch", origin + fwd * 0.7, 2.0)
			hit.emit(true)
			return
	Sfx.play_3d("punch", origin + fwd * 0.6, -14.0, 1.6)     # swing through the air


func _shoot(w: Dictionary) -> void:
	var ray: Array = player.rig.aim_ray()
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0
	var spread := deg_to_rad(float(w["spread"]) * (1.8 if moving else 1.0) * (0.5 if player.aiming else 1.0))
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	dir = dir.rotated(dir.cross(Vector3.UP).normalized(), _rng.randf_range(-spread, spread))
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * float(w["range"]), HIT_MASK, [player.get_rid()])
	var res := space.intersect_ray(q)
	# Moderate recoil: kicks the camera up a little, with slight random sideways drift.
	var r := float(w["recoil"]) * (0.6 if player.aiming else 1.0)
	GameInput.add_look(Vector2(_rng.randf_range(-0.25, 0.25) * r, -r))
	var muzzle: Vector3 = player.global_position + Vector3(0, 1.45, 0)
	Sfx.play_3d(w["sound"], muzzle, 0.0)
	get_tree().call_group("panic_listeners", "on_gunshot", muzzle)
	fired.emit()
	if res.is_empty():
		return
	var collider: Object = res["collider"]
	var pos: Vector3 = res["position"]
	if collider and collider.has_method("on_hit"):
		collider.on_hit(pos, float(w["damage"]), dir, true)
		hit.emit(true)
		return
	Fx.sparks(pos, res["normal"])
	Sfx.play_3d("bullet_impact", pos, -6.0)
	var mi := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	mi.global_position = pos
	mi.visible = true
	hit.emit(false)

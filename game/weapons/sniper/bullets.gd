extends Node3D
## Real projectile bullets for the sniper rifles (not hitscan).
## Every physics tick each bullet is integrated in fixed sub-steps (ballistics.gd) and a
## ray is cast along the travelled chord, so drop and time of flight are real.
## Hits on people are split into head / body / limb zones from the hit height on the
## capsule. A faint tracer shows the bullet's path through the scope.

signal impact(info: Dictionary)

const Ballistics := preload("res://weapons/sniper/ballistics.gd")
const HIT_MASK := 1 | 4
const POOL := 8
const HOLES := 24
const ZONE_MULT := {"head": 1.0, "body": 1.0, "limb": 0.5}   # head x3 is applied by the people manager

var exclude: Array[RID] = []
var _bullets: Array = []
var _holes: Array[MeshInstance3D] = []
var _hole_i := 0


func _ready() -> void:
	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3.ONE
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tracer_mesh.material = tm
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = tracer_mesh
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mi)
		_bullets.append({"active": false, "mesh": mi, "pos": Vector3.ZERO, "vel": Vector3.ZERO,
			"t": 0.0, "acc": 0.0, "since": 0.0, "origin": Vector3.ZERO, "k": 0.0, "damage": 0.0, "id": 0})
	var hole := QuadMesh.new()
	hole.size = Vector2(0.09, 0.09)
	var hm := StandardMaterial3D.new()
	hm.albedo_texture = _hole_texture()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.roughness = 1.0
	hole.material = hm
	for i in HOLES:
		var mi := MeshInstance3D.new()
		mi.mesh = hole
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mi)
		_holes.append(mi)


func _hole_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
			var c := 0.03 if d < 0.4 else 0.18
			img.set_pixel(x, y, Color(c, c * 0.95, c * 0.9, a))
	return ImageTexture.create_from_image(img)


var _next_id := 1


## Launches a bullet. Returns its id.
func fire(origin: Vector3, velocity: Vector3, k: float, damage: float) -> int:
	var b: Dictionary = _bullets[0]
	for c in _bullets:
		if not c["active"]:
			b = c
			break
	b["active"] = true
	b["pos"] = origin
	b["vel"] = velocity
	b["origin"] = origin
	b["t"] = 0.0
	b["acc"] = 0.0
	b["since"] = 0.0
	b["k"] = k
	b["damage"] = damage
	b["id"] = _next_id
	_next_id += 1
	(b["mesh"] as MeshInstance3D).visible = false
	return int(b["id"])


func active_count() -> int:
	var n := 0
	for b in _bullets:
		if b["active"]:
			n += 1
	return n


## Visual position of a bullet (between physics ticks), or null when it is gone.
func bullet_state(id: int) -> Variant:
	for b in _bullets:
		if b["active"] and int(b["id"]) == id:
			var v: Vector3 = b["vel"]
			var p: Vector3 = b["pos"]
			return [p + v * float(b["since"]), v]
	return null


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for b in _bullets:
		if not b["active"]:
			continue
		var start: Vector3 = b["pos"]
		var pos: Vector3 = start
		var vel: Vector3 = b["vel"]
		var acc: float = float(b["acc"]) + delta
		var k: float = b["k"]
		var t0: float = b["t"]
		while acc >= Ballistics.STEP:
			var r := Ballistics.step(pos, vel, k, Ballistics.STEP)
			pos = r[0]
			vel = r[1]
			acc -= Ballistics.STEP
			b["t"] = float(b["t"]) + Ballistics.STEP
		b["acc"] = acc
		b["since"] = 0.0
		if pos != start:
			var q := PhysicsRayQueryParameters3D.create(start, pos, HIT_MASK, exclude)
			var res := space.intersect_ray(q)
			if not res.is_empty():
				# Time of flight at the hit point (fraction of this tick's chord).
				var f := start.distance_to(res["position"]) / maxf(start.distance_to(pos), 1e-4)
				b["t"] = t0 + (float(b["t"]) - t0) * f
				_hit(b, res, vel)
				continue
		b["pos"] = pos
		b["vel"] = vel
		if float(b["t"]) > Ballistics.MAX_TIME or pos.y < -20.0:
			_retire(b)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for b in _bullets:
		if not b["active"]:
			continue
		b["since"] = float(b["since"]) + delta
		var mi: MeshInstance3D = b["mesh"]
		var vel: Vector3 = b["vel"]
		var p: Vector3 = (b["pos"] as Vector3) + vel * float(b["since"])
		var travelled := p.distance_to(b["origin"])
		if travelled < 12.0 or cam == null:
			mi.visible = false
			continue
		# Keep the tracer a few pixels wide however far it is (it is a heat shimmer, not a laser).
		var dist := cam.global_position.distance_to(p)
		var w := clampf(dist * 0.0009, 0.012, 1.2)
		var length := clampf(vel.length() * 0.012, 2.0, 12.0) * (1.0 + dist * 0.002)
		var fwd := vel.normalized()
		var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis.looking_at(fwd, up).scaled(Vector3(w, w, length)), p - fwd * length * 0.5)
		mi.visible = true


func _retire(b: Dictionary) -> void:
	b["active"] = false
	(b["mesh"] as MeshInstance3D).visible = false


func _hit(b: Dictionary, res: Dictionary, vel: Vector3) -> void:
	_retire(b)
	var point: Vector3 = res["position"]
	var normal: Vector3 = res["normal"]
	var collider: Object = res["collider"]
	var dir := vel.normalized()
	var info := {"id": b["id"], "point": point, "normal": normal, "collider": collider,
		"distance": (b["origin"] as Vector3).distance_to(point), "time": float(b["t"]),
		"speed": vel.length(), "kind": "world", "zone": "", "killed": false}
	var dmg: float = b["damage"]
	if collider != null and "ped" in collider and "manager" in collider and collider.manager != null \
			and collider.manager.has_method("damage"):
		var ped: Dictionary = collider.ped
		var zone := zone_of(ped, point)
		info["kind"] = "ped"
		info["zone"] = zone
		collider.manager.damage(ped, point, dmg * float(ZONE_MULT[zone]), dir, true)
		info["killed"] = str(ped.get("state", "")) == "dead"
	elif collider != null and collider.has_method("on_hit"):
		info["kind"] = "target" if collider.has_method("is_range_target") else "object"
		collider.on_hit(point, dmg, dir, true)
		if info["kind"] == "target":
			info["zone"] = collider.last_zone()
		Fx.sparks(point, normal)
	else:
		Fx.sparks(point, normal)
		Sfx.play_3d("bullet_impact", point, -2.0)
		_place_hole(point, normal)
	impact.emit(info)


## Head / body / limb from where a bullet met a person's capsule.
static func zone_of(ped: Dictionary, point: Vector3) -> String:
	var n: Node3D = ped.get("node")
	if n == null:
		return "body"
	var h := point.y - n.global_position.y
	if h > 1.5:
		return "head"
	if h < 0.85:
		return "limb"            # legs
	var off := point - n.global_position
	off.y = 0.0
	var side := absf(off.dot(n.global_basis.x.normalized()))
	return "limb" if side > 0.2 else "body"     # arms hang at the sides of the torso


func _place_hole(point: Vector3, normal: Vector3) -> void:
	var mi := _holes[_hole_i]
	_hole_i = (_hole_i + 1) % HOLES
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	mi.global_transform = Transform3D(Basis.looking_at(-normal, up), point + normal * 0.012)
	mi.visible = true

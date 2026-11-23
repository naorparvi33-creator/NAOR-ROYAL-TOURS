extends Node3D
## Stunt jumps: striped ramps on the outer ring road around the city, in the lane by
## the edge of the map. Hit one fast in a car and the jump plays in slow motion; a clean
## landing pays by distance, and every ramp pays a bonus the first time.

signal jump_done(id: int, dist: float, first: bool)

const Geo := preload("res://missions/geo.gd")
## Side profile (distance along the ramp, height): a gentle entry, a steeper kicker
## and a short flat lip. The back is a wall: drive it the right way round.
const PROFILE := [Vector2(0, 0), Vector2(4.0, 0.3), Vector2(11.0, 1.7), Vector2(12.2, 1.7)]
const KICK_FROM := 4.0
const KICK_TO := 11.0
const LENGTH := 12.2
const WIDTH := 3.4
const MIN_SPEED := 11.0
const SLOWMO := 0.4
const SLOWMO_MS := 1300

var player: Node3D
var ui: CanvasLayer
var done: Array = []           # ramp ids already completed once (saved)
var ramps: Array = []          # Transform3D of each ramp (origin = foot of the up slope)

var _jump := {}                # running jump
var _slow_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# position on the road, direction of travel up the ramp
	# On the outer ring road, in the lane next to the edge of the map (no parked cars
	# there and no AI traffic in that lane).
	var specs := [
		[Vector3(265, 0, 106), Vector3(0, 0, -1)],
		[Vector3(265, 0, -106), Vector3(0, 0, -1)],
		[Vector3(-265, 0, 0), Vector3(0, 0, 1)],
		[Vector3(-106, 0, 265), Vector3(1, 0, 0)],
		[Vector3(106, 0, 265), Vector3(1, 0, 0)],
		[Vector3(0, 0, -265), Vector3(-1, 0, 0)],
	]
	var mat := _stripe_material()
	var mesh := _ramp_mesh(mat)
	# One convex piece per profile segment (the profile itself is not convex).
	var shapes: Array = []
	for k in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[k]
		var b: Vector2 = PROFILE[k + 1]
		var cs := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for sx in [-0.5, 0.5]:
			pts.append(Vector3(sx * WIDTH, a.y, a.x))
			pts.append(Vector3(sx * WIDTH, b.y, b.x))
			pts.append(Vector3(sx * WIDTH, -0.05, a.x))
			pts.append(Vector3(sx * WIDTH, -0.05, b.x))
		cs.points = pts
		shapes.append(cs)
	for s in specs:
		var c: Vector3 = s[0]
		var f: Vector3 = s[1]
		var pos := c + Geo.right_of(f) * 6.2 - f * (LENGTH * 0.5)
		var xf := Transform3D(Basis.looking_at(-f, Vector3.UP), pos)
		ramps.append(xf)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		for sh in shapes:
			var col := CollisionShape3D.new()
			col.shape = sh
			body.add_child(col)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visibility_range_end = 220.0
		body.add_child(mi)
		add_child(body)
		body.global_transform = xf
		body.add_to_group("map_marker")
		body.set_meta("map_color", Color(0.4, 1.0, 0.5))


func count() -> int:
	return done.size()


func _physics_process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	if not player.get("in_vehicle") or player.vehicle == null:
		if not _jump.is_empty():
			_jump = {}
		return
	var v: Node3D = player.vehicle
	if not ("linear_velocity" in v):
		return
	var vel: Vector3 = v.linear_velocity
	var spd := vel.length()
	if _jump.is_empty():
		if spd < MIN_SPEED:
			return
		for i in ramps.size():
			var xf: Transform3D = ramps[i]
			var local := xf.affine_inverse() * v.global_position
			if absf(local.x) < WIDTH * 0.5 + 0.6 and local.z > KICK_FROM + 0.5 and local.z < KICK_TO - 0.5:
				var f := xf.basis.z
				if vel.normalized().dot(f) > 0.8:
					_jump = {"id": i, "from": v.global_position, "t": 0.0, "air": false, "air_t": 0.0, "base_h": _height(v)}
					# Stunt assist: line the car up with the slope so it takes off cleanly
					# instead of slamming its nose into the ramp.
					if v is RigidBody3D:
						var k0: Vector2 = PROFILE[1]
						var k1: Vector2 = PROFILE[2]
						var slope := (f * (k1.x - k0.x) + Vector3.UP * (k1.y - k0.y)).normalized()
						var rb := v as RigidBody3D
						rb.linear_velocity = slope * spd
						rb.angular_velocity = Vector3.ZERO
				break
		return
	_jump["t"] = float(_jump["t"]) + delta
	var air := _airborne(v)
	if bool(_jump.get("landed", false)):
		# Let the car settle before judging the landing.
		_jump["settle"] = float(_jump["settle"]) + delta
		if float(_jump["settle"]) > 0.45:
			_end_jump(v, true)
		return
	if air:
		if not bool(_jump["air"]):
			_jump["from"] = v.global_position     # measure from the take-off point
		_jump["air"] = true
		_jump["air_t"] = float(_jump["air_t"]) + delta
		if v is RigidBody3D:
			(v as RigidBody3D).angular_velocity *= 0.9     # keep the flight steady
		if float(_jump["air_t"]) > 0.12 and Engine.time_scale > SLOWMO + 0.01 and _slow_until == 0:
			Engine.time_scale = SLOWMO
			_slow_until = Time.get_ticks_msec() + SLOWMO_MS
	if float(_jump["t"]) > 6.0:
		_end_jump(v, false)
	elif bool(_jump["air"]) and not air and float(_jump["air_t"]) > 0.2:
		_jump["landed"] = true
		_jump["settle"] = 0.0
		_jump["to"] = v.global_position
		_restore_time()
	elif not bool(_jump["air"]) and float(_jump["t"]) > 2.0:
		_jump = {}       # never left the ground


## No wheel touches the ground (or, for other vehicles, high above the road).
func _airborne(v: Node3D) -> bool:
	var wheels: Variant = v.get("_wheels")
	if wheels is Array and (wheels as Array).size() > 0:
		for w in wheels:
			if (w as VehicleWheel3D).is_in_contact():
				return false
		return true
	return _height(v) > float(_jump.get("base_h", 1.0)) + 0.5


func _height(v: Node3D) -> float:
	var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3(0, 0.2, 0), v.global_position + Vector3(0, -30, 0), 1, [(v as CollisionObject3D).get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	return v.global_position.y - (hit["position"] as Vector3).y


func _end_jump(v: Node3D, landed: bool) -> void:
	var j := _jump
	_jump = {}
	_restore_time()
	if not landed:
		return
	var from: Vector3 = j["from"]
	var to: Vector3 = j.get("to", v.global_position)
	var dist := Geo.flat_dist(from, to)
	var upright: bool = v.global_basis.y.y > 0.55
	if not upright or dist < 10.0 or float(j["air_t"]) < 0.45:
		ui.notice(Loc.t("stunt_fail"), "%.1f m" % dist, Color(1.0, 0.5, 0.4), 1.8)
		return
	var id: int = j["id"]
	var reward := 100 + int(dist * 12.0)
	var first := not (id in done)
	var sub := "%.1f m   +$%d" % [dist, reward]
	if first:
		done.append(id)
		reward += 500
		sub = "%.1f m   +$%d   ·   %s" % [dist, reward, Loc.t("stunt_unique") % [done.size(), ramps.size()]]
		if done.size() == ramps.size():
			reward += 5000
			sub = "%s   +$%d" % [Loc.t("stunt_all"), reward]
	player.add_money(reward)
	Sfx.play_ui("mission_done")
	ui.notice(Loc.t("stunt"), sub, Color(0.5, 1.0, 0.6), 3.0)
	jump_done.emit(id, dist, first)


func _process(_delta: float) -> void:
	# Slow motion is undone in real time, whatever happens to the jump.
	if _slow_until != 0 and Time.get_ticks_msec() >= _slow_until:
		_restore_time()


func _restore_time() -> void:
	_slow_until = 0
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _ramp_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := WIDTH * 0.5
	var u := 0.0
	# Driving surface.
	for k in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[k]
		var b: Vector2 = PROFILE[k + 1]
		var seg := a.distance_to(b)
		var n := Vector3(0, b.x - a.x, -(b.y - a.y)).normalized()
		_quad(st, [Vector3(-w, a.y, a.x), Vector3(w, a.y, a.x), Vector3(w, b.y, b.x), Vector3(-w, b.y, b.x)],
			[Vector2(0, u), Vector2(1, u), Vector2(1, u + seg / 2.0), Vector2(0, u + seg / 2.0)], n)
		u += seg / 2.0
	# Side walls and the back wall.
	for sx in [-1.0, 1.0]:
		for k in PROFILE.size() - 1:
			var a: Vector2 = PROFILE[k]
			var b: Vector2 = PROFILE[k + 1]
			var flat := Vector2(0.02, 0.02)
			_quad(st, [Vector3(sx * w, 0, a.x), Vector3(sx * w, a.y, a.x), Vector3(sx * w, b.y, b.x), Vector3(sx * w, 0, b.x)],
				[flat, flat, flat, flat], Vector3(sx, 0, 0))
	var top: Vector2 = PROFILE[PROFILE.size() - 1]
	_quad(st, [Vector3(-w, 0, top.x), Vector3(w, 0, top.x), Vector3(w, top.y, top.x), Vector3(-w, top.y, top.x)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.8), Vector2(0, 0.8)], Vector3(0, 0, 1))
	st.set_material(mat)
	return st.commit()


func _quad(st: SurfaceTool, v: Array, uv: Array, n: Vector3) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[idx])
		st.add_vertex(v[idx])


func _stripe_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := int(floor((x + y) / 8.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.75, 0.1) if stripe else Color(0.08, 0.08, 0.08))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

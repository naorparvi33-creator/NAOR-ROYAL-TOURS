extends Node3D
## 20 hidden golden owl statuettes around the city. Spots are found once at start
## with downward rays: open ground inside the blocks (alleys between buildings, shop
## car parks, corners of the park) is preferred, otherwise a sidewalk corner against a
## wall. The layout is seeded, so every session finds the same spots (saved by id).
## Walk or drive through a statuette to collect it.

signal collected(id: int, count: int)

const Geo := preload("res://missions/geo.gd")
const COUNT := 20
const REWARD := 250
const ALL_BONUS := 10000

var player: Node3D
var ui: CanvasLayer
var found: Array = []          # ids already collected (from the save)
var _owls: Array = []          # [id, Node3D]
var _mesh: ArrayMesh
var _check_t := 0.0
var _t := 0.0


func _ready() -> void:
	_mesh = _build_mesh()
	# The city's colliders exist after the first physics frames.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_place()


func count() -> int:
	return found.size()


func _place() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_202_611
	var spots: Array = []
	var blocks: Array = []
	for i in range(-Geo.RINGS, Geo.RINGS + 1):
		for j in range(-Geo.RINGS, Geo.RINGS + 1):
			blocks.append(Vector2i(i, j))
	# Shuffle with the seeded RNG.
	for k in range(blocks.size() - 1, 0, -1):
		var r := rng.randi_range(0, k)
		var tmp: Vector2i = blocks[k]
		blocks[k] = blocks[r]
		blocks[r] = tmp
	var world := get_world_3d()
	for b in blocks:
		if spots.size() >= COUNT:
			break
		var bi: int = b.x
		var bj: int = b.y
		var c := Geo.block_center(bi, bj)
		var hidden := Vector3.INF
		var limit := 37.0 if (bi != 0 or bj != 0) else 36.0
		for tries in 40:
			var p := c + Vector3(rng.randf_range(-limit, limit), 0, rng.randf_range(-limit, limit))
			var gy := Geo.ground_y(world, p, 99.0, 60.0)
			if gy < 0.6 and _clear_around(world, p + Vector3(0, gy + 0.5, 0)):
				hidden = Vector3(p.x, gy, p.z)
				break
		if hidden == Vector3.INF:
			# A sidewalk corner against the wall instead.
			var side := rng.randi_range(0, 3)
			hidden = Geo.walk_point(bi, bj, side, 0.97 if rng.randf() < 0.5 else -0.97, Geo.WALL_IN)
		spots.append(hidden)
	# Fewer blocks than statuettes: put the rest on sidewalk corners of random blocks.
	while spots.size() < COUNT:
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		if b == Vector2i.ZERO:
			continue
		spots.append(Geo.walk_point(b.x, b.y, rng.randi_range(0, 3), rng.randf_range(-0.9, 0.9), Geo.WALL_IN))
	for id in COUNT:
		if id in found:
			continue
		var n := MeshInstance3D.new()
		n.mesh = _mesh
		n.visibility_range_end = 55.0
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		n.global_position = spots[id] + Vector3(0, 0.35, 0)
		_owls.append([id, n])


## Not inside a wall or tree: a short horizontal ray in 4 directions must be free.
func _clear_around(world: World3D, p: Vector3) -> bool:
	var space := world.direct_space_state
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var q := PhysicsRayQueryParameters3D.create(p, p + d * 0.55, 1)
		if not space.intersect_ray(q).is_empty():
			return false
	return true


func _process(delta: float) -> void:
	if player == null or _owls.is_empty():
		return
	_t += delta
	# Spin and bob (only the few that can be seen are near enough to matter).
	var pp: Vector3 = player.global_position
	for o in _owls:
		var n: Node3D = o[1]
		if n.global_position.distance_squared_to(pp) < 3600.0:
			n.rotation.y = _t * 1.6 + float(o[0])
			n.position.y += sin(_t * 2.5 + float(o[0])) * delta * 0.12
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.1
	var r := 3.0 if player.get("in_vehicle") else 1.3
	for o in _owls:
		var n: Node3D = o[1]
		var off := n.global_position - pp
		if Vector2(off.x, off.z).length() < r and absf(off.y) < 2.5:
			_collect(o)
			break


func _collect(o: Array) -> void:
	var id: int = o[0]
	var n: Node3D = o[1]
	_owls.erase(o)
	n.queue_free()
	found.append(id)
	player.add_money(REWARD)
	Sfx.play_ui("mission_done")
	var c := found.size()
	if c >= COUNT:
		player.add_money(ALL_BONUS)
		ui.notice(Loc.t("owl_all"), "+$%d" % (REWARD + ALL_BONUS), Color(1.0, 0.85, 0.3), 4.0)
	else:
		ui.notice("%s %d/%d" % [Loc.t("owl"), c, COUNT], "+$%d" % REWARD, Color(1.0, 0.85, 0.3))
	collected.emit(id, c)


## Positions still to find (for a map, debugging or tests).
func remaining_positions() -> Array:
	var out: Array = []
	for o in _owls:
		out.append((o[1] as Node3D).global_position)
	return out


func _build_mesh() -> ArrayMesh:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.28)
	gold.metallic = 1.0
	gold.roughness = 0.22
	gold.emission_enabled = true
	gold.emission = Color(0.55, 0.38, 0.08)
	gold.emission_energy_multiplier = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.04, 0.03)
	dark.roughness = 0.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Body, head, ears, base.
	var body := SphereMesh.new()
	body.radius = 0.16
	body.height = 0.4
	body.radial_segments = 14
	body.rings = 8
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0, 0.2, 0)))
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.24
	head.radial_segments = 14
	head.rings = 7
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.44, 0)))
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.04
		ear.height = 0.1
		ear.radial_segments = 6
		st.append_from(ear, 0, Transform3D(Basis(Vector3(0, 0, 1), -sx * 0.35), Vector3(sx * 0.07, 0.56, 0)))
		var wing := SphereMesh.new()
		wing.radius = 0.06
		wing.height = 0.28
		wing.radial_segments = 8
		wing.rings = 5
		st.append_from(wing, 0, Transform3D(Basis(), Vector3(sx * 0.15, 0.2, 0.02)))
	var base := CylinderMesh.new()
	base.top_radius = 0.15
	base.bottom_radius = 0.18
	base.height = 0.05
	base.radial_segments = 14
	st.append_from(base, 0, Transform3D(Basis(), Vector3(0, 0.0, 0)))
	st.set_material(gold)
	var mesh := st.commit()
	# Eyes as a second surface.
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		eye.radial_segments = 8
		eye.rings = 4
		st2.append_from(eye, 0, Transform3D(Basis(), Vector3(sx * 0.05, 0.46, -0.11)))
	st2.set_material(dark)
	st2.commit(mesh)
	return mesh

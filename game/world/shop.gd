extends RefCounted
## Walk-in corner shop: hollow one-storey building with a doorway, counter, shelves
## of products, a warm ceiling light, a sign, and a cash register the player can rob.
## Walls go into the block's facade mesh (shared draw call); the interior is separate.

const NAMES := ["מכולת השכונה", "קפה פינתי", "פיצה רחוב", "כלי בית", "מכבסה 24/7", "ירקות טריים", "פלאפל הגדול", "חומרי בניין"]
const H := 4.2
const T := 0.3

var city: Node3D


## lot: Rect2 in block space; the shop sits at the lot's -Z street edge.
func build(st: SurfaceTool, block_center: Vector3, lot: Rect2, tint: Color, bseed: float, index: int) -> void:
	var c: Variant = city
	var curb: float = c.CURB_H
	var w := 14.0
	var d := 11.0
	var x0 := lot.position.x + 2.0
	var z0 := lot.position.y + 0.5            # front wall on the street side
	var base := block_center + Vector3(x0 + w * 0.5, curb, z0 + d * 0.5)
	var col := Color(tint.r, tint.g, tint.b, bseed)
	var door := 2.4
	# Walls (front has a doorway in the middle).
	var seg := (w - door) * 0.5
	_wall(st, col, base + Vector3(-w * 0.5 + seg * 0.5, H * 0.5, -d * 0.5), Vector3(seg, H, T))
	_wall(st, col, base + Vector3(w * 0.5 - seg * 0.5, H * 0.5, -d * 0.5), Vector3(seg, H, T))
	_wall(st, col, base + Vector3(0, H - 0.65, -d * 0.5), Vector3(door, 1.3, T), true)
	_wall(st, col, base + Vector3(0, H * 0.5, d * 0.5), Vector3(w, H, T))
	_wall(st, col, base + Vector3(-w * 0.5, H * 0.5, 0), Vector3(T, H, d))
	_wall(st, col, base + Vector3(w * 0.5, H * 0.5, 0), Vector3(T, H, d))
	# Roof with a parapet.
	var dark := Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.8, bseed)
	_wall(st, dark, base + Vector3(0, H + 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4), true)
	_wall(st, dark, base + Vector3(0, H + 0.55, -d * 0.5 - 0.05), Vector3(w + 0.4, 0.6, 0.25), true)

	var interior := Node3D.new()
	interior.position = base
	city.add_child(interior)
	_interior(interior, w, d, index)
	# Sign over the door.
	var sign := Label3D.new()
	sign.text = NAMES[index % NAMES.size()]
	sign.font_size = 96
	sign.pixel_size = 0.006
	sign.outline_size = 18
	sign.modulate = Color(1.0, 0.92, 0.7)
	sign.position = Vector3(0, H + 0.55, -d * 0.5 - 0.2)
	sign.rotation.y = PI
	interior.add_child(sign)


func _wall(st: SurfaceTool, col: Color, pos: Vector3, size: Vector3, plain := false) -> void:
	var c: Variant = city
	c._add_box(st, pos, size, col, 1.0 if plain else 0.0, pos.y + size.y * 0.5)
	c._box_collision(pos, size)


func _interior(root: Node3D, w: float, d: float, index: int) -> void:
	var floor_mat := Mats.pbr("planks", 1.2, Color(0.95, 0.9, 0.85))
	var wood := Mats.pbr("planks", 0.8, Color(0.75, 0.6, 0.45))
	var inner := Mats.pbr("plaster", 2.0, Color(0.98, 0.96, 0.92))
	_box(root, Vector3(w - T, 0.04, d - T), Vector3(0, 0.02, 0), floor_mat, false)
	# Plaster lining so the inside does not show the outside facade.
	_box(root, Vector3(w - 0.7, 3.9, 0.05), Vector3(0, 1.95, d * 0.5 - 0.2), inner, false)
	_box(root, Vector3(0.05, 3.9, d - 0.7), Vector3(-w * 0.5 + 0.2, 1.95, 0), inner, false)
	_box(root, Vector3(0.05, 3.9, d - 0.7), Vector3(w * 0.5 - 0.2, 1.95, 0), inner, false)
	_box(root, Vector3(w - 0.4, 0.05, d - 0.4), Vector3(0, H - 0.05, 0), inner, false)   # ceiling
	# Counter with the register.
	_box(root, Vector3(3.2, 1.0, 0.7), Vector3(-w * 0.5 + 2.6, 0.5, -d * 0.5 + 2.6), wood, true)
	var reg := Register.new()
	reg.position = Vector3(-w * 0.5 + 2.3, 1.12, -d * 0.5 + 2.6)
	root.add_child(reg)
	# Shelves along the back and right walls, stocked with products.
	var products := _product_mesh(index)
	for k in 3:
		var sx := -w * 0.5 + 4.5 + k * 3.2
		_box(root, Vector3(2.6, 2.2, 0.5), Vector3(sx, 1.1, d * 0.5 - 0.6), wood, true)
		var mi := MeshInstance3D.new()
		mi.mesh = products
		mi.position = Vector3(sx, 0, d * 0.5 - 0.6)
		root.add_child(mi)
	for k in 2:
		var sz := -d * 0.5 + 4.5 + k * 3.0
		_box(root, Vector3(0.5, 2.2, 2.4), Vector3(w * 0.5 - 0.6, 1.1, sz), wood, true)
		var mi := MeshInstance3D.new()
		mi.mesh = products
		mi.rotation.y = PI * 0.5
		mi.position = Vector3(w * 0.5 - 0.6, 0, sz)
		root.add_child(mi)
	var light := OmniLight3D.new()
	light.position = Vector3(0, H - 0.6, 0)
	light.light_color = Color(1.0, 0.86, 0.68)
	light.light_energy = 1.6
	light.omni_range = 10.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	light.distance_fade_length = 15.0
	root.add_child(light)


## Rows of small coloured boxes on a shelf: one surface per colour, so 7 draw calls
## for a whole shelf of products.
func _product_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var palette := [Color(0.85, 0.2, 0.15), Color(0.2, 0.45, 0.85), Color(0.95, 0.8, 0.2), Color(0.25, 0.65, 0.3),
		Color(0.95, 0.95, 0.92), Color(0.55, 0.3, 0.15), Color(0.9, 0.5, 0.15)]
	var tools: Array[SurfaceTool] = []
	for c in palette:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
	for shelf in 4:
		var y := 0.35 + shelf * 0.5
		var x := -1.15
		while x < 1.1:
			var bw := rng.randf_range(0.12, 0.26)
			var bh := rng.randf_range(0.15, 0.36)
			var bm := BoxMesh.new()
			bm.size = Vector3(bw, bh, 0.22)
			tools[rng.randi() % palette.size()].append_from(bm, 0, Transform3D(Basis(), Vector3(x + bw * 0.5, y + bh * 0.5, -0.27)))
			x += bw + 0.02
	var mesh := ArrayMesh.new()
	for i in palette.size():
		tools[i].set_material(Mats.plain(palette[i], 0.55))
		tools[i].commit(mesh)
	return mesh


func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = 70.0
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		col.shape = bs
		body.add_child(col)
		body.position = pos
		root.add_child(body)


## Cash register: the context button empties it; it refills after two minutes.
class Register extends Node3D:
	var _cooldown := 0.0

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.25, 0.35)
		mi.mesh = bm
		mi.material_override = Mats.plain(Color(0.12, 0.12, 0.13), 0.4, 0.3)
		add_child(mi)
		set_meta("ctx_label", "ctx_rob")
		add_to_group("pickup")

	func collect(player: Node) -> void:
		player.add_money(randi_range(120, 320))
		get_tree().call_group("panic_listeners", "on_gunshot", global_position)
		get_tree().call_group("crime_listeners", "report_crime", "rob", global_position)
		_cooldown = 120.0
		set_process(true)

	func _process(delta: float) -> void:
		_cooldown -= delta
		if _cooldown <= 0.0:
			add_to_group("pickup")
			set_process(false)

extends RefCounted
## Interior building kit: every static box of a room goes into one merged mesh per
## material (a whole furnished room is a handful of draw calls), plus helpers for
## procedural furniture, CC0 Poly Haven models, warm lights without shadows and signs.
## Works in the site's local frame (root node): x along the street face, z into the
## building, y up. Furniture "faces" -z (toward the street) unless rotated.

const MODELS := "res://world/interiors/models/%s/%s.gltf"
const DRAW := 60.0              # interior draw distance

var root: Node3D
var body: StaticBody3D
var _tools := {}                # Material -> SurfaceTool
var _scenes := {}
static var _mats := {}


func _init(r: Node3D) -> void:
	root = r
	body = StaticBody3D.new()
	body.name = "Furniture"
	root.add_child(body)


# ------------------------------------------------------------ materials

static func mat(kind: String, tint := Color.WHITE) -> Material:
	var key := kind + tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var mt: Material
	match kind:
		"wood":
			mt = Mats.plain(tint, 0.55)
		"rough_wood":
			mt = Mats.pbr("planks", 0.8, tint)
		"floor_wood":
			mt = _parquet(tint)
		"plaster":
			mt = Mats.pbr("plaster", 2.0, tint)
		"fabric":
			var f := StandardMaterial3D.new()
			f.albedo_color = tint
			f.normal_enabled = true
			f.normal_texture = load("res://assets/textures/fabric_normal.jpg")
			f.normal_scale = 0.7
			f.roughness = 0.95
			f.uv1_triplanar = true
			f.uv1_world_triplanar = true
			f.uv1_scale = Vector3.ONE / 0.35
			mt = f
		"concrete":
			mt = Mats.pbr("concrete", 2.0, tint)
		"tiles":
			mt = _tiles(tint, 0.6)
		"big_tiles":
			mt = _tiles(tint, 1.0)
		"metal":
			mt = Mats.plain(tint, 0.35, 0.75)
		"plastic":
			mt = Mats.plain(tint, 0.45, 0.0)
		"glow":
			var g := StandardMaterial3D.new()
			g.albedo_color = tint
			g.emission_enabled = true
			g.emission = tint
			g.emission_energy_multiplier = 2.2
			mt = g
		"screen":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.02, 0.02, 0.03)
			s.emission_enabled = true
			s.emission = tint
			s.emission_energy_multiplier = 0.9
			s.roughness = 0.15
			mt = s
		_:
			mt = Mats.plain(tint, 0.6)
	_mats[key] = mt
	return mt


## Wooden floor boards drawn into a small generated texture (clean, varnished look).
static func _parquet(tint: Color) -> StandardMaterial3D:
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var board_w := 16
	for bx in 128 / board_w:
		var y := -rng.randi_range(0, 100)
		while y < 128:
			var l := rng.randi_range(70, 130)
			var shade := rng.randf_range(0.82, 1.08)
			for py in range(maxi(y, 0), mini(y + l, 128)):
				for px in range(bx * board_w, bx * board_w + board_w):
					var grain := 0.94 + 0.06 * sin(float(px) * 1.8 + float(py) * 0.1 + bx * 3.0)
					var k := shade * grain
					img.set_pixel(px, py, Color(tint.r * k, tint.g * k, tint.b * k))
			if y + l < 128 and y + l >= 0:
				img.fill_rect(Rect2i(bx * board_w, y + l, board_w, 1), tint.darkened(0.55))
			y += l + 1
		img.fill_rect(Rect2i(bx * board_w, 0, 1, 128), tint.darkened(0.55))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.45
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Floor tiles drawn into a small generated texture (world-triplanar like the rest).
static func _tiles(tint: Color, tile_m: float) -> StandardMaterial3D:
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tile_m * 100.0) + 5
	for ty in 2:
		for tx in 2:
			var shade := rng.randf_range(0.93, 1.03)
			var c := Color(tint.r * shade, tint.g * shade, tint.b * shade)
			img.fill_rect(Rect2i(tx * 64, ty * 64, 64, 64), c)
	var grout := Color(tint.r * 0.62, tint.g * 0.62, tint.b * 0.6)
	for k in 3:
		var p := clampi(k * 64 - 1, 0, 126)
		img.fill_rect(Rect2i(p, 0, 2, 128), grout)
		img.fill_rect(Rect2i(0, p, 128, 2), grout)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / (tile_m * 2.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# ------------------------------------------------------------ primitives

## Static box (merged into the room mesh). rot_y in radians about the box centre.
func box(m: Material, center: Vector3, size: Vector3, collide := false, rot_y := 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var xf := Transform3D(Basis(Vector3.UP, rot_y), center)
	_tool(m).append_from(bm, 0, xf)
	if collide:
		col_box(center, size, rot_y)


func cyl(m: Material, center: Vector3, radius: float, height: float, segs := 12, top_r := -1.0) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius if top_r < 0.0 else top_r
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	_tool(m).append_from(cm, 0, Transform3D(Basis(), center))


func sphere(m: Material, center: Vector3, radius: float, squash := 1.0) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	_tool(m).append_from(sm, 0, Transform3D(Basis().scaled(Vector3(1, squash, 1)), center))


## Any mesh with a full transform.
func mesh(m: Material, mesh_res: Mesh, xf: Transform3D) -> void:
	_tool(m).append_from(mesh_res, 0, xf)


func col_box(center: Vector3, size: Vector3, rot_y := 0.0) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
	body.add_child(col)
	return col


func _tool(m: Material) -> SurfaceTool:
	if not _tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[m] = st
	return _tools[m]


## Builds the merged mesh (one surface per material).
func commit() -> MeshInstance3D:
	var am := ArrayMesh.new()
	for m in _tools:
		var st: SurfaceTool = _tools[m]
		st.set_material(m)
		st.commit(am)
	_tools.clear()
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.visibility_range_end = DRAW
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


# ------------------------------------------------------------ models, lights, signs

## Poly Haven (CC0) model, limited draw distance, no shadows.
func model(name: String, pos: Vector3, rot_y := 0.0, scale := 1.0, collider := Vector3.ZERO) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(MODELS % [name, name])
	var inst: Node3D = (_scenes[name] as PackedScene).instantiate()
	inst.transform = Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * scale), pos)
	root.add_child(inst)
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = DRAW * 0.8
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collider != Vector3.ZERO:
		col_box(pos + Vector3(0, collider.y * 0.5, 0), collider, rot_y)
	return inst


## Warm interior light: no shadows, fades out with distance.
func light(pos: Vector3, color := Color(1.0, 0.85, 0.66), energy := 1.5, rng := 9.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 0.9
	l.shadow_enabled = false
	l.light_specular = 0.4
	l.distance_fade_enabled = true
	l.distance_fade_begin = 38.0
	l.distance_fade_length = 14.0
	root.add_child(l)
	return l


## Ceiling light fitting (glowing panel); the actual light is added with light().
func ceiling_panel(pos: Vector3, size := Vector2(1.2, 0.6)) -> void:
	box(mat("metal", Color(0.85, 0.85, 0.85)), pos + Vector3(0, 0.03, 0), Vector3(size.x + 0.06, 0.05, size.y + 0.06))
	box(mat("glow", Color(1.0, 0.93, 0.8)), pos, Vector3(size.x, 0.03, size.y))


## Text sign. Facing: rot_y (0 = readable from +z, PI = readable from -z / the street).
func sign(text: String, pos: Vector3, rot_y: float, font_size := 96, color := Color(1, 0.95, 0.85), outline := Color(0, 0, 0, 0.8), pixel := 0.006) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = outline
	l.position = pos
	l.rotation.y = rot_y
	l.visibility_range_end = 150.0
	root.add_child(l)
	return l


# ------------------------------------------------------------ furniture

func rug(c: Vector3, w: float, l: float, col: Color) -> void:
	box(mat("fabric", col), c + Vector3(0, 0.012, 0), Vector3(w, 0.012, l))
	box(mat("fabric", col.darkened(0.35)), c + Vector3(0, 0.008, 0), Vector3(w + 0.12, 0.008, l + 0.12))


## Double bed, head against +z (rotate for other walls).
func bed(c: Vector3, rot := 0.0, blanket := Color(0.25, 0.35, 0.55)) -> void:
	var b := Basis(Vector3.UP, rot)
	var wood := mat("wood", Color(0.55, 0.38, 0.25))
	_rbox(wood, c, b, Vector3(0, 0.2, 0), Vector3(1.7, 0.3, 2.1), true)
	_rbox(wood, c, b, Vector3(0, 0.6, 1.02), Vector3(1.76, 1.05, 0.08))
	_rbox(mat("fabric", Color(0.93, 0.92, 0.88)), c, b, Vector3(0, 0.45, -0.02), Vector3(1.6, 0.22, 2.0))
	_rbox(mat("fabric", blanket), c, b, Vector3(0, 0.575, -0.3), Vector3(1.66, 0.06, 1.45))
	_rbox(mat("fabric", blanket.darkened(0.2)), c, b, Vector3(0, 0.36, -1.0), Vector3(1.66, 0.3, 0.04))
	for sx in [-0.4, 0.4]:
		_rbox(mat("fabric", Color(0.97, 0.96, 0.93)), c, b, Vector3(sx, 0.62, 0.72), Vector3(0.62, 0.14, 0.38))


## Wardrobe against +z, front toward -z.
func wardrobe(c: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var wood := mat("wood", Color(0.82, 0.74, 0.62))
	_rbox(wood, c, b, Vector3(0, 1.1, 0), Vector3(1.9, 2.2, 0.62), true)
	var dark := mat("plastic", Color(0.15, 0.12, 0.1))
	_rbox(dark, c, b, Vector3(0, 1.1, -0.315), Vector3(0.015, 2.1, 0.01))
	_rbox(dark, c, b, Vector3(-0.475, 1.1, -0.315), Vector3(0.012, 2.1, 0.01))
	_rbox(dark, c, b, Vector3(0.475, 1.1, -0.315), Vector3(0.012, 2.1, 0.01))
	var metal := mat("metal", Color(0.75, 0.75, 0.72))
	for sx in [-0.08, 0.08, -0.56, 0.56]:
		_rbox(metal, c, b, Vector3(sx, 1.1, -0.34), Vector3(0.025, 0.3, 0.03))
	# A mirror on one door.
	_rbox(mat("metal", Color(0.8, 0.85, 0.9)), c, b, Vector3(0.71, 1.25, -0.32), Vector3(0.34, 1.2, 0.01))


## Kitchen run along local x (length), back against +z.
func kitchen(c: Vector3, length: float, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var white := mat("wood", Color(0.95, 0.95, 0.93))
	var top := mat("concrete", Color(0.35, 0.34, 0.33))
	var fridge_w := 0.8
	var run := length - fridge_w
	_rbox(white, c, b, Vector3(-fridge_w * 0.5, 0.44, 0), Vector3(run, 0.88, 0.6), true)
	_rbox(top, c, b, Vector3(-fridge_w * 0.5, 0.9, -0.01), Vector3(run + 0.02, 0.04, 0.64))
	_rbox(white, c, b, Vector3(-fridge_w * 0.5, 1.85, 0.12), Vector3(run, 0.7, 0.36))
	var dark := mat("plastic", Color(0.1, 0.1, 0.1))
	var x0 := -length * 0.5
	for k in int(run / 0.6):
		_rbox(dark, c, b, Vector3(x0 + 0.6 * (k + 1), 0.45, -0.305), Vector3(0.01, 0.84, 0.01))
	# Hob and sink.
	_rbox(dark, c, b, Vector3(x0 + 0.6, 0.925, -0.02), Vector3(0.58, 0.012, 0.5))
	_rbox(mat("metal", Color(0.8, 0.8, 0.82)), c, b, Vector3(x0 + run - 0.5, 0.915, -0.02), Vector3(0.5, 0.02, 0.4))
	_rbox(mat("metal", Color(0.75, 0.75, 0.78)), c, b, Vector3(x0 + run - 0.5, 1.05, 0.22), Vector3(0.04, 0.3, 0.04))
	# Fridge.
	_rbox(mat("metal", Color(0.86, 0.87, 0.88)), c, b, Vector3(length * 0.5 - fridge_w * 0.5, 0.95, 0.0), Vector3(fridge_w - 0.04, 1.9, 0.66), true)
	_rbox(dark, c, b, Vector3(length * 0.5 - fridge_w * 0.5, 1.25, -0.335), Vector3(fridge_w - 0.06, 0.012, 0.01))


## Low TV cabinet with a flat screen (front toward -z).
func tv(c: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", Color(0.3, 0.22, 0.16)), c, b, Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 0.45), true)
	_rbox(mat("plastic", Color(0.04, 0.04, 0.05)), c, b, Vector3(0, 1.12, 0.1), Vector3(1.4, 0.8, 0.05))
	_rbox(mat("screen", Color(0.25, 0.4, 0.6)), c, b, Vector3(0, 1.12, 0.07), Vector3(1.34, 0.74, 0.01))


func table(c: Vector3, w: float, l: float, h := 0.76, top_col := Color(0.6, 0.45, 0.3), round_top := false) -> void:
	var leg := mat("metal", Color(0.12, 0.12, 0.12))
	if round_top:
		cyl(mat("wood", top_col), c + Vector3(0, h - 0.02, 0), w * 0.5, 0.04, 20)
		cyl(leg, c + Vector3(0, h * 0.5, 0), 0.04, h, 8)
		cyl(leg, c + Vector3(0, 0.02, 0), 0.25, 0.04, 12)
	else:
		box(mat("wood", top_col), c + Vector3(0, h - 0.02, 0), Vector3(w, 0.04, l))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				box(leg, c + Vector3(sx * (w * 0.5 - 0.06), h * 0.5 - 0.02, sz * (l * 0.5 - 0.06)), Vector3(0.05, h - 0.04, 0.05))
	col_box(c + Vector3(0, h * 0.5, 0), Vector3(w, h, w if round_top else l))


## Shop counter along local x with a front panel facing -z.
func counter(c: Vector3, length: float, rot := 0.0, col := Color(0.45, 0.32, 0.22), top_col := Color(0.2, 0.2, 0.21)) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", col), c, b, Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.7), true)
	_rbox(mat("concrete", top_col), c, b, Vector3(0, 1.02, -0.03), Vector3(length + 0.06, 0.05, 0.8))
	_rbox(mat("metal", Color(0.7, 0.7, 0.7)), c, b, Vector3(0, 0.1, -0.36), Vector3(length, 0.06, 0.02))


## Cash register / card terminal on a counter.
func register(p: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("plastic", Color(0.12, 0.12, 0.13)), p, b, Vector3(0, 0.06, 0), Vector3(0.36, 0.12, 0.32))
	_rbox(mat("screen", Color(0.3, 0.7, 0.45)), p, b, Vector3(0, 0.25, 0.08), Vector3(0.26, 0.18, 0.02))


## Wall shelf unit stocked with small coloured products (front toward -z).
func product_shelf(c: Vector3, length: float, rot := 0.0, seed_value := 1, palette: Array = []) -> void:
	var b := Basis(Vector3.UP, rot)
	var wood := mat("wood", Color(0.7, 0.58, 0.45))
	_rbox(wood, c, b, Vector3(0, 1.1, 0.2), Vector3(length, 2.2, 0.06), true)
	_rbox(wood, c, b, Vector3(-length * 0.5, 1.1, 0), Vector3(0.04, 2.2, 0.45))
	_rbox(wood, c, b, Vector3(length * 0.5, 1.1, 0), Vector3(0.04, 2.2, 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 3
	if palette.is_empty():
		palette = [Color(0.85, 0.2, 0.15), Color(0.2, 0.45, 0.85), Color(0.95, 0.8, 0.2), Color(0.25, 0.65, 0.3),
			Color(0.95, 0.95, 0.92), Color(0.55, 0.3, 0.15)]
	for s in 4:
		var y := 0.25 + s * 0.5
		_rbox(wood, c, b, Vector3(0, y - 0.02, 0), Vector3(length - 0.04, 0.03, 0.42))
		var x := -length * 0.5 + 0.08
		while x < length * 0.5 - 0.2:
			var bw := rng.randf_range(0.1, 0.24)
			var bh := rng.randf_range(0.12, 0.32)
			var col: Color = palette[rng.randi() % palette.size()]
			_rbox(mat("plastic", col), c, b, Vector3(x + bw * 0.5, y + bh * 0.5, 0.02), Vector3(bw, bh, 0.26))
			x += bw + 0.02


## Clothes rail with hanging garments in many colours.
func clothes_rack(c: Vector3, length: float, rot := 0.0, seed_value := 1) -> void:
	var b := Basis(Vector3.UP, rot)
	var metal := mat("metal", Color(0.7, 0.7, 0.72))
	_rbox(metal, c, b, Vector3(0, 1.55, 0), Vector3(length, 0.03, 0.03))
	for sx in [-0.5, 0.5]:
		_rbox(metal, c, b, Vector3(sx * length, 0.78, 0), Vector3(0.03, 1.56, 0.03))
		_rbox(metal, c, b, Vector3(sx * length, 0.02, 0), Vector3(0.05, 0.03, 0.55))
	col_box(c + Vector3(0, 0.8, 0), Vector3(length, 1.6, 0.5), rot)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 131 + 17
	var colors := [Color(0.1, 0.12, 0.2), Color(0.75, 0.1, 0.1), Color(0.9, 0.9, 0.88), Color(0.15, 0.4, 0.25),
		Color(0.85, 0.65, 0.2), Color(0.3, 0.3, 0.32), Color(0.45, 0.55, 0.8), Color(0.6, 0.35, 0.5)]
	var x := -length * 0.5 + 0.12
	while x < length * 0.5 - 0.1:
		var col: Color = colors[rng.randi() % colors.size()]
		var h := rng.randf_range(0.7, 1.0)
		_rbox(mat("fabric", col), c, b, Vector3(x, 1.5 - h * 0.5, 0), Vector3(0.05, h, 0.5))
		_rbox(metal, c, b, Vector3(x, 1.53, 0), Vector3(0.012, 0.06, 0.012))
		x += rng.randf_range(0.07, 0.11)


## Shop mannequin dressed in an outfit (shirt, pants colours).
func mannequin(c: Vector3, shirt: Color, pants: Color, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var skin := mat("plastic", Color(0.92, 0.9, 0.86))
	cyl(mat("metal", Color(0.2, 0.2, 0.2)), c + Vector3(0, 0.02, 0), 0.22, 0.04, 12)
	cyl(mat("metal", Color(0.2, 0.2, 0.2)), c + Vector3(0, 0.25, 0), 0.02, 0.5, 6)
	for sx in [-0.1, 0.1]:
		_rbox(mat("fabric", pants), c, b, Vector3(sx, 0.75, 0), Vector3(0.15, 0.88, 0.17))
	_rbox(mat("fabric", shirt), c, b, Vector3(0, 1.38, 0), Vector3(0.42, 0.56, 0.24))
	for sx in [-0.27, 0.27]:
		_rbox(mat("fabric", shirt), c, b, Vector3(sx, 1.37, 0), Vector3(0.11, 0.55, 0.13))
	cyl(skin, c + Vector3(0, 1.72, 0), 0.05, 0.12, 8)
	sphere(skin, c + Vector3(0, 1.86, 0), 0.12, 1.2)
	col_box(c + Vector3(0, 0.95, 0), Vector3(0.5, 1.9, 0.5))


func plant(c: Vector3, h := 1.2) -> void:
	cyl(mat("concrete", Color(0.75, 0.42, 0.3)), c + Vector3(0, 0.2, 0), 0.24, 0.4, 12, 0.3)
	cyl(mat("plastic", Color(0.25, 0.18, 0.12)), c + Vector3(0, 0.39, 0), 0.27, 0.02, 12)
	var leaf := mat("plastic", Color(0.16, 0.38, 0.14))
	sphere(leaf, c + Vector3(0, 0.4 + h * 0.45, 0), 0.32, 1.4)
	sphere(leaf, c + Vector3(0.15, 0.4 + h * 0.75, 0.05), 0.24, 1.2)
	sphere(leaf, c + Vector3(-0.12, 0.4 + h * 0.62, -0.1), 0.26, 1.2)
	col_box(c + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5))


func desk(c: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", Color(0.5, 0.4, 0.3)), c, b, Vector3(0, 0.74, 0), Vector3(1.6, 0.04, 0.8))
	_rbox(mat("metal", Color(0.25, 0.25, 0.27)), c, b, Vector3(-0.6, 0.37, 0), Vector3(0.4, 0.72, 0.75))
	_rbox(mat("metal", Color(0.25, 0.25, 0.27)), c, b, Vector3(0.75, 0.37, 0), Vector3(0.04, 0.72, 0.75))
	_rbox(mat("plastic", Color(0.06, 0.06, 0.07)), c, b, Vector3(0.2, 1.0, 0.2), Vector3(0.6, 0.38, 0.03))
	_rbox(mat("screen", Color(0.35, 0.5, 0.75)), c, b, Vector3(0.2, 1.0, 0.18), Vector3(0.56, 0.34, 0.01))
	_rbox(mat("plastic", Color(0.1, 0.1, 0.1)), c, b, Vector3(0.2, 0.8, 0.2), Vector3(0.06, 0.12, 0.06))
	_rbox(mat("plastic", Color(0.15, 0.15, 0.15)), c, b, Vector3(0.2, 0.765, -0.1), Vector3(0.45, 0.02, 0.15))
	col_box(c + Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 0.8), rot)


func lockers(c: Vector3, count: int, rot := 0.0, col := Color(0.35, 0.42, 0.5)) -> void:
	var b := Basis(Vector3.UP, rot)
	var w := 0.45
	var m := mat("metal", col)
	var dark := mat("plastic", Color(0.08, 0.08, 0.1))
	for i in count:
		var x := (i - (count - 1) * 0.5) * w
		_rbox(m, c, b, Vector3(x, 0.95, 0), Vector3(w - 0.02, 1.9, 0.5))
		for k in 3:
			_rbox(dark, c, b, Vector3(x, 1.6 - k * 0.04, -0.252), Vector3(0.22, 0.012, 0.005))
		_rbox(mat("metal", Color(0.8, 0.8, 0.8)), c, b, Vector3(x + 0.15, 1.0, -0.26), Vector3(0.02, 0.12, 0.02))
	col_box(c + Vector3(0, 0.95, 0), Vector3(w * count, 1.9, 0.5), rot)


## Board on the wall with guns hanging on pegs (uses the game's own gun meshes).
func gun_wall(c: Vector3, length: float, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", Color(0.78, 0.72, 0.6)), c, b, Vector3(0, 1.75, 0.04), Vector3(length, 1.7, 0.04))
	var rifle: MeshInstance3D = RifleMesh.build()
	var pistol: MeshInstance3D = RifleMesh.build_pistol()
	var gm := mat("metal", Color(0.12, 0.12, 0.13))
	var n := int(length / 1.0)
	for i in n:
		var x := (i - (n - 1) * 0.5) * 1.0
		for row in 2:
			var p := c + b * Vector3(x, 2.25 - row * 0.55, -0.02)
			var xf := Transform3D(b * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.FORWARD, 0.04) * Basis().scaled(Vector3.ONE * 1.25), p)
			mesh(gm, rifle.mesh, xf)
		var pp := c + b * Vector3(x, 1.12, -0.02)
		mesh(gm, pistol.mesh, Transform3D(b * Basis(Vector3.UP, PI * 0.5) * Basis().scaled(Vector3.ONE * 1.4), pp))
	rifle.free()
	pistol.free()


## Glass display counter (gun shop / jewellery).
func display_counter(c: Vector3, length: float, glass: Material, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", Color(0.18, 0.16, 0.15)), c, b, Vector3(0, 0.35, 0), Vector3(length, 0.7, 0.7), true)
	_rbox(glass, c, b, Vector3(0, 0.85, 0), Vector3(length, 0.3, 0.7))
	_rbox(mat("metal", Color(0.7, 0.7, 0.7)), c, b, Vector3(0, 1.005, 0), Vector3(length + 0.02, 0.01, 0.72))
	col_box(c + Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.7), rot)
	var pistol: MeshInstance3D = RifleMesh.build_pistol()
	var gm := mat("metal", Color(0.15, 0.15, 0.16))
	var n := int(length / 0.6)
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.6
		var xf := Transform3D(b * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, 0.5) * Basis().scaled(Vector3.ONE * 1.3), c + b * Vector3(x, 0.74, 0))
		mesh(gm, pistol.mesh, xf)
	pistol.free()


func hospital_bed(c: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var metal := mat("metal", Color(0.82, 0.83, 0.85))
	_rbox(metal, c, b, Vector3(0, 0.45, 0), Vector3(0.95, 0.08, 2.0), true)
	for sx in [-0.42, 0.42]:
		for sz in [-0.92, 0.92]:
			_rbox(metal, c, b, Vector3(sx, 0.22, sz), Vector3(0.04, 0.44, 0.04))
	_rbox(mat("fabric", Color(0.9, 0.93, 0.96)), c, b, Vector3(0, 0.56, 0), Vector3(0.9, 0.14, 1.95))
	_rbox(mat("fabric", Color(0.55, 0.72, 0.82)), c, b, Vector3(0, 0.64, -0.25), Vector3(0.92, 0.03, 1.2))
	_rbox(metal, c, b, Vector3(0, 0.75, 0.98), Vector3(0.95, 0.6, 0.04))
	_rbox(mat("fabric", Color(0.98, 0.98, 0.98)), c, b, Vector3(0, 0.68, 0.78), Vector3(0.6, 0.12, 0.32))


## Hospital curtain on a ceiling rail (front toward -z).
func curtain(c: Vector3, length: float, rot := 0.0, col := Color(0.55, 0.75, 0.78)) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("metal", Color(0.8, 0.8, 0.8)), c, b, Vector3(0, 2.55, 0), Vector3(length, 0.03, 0.04))
	var folds := int(length / 0.25)
	for i in folds:
		var x := (i - (folds - 1) * 0.5) * 0.25
		var zz := 0.05 if i % 2 == 0 else -0.05
		_rbox(mat("fabric", col), c, b, Vector3(x, 1.4, zz), Vector3(0.26, 2.2, 0.02))


func mailboxes(c: Vector3, cols: int, rows: int, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var m := mat("metal", Color(0.62, 0.55, 0.38))
	var dark := mat("plastic", Color(0.08, 0.08, 0.08))
	_rbox(m, c, b, Vector3(0, 1.3, 0.1), Vector3(cols * 0.32 + 0.06, rows * 0.24 + 0.06, 0.2))
	for i in cols:
		for j in rows:
			var x := (i - (cols - 1) * 0.5) * 0.32
			var y := 1.3 + (j - (rows - 1) * 0.5) * 0.24
			_rbox(dark, c, b, Vector3(x, y + 0.05, -0.005), Vector3(0.2, 0.02, 0.01))


## Steel elevator doors with a call button panel (front toward -z).
func elevator(c: Vector3, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var steel := mat("metal", Color(0.7, 0.72, 0.74))
	_rbox(mat("metal", Color(0.3, 0.3, 0.32)), c, b, Vector3(0, 1.2, 0.02), Vector3(1.5, 2.4, 0.06))
	_rbox(steel, c, b, Vector3(-0.31, 1.05, -0.02), Vector3(0.6, 2.1, 0.03))
	_rbox(steel, c, b, Vector3(0.31, 1.05, -0.02), Vector3(0.6, 2.1, 0.03))
	_rbox(mat("plastic", Color(0.1, 0.1, 0.1)), c, b, Vector3(0.95, 1.2, -0.01), Vector3(0.14, 0.3, 0.02))
	_rbox(mat("glow", Color(1.0, 0.75, 0.3)), c, b, Vector3(0.95, 1.25, -0.025), Vector3(0.05, 0.05, 0.01))
	_rbox(mat("glow", Color(1.0, 0.3, 0.2)), c, b, Vector3(0, 2.32, -0.04), Vector3(0.3, 0.1, 0.01))


func sandbags(c: Vector3, length: float, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var m := mat("fabric", Color(0.55, 0.5, 0.38))
	var n := int(length / 0.55)
	for row in 3:
		for i in n - (row % 2):
			var x := (i - (n - 1 - (row % 2)) * 0.5) * 0.55
			_rbox(m, c, b, Vector3(x, 0.1 + row * 0.19, 0), Vector3(0.52, 0.2, 0.34))
	col_box(c + Vector3(0, 0.3, 0), Vector3(length, 0.6, 0.36), rot)


func crate(c: Vector3, s := 0.8, rot := 0.0) -> void:
	box(mat("rough_wood", Color(0.8, 0.68, 0.5)), c + Vector3(0, s * 0.5, 0), Vector3(s, s, s), true, rot)


## Picture frame with a plain colour "painting" (front toward -z by default).
func frame(c: Vector3, w: float, h: float, rot := 0.0, col := Color(0.4, 0.55, 0.7)) -> void:
	var b := Basis(Vector3.UP, rot)
	_rbox(mat("wood", Color(0.2, 0.15, 0.1)), c, b, Vector3.ZERO, Vector3(w + 0.08, h + 0.08, 0.03))
	_rbox(mat("plastic", col), c, b, Vector3(0, 0, -0.018), Vector3(w, h, 0.005))
	_rbox(mat("plastic", col.lightened(0.35)), c, b, Vector3(-w * 0.18, -h * 0.1, -0.022), Vector3(w * 0.4, h * 0.45, 0.004))


func _rbox(m: Material, c: Vector3, b: Basis, off: Vector3, size: Vector3, collide := false) -> void:
	var rot := b.get_euler().y
	box(m, c + b * off, size, collide, rot)

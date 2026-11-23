extends Node3D
## Sunny modern city district, generated in code.
##  * 5 x 5 playable blocks on a grid with roads between them (markings in ground.gdshader).
##  * The central block is a park with the training course, pines, rocks and grass.
##  * Every other block: raised sidewalk with curbs and 1-4 buildings of varied height,
##    facade material, tint and windows (one merged mesh per block and facade material).
##  * Palms, street lights and traffic lights along the sidewalks (MultiMesh).
##  * An outer ring of tall buildings closes the view at the edge of the map.
## The layout constants must match world/terrain_noise.gdshaderinc.

const PITCH := 106.0        # block + road
const ROAD_W := 16.0
const BLOCK := PITCH - ROAD_W   # 90 m including sidewalk
const WALK_W := 4.0         # sidewalk width
const CURB_H := 0.15
const RINGS := 2            # playable blocks from the centre (5 x 5)
const SUN_DIR := Vector3(0.374, 0.743, -0.555)   # sun in the sky photo

var sun: DirectionalLight3D
var grass: MultiMeshInstance3D
var _static: StaticBody3D
var _facades: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()
var _palms: Array = [[], [], []]
var _lamps: Array = []
var _signals: Array = []
var _buildings: Array = []   # {pos, size, material, block_center}
var _shop_count := 0
var _deco := RandomNumberGenerator.new()   # facade decor only: keeps the layout rng sequence
var _volumes: Array[AABB] = []   # facade volumes: window columns are centred on their faces
var _walk_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _wet_t := 0.0


func _ready() -> void:
	_rng.seed = 20261123
	_deco.seed = 77031
	_build_environment()
	_build_ground()
	_static = StaticBody3D.new()
	_static.name = "Static"
	add_child(_static)
	# Facade materials = building typologies (see building.gdshader `style`):
	# 0 brick low-rise, 1 stucco apartments / art-deco, 2 concrete offices, 3 glass towers.
	var sky_tex: Texture2D = preload("res://assets/sky/sky.jpg")
	var ads: Texture2D = load("res://assets/textures/billboards.png")
	var fac_tex := ["brick", "plaster", "concrete", "concrete"]
	for k in fac_tex.size():
		var m: String = fac_tex[k]
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://world/building.gdshader")
		sm.set_shader_parameter("wall_albedo", load("res://assets/textures/%s_albedo.jpg" % m))
		sm.set_shader_parameter("wall_normal", load("res://assets/textures/%s_normal.jpg" % m))
		sm.set_shader_parameter("wall_tile", [2.5, 3.5, 3.5, 4.0][k])
		sm.set_shader_parameter("brightness", [1.45, 0.92, 0.95, 0.8][k])
		sm.set_shader_parameter("style", k)
		sm.set_shader_parameter("sky_pano", sky_tex)
		sm.set_shader_parameter("ads", ads)
		_facades.append(sm)
	_apply_detail()

	_build_sidewalks()
	for i in range(-RINGS - 1, RINGS + 2):
		for j in range(-RINGS - 1, RINGS + 2):
			var outer := absi(i) > RINGS or absi(j) > RINGS
			if i == 0 and j == 0:
				continue
			_build_block(Vector3(i * PITCH, 0, j * PITCH), outer)
	_build_street_props()
	preload("res://world/street_dressing.gd").new().dress(self, _buildings, _rng)

	var park := preload("res://world/park.gd").new()
	add_child(park)
	grass = preload("res://world/grass_field.gd").new()
	add_child(grass)
	Settings.changed.connect(_on_setting)
	_apply_shadows()
	_hook_quality.call_deferred()


func set_follow(n: Node3D) -> void:
	grass.follow = n


func _on_setting(key: String) -> void:
	if key in ["shadows", "battery_saver"]:
		_apply_shadows()


func _apply_shadows() -> void:
	sun.shadow_enabled = Perf.shadows_enabled()


## Facade shader cost follows the graphics preset (core/quality.gd): low = flat glass.
func _hook_quality() -> void:
	var q := get_tree().root.find_child("Quality", true, false)
	if q and q.has_signal("preset_applied"):
		q.preset_applied.connect(func(_p: String) -> void: _apply_detail())
	_apply_detail()


func _apply_detail() -> void:
	var q := get_tree().root.find_child("Quality", true, false) if is_inside_tree() else null
	var preset := str(q.get("effective")) if q else str(Settings.get_value("quality_preset"))
	if not preset in ["low", "medium", "high"]:
		preset = "low" if OS.has_feature("web") else "medium"
	var d: int = {"low": 0, "medium": 1, "high": 2}[preset]
	for m in _facades:
		m.set_shader_parameter("detail", d)
	if _walk_mat:
		_walk_mat.set_shader_parameter("detail", d)
	if _ground_mat:
		_ground_mat.set_shader_parameter("detail", d)


## Rain darkens the sidewalks like the roads (world/env/city_lights.gd sets the ground).
func _process(delta: float) -> void:
	_wet_t += delta
	if _wet_t < 0.5 or _ground_mat == null or _walk_mat == null:
		return
	_wet_t = 0.0
	var w: Variant = _ground_mat.get_shader_parameter("wetness")
	if w != null:
		_walk_mat.set_shader_parameter("wetness", float(w))


# ------------------------------------------------------------ environment

func _build_environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://assets/sky/sky.jpg")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# Warm city haze: distant buildings soften into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0028
	env.fog_light_color = Color(0.78, 0.8, 0.84)
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-SUN_DIR, Vector3.UP)
	sun.light_energy = 2.3
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_angular_distance = 0.5
	# One shadow pass with a limited range: the biggest single saving on mobile.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)


func _build_ground() -> void:
	var size := PITCH * (RINGS * 2 + 3)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/ground.gdshader")
	for n in ["grass", "dirt", "asphalt"]:
		mat.set_shader_parameter(n + "_albedo", load("res://assets/textures/%s_albedo.jpg" % n))
		mat.set_shader_parameter(n + "_normal", load("res://assets/textures/%s_normal.jpg" % n))
		mat.set_shader_parameter(n + "_rough", load("res://assets/textures/%s_rough.jpg" % n))
	pm.material = mat
	_ground_mat = mat
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	# Invisible walls inside the outer ring of buildings.
	var edge := PITCH * (RINGS + 0.5) + ROAD_W * 0.5 + 2.0
	for k in 4:
		var wall := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(edge * 2.0, 30, 1)
		wall.shape = bs
		wall.rotation.y = k * PI * 0.5
		wall.position = Vector3(0, 15, -edge).rotated(Vector3.UP, k * PI * 0.5)
		body.add_child(wall)
	add_child(body)


# ------------------------------------------------------------ sidewalks

func _build_sidewalks() -> void:
	# All sidewalks in one mesh: a slab per block (a ring around the park).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BLOCK * 0.5
	for i in range(-RINGS - 1, RINGS + 2):
		for j in range(-RINGS - 1, RINGS + 2):
			var c := Vector3(i * PITCH, 0, j * PITCH)
			if i == 0 and j == 0:
				# Park: four strips around the lawn.
				for k in 4:
					var along := Vector3(BLOCK, CURB_H, WALK_W)
					var off := Vector3(0, CURB_H * 0.5, half - WALK_W * 0.5)
					var r := Basis(Vector3.UP, k * PI * 0.5)
					var sz := along if k % 2 == 0 else Vector3(WALK_W, CURB_H, BLOCK - WALK_W * 2.0)
					var pos := c + r * off
					_add_box(st, pos, sz, Color.WHITE, 1.0, 0.0)
					_box_collision(pos, sz)
			else:
				var sz := Vector3(BLOCK, CURB_H, BLOCK)
				var pos := c + Vector3(0, CURB_H * 0.5, 0)
				_add_box(st, pos, sz, Color.WHITE, 1.0, 0.0)
				_box_collision(pos, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_walk_mat = ShaderMaterial.new()
	_walk_mat.shader = preload("res://world/sidewalk.gdshader")
	_walk_mat.set_shader_parameter("pavers_albedo", load("res://assets/textures/pavers_albedo.jpg"))
	_walk_mat.set_shader_parameter("pavers_normal", load("res://assets/textures/pavers_normal.jpg"))
	_walk_mat.set_shader_parameter("concrete_albedo", load("res://assets/textures/concrete_albedo.jpg"))
	mi.material_override = _walk_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------ buildings

func _build_block(center: Vector3, outer: bool) -> void:
	var tools: Array[SurfaceTool] = []
	var used: Array[bool] = []
	for m in _facades.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
		used.append(false)

	var inner := BLOCK - WALK_W * 2.0
	var lots: Array[Rect2] = []
	var pattern := _rng.randi_range(0, 3) if not outer else 0
	match pattern:
		0:
			lots.append(Rect2(-inner * 0.5, -inner * 0.5, inner, inner))
		1:
			for a in 2:
				for b in 2:
					lots.append(Rect2(-inner * 0.5 + a * inner * 0.5, -inner * 0.5 + b * inner * 0.5, inner * 0.5, inner * 0.5))
		2:
			for a in 3:
				lots.append(Rect2(-inner * 0.5 + a * inner / 3.0, -inner * 0.5, inner / 3.0, inner))
		3:
			lots.append(Rect2(-inner * 0.5, -inner * 0.5, inner, inner * 0.5))
			for a in 2:
				lots.append(Rect2(-inner * 0.5 + a * inner * 0.5, 0, inner * 0.5, inner * 0.5))

	# Taller buildings toward the "downtown" corner of the map.
	var downtown := clampf(1.0 - (center - Vector3(PITCH, 0, -PITCH)).length() / (PITCH * 3.0), 0.0, 1.0)
	for li in lots.size():
		var lot: Rect2 = lots[li]
		# One lot in some blocks is a walk-in corner shop with a small car park.
		if not outer and pattern == 1 and li == 0:
			var sm := 1
			var shop := preload("res://world/shop.gd").new()
			shop.city = self
			shop.build(tools[sm], center, lot, _tint_for(sm), _rng.randf(), _shop_count)
			_shop_count += 1
			used[sm] = true
			continue
		var gap := 1.0 if lots.size() > 1 else 0.0
		var r := lot.grow(-gap)
		var floors := _rng.randi_range(2, 5) + int(downtown * _rng.randi_range(0, 14))
		if outer:
			floors = _rng.randi_range(10, 22)
		var top := 4.2 + floors * 3.3
		_rng.randi_range(0, 2)   # was the facade pick: keeps the layout rng sequence unchanged
		var m := _pick_style(floors, outer)
		var tint := _tint_for(m)
		var bseed := _rng.randf()
		var pos := center + Vector3(r.position.x + r.size.x * 0.5, CURB_H + top * 0.5, r.position.y + r.size.y * 0.5)
		var size := Vector3(r.size.x, top, r.size.y)
		var col := Color(tint.r, tint.g, tint.b, bseed)
		_volumes.append(AABB(pos - size * 0.5, size))
		_add_box(tools[m], pos, size, col, 0.0, CURB_H + top)
		var units: Array[Vector3] = []
		for u in _rng.randi_range(1, 3):
			var ux := _rng.randf_range(-r.size.x * 0.3, r.size.x * 0.3)
			var uz := _rng.randf_range(-r.size.y * 0.3, r.size.y * 0.3)
			units.append(Vector3(ux, 0, uz))
		var sniper_block := center.distance_to(Vector3(PITCH, 0, 0)) < 1.0
		_decorate(tools[m], m, pos, size, pos.y + top * 0.5, col, units, _street_normals(pos, size, center), outer, sniper_block)
		used[m] = true
		_box_collision(pos, size)
		if not outer:
			_buildings.append({"pos": pos, "size": size, "m": m, "block": center})

	var mesh := ArrayMesh.new()
	for m in tools.size():
		if not used[m]:
			continue
		tools[m].set_material(_facades[m])
		tools[m].commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


## Building typology from its height (material index = building.gdshader style).
func _pick_style(floors: int, outer: bool) -> int:
	var r := _deco.randf()
	if floors >= 12 or outer:
		return 3 if r < 0.45 else (2 if r < 0.75 else 1)
	if floors >= 6:
		return 1 if r < 0.5 else (2 if r < 0.72 else (0 if r < 0.9 else 3))
	return 0 if r < 0.45 else 1


func _tint_for(material_index: int) -> Color:
	_rng.randi_range(0, 5)   # keeps the layout rng sequence unchanged; colours use _deco
	var options: Array
	match material_index:
		0:  # brick: red, brown and buff bricks
			options = [Color(1, 1, 1), Color(0.85, 0.72, 0.66), Color(1.05, 0.95, 0.82), Color(0.75, 0.6, 0.55)]
		1:  # stucco: warm sun-bleached pastels of a coastal city
			options = [Color(1.0, 0.93, 0.8), Color(1.0, 0.8, 0.66), Color(0.98, 0.72, 0.62), Color(0.85, 0.93, 0.88),
				Color(1.0, 0.9, 0.74), Color(0.82, 0.88, 0.98), Color(1.0, 0.97, 0.92), Color(0.95, 0.7, 0.72)]
		2:  # concrete / travertine offices
			options = [Color(1.18, 1.14, 1.08), Color(1.08, 1.08, 1.1), Color(1.2, 1.1, 0.95), Color(0.98, 0.97, 0.97)]
		_:  # glass towers: tint of the coated glass
			options = [Color(0.55, 0.78, 0.85), Color(0.5, 0.62, 0.75), Color(0.75, 0.68, 0.55),
				Color(0.6, 0.75, 0.68), Color(0.7, 0.72, 0.75)]
	return options[_deco.randi_range(0, options.size() - 1)]


# ------------------------------------------------------------ facade decor

## Outward normals of the faces of a building that look onto a street.
func _street_normals(pos: Vector3, size: Vector3, block: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for face in 4:
		var n := Vector3(1, 0, 0).rotated(Vector3.UP, -face * PI * 0.5).round()
		var wall := pos + n * absf((size * 0.5).dot(n))
		if absf((wall - block).dot(n)) >= BLOCK * 0.5 - 6.0:
			out.append(n)
	return out


## Parapets, cornices, setbacks, balconies, AC units, awnings and rooftop clutter.
## Everything goes into the block's facade mesh (no extra draw calls) and has no collision.
func _decorate(st: SurfaceTool, m: int, pos: Vector3, size: Vector3, roof_y: float, col: Color,
		units: Array[Vector3], street: Array[Vector3], outer: bool, sniper_block: bool) -> void:
	var a := col.a
	var dark := Color(col.r * 0.82, col.g * 0.82, col.b * 0.82, a)
	var trim := Color(minf(col.r * 1.08, 1.2), minf(col.g * 1.08, 1.2), minf(col.b * 1.05, 1.2), a)
	if m == 3:
		trim = Color(0.75, 0.76, 0.78, a)
	elif m == 0:
		trim = Color(0.95, 0.9, 0.82, a)
	var floors := int((size.y - 4.2) / 3.3 + 0.5)
	var metal := Color(0.32, 0.32, 0.33, a)
	# Projecting cornice on brick and some stucco buildings, parapet walls on all.
	if m == 0 or (m == 1 and a > 0.5):
		_add_box(st, Vector3(pos.x, roof_y - 0.2, pos.z), Vector3(size.x + 0.5, 0.4, size.z + 0.5), trim, 1.0, 0.0)
	var ph := 0.7
	var pt := 0.3
	for n in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var along: Vector3 = n.cross(Vector3.UP).abs()
		var half_d := absf((size * 0.5).dot(n))
		var length := absf(size.dot(along))
		_add_box(st, Vector3(pos.x, roof_y + ph * 0.5, pos.z) + n * (half_d - pt * 0.5),
			along * length + n.abs() * pt + Vector3(0, ph, 0), dark if m != 3 else trim, 1.0, 0.0)
		# String course above the shops.
		if m != 3:
			_add_box(st, Vector3(pos.x, CURB_H + 4.3, pos.z) + n * (half_d + 0.06),
				along * (length + 0.24) + n.abs() * 0.12 + Vector3(0, 0.2, 0), trim, 1.0, 0.0)
	var top_y := roof_y
	# Tall buildings step back near the top (art-deco and tower crowns).
	if (m == 3 or m == 2 or (m == 1 and a > 0.6)) and floors >= 9 and minf(size.x, size.z) > 20.0:
		var tiers := 1 if m == 2 else 2
		var ts := Vector3(size.x * 0.72, 3.3 * (2 + _deco.randi_range(0, 2)), size.z * 0.72)
		for t in tiers:
			var tp := Vector3(pos.x, top_y + ts.y * 0.5, pos.z)
			_volumes.append(AABB(tp - ts * 0.5, ts))
			_add_box(st, tp, ts, col, 0.0, top_y + ts.y)
			_add_box(st, tp + Vector3(0, ts.y * 0.5 + 0.3, 0), Vector3(ts.x + 0.3, 0.6, ts.z + 0.3), trim, 1.0, 0.0)
			top_y += ts.y
			ts = Vector3(ts.x * 0.7, ts.y * 0.8, ts.z * 0.7)
		if m == 3 or _deco.randf() < 0.5:
			_add_box(st, Vector3(pos.x, top_y + 4.0, pos.z), Vector3(0.35, 8.0, 0.35), Color(0.6, 0.6, 0.62, a), 2.0, 0.0)
	# Rooftop HVAC units (positions from the layout rng, as before).
	for u in units:
		var up := Vector3(pos.x + u.x, roof_y + 0.7, pos.z + u.z)
		_add_box(st, up, Vector3(2.5, 1.4, 2.0), Color(0.85, 0.86, 0.87, a), 2.0, 0.0)
		_add_box(st, up + Vector3(0, 0.75, 0), Vector3(1.2, 0.1, 1.2), Color(0.5, 0.5, 0.5, a), 2.0, 0.0)
	var ix := size.x * 0.5 - 4.0
	var iz := size.z * 0.5 - 4.0
	if ix > 2.0 and iz > 2.0 and not sniper_block:
		# Wooden water tank on legs.
		if (m == 0 or m == 1) and floors <= 9 and _deco.randf() < 0.6:
			var tp := Vector3(pos.x + _deco.randf_range(-ix, ix), roof_y, pos.z + _deco.randf_range(-iz, iz))
			for lx in [-0.9, 0.9]:
				for lz in [-0.9, 0.9]:
					_add_box(st, tp + Vector3(lx, 1.0, lz), Vector3(0.18, 2.0, 0.18), metal, 2.0, 0.0)
			_add_cylinder(st, tp + Vector3(0, 2.0, 0), 1.5, 2.6, 10, Color(1, 1, 1, a), 5.0)
			_add_cone(st, tp + Vector3(0, 4.6, 0), 1.6, 0.9, 10, Color(0.3, 0.3, 0.32, a))
		# Antennas.
		for k in _deco.randi_range(0, 2):
			var ap := Vector3(pos.x + _deco.randf_range(-ix, ix), roof_y, pos.z + _deco.randf_range(-iz, iz))
			var ah := _deco.randf_range(2.5, 6.0)
			_add_box(st, ap + Vector3(0, ah * 0.5, 0), Vector3(0.08, ah, 0.08), metal, 2.0, 0.0)
			_add_box(st, ap + Vector3(0, ah * 0.8, 0), Vector3(1.4, 0.05, 0.05), metal, 2.0, 0.0)
		# Billboard facing a street (original made-up adverts, assets/textures/billboards.png).
		if not outer and floors <= 8 and street.size() > 0 and _deco.randf() < 0.55:
			var n: Vector3 = street[_deco.randi_range(0, street.size() - 1)]
			var along := n.cross(Vector3.UP)
			var half_d := absf((size * 0.5).dot(n))
			var bw := minf(12.0, absf(size.dot(along)) - 4.0)
			if bw > 6.0:
				var bh := bw * 0.25
				var bc := Vector3(pos.x, roof_y, pos.z) + n * (half_d - 2.5)
				var lift := 2.2
				for side in [-0.35, 0.35]:
					_add_box(st, bc + along * (bw * side) + Vector3(0, (lift + bh * 0.5) * 0.5, 0) - n * 0.6,
						Vector3(0.25, lift + bh * 0.5, 0.25), metal, 2.0, 0.0)
				var pc := bc + Vector3(0, lift + bh * 0.5, 0)
				_add_box(st, pc - n * 0.15, (along * bw).abs() + n.abs() * 0.25 + Vector3(0, bh + 0.2, 0), metal, 2.0, 0.0)
				var ad := _deco.randi_range(0, 7)
				_add_quad(st, pc, along * (bw * 0.5 - 0.1), Vector3(0, bh * 0.5, 0), n, Color(1, 1, 1, a), 4.0,
					Vector2((ad % 2) * 0.5, (ad / 2) * 0.25), Vector2(0.5, 0.25))
				_add_box(st, pc + n * 0.5 - Vector3(0, bh * 0.5 + 0.1, 0), (along * bw).abs() + n.abs() * 0.8 + Vector3(0, 0.06, 0), metal, 2.0, 0.0)
	if outer:
		return
	# Street faces: awnings over shops, balconies (stucco), AC units (brick / concrete).
	var awn_cols := [Color(0.62, 0.12, 0.1), Color(0.1, 0.35, 0.25), Color(0.12, 0.2, 0.42), Color(0.85, 0.55, 0.12), Color(0.2, 0.2, 0.22)]
	for n in street:
		var along := n.cross(Vector3.UP)
		var half_d := absf((size * 0.5).dot(n))
		var half_len := absf((size * 0.5).dot(along))
		var wall := Vector3(pos.x, 0, pos.z) + n * half_d
		var u_axis_z := absf(n.x) > 0.5
		var wall_u := wall.z if u_axis_z else wall.x
		var u_sign := along.z if u_axis_z else along.x
		var ac: Color = awn_cols[_deco.randi_range(0, awn_cols.size() - 1)]
		ac.a = a
		# Awnings over some 4.5 m shop cells (the world grid of the painted shop windows).
		var k := ceili((wall_u - half_len) / 4.5)
		while (k + 1) * 4.5 <= wall_u + half_len:
			if _deco.randf() < 0.4:
				var t := ((k + 0.5) * 4.5 - wall_u) * u_sign
				var a0 := wall + along * t + n * 0.05 + Vector3(0, CURB_H + 3.45, 0)
				var out := n * 1.4 - Vector3(0, 0.55, 0)
				var hw := along * 1.95
				var nn := out.cross(hw).normalized()
				if nn.y < 0.0:
					nn = -nn
				_add_quad(st, a0 + out * 0.5, hw, out * 0.5, nn, ac, 3.0, Vector2.ZERO, Vector2.ZERO, true)
				_add_quad(st, a0 + out - Vector3(0, 0.14, 0), hw, Vector3(0, 0.14, 0), n, ac, 3.0, Vector2.ZERO, Vector2.ZERO, true)
			k += 1
		if floors < 2:
			continue
		if m == 1 and floors <= 12:
			# Balconies in a regular rhythm from the second floor up.
			var cols := maxi(1, int((half_len * 2.0 - 2.0) / 3.8))
			var cw := (half_len * 2.0 - 2.0) / cols
			var every := 1 if a < 0.5 and floors <= 7 else 2
			var rail := metal if a > 0.3 else trim
			for c in cols:
				if c % every != 0:
					continue
				var t := -half_len + 1.0 + (c + 0.5) * cw
				var bw := minf(cw - 0.6, 3.2)
				for f in range(1, floors):
					var bc := wall + along * t + n * 0.6 + Vector3(0, CURB_H + 4.2 + (f - 1) * 3.3 + 0.08, 0)
					_add_box(st, bc, (along * bw).abs() + n.abs() * 1.2 + Vector3(0, 0.16, 0), trim, 1.0, 0.0, -n)
					# Railing: one two-sided panel (painted metal or a solid stucco parapet).
					_add_quad(st, bc + n * 0.58 + Vector3(0, 0.55, 0), along * (bw * 0.5), Vector3(0, 0.47, 0), n, rail,
						2.0 if a > 0.3 else 1.0, Vector2.ZERO, Vector2.ZERO, true)
		elif (m == 0 or m == 2) and floors <= 14:
			# Window AC units.
			for i in _deco.randi_range(2, 6 + floors / 2):
				var t := _deco.randf_range(-half_len + 1.5, half_len - 1.5)
				var f := _deco.randi_range(1, floors - 1)
				var y := CURB_H + 4.2 + f * 3.3 + 0.45
				_add_box(st, wall + along * t + n * 0.25 + Vector3(0, y, 0), (along * 0.8).abs() + n.abs() * 0.5 + Vector3(0, 0.5, 0),
					Color(0.72, 0.72, 0.7, a), 2.0, 0.0)


# ------------------------------------------------------------ street props

func _build_street_props() -> void:
	var half := BLOCK * 0.5
	var edge := half - 1.0
	for i in range(-RINGS, RINGS + 1):
		for j in range(-RINGS, RINGS + 1):
			var c := Vector3(i * PITCH, CURB_H, j * PITCH)
			for side in 4:
				# side 0: +X edge, 1: +Z, 2: -X, 3: -Z. "out" points toward the road.
				var out := Vector3(1, 0, 0).rotated(Vector3.UP, -side * PI * 0.5)
				var along := out.cross(Vector3.UP)
				var k := 0
				var t := -half + 12.0
				while t <= half - 12.0:
					var p := c + out * edge + along * t
					var yaw := atan2(-out.z, out.x)
					if k % 2 == 0:
						_palms[_rng.randi_range(0, 2)].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p))
					else:
						_lamps.append(Transform3D(Basis(Vector3.UP, yaw), p - out * 0.3))
					k += 1
					t += 11.0
			# One traffic light at each block corner, arm reaching over the road.
			for corner in 4:
				var out := Vector3(1, 0, 0).rotated(Vector3.UP, -corner * PI * 0.5)
				var along := out.cross(Vector3.UP)
				var p := c + out * edge + along * edge
				var yaw := atan2(-out.z, out.x)
				_signals.append(Transform3D(Basis(Vector3.UP, yaw), p))

	var bark := Mats.pbr_uv("palmbark", 1.0, Color(0.95, 0.9, 0.85), 0.95)
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fronds := Mats.foliage("res://assets/foliage/palm_frond.png")
	for v in 3:
		_multimesh(Props.palm(300 + v * 11, bark, fronds), _palms[v])
	var metal := Mats.plain(Color(0.16, 0.17, 0.18), 0.45, 0.6)
	var lamp_glass := Mats.plain(Color(0.9, 0.9, 0.85), 0.2)
	_multimesh(Props.street_lamp(metal, lamp_glass), _lamps, false)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.1, 0.05)
	red.emission_enabled = true
	red.emission = Color(1, 0.12, 0.05)
	red.emission_energy_multiplier = 3.0
	var off := Mats.plain(Color(0.08, 0.09, 0.08), 0.3)
	_multimesh(Props.traffic_light(metal, red, off), _signals, false)
	# Thin collision for poles and palm trunks.
	for list in [_lamps, _signals, _palms[0], _palms[1], _palms[2]]:
		for xf in list:
			var col := CollisionShape3D.new()
			var cs := CylinderShape3D.new()
			cs.radius = 0.2
			cs.height = 3.0
			col.shape = cs
			col.position = xf.origin + Vector3(0, 1.5, 0)
			_static.add_child(col)


# ------------------------------------------------------------ helpers

func _multimesh(mesh: Mesh, xfs: Array, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _box_collision(pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = pos
	_static.add_child(col)


## Adds an axis-aligned box. UV.x = part kind (0 facade with windows, 1 plain wall, 2 metal,
## 3 awning, 4 billboard, 5 water tank), UV.y = building top, UV2 = extent of the facade
## volume along each wall so window columns are centred on the face (see building.gdshader).
func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color, plain: float, top: float, skip := Vector3.ZERO) -> void:
	var h := s * 0.5
	var vol := _volume_at(c) if plain < 0.5 else AABB()
	var known := vol.size != Vector3.ZERO
	var faces := [
		[Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP],
		[Vector3.LEFT, Vector3(0, 0, 1), Vector3.UP],
		[Vector3.FORWARD, Vector3(-1, 0, 0), Vector3.UP],
		[Vector3.BACK, Vector3(1, 0, 0), Vector3.UP],
		[Vector3.UP, Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3.DOWN, Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		if n == skip:
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n * (h * n.abs()).length()
		var hu := (h * u.abs()).length()
		var hv := (h * v.abs()).length()
		var ext := Vector2(-1.0e4, 1.0e4)
		if known:
			ext = Vector2(vol.position.z, vol.end.z) if absf(n.x) > 0.5 else Vector2(vol.position.x, vol.end.x)
		var p := [o - u * hu - v * hv, o + u * hu - v * hv, o + u * hu + v * hv, o - u * hu + v * hv]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(color)
			st.set_normal(n)
			st.set_tangent(Plane(u, 1.0))   # explicit: UVs carry data, not texture coords
			st.set_uv(Vector2(plain, top))
			st.set_uv2(ext)
			st.add_vertex(p[k])


## Smallest registered facade volume containing p (zero AABB if none). Also used for the
## boxes world/interiors/carver.gd rebuilds, so carved buildings keep their window layout.
func _volume_at(p: Vector3) -> AABB:
	var best := AABB()
	var best_a := INF
	for v in _volumes:
		if v.grow(0.05).has_point(p):
			var ar := v.size.x * v.size.z
			if ar < best_a:
				best_a = ar
				best = v
	return best


## Quad centred at c spanning +-hu, +-hv, facing n. UV2 = atlas rect (billboards).
func _add_quad(st: SurfaceTool, c: Vector3, hu: Vector3, hv: Vector3, n: Vector3, color: Color, kind: float,
		uv0 := Vector2.ZERO, uv_size := Vector2.ZERO, two_sided := false) -> void:
	var p := [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
	var t := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var order := [0, 2, 1, 0, 3, 2] if hu.cross(hv).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for side in (2 if two_sided else 1):
		var nn := n if side == 0 else -n
		for k in order:
			var kk: int = k
			st.set_color(color)
			st.set_normal(nn)
			st.set_tangent(Plane(hu.normalized(), 1.0))
			st.set_uv(Vector2(kind, 0.0))
			st.set_uv2(uv0 + (t[kk] as Vector2) * uv_size)
			st.add_vertex(p[kk])
		order = [order[0], order[2], order[1], order[3], order[5], order[4]]


## Vertical cylinder side from the base centre b.
func _add_cylinder(st: SurfaceTool, b: Vector3, r: float, h: float, sides: int, color: Color, kind: float) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var up := Vector3(0, h, 0)
		var q := [b + d0 * r, b + d1 * r, b + d1 * r + up, b + d0 * r + up]
		var dn := (d0 + d1).normalized()
		var order := [0, 2, 1, 0, 3, 2] if (d1 - d0).cross(up).dot(dn) > 0.0 else [0, 1, 2, 0, 2, 3]
		for k in order:
			var kk: int = k
			st.set_color(color)
			st.set_normal(d0 if kk == 0 or kk == 3 else d1)
			st.set_tangent(Plane(dn.cross(Vector3.UP), 1.0))
			st.set_uv(Vector2(kind, 0.0))
			st.set_uv2(Vector2(-1.0e4, 1.0e4))
			st.add_vertex(q[kk])


## Cone roof (metal) from the base centre b.
func _add_cone(st: SurfaceTool, b: Vector3, r: float, h: float, sides: int, color: Color) -> void:
	var tip := b + Vector3(0, h, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := b + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := b + Vector3(cos(a1), 0, sin(a1)) * r
		var nn := (p1 - p0).cross(tip - p0).normalized()
		if nn.y < 0.0:
			nn = -nn
		# Same winding rule as the boxes: (b - a) x (c - a) points along -n for a front face.
		var tri := [p0, p1, tip] if (p1 - p0).cross(tip - p0).dot(nn) < 0.0 else [p0, tip, p1]
		for q in tri:
			st.set_color(color)
			st.set_normal(nn)
			st.set_tangent(Plane(Vector3.RIGHT, 1.0))
			st.set_uv(Vector2(2.0, 0.0))
			st.set_uv2(Vector2(-1.0e4, 1.0e4))
			st.add_vertex(q)

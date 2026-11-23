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


func _ready() -> void:
	_rng.seed = 20261123
	_build_environment()
	_build_ground()
	_static = StaticBody3D.new()
	_static.name = "Static"
	add_child(_static)
	for m in ["brick", "stucco", "panels"]:
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://world/building.gdshader")
		sm.set_shader_parameter("wall_albedo", load("res://assets/textures/%s_albedo.jpg" % m))
		sm.set_shader_parameter("wall_normal", load("res://assets/textures/%s_normal.jpg" % m))
		sm.set_shader_parameter("wall_tile", 2.5 if m == "brick" else 3.5)
		sm.set_shader_parameter("brightness", {"brick": 1.0, "stucco": 0.72, "panels": 0.85}[m])
		_facades.append(sm)

	_build_sidewalks()
	for i in range(-RINGS - 1, RINGS + 2):
		for j in range(-RINGS - 1, RINGS + 2):
			var outer := absi(i) > RINGS or absi(j) > RINGS
			if i == 0 and j == 0:
				continue
			_build_block(Vector3(i * PITCH, 0, j * PITCH), outer)
	_build_street_props()
	preload("res://world/street_dressing.gd").new().dress(self, _buildings, _rng)
	add_child(preload("res://world/street_life.gd").new())   # street trees, hydrants, bus stops

	var park := preload("res://world/park.gd").new()
	add_child(park)
	grass = preload("res://world/grass_field.gd").new()
	add_child(grass)
	Settings.changed.connect(_on_setting)
	_apply_shadows()


func set_follow(n: Node3D) -> void:
	grass.follow = n


func _on_setting(key: String) -> void:
	if key in ["shadows", "battery_saver"]:
		_apply_shadows()


func _apply_shadows() -> void:
	sun.shadow_enabled = Perf.shadows_enabled()


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
	mi.material_override = Mats.pbr("pavers", 2.0, Color(0.92, 0.92, 0.92))
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
		var m := _rng.randi_range(0, _facades.size() - 1)
		var tint := _tint_for(m)
		var bseed := _rng.randf()
		var pos := center + Vector3(r.position.x + r.size.x * 0.5, CURB_H + top * 0.5, r.position.y + r.size.y * 0.5)
		var size := Vector3(r.size.x, top, r.size.y)
		var col := Color(tint.r, tint.g, tint.b, bseed)
		_add_box(tools[m], pos, size, col, 0.0, CURB_H + top)
		# Cornice and rooftop units (plain, no windows).
		var dark := Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.8, bseed)
		_add_box(tools[m], pos + Vector3(0, top * 0.5 + 0.25, 0), Vector3(size.x + 0.5, 0.5, size.z + 0.5), dark, 1.0, 0.0)
		for u in _rng.randi_range(1, 3):
			var ux := _rng.randf_range(-r.size.x * 0.3, r.size.x * 0.3)
			var uz := _rng.randf_range(-r.size.y * 0.3, r.size.y * 0.3)
			_add_box(tools[m], pos + Vector3(ux, top * 0.5 + 1.2, uz), Vector3(2.5, 1.4, 2.0), Color(0.6, 0.6, 0.6, bseed), 1.0, 0.0)
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


func _tint_for(material_index: int) -> Color:
	var options: Array
	match material_index:
		0:  # brick
			options = [Color(1, 1, 1), Color(0.85, 0.75, 0.7), Color(1.0, 0.92, 0.85)]
		1:  # stucco: warm sunny-city colours
			options = [Color(1.0, 0.95, 0.85), Color(1.0, 0.85, 0.7), Color(0.95, 0.9, 1.0),
				Color(0.85, 0.95, 0.9), Color(1.0, 0.8, 0.75), Color(1, 1, 1)]
		_:  # concrete panels
			options = [Color(1, 1, 1), Color(0.85, 0.88, 0.95), Color(0.95, 0.93, 0.88)]
	return options[_rng.randi_range(0, options.size() - 1)]


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


## Adds an axis-aligned box. UV.x = plain flag, UV.y = building top (see building.gdshader).
func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color, plain: float, top: float) -> void:
	var h := s * 0.5
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
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n * (h * n.abs()).length()
		var hu := (h * u.abs()).length()
		var hv := (h * v.abs()).length()
		var p := [o - u * hu - v * hv, o + u * hu - v * hv, o + u * hu + v * hv, o - u * hu + v * hv]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(color)
			st.set_normal(n)
			st.set_tangent(Plane(u, 1.0))   # explicit: UVs carry data, not texture coords
			st.set_uv(Vector2(plain, top))
			st.add_vertex(p[k])

extends Node
## Pooled visual effects: blood spray, blood pools under bodies, bullet sparks and
## muzzle flashes. CPU particles so they work on every renderer (phone and browser).
## Blood can be switched off in the settings.

const BURSTS := 8
const POOLS := 10

var _blood: Array[CPUParticles3D] = []
var _sparks: Array[CPUParticles3D] = []
var _pools: Array[MeshInstance3D] = []
var _bi := 0
var _si := 0
var _pi := 0
var _pool_mat: StandardMaterial3D
var _growing: Array = []    # [mesh, target_scale, time]


func _ready() -> void:
	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.45, 0.02, 0.02)
	blood_mat.roughness = 0.35
	var drop := SphereMesh.new()
	drop.radius = 0.025
	drop.height = 0.05
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = blood_mat
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.8, 0.4)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.015, 0.015, 0.06)
	spark.material = spark_mat
	for i in BURSTS:
		_blood.append(_make_burst(drop, 28, 0.7, Color(1, 1, 1)))
		_sparks.append(_make_burst(spark, 10, 0.25, Color(1, 1, 1)))

	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_texture = _make_splat_texture()
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.albedo_color = Color(0.42, 0.02, 0.02)
	_pool_mat.roughness = 0.15
	_pool_mat.metallic_specular = 0.8
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.material = _pool_mat
	for i in POOLS:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		_pools.append(mi)


func _make_burst(mesh: Mesh, amount: int, life: float, _c: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.mesh = mesh
	p.direction = Vector3(0, 0, -1)
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.top_level = true
	add_child(p)
	return p


func _make_splat_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var blobs := []
	for i in 9:
		blobs.append([Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7)) * s, rng.randf_range(0.12, 0.3) * s])
	for y in s:
		for x in s:
			var a := 0.0
			for b in blobs:
				var d: float = Vector2(x, y).distance_to(b[0]) / b[1]
				a = maxf(a, clampf(1.4 - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.15, 0.5, a)))
	return ImageTexture.create_from_image(img)


func blood_enabled() -> bool:
	return bool(Settings.get_value("blood"))


## Blood spray from a hit, flying along dir.
func blood(pos: Vector3, dir: Vector3) -> void:
	if not blood_enabled():
		return
	var p := _blood[_bi]
	_bi = (_bi + 1) % BURSTS
	_aim(p, pos, dir)
	p.restart()


func sparks(pos: Vector3, normal: Vector3) -> void:
	var p := _sparks[_si]
	_si = (_si + 1) % BURSTS
	_aim(p, pos, normal)
	p.restart()


## A pool of blood that spreads on the ground under a body.
func blood_pool(pos: Vector3) -> void:
	if not blood_enabled():
		return
	var mi := _pools[_pi]
	_pi = (_pi + 1) % POOLS
	mi.global_position = pos + Vector3(0, 0.02, 0)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * 0.1
	mi.visible = true
	_growing.append([mi, randf_range(0.9, 1.4), 0.0])


func clear_pool_near(pos: Vector3) -> void:
	for mi in _pools:
		if mi.visible and mi.global_position.distance_to(pos) < 1.2:
			mi.visible = false


func _process(delta: float) -> void:
	for g in _growing:
		g[2] += delta
		var k := clampf(g[2] / 4.0, 0.0, 1.0)
		(g[0] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.1, g[1], 1.0 - pow(1.0 - k, 2.0))
	_growing = _growing.filter(func(g): return g[2] < 4.0)


func _aim(p: CPUParticles3D, pos: Vector3, dir: Vector3) -> void:
	p.global_position = pos
	if dir.length() < 0.01:
		dir = Vector3.UP
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	p.global_basis = Basis.looking_at(d, up)

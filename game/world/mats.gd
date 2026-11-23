class_name Mats
## Shared PBR materials (one instance per kind keeps draw calls and memory low).
## Textures: Poly Haven (CC0). World-triplanar mapping so boxes of any size look right.

static var _cache := {}


static func pbr(name: String, world_scale := 1.0, tint := Color.WHITE, roughness := 0.9) -> StandardMaterial3D:
	var key := "%s_%.2f_%s" % [name, world_scale, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s_albedo.jpg" % name)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s_normal.jpg" % name)
	m.roughness = roughness
	var rough_path := "res://assets/textures/%s_rough.jpg" % name
	if ResourceLoader.exists(rough_path):
		m.roughness_texture = load(rough_path)
		m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / world_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


## Same as pbr() but using the mesh's own UVs (for characters and props).
static func pbr_uv(name: String, uv_scale := 1.0, tint := Color.WHITE, roughness := 0.9, albedo_name := "") -> StandardMaterial3D:
	var key := "uv_%s_%s_%.2f_%s" % [name, albedo_name, uv_scale, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var alb := albedo_name if albedo_name != "" else name
	m.albedo_texture = load("res://assets/textures/%s_albedo.jpg" % alb)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s_normal.jpg" % name)
	m.roughness = roughness
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	_cache[key] = m
	return m


static func plain(c: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var key := "plain_%s_%.2f_%.2f" % [c.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


static func foliage(tex_path: String) -> ShaderMaterial:
	if _cache.has(tex_path):
		return _cache[tex_path]
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/foliage.gdshader")
	m.set_shader_parameter("tex", load(tex_path))
	_cache[tex_path] = m
	return m

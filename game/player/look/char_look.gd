extends RefCounted
## Runtime character shading. Swaps the StandardMaterial3D surfaces of a character model
## (MakeHuman glb from tools/chargen) for the custom shaders in this folder, matching by
## material name so regenerated models keep working:
##   *skin* / *body*                 -> char_skin.gdshader  (wrap-lit skin, two-lobe spec, rim)
##   *eye* (not brow / lash)         -> char_eye.gdshader   (wet cornea, catchlight)
##   *hair* (not chair)              -> char_hair.gdshader  (strand highlight, fuzzy edge)
##   *lash*                          -> same material, darker and matte
##   cloth / shirt / pants / bag ... -> char_cloth.gdshader (fabric sheen)
## Anything else (brows, shoes, soles, glasses, unknown) keeps its own material.
## The converted materials are cached per source material, so all instances of a model share
## them (same draw calls / batching as before). Cost scales with the quality preset:
## low = no micro normal, single specular lobe, no fuzzy hair edge.

const SKIN := preload("res://player/look/char_skin.gdshader")
const EYE := preload("res://player/look/char_eye.gdshader")
const HAIR := preload("res://player/look/char_hair.gdshader")
const CLOTH := preload("res://player/look/char_cloth.gdshader")

const CLOTH_WORDS := ["cloth", "shirt", "pant", "jean", "top", "dress", "jacket", "hood",
	"fabric", "knit", "bag", "coat", "skirt", "short", "trouser", "sweater", "vest", "cap"]

static var _cache := {}          # "<tier>:<material instance id>" -> Material (or null)
static var _shaders := {}        # variant key -> Shader
static var _quality_node: Node = null
static var enabled := true
## Overrides the preset tier ("low" / "medium" / "high"); empty = follow core/quality.gd.
static var force_tier := ""


## Applies the character shaders to every mesh under `root`.
static func apply(root: Node) -> void:
	if not enabled or root == null:
		return
	var tier := _tier(root)
	for g in root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var sm := _convert(src, tier)
			if sm != null:
				mi.set_surface_override_material(i, sm)


## "low" / "medium" / "high" as resolved by core/quality.gd (medium if unknown).
static func _tier(from: Node) -> String:
	if force_tier != "":
		return force_tier
	if _quality_node == null or not is_instance_valid(_quality_node):
		_quality_node = null
		var tree := from.get_tree() if from.is_inside_tree() else (Engine.get_main_loop() as SceneTree)
		if tree and tree.root:
			_quality_node = tree.root.find_child("Quality", true, false)
	if _quality_node and "effective" in _quality_node:
		var e := str(_quality_node.get("effective"))
		if e in ["low", "medium", "high"]:
			return e
	return "medium"


static func kind_of(mat_name: String) -> String:
	var n := mat_name.to_lower()
	if n.contains("lash"):
		return "lash"
	if n.contains("brow"):
		return ""
	if n.contains("skin") or n.contains("body"):
		return "skin"
	if n.contains("eye"):
		return "eye"
	if n.contains("hair") and not n.contains("chair"):
		return "hair"
	for w in CLOTH_WORDS:
		if n.contains(w):
			return "cloth"
	return ""


static func _convert(src: Material, tier: String) -> Material:
	var bm := src as BaseMaterial3D
	if bm == null:
		return null
	var key := "%s:%d" % [tier, bm.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	var kind := kind_of(bm.resource_name)
	var sm: ShaderMaterial = null
	match kind:
		"skin":
			sm = ShaderMaterial.new()
			sm.shader = SKIN
			_common(sm, bm)
			sm.set_shader_parameter("roughness_base", clampf(bm.roughness, 0.35, 0.7))
			# The pore map is strong at a distance: keep the face smooth, let the light do the shape.
			sm.set_shader_parameter("normal_depth", (bm.normal_scale if bm.normal_enabled else 0.0) * 0.6)
			sm.set_shader_parameter("micro_strength", 0.45 if tier == "high" else 0.0)
			sm.set_shader_parameter("two_lobes", 0.0 if tier == "low" else 1.0)
		"eye":
			sm = ShaderMaterial.new()
			sm.shader = EYE
			sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
			sm.set_shader_parameter("albedo_color", bm.albedo_color)
		"hair":
			sm = ShaderMaterial.new()
			sm.shader = _variant(HAIR, bm.cull_mode, tier == "low")
			_common(sm, bm)
			sm.set_shader_parameter("normal_depth", bm.normal_scale if bm.normal_enabled else 0.0)
		"lash":
			# Lashes: darker and matte, so the lash strips stop catching the blue sky.
			var lm := bm.duplicate() as BaseMaterial3D
			lm.albedo_color = bm.albedo_color.darkened(0.45)
			lm.roughness = 1.0
			lm.metallic_specular = 0.1
			_cache[key] = lm
			return lm
		"cloth":
			sm = ShaderMaterial.new()
			sm.shader = _variant(CLOTH, bm.cull_mode, false)
			_common(sm, bm)
			sm.set_shader_parameter("uv_scale", Vector2(bm.uv1_scale.x, bm.uv1_scale.y))
			sm.set_shader_parameter("roughness_base", bm.roughness)
			sm.set_shader_parameter("has_normal", 1.0 if (bm.normal_enabled and bm.normal_texture) else 0.0)
			# Denim / dark cloth gets less sheen than light cotton.
			sm.set_shader_parameter("sheen", 0.35 if tier == "low" else 0.45)
	if sm != null:
		sm.resource_name = bm.resource_name + "_look"
		sm.render_priority = bm.render_priority
	_cache[key] = sm
	return sm


static func _common(sm: ShaderMaterial, bm: BaseMaterial3D) -> void:
	sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
	sm.set_shader_parameter("albedo_color", bm.albedo_color)
	if bm.normal_enabled and bm.normal_texture:
		sm.set_shader_parameter("normal_tex", bm.normal_texture)
		sm.set_shader_parameter("normal_depth", bm.normal_scale)
	else:
		sm.set_shader_parameter("normal_depth", 0.0)


## Same shader code with a different cull mode (double-sided source materials) and, for the
## hair on the low preset, without the dithered silhouette.
static func _variant(base: Shader, cull: int, plain: bool) -> Shader:
	var double := cull == BaseMaterial3D.CULL_DISABLED
	var key := "%s|%s|%s" % [base.resource_path, double, plain]
	if _shaders.has(key):
		return _shaders[key]
	var code := base.code
	var is_default := (code.contains("cull_disabled") == double) and not (plain and code.contains("#define FUZZY"))
	if is_default:
		_shaders[key] = base
		return base
	if double:
		code = code.replace("cull_back", "cull_disabled")
	else:
		code = code.replace("cull_disabled", "cull_back")
	if plain:
		code = code.replace("#define FUZZY", "")
	var s := Shader.new()
	s.code = code
	_shaders[key] = s
	return s

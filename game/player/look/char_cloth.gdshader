shader_type spatial;
// Clothing: the generator's colour + weave normal, plus fabric sheen (a soft, light-tinted rim
// that real cotton / denim shows at grazing angles), weave cavities slightly darker and a
// little roughness variation so the folds do not look like plastic.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float normal_depth = 1.0;
uniform float sheen = 0.45;
uniform float has_normal = 1.0;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec4 a = texture(albedo_tex, uv) * albedo_color;
	// Real white cotton reflects ~65 %, not ~90 %: compress near-white albedo so white
	// shirts, zips and hoodie strings stop glowing in the low sun.
	float am = max(a.r, max(a.g, a.b));
	if (am > 0.45) {
		a.rgb *= (0.45 + (am - 0.45) * 0.45) / am;
	}
	vec3 n = has_normal > 0.5 ? texture(normal_tex, uv).xyz : vec3(0.5, 0.5, 1.0);
	float cav = clamp(1.0 - (abs(n.x - 0.5) + abs(n.y - 0.5)) * 0.6, 0.75, 1.0);
	ALBEDO = a.rgb * cav;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(roughness_base + (1.0 - cav) * 0.2, 0.0, 1.0);
	SPECULAR = 0.4;
	// The engine's rim falloff exponent is (1 - roughness) * 16: at the generator's
	// roughness 1.0 it is 0 and the "rim" covered the whole garment as a flat glow
	// (light cloth looked emissive in the sun). Shape the sheen to grazing angles here.
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	RIM = sheen * (1.0 - ndv) * (1.0 - ndv);
	RIM_TINT = 0.55;
	BACKLIGHT = a.rgb * 0.12;
	// Hemispherical occlusion (sky light from above): the undersides of sleeves, the
	// lower torso and the folds turned to the ground darken, so the clothes keep their
	// volume in the shade instead of reading as one flat colour.
	float wy = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	AO = mix(0.5, 1.0, smoothstep(-0.8, 0.6, wy)) * cav;
	AO_LIGHT_AFFECT = 0.0;
}

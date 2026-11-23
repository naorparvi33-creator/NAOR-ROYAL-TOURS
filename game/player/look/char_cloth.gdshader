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
	vec3 n = has_normal > 0.5 ? texture(normal_tex, uv).xyz : vec3(0.5, 0.5, 1.0);
	float cav = clamp(1.0 - (abs(n.x - 0.5) + abs(n.y - 0.5)) * 0.6, 0.75, 1.0);
	ALBEDO = a.rgb * cav;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(roughness_base + (1.0 - cav) * 0.2, 0.0, 1.0);
	SPECULAR = 0.4;
	RIM = sheen;
	RIM_TINT = 0.55;
	BACKLIGHT = a.rgb * 0.12;
}

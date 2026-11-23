shader_type spatial;
// Character hair (shell + strand-tip fins, see tools/chargen): alpha-tested strand tips,
// a soft sheen and a little light passing through the thin ends. Replaces the imported
// StandardMaterial3D (human_model.gd), whose alpha scissor variant loses the sky ambient
// light in the Mobile renderer.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 0.6;
uniform float roughness = 0.5;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * albedo.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
	BACKLIGHT = ALBEDO * 0.25;
}

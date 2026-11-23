shader_type spatial;
// Tree foliage cards: alpha-tested needles, soft wrap lighting, light passing
// through the needles, and a gentle sway that grows toward the top of the tree.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 0.9 + origin.x * 0.13 + origin.z * 0.11);
	VERTEX.xz += vec2(0.06, 0.04) * sway * max(VERTEX.y - 2.0, 0.0) * 0.08;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * tint;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.2, 0.25, 0.1);
}

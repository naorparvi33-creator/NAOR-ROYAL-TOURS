shader_type spatial;
// Character skin (player/look/char_look.gd swaps it in for the "skin" material of the
// MakeHuman models at runtime). Works on Mobile and Compatibility: no SSS / SSAO needed.
//  * pre-integrated-style wrap lighting: red light bleeds further past the terminator and
//    shadow penumbras turn warm, which reads as subsurface scattering;
//  * two-lobe GGX specular (broad + a tight oily lobe), stronger on the lips;
//  * roughness varies with the pore normal map, stubble and lips;
//  * a backlit rim that makes the silhouette glow when the sun is behind the person;
//  * optional micro-detail normal (same pore map at 7x) on the high preset.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.5;
uniform float normal_depth = 1.0;
uniform float micro_strength = 0.0;
uniform float sss_wrap : hint_range(0.0, 1.0) = 0.4;
uniform float rim_strength = 0.35;
uniform float spec_strength = 0.8;
uniform float two_lobes = 1.0;

varying float v_gloss;     // 0 = normal skin, 1 = lips (wetter, more specular)

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	vec3 n = texture(normal_tex, UV).xyz;
	float pore = n.x + n.y - 1.0;               // signed pore cavity (-.. +)
	if (micro_strength > 0.0) {
		vec3 m = texture(normal_tex, UV * 7.3).xyz;
		n.xy += (m.xy - 0.5) * micro_strength;
	}
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth;

	// Lips: much redder than the surrounding skin (g / r ratio drops).
	float gr = a.g / max(a.r, 0.02);
	float lips = smoothstep(0.6, 0.48, gr) * smoothstep(0.05, 0.15, a.r);
	// Stubble / brows: darker than the skin tone -> drier, rougher.
	float lum = dot(a.rgb, vec3(0.3, 0.59, 0.11));
	float hairy = smoothstep(0.16, 0.06, lum);
	v_gloss = lips;

	// Slight colour richness: skin albedo tends to look grey after sRGB -> linear on phones.
	vec3 c = a.rgb;
	c = mix(vec3(lum), c, 1.04);
	ALBEDO = c;
	ROUGHNESS = clamp(roughness_base + pore * 0.15 - lips * 0.15 + hairy * 0.2, 0.3, 0.9);
	SPECULAR = mix(0.35, 0.55, lips);
	METALLIC = 0.0;
}

float d_ggx(float ndh, float r) {
	float a = r * r;
	float a2 = a * a;
	float d = ndh * ndh * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d + 1e-5);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ndv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
	// Wrap per channel: red wraps furthest.
	vec3 w = sss_wrap * vec3(1.0, 0.55, 0.4);
	vec3 diff = clamp((vec3(ndl) + w) / (1.0 + w), 0.0, 1.0);
	diff *= diff * (3.0 - 2.0 * diff) * 0.35 + 0.65;   // a softer, rounder falloff
	// Warm penumbra: soften the shadow edge more in red than in blue.
	vec3 att = vec3(ATTENUATION);
	vec3 att_c = pow(att, mix(vec3(1.0), vec3(0.6, 0.85, 0.95), sss_wrap * 1.5));
	DIFFUSE_LIGHT += LIGHT_COLOR * diff * att_c / PI;

	// Rim: grazing view, sun from behind or the side.
	float back = clamp(dot(-VIEW, LIGHT) * 0.6 + 0.4, 0.0, 1.0);
	float rim = pow(1.0 - ndv, 4.0) * back * rim_strength;
	DIFFUSE_LIGHT += LIGHT_COLOR * att * rim * vec3(1.0, 0.85, 0.75) / PI;

	// Specular (Schlick fresnel, GGX, Smith-like visibility).
	float nl = max(ndl, 0.0);
	if (nl > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = max(dot(NORMAL, h), 0.0);
		float r = ROUGHNESS;
		float d = d_ggx(ndh, r);
		d = mix(d, d_ggx(ndh, r * 0.7), 0.07 * two_lobes + v_gloss * 0.2);
		float k = r * r * 0.5;
		float vis = 0.25 / ((nl * (1.0 - k) + k) * (ndv * (1.0 - k) + k));
		float f = 0.028 + 0.972 * pow(1.0 - max(dot(LIGHT, h), 0.0), 5.0);
		SPECULAR_LIGHT += LIGHT_COLOR * att * nl * d * vis * f * spec_strength * (1.0 + v_gloss);
	}
}

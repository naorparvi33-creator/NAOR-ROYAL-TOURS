shader_type spatial;
// Hair shell: Kajiya-Kay style two-lobe highlight along the strands (the strand texture runs
// along V, so BINORMAL follows the hair), darker roots, a wrap-diffuse that lets light pass
// through, and (FUZZY) a dithered (discard) silhouette so the outline breaks into
// strands. It is a dithered discard in the opaque pass, so there is no sorting.
#define FUZZY
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform float normal_depth = 0.8;
uniform float spec_strength = 1.0;
uniform float fuzz = 1.0;

varying vec3 v_strand;
varying float v_shift;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 base = albedo_color.rgb * t.rgb;
	// Roots (near the crown / parting, small V) a little darker, ends a little lighter.
	float along = clamp(UV.y * 0.8, 0.0, 1.0);
	base *= mix(0.86, 1.04, smoothstep(0.0, 0.8, along));
	ALBEDO = base;
	NORMAL_MAP = texture(normal_tex, UV).xyz;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = 0.5;
	SPECULAR = 0.3;
	v_strand = normalize(BINORMAL);
	v_shift = (t.r - 0.75) * 0.6;
#ifdef FUZZY
	// Silhouette breaks into strands: the darker strand gaps are cut away at grazing angles.
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float cut = edge * edge * edge * fuzz * (1.35 - t.r) * 1.6;
	// Interleaved gradient noise as a per-pixel threshold = ordered dithering (opaque pass,
	// plain discard: works the same on Mobile and Compatibility).
	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (1.0 - cut < 0.15 + ign * 0.7) {
		discard;
	}
#endif
}

float kk(vec3 t, vec3 h, float e) {
	float th = dot(t, h);
	return pow(sqrt(max(1.0 - th * th, 0.0)), e);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp((ndl + 0.4) / 1.4, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diff / PI;
	vec3 h = normalize(LIGHT + VIEW);
	vec3 t1 = normalize(v_strand + NORMAL * (v_shift - 0.12));
	vec3 t2 = normalize(v_strand + NORMAL * (v_shift + 0.18));
	float s = kk(t1, h, 120.0) * 0.07;
	vec3 sc = vec3(s) + kk(t2, h, 28.0) * 0.06 * (ALBEDO * 1.5 + 0.1);
	sc *= smoothstep(-0.2, 0.35, ndl);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * sc * spec_strength;
}

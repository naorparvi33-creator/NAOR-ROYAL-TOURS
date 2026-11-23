shader_type spatial;
// Wet eyes: soft diffuse on the iris / sclera, a very tight specular from real lights and a
// small catchlight on the cornea so the eyes look alive even
// in shade. The sclera is toned down a little so it never glows paper-white.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float catchlight = 0.55;

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	vec3 c = a.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	// Sclera (bright, unsaturated) a touch darker and warmer.
	float sclera = smoothstep(0.45, 0.75, lum) * (1.0 - smoothstep(0.08, 0.2, max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))));
	c *= mix(1.0, 0.82, sclera);
	c = mix(c, c * vec3(1.0, 0.95, 0.9), sclera);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	// Catchlight: a small soft reflection on the cornea at the edge of the pupil (the eye
	// texture has the iris centred in UV space), plus a view-dependent glint.
	float dsp = length(UV - vec2(0.44, 0.43));
	float spot = smoothstep(0.04, 0.018, dsp);
	vec3 r = reflect(-VIEW, NORMAL);
	float s = max(dot(r, normalize(vec3(-0.2, 0.3, 1.0))), 0.0);
	spot += pow(s, 60.0) * 0.6;
	EMISSION = vec3(spot * catchlight);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + 0.3) / 1.3, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float ndh = max(dot(NORMAL, h), 0.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * pow(ndh, 600.0) * 3.0 * step(0.0, ndl);
}

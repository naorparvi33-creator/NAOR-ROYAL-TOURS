shader_type spatial;
// Fountain pool water: wind / jet ripples as animated normals, a fresnel blend from
// the stone floor colour (looking down) to a sky reflection tint (grazing view),
// and sharp sun glints. Opaque on purpose: no screen texture (Mobile / Web safe).
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 deep : source_color = vec3(0.12, 0.26, 0.27);
uniform vec3 shallow : source_color = vec3(0.24, 0.4, 0.38);
uniform vec3 sky : source_color = vec3(0.62, 0.76, 0.9);

float wave(vec2 p, vec2 d, float f, float s) {
	return sin(dot(p, d) * f + TIME * s);
}

void fragment() {
	vec2 p = UV;
	float r = UV2.y;                              // 0 at the centre, 1 at the edge
	// Rings spreading from where the falling water lands + a light chop.
	float ring_r = UV2.x > 0.25 ? 1.0 : 0.6;
	float rings = sin((r * 26.0 - TIME * 5.0)) * smoothstep(0.0, 0.15, abs(r - ring_r * 0.5)) * 0.5;
	vec2 g = vec2(
		wave(p, vec2(0.8, 0.6), 6.0, 2.1) + wave(p, vec2(-0.3, 0.95), 9.0, 2.9) * 0.6,
		wave(p, vec2(0.2, -0.98), 7.0, 2.4) + wave(p, vec2(0.9, -0.4), 11.0, 3.3) * 0.5);
	vec2 radial = normalize(p + 1e-4) * rings;
	vec3 n = normalize(vec3((g * 0.06 + radial * 0.12), 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 body = mix(shallow, deep, smoothstep(0.0, 1.0, 1.0 - r * 0.6));
	ALBEDO = mix(body, sky, fres * 0.45) * 0.8;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}

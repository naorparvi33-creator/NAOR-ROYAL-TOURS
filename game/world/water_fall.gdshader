shader_type spatial;
// Falling / rising water sheets: streaks scrolling along UV.y, mostly transparent,
// brighter where they catch the sun. Alpha-blended, no depth write.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float col_id = floor(uv.x * 14.0);
	float speed = 1.4 + h21(vec2(col_id, 3.0)) * 0.8;
	float v = fract(uv.y * 2.0 - TIME * speed + h21(vec2(col_id, 7.0)));
	float streak = smoothstep(0.0, 0.25, v) * smoothstep(1.0, 0.55, v);
	float thin = smoothstep(0.5, 0.0, abs(fract(uv.x * 14.0) - 0.5) - 0.1);
	float a = streak * mix(0.35, 0.8, thin);
	a *= smoothstep(0.0, 0.08, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y) * 0.6);
	ALBEDO = vec3(0.85, 0.92, 0.95);
	ALPHA = clamp(a * 0.5, 0.0, 1.0);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
	EMISSION = vec3(0.08, 0.1, 0.11) * a;
}

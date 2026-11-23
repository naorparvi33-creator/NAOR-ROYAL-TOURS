// Shared by the ground and the grass so grass never grows on dirt patches.

float tn_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float tn_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = tn_hash(i);
	float b = tn_hash(i + vec2(1.0, 0.0));
	float c = tn_hash(i + vec2(0.0, 1.0));
	float d = tn_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float tn_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * tn_noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

// 0 = grass, 1 = bare dirt.
float tn_dirt_mask(vec2 world_xz) {
	float n = tn_fbm(world_xz * 0.045);
	// Worn path along the training course (z = -40..20 near x = 0).
	float path = 1.0 - smoothstep(1.2, 2.6, abs(world_xz.x - 2.0 + sin(world_xz.y * 0.08) * 3.0));
	path *= step(-45.0, world_xz.y) * step(world_xz.y, 25.0);
	return clamp(smoothstep(0.58, 0.7, n) + path * 0.9, 0.0, 1.0);
}

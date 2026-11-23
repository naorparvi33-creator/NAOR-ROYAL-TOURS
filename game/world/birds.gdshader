shader_type spatial;
// Gulls: each instance flies a wobbly loop around its flock centre (instance origin).
// INSTANCE_CUSTOM = (loop phase, loop radius, angular speed, flap phase).
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

varying vec3 tint;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float a = cd.x + TIME * cd.y * 0.0 + TIME * cd.z;
	float r = cd.y * (1.0 + 0.25 * sin(a * 2.0 + cd.w));
	vec3 off = vec3(cos(a) * r, sin(a * 1.7 + cd.w) * 2.5, sin(a) * r * 0.75);
	// Forward = derivative of the loop.
	vec3 fwd = normalize(vec3(-sin(a) * r, 0.0, cos(a) * r * 0.75));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 up = cross(fwd, right);
	// Bank into the turn.
	float bank = -0.35;
	vec3 r2 = right * cos(bank) + up * sin(bank);
	vec3 u2 = cross(fwd, r2);
	// Flap in bursts, glide in between.
	float burst = smoothstep(-0.2, 0.6, sin(TIME * 0.6 + cd.w * 3.0));
	float flap = sin(TIME * 9.0 + cd.w) * burst;
	vec3 v = VERTEX;
	float w = UV.x;
	v.y += (flap * 0.32 + 0.06) * w * (0.6 + 0.4 * w);
	vec3 local = r2 * v.x + u2 * v.y + fwd * v.z;
	VERTEX = (local * 1.8 + off);
	NORMAL = u2;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
	BACKLIGHT = tint * 0.5;
}

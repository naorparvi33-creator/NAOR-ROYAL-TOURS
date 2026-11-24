shader_type canvas_item;
render_mode unshaded, blend_add;
// Sun glare while the sun is on screen and not hidden by a building: a warm bloom
// around the sun, a thin anamorphic streak and a few faint ghosts mirrored through
// the centre of the frame. The node is hidden while `intensity` is ~0.

uniform vec2 sun_uv = vec2(0.5);
uniform float intensity = 0.0;
uniform float aspect = 2.0;
uniform vec3 tint : source_color = vec3(1.0, 0.75, 0.45);

float ghost(vec2 uv, vec2 c, float r) {
	vec2 d = uv - c;
	d.x *= aspect;
	float l = length(d);
	return smoothstep(r, r * 0.55, l) * (0.6 + 0.4 * smoothstep(r * 0.4, r, l));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - sun_uv;
	d.x *= aspect;
	float l = length(d);
	vec3 col = tint * (exp(-l * 9.0) * 0.55 + exp(-l * 3.0) * 0.14);
	// Anamorphic streak.
	col += vec3(1.0, 0.82, 0.62) * exp(-abs(d.y) * 160.0) * exp(-abs(d.x) * 1.6) * 0.3;
	// Ghosts along the line through the centre.
	vec2 axis = vec2(0.5) - sun_uv;
	col += vec3(0.55, 0.75, 1.0) * ghost(uv, sun_uv + axis * 1.4, 0.035) * 0.05;
	col += vec3(1.0, 0.6, 0.35) * ghost(uv, sun_uv + axis * 1.75, 0.07) * 0.035;
	col += vec3(0.6, 1.0, 0.7) * ghost(uv, sun_uv + axis * 2.2, 0.025) * 0.06;
	col += vec3(0.8, 0.6, 1.0) * ghost(uv, sun_uv + axis * 0.6, 0.02) * 0.05;
	COLOR = vec4(col * intensity, 1.0);
}

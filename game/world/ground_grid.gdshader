shader_type spatial;
// Cheap procedural ground: soft grass tint with 1 m and 10 m grid lines,
// computed from world position (no textures, works on any size).
render_mode diffuse_lambert, specular_disabled;

uniform vec3 grass_a : source_color = vec3(0.33, 0.45, 0.24);
uniform vec3 grass_b : source_color = vec3(0.29, 0.40, 0.21);
uniform vec3 line_color : source_color = vec3(0.22, 0.30, 0.17);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float cell, float width) {
	vec2 g = abs(fract(p / cell - 0.5) - 0.5) * cell;
	vec2 fw = fwidth(p) * 0.75;
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 c = floor(p / 10.0);
	float checker = mod(c.x + c.y, 2.0);
	vec3 col = mix(grass_a, grass_b, checker);
	col = mix(col, line_color, grid(p, 1.0, 0.02) * 0.35);
	col = mix(col, line_color, grid(p, 10.0, 0.06) * 0.8);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

shader_type canvas_item;
render_mode unshaded, blend_mul;
// Cheap film finish without reading the screen (medium preset): one multiply pass that
// darkens the corners (vignette) and adds fine animated film grain.

uniform float vignette = 0.32;
uniform float grain = 0.05;
uniform float aspect = 2.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	d.x *= aspect * 0.6;
	float v = 1.0 - vignette * smoothstep(0.25, 0.95, length(d) * 1.25);
	float n = hash12(floor(FRAGCOORD.xy * 0.75) + fract(TIME * 7.13) * vec2(311.7, 183.3));
	COLOR = vec4(vec3(v * (1.0 - grain * n)), 1.0);
}

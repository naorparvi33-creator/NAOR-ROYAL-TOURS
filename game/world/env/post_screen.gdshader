shader_type canvas_item;
render_mode unshaded;
// Full film finish (high preset): reads the rendered frame once.
//  * chromatic aberration that only grows toward the edges of the frame,
//  * luminance-aware film grain (stronger in the mid-tones, like real film),
//  * soft vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.32;
uniform float grain = 0.045;
uniform float aberration = 0.0025;
uniform float aspect = 2.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * aberration * r2 * 4.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv - off, 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv + off, 0.0).b;
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float n = hash12(floor(FRAGCOORD.xy * 0.75) + fract(TIME * 7.13) * vec2(311.7, 183.3)) - 0.5;
	col += n * grain * (0.35 + l * (1.0 - l) * 2.6);
	vec2 dv = d;
	dv.x *= aspect * 0.6;
	col *= 1.0 - vignette * smoothstep(0.25, 0.95, length(dv) * 1.25);
	COLOR = vec4(col, 1.0);
}

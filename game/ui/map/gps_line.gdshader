shader_type spatial;
// Faint GPS ribbon on the road: chevrons flowing toward the destination, soft edges.
// UV.x = metres along the route, UV.y = 0..1 across the ribbon.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.75, 1.0, 0.7);
uniform float fade_start = 140.0;
uniform float fade_end = 260.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float chev = fract(UV.x * 0.22 - across * 0.35 - TIME * 1.4);
	float band = smoothstep(0.0, 0.08, chev) * (1.0 - smoothstep(0.42, 0.5, chev));
	float edge = 1.0 - smoothstep(0.7, 1.0, across);
	float near = smoothstep(2.0, 8.0, UV.x);
	float far = 1.0 - smoothstep(fade_start, fade_end, UV.x);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * edge * near * far * (0.35 + 0.65 * band);
}

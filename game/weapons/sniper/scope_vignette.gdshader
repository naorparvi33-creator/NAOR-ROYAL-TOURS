shader_type canvas_item;
// Scope tube: black outside the eyepiece circle, a soft dark edge (eye relief shadow)
// and darker glass toward the rim. Coordinates are in the control's own units.

uniform vec2 rect_size = vec2(1600.0, 750.0);
uniform vec2 center = vec2(800.0, 375.0);
uniform float radius = 340.0;
uniform float edge = 18.0;
uniform float open = 1.0;      // 0..1 scope-in animation

void fragment() {
	vec2 p = UV * rect_size;
	float d = length(p - center);
	float r = radius * mix(0.35, 1.0, open);
	float outside = smoothstep(r - edge, r + edge * 0.35, d);
	float ring = smoothstep(r * 0.7, r, d) * 0.5;
	float dark = clamp(outside + ring * (1.0 - outside), 0.0, 1.0);
	COLOR = vec4(0.015, 0.018, 0.015, mix(1.0, dark, open));
}

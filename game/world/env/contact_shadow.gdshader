shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Soft contact shadow / ambient occlusion blob under cars and people (one MultiMesh,
// one draw call). INSTANCE_CUSTOM: r = size of the solid core (0 round .. 0.8 boxy),
// a = darkness.

varying vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 q = abs(UV - 0.5) * 2.0;
	float core = inst.r;
	vec2 e = max(q - core, vec2(0.0)) / max(1.0 - core, 0.001);
	float f = 1.0 - smoothstep(0.0, 1.0, length(e));
	f = f * f * (3.0 - 2.0 * f);
	// Black with alpha rather than a multiply blend: the Mobile renderer stores
	// colour pre-scaled, which would turn a neutral multiply into a dark square.
	ALBEDO = vec3(0.0);
	ALPHA = f * inst.a;
}

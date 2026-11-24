shader_type spatial;
// Tree / palm / shrub foliage cards (alpha-tested), shared by every builder.
// Vertex colour carries baked data from the builders:
//   COLOR.rgb = tint * baked ambient occlusion (dark inside the crown, bright outside)
//   COLOR.a   = flex: 0 where the leaf is attached, 1 at the free tip (leaf flutter)
// Wind = whole-tree bend that grows with height + travelling gusts + leaf flutter.
// Lighting: soft wrap diffuse, light through the leaves (backlight) and a per-tree
// colour shift so a row of identical meshes does not look copy-pasted.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float wind_strength = 1.0;
uniform float translucency = 0.55;
uniform vec2 wind_dir = vec2(0.86, 0.5);

varying vec3 inst_tint;

float h11(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = h11(origin.x * 0.137 + origin.z * 0.291);
	// Gusts travel across the city along the wind.
	float phase = dot(origin.xz, wind_dir) * 0.045 - TIME * 0.55;
	float gust = 0.55 + 0.45 * sin(phase * 6.2831) * sin(phase * 2.7 + 1.3);
	float h = max(VERTEX.y, 0.0) * 0.1;            // ~1 at a 10 m crown
	float bend = h * h * wind_strength;
	float sway = sin(TIME * (0.8 + seed * 0.3) + seed * 6.2831) * 0.35 + gust * 0.65;
	VERTEX.xz += wind_dir * bend * sway * 0.22;
	VERTEX.y -= bend * sway * 0.04;
	// Leaf / frond-tip flutter.
	float flex = COLOR.a;
	float fl = sin(TIME * (5.5 + seed * 2.0) + dot(VERTEX, vec3(2.1, 1.7, 2.9)));
	VERTEX += NORMAL * fl * flex * 0.05 * (0.5 + gust) * wind_strength;
	VERTEX.y += sin(TIME * 2.3 + VERTEX.x * 0.8 + seed * 9.0) * flex * flex * 0.08 * gust * wind_strength;
	// Per-tree colour: a little more yellow / blue / darker.
	inst_tint = mix(vec3(1.0), vec3(1.12, 1.06, 0.78), seed * 0.6) * mix(0.88, 1.08, h11(seed * 31.7));
	COLOR.rgb *= inst_tint;
}

void fragment() {
	vec4 c = texture(tex, UV);
	// Builders give "volume" normals pointing out of the crown. Godot flips NORMAL on
	// back faces of double-sided cards; undo that so a card shades the same from
	// both sides (otherwise half the crown turns black).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col = c.rgb * COLOR.rgb * tint;
	ALBEDO = col;
	// Keep distant foliage from thinning out as the mipmapped alpha softens.
	float d = length(VERTEX);
	ALPHA = clamp(c.a * (1.0 + clamp(d / 70.0, 0.0, 1.0) * 0.8), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.78;
	SPECULAR = 0.35;
	BACKLIGHT = col * translucency * vec3(1.0, 1.1, 0.6);
}

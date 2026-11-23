shader_type spatial;
// Grass clumps (two crossed cards) drawn with one MultiMesh that follows the player.
// Placement, rotation and size come from a hash of the world cell, so the grass
// never "jumps" when the patch is re-centred. It fades out with distance.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D card : source_color, filter_linear_mipmap, repeat_disable;
uniform float spacing = 0.55;
uniform float fade_start = 13.0;
uniform float fade_end = 19.5;

varying float shade;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = floor(origin.xz / spacing + 0.5);
	float h1 = tn_hash(cell);
	float h2 = tn_hash(cell + 17.3);
	float h3 = tn_hash(cell + 41.7);
	vec2 jitter = (vec2(h1, h2) - 0.5) * spacing;
	vec2 wxz = origin.xz + jitter;

	float dist = distance(wxz, CAMERA_POSITION_WORLD.xz);
	float s = mix(0.7, 1.25, h3);
	s *= 1.0 - tn_dirt_mask(wxz);
	s *= 1.0 - smoothstep(fade_start, fade_end, dist);
	s *= smoothstep(0.15, 0.35, tn_noise(wxz * 0.3) + 0.25);  // natural gaps

	float a = h1 * 6.2831;
	mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec3 v = VERTEX * s;
	v.xz = r * v.xz;
	float top = 1.0 - UV.y;
	float wind = sin(TIME * 1.6 + wxz.x * 0.35 + wxz.y * 0.2) + 0.5 * sin(TIME * 2.9 + wxz.x * 1.1);
	v.xz += vec2(0.06, 0.03) * wind * top * top * s;
	VERTEX = v + vec3(jitter.x, 0.0, jitter.y);
	NORMAL = vec3(0.0, 1.0, 0.0);  // lit like the ground, avoids dark back faces
	shade = mix(0.55, 1.0, top) * mix(0.85, 1.1, h2);
}

void fragment() {
	vec4 c = texture(card, UV);
	ALBEDO = c.rgb * shade;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
}

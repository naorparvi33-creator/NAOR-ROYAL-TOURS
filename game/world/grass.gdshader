shader_type spatial;
// Grass clumps (two crossed cards) drawn with one MultiMesh that follows the player.
// Placement, rotation and size come from a hash of the world cell, so the grass
// never "jumps" when the patch is re-centred. It fades out with distance.
//  * clumping: clump size follows a noise field, with natural bare gaps
//  * colour: lush / dry / dark patches from large-scale noise + per-clump jitter
//  * wind: travelling gust waves (a "rolling" lawn) plus a fast flutter; blades
//    bent by a gust catch the light (sheen)
//  * roots are dark (blades shade each other), tips are sunlit and let light through
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D card : source_color, filter_linear_mipmap, repeat_disable;
uniform float spacing = 0.55;
uniform float fade_start = 13.0;
uniform float fade_end = 19.5;
uniform vec2 wind_dir = vec2(0.86, 0.5);
uniform float wind_strength = 1.0;
// Paved / planted spots with no lawn: (x, z, radius, unused).
uniform vec4 clear_spots[4];

varying float shade;
varying vec3 patch_tint;
varying float sheen;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = floor(origin.xz / spacing + 0.5);
	float h1 = tn_hash(cell);
	float h2 = tn_hash(cell + 17.3);
	float h3 = tn_hash(cell + 41.7);
	vec2 jitter = (vec2(h1, h2) - 0.5) * spacing;
	vec2 wxz = origin.xz + jitter;

	float dist = distance(wxz, CAMERA_POSITION_WORLD.xz);
	float clump = tn_noise(wxz * 0.9);
	float s = mix(0.65, 1.3, h3) * mix(0.75, 1.15, clump);
	s *= 1.0 - tn_dirt_mask(wxz);
	s *= step(abs(wxz.x), PARK_HALF - 0.4) * step(abs(wxz.y), PARK_HALF - 0.4);  // grass only in the park
	s *= 1.0 - smoothstep(fade_start, fade_end, dist);
	s *= smoothstep(0.15, 0.35, tn_noise(wxz * 0.3) + 0.25);  // natural gaps
	for (int i = 0; i < 4; i++) {
		s *= smoothstep(clear_spots[i].z, clear_spots[i].z + 0.6, distance(wxz, clear_spots[i].xy));
	}

	float a = h1 * 6.2831;
	mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec3 v = VERTEX * s;
	v.xz = r * v.xz;
	float top = 1.0 - UV.y;
	// Gust waves roll across the lawn along the wind.
	float wave = dot(wxz, wind_dir) * 0.22 - TIME * 1.9;
	float gust = smoothstep(-0.2, 1.0, sin(wave) * 0.6 + tn_noise(wxz * 0.08 - wind_dir * TIME * 0.35) * 0.8);
	float flutter = sin(TIME * 4.3 + h2 * 6.2831 + wxz.x * 1.7) * 0.35;
	float bend = (0.05 + gust * 0.16 * wind_strength + flutter * 0.04) * top * top * s;
	v.xz += wind_dir * bend;
	v.y -= bend * bend * 2.0;
	VERTEX = v + vec3(jitter.x, 0.0, jitter.y);
	NORMAL = vec3(0.0, 1.0, 0.0);  // lit like the ground, avoids dark back faces
	shade = mix(0.34, 1.0, pow(top, 0.8)) * mix(0.85, 1.1, h2);
	sheen = gust * top;

	// Large-scale lawn colour: lush green, sun-dried yellow and darker damp patches.
	float dry = smoothstep(0.45, 0.8, tn_fbm(wxz * 0.035 + 3.1));
	float damp = smoothstep(0.55, 0.8, tn_noise(wxz * 0.12 + 9.0));
	patch_tint = mix(vec3(0.82, 0.9, 0.7), vec3(1.05, 0.95, 0.55), dry);
	patch_tint *= mix(1.0, 0.8, damp);
	patch_tint *= mix(vec3(1.0), vec3(1.08, 1.0, 0.9), h3 * 0.6);
	// Toward the edge of the patch, blend toward the darker lawn texture underneath.
	patch_tint *= mix(1.0, 0.72, smoothstep(5.0, fade_end, dist));
}

void fragment() {
	vec4 c = texture(card, UV);
	vec3 col = c.rgb * patch_tint * shade;
	col += vec3(0.07, 0.08, 0.03) * sheen;   // bent blades show their lighter side
	ALBEDO = col;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.85;
	BACKLIGHT = col * 0.45 * (1.0 - UV.y);
}

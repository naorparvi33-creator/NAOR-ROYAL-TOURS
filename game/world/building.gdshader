shader_type spatial;
// City building facades. Windows are computed from the world position, so a whole
// block of buildings is one mesh (one draw call per facade material).
// Per-vertex data: COLOR.rgb = wall tint, COLOR.a = random seed,
// UV.x = 1 for plain parts (cornices, rooftop units), UV.y = building top height.
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wall_tile = 3.0;
uniform float brightness = 1.0;
uniform float floor_h = 3.3;
uniform float win_spacing = 3.0;
uniform float ground_floor_h = 4.2;

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 vcol;
varying vec2 vdata;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
	vdata = UV;
}

float box_mask(vec2 p, vec2 lo, vec2 hi) {
	vec2 fw = fwidth(p) * 0.7;
	vec2 a = smoothstep(lo - fw, lo + fw, p);
	vec2 b = 1.0 - smoothstep(hi - fw, hi + fw, p);
	return a.x * a.y * b.x * b.y;
}

void fragment() {
	vec3 an = abs(wnorm);
	if (an.y > 0.6) {
		// Flat roof: weathered concrete.
		vec3 r = texture(wall_albedo, wpos.xz / 6.0).rgb;
		ALBEDO = mix(vec3(0.42, 0.41, 0.39), r * 0.6, 0.35) * mix(0.85, 1.05, tn_noise(wpos.xz * 0.3));
		ROUGHNESS = 0.95;
	} else {
		float u = an.x > an.z ? wpos.z : wpos.x;
		float v = wpos.y;
		vec2 tuv = vec2(u, v) / wall_tile;
		vec3 wall = texture(wall_albedo, tuv).rgb * vcol.rgb * brightness;
		// Grime: darker near the ground and streaks under the roof line.
		wall *= mix(0.78, 1.0, smoothstep(0.0, 2.5, v));
		wall *= mix(0.92, 1.03, tn_noise(vec2(u * 0.4, v * 0.08) + vcol.a * 50.0));
		vec3 nm = texture(wall_normal, tuv).rgb;

		float glass = 0.0;
		float frame = 0.0;
		float lit = 0.0;
		if (vdata.x < 0.5) {
			if (v < ground_floor_h) {
				// Shop windows.
				vec2 c = vec2(fract(u / 4.5), v);
				glass = box_mask(c, vec2(0.07, 0.45), vec2(0.93, 3.5));
				frame = box_mask(c, vec2(0.04, 0.35), vec2(0.96, 3.6)) - glass;
				lit = 0.4;
			} else if (v < vdata.y - 1.2) {
				float fv = (v - ground_floor_h) / floor_h;
				vec2 cell = vec2(floor(u / win_spacing), floor(fv));
				vec2 c = vec2(fract(u / win_spacing), fract(fv));
				glass = box_mask(c, vec2(0.22, 0.26), vec2(0.78, 0.82));
				frame = box_mask(c, vec2(0.19, 0.2), vec2(0.81, 0.85)) - glass;
				lit = tn_hash(cell + vcol.a * 97.0);
			}
		}
		// Glass: dark with strong sky reflection; some windows have light blinds.
		vec3 glass_col = mix(vec3(0.1, 0.13, 0.16), vec3(0.55, 0.52, 0.46), step(0.78, lit) * 0.7);
		vec3 frame_col = mix(vec3(0.2), vec3(0.85, 0.84, 0.8), step(0.5, vcol.a));
		vec3 col = mix(wall, frame_col, clamp(frame, 0.0, 1.0));
		col = mix(col, glass_col, glass);
		ALBEDO = col;
		NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), max(glass, frame));
		ROUGHNESS = mix(0.9, 0.04, glass);
		SPECULAR = mix(0.3, 0.9, glass);
	}
}

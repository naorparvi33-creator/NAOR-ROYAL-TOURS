shader_type spatial;
// Sidewalks of the whole city (one mesh, see city.gd _build_sidewalks).
//  * Pavers (Poly Haven, CC0) sampled at two scales so the tiling does not show.
//  * Concrete curb stones along the road edge, with a worn rounded lip and dirt.
//  * Stains, chewing-gum dots, darker joints, tree pits under the palms.
//  * Rain: darker and glossy, like the roads (wetness is copied from the ground material).
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D pavers_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pavers_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness = 0.0;
uniform int detail = 1;

const float BLOCK_HALF = 45.0;   // (PITCH - ROAD_W) / 2
const float CURB_W = 0.32;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 bc = (floor(p / CITY_PITCH + 0.5)) * CITY_PITCH;
	vec2 q = p - bc;
	float cheb = max(abs(q.x), abs(q.y));
	float edge = BLOCK_HALF - cheb;                       // distance to the road edge
	bool park = abs(bc.x) < 1.0 && abs(bc.y) < 1.0;
	float lawn = park ? abs(cheb - PARK_HALF) : 99.0;      // edge toward the park lawn
	vec3 alb;
	vec3 nm = vec3(0.5, 0.5, 1.0);
	float rough = 0.85;

	if (abs(wnorm.y) < 0.5) {
		// Curb face: concrete, dirty toward the road.
		vec2 cuv = vec2(wpos.x + wpos.z, wpos.y) / 1.5;
		alb = texture(concrete_albedo, cuv).rgb * vec3(0.78, 0.77, 0.74);
		alb *= mix(0.6, 1.0, smoothstep(0.0, 0.12, wpos.y));
		alb *= mix(0.85, 1.05, tn_noise(vec2(wpos.x + wpos.z, 0.0) * 0.7));
		rough = 0.9;
	} else {
		vec2 uv = p / 2.0;
		vec3 a1 = texture(pavers_albedo, uv).rgb;
		vec3 a2 = texture(pavers_albedo, uv * 0.43 + vec2(0.27, 0.61)).rgb;
		alb = mix(a1, a1 * a2 / max(dot(a2, vec3(0.333)), 0.05), 0.3) * vec3(0.93, 0.91, 0.88);
		nm = texture(pavers_normal, uv).rgb;
		// Sun-bleached and stained in large patches.
		float macro = tn_fbm(p * 0.07);
		alb *= mix(0.82, 1.08, macro);
		if (detail > 0) {
			// Dark stains (spills, oil, old rain marks).
			float st = smoothstep(0.62, 0.78, tn_fbm(p * 0.45 + 7.3));
			alb *= 1.0 - st * 0.3;
			// Chewing gum / dirt dots.
			vec2 gc = floor(p * 3.0);
			float g = step(0.985, tn_hash(gc)) * (1.0 - smoothstep(0.08, 0.13, length(fract(p * 3.0) - 0.5)));
			alb = mix(alb, vec3(0.22, 0.21, 0.2), g * 0.8);
		}
		// Grime collects along the building line and the curb.
		alb *= mix(1.0, 0.78, (1.0 - smoothstep(0.0, 1.2, edge - 0.3)) * 0.6);
		// Curb stones: lighter concrete with joints every 1.2 m and a worn edge.
		float curb = 1.0 - smoothstep(CURB_W - 0.01, CURB_W + 0.01, edge);
		curb = max(curb, park ? 1.0 - smoothstep(CURB_W - 0.01, CURB_W + 0.01, lawn) : 0.0);
		float along = abs(q.x) > abs(q.y) ? p.y : p.x;
		vec3 cc = texture(concrete_albedo, vec2(along, edge) / 1.3).rgb * vec3(0.92, 0.9, 0.86);
		cc *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.02, abs(fract(along / 1.2) - 0.5) * 1.2 - 0.58));
		cc *= mix(0.75, 1.0, smoothstep(0.0, 0.08, edge));
		alb = mix(alb, cc, curb);
		nm = mix(nm, vec3(0.5, 0.5, 1.0), curb);
		// Tree pits under the palms (city.gd: every 22 m along each side, 1 m from the edge).
		if (!park || cheb > PARK_HALF) {
			float off = abs(edge - 1.0);
			float a = abs(q.x) > abs(q.y) ? q.y : q.x;
			float k = abs(fract((a + 33.0) / 22.0 + 0.5) - 0.5) * 22.0;
			float pit = (1.0 - smoothstep(0.62, 0.66, max(off, k))) * step(abs(a), 34.0);
			float ring = pit * (1.0 - smoothstep(0.5, 0.54, max(off, k)));
			vec3 soil = vec3(0.2, 0.15, 0.11) * mix(0.7, 1.1, tn_noise(p * 9.0));
			alb = mix(alb, vec3(0.16, 0.16, 0.17), pit);
			alb = mix(alb, soil, ring);
		}
		rough = mix(0.88, 0.8, curb);
	}

	if (wetness > 0.0) {
		float pud = smoothstep(0.55, 0.65, tn_fbm(p * 0.25 + 1.7)) * smoothstep(0.3, 0.9, wetness);
		alb *= mix(1.0, 0.62, wetness) * mix(1.0, 0.8, pud);
		rough = mix(rough, 0.3, wetness * 0.8);
		rough = mix(rough, 0.05, pud);
		nm = mix(nm, vec3(0.5, 0.5, 1.0), pud);
	}
	ALBEDO = alb;
	NORMAL_MAP = nm;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}

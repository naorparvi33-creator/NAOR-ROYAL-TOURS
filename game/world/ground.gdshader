shader_type spatial;
// One ground plane for the whole city.
//  * Park block: scanned grass and forest-floor textures blended by noise.
//  * Everywhere else: asphalt (Poly Haven, CC0) with road markings computed from the
//    city grid: double yellow centre line, dashed lane lines and zebra crossings.
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 inside a band |x - c| < w with anti-aliased edges.
float band(float x, float c, float w) {
	float d = abs(x - c) - w;
	float fw = fwidth(x) * 0.75;
	return 1.0 - smoothstep(-fw, fw, d);
}

void fragment() {
	vec2 p = world_pos.xz;

	// ---------------- park lawn
	vec2 uv = p / tile_m;
	vec2 uv2 = p / (tile_m * 3.7) + vec2(0.37, 0.71);
	vec3 ga = mix(texture(grass_albedo, uv).rgb, texture(grass_albedo, uv2).rgb, 0.45);
	float macro = tn_fbm(p * 0.012);
	ga = ga * vec3(0.78, 1.3, 0.55) * 1.05;
	ga *= mix(vec3(1.08, 1.02, 0.85), vec3(0.85, 1.0, 0.95), macro);
	vec3 da = mix(texture(dirt_albedo, uv * 0.8).rgb, texture(dirt_albedo, uv2).rgb, 0.4);
	float d = tn_dirt_mask(p);
	vec3 park_albedo = mix(ga, da, d);
	vec3 park_normal = mix(texture(grass_normal, uv).rgb, texture(dirt_normal, uv * 0.8).rgb, d);
	float park_rough = mix(texture(grass_rough, uv).r, texture(dirt_rough, uv * 0.8).r, d);

	// ---------------- roads
	vec2 auv = p / 4.0;
	vec3 aa = texture(asphalt_albedo, auv).rgb;
	aa *= mix(0.8, 1.08, tn_fbm(p * 0.05));                 // patches / repairs
	vec3 an = texture(asphalt_normal, auv).rgb;
	float ar = texture(asphalt_rough, auv).r;

	// q = offset from the nearest road centre lines (0 on the centre line).
	vec2 q = p - (floor(p / CITY_PITCH) + 0.5) * CITY_PITCH;
	float half_w = ROAD_W * 0.5;
	float on_vroad = step(abs(q.x), half_w);      // road running along z
	float on_hroad = step(abs(q.y), half_w);      // road running along x
	float inter = on_vroad * on_hroad;

	float white = 0.0;
	float yellow = 0.0;
	// Lines along z-roads, stopped before the crossings.
	float vfree = on_vroad * step(half_w + 4.0, abs(q.y));
	yellow += vfree * band(abs(q.x), 0.18, 0.07);
	white += vfree * band(abs(q.x), 4.0, 0.07) * step(fract(p.y / 9.0), 0.45);
	// Lines along x-roads.
	float hfree = on_hroad * step(half_w + 4.0, abs(q.x));
	yellow += hfree * band(abs(q.y), 0.18, 0.07);
	white += hfree * band(abs(q.y), 4.0, 0.07) * step(fract(p.x / 9.0), 0.45);
	// Zebra crossings at each side of every intersection.
	float zv = on_vroad * (1.0 - inter) * band(abs(q.y), half_w + 2.1, 1.5) * step(abs(q.x), half_w - 0.4);
	white += zv * step(fract(q.x / 1.2), 0.55);
	float zh = on_hroad * (1.0 - inter) * band(abs(q.x), half_w + 2.1, 1.5) * step(abs(q.y), half_w - 0.4);
	white += zh * step(fract(q.y / 1.2), 0.55);
	// Stop lines on the approaching lane.
	white += on_vroad * band(abs(q.y), half_w + 4.0, 0.2) * step(abs(q.x), half_w - 0.4) * step(0.0, q.x * sign(q.y));
	white += on_hroad * band(abs(q.x), half_w + 4.0, 0.2) * step(abs(q.y), half_w - 0.4) * step(0.0, -q.y * sign(q.x));

	float wear = mix(0.55, 1.0, smoothstep(0.15, 0.4, tn_noise(p * 2.5)));   // worn paint
	white = clamp(white, 0.0, 1.0) * wear;
	yellow = clamp(yellow, 0.0, 1.0) * wear;
	vec3 road_albedo = mix(aa, vec3(0.82, 0.82, 0.78), white * 0.9);
	road_albedo = mix(road_albedo, vec3(0.85, 0.62, 0.12), yellow * 0.9);
	float road_rough = mix(ar, 0.55, max(white, yellow));

	// Wear: oil streaks down the lane centres and dirt in the gutters by the curb.
	float oil = vfree * (band(abs(q.x), 2.0, 0.4) + band(abs(q.x), 6.0, 0.4))
		+ hfree * (band(abs(q.y), 2.0, 0.4) + band(abs(q.y), 6.0, 0.4));
	oil *= smoothstep(0.3, 0.8, tn_noise(p * 0.7));
	float gutter = max(on_vroad * (1.0 - on_hroad) * smoothstep(6.9, 8.0, abs(q.x)),
		on_hroad * (1.0 - on_vroad) * smoothstep(6.9, 8.0, abs(q.y)));
	road_albedo *= 1.0 - clamp(oil * 0.22 + gutter * 0.3, 0.0, 0.5);
	road_rough = mix(road_rough, 0.45, oil * 0.5);

	// Manhole covers in the lanes.
	vec2 mv = vec2(abs(q.x) - 2.0, mod(p.y + 5.0, 37.0) - 18.5);
	vec2 mhv = vec2(abs(q.y) - 2.0, mod(p.x + 11.0, 37.0) - 18.5);
	float disk = vfree * (1.0 - smoothstep(0.33, 0.37, length(mv)))
		+ hfree * (1.0 - smoothstep(0.33, 0.37, length(mhv)));
	disk = clamp(disk, 0.0, 1.0);
	vec2 mlocal = vfree > 0.5 ? mv : mhv;
	float grooves = step(0.5, fract((mlocal.x + mlocal.y) * 8.0));
	road_albedo = mix(road_albedo, vec3(0.1, 0.095, 0.09) * mix(0.8, 1.3, grooves), disk);
	road_rough = mix(road_rough, 0.5, disk);

	float park = tn_park(p);
	ALBEDO = mix(road_albedo, park_albedo, park);
	NORMAL_MAP = mix(an, park_normal, park);
	ROUGHNESS = mix(road_rough, park_rough, park);
	SPECULAR = 0.35;
}

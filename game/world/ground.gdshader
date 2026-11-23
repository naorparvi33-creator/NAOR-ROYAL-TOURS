shader_type spatial;
// Realistic ground: photo-scanned grass and forest-floor textures (Poly Haven, CC0)
// blended by world-space noise. Two texture scales are mixed to hide tiling.
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = p / tile_m;
	vec2 uv2 = p / (tile_m * 3.7) + vec2(0.37, 0.71);

	vec3 ga = mix(texture(grass_albedo, uv).rgb, texture(grass_albedo, uv2).rgb, 0.45);
	vec3 gn = texture(grass_normal, uv).rgb;
	float gr = texture(grass_rough, uv).r;
	vec3 da = mix(texture(dirt_albedo, uv * 0.8).rgb, texture(dirt_albedo, uv2).rgb, 0.4);
	vec3 dn = texture(dirt_normal, uv * 0.8).rgb;
	float dr = texture(dirt_rough, uv * 0.8).r;

	// Grade the scanned grass toward a fresh green and add large-scale variation
	// (lush / drier areas) so the field does not look repetitive.
	float macro = tn_fbm(p * 0.012);
	ga = ga * vec3(0.78, 1.3, 0.55) * 1.05;
	ga *= mix(vec3(1.08, 1.02, 0.85), vec3(0.85, 1.0, 0.95), macro);

	float d = tn_dirt_mask(p);
	ALBEDO = mix(ga, da, d);
	NORMAL_MAP = mix(gn, dn, d);
	ROUGHNESS = mix(gr, dr, d);
	SPECULAR = 0.3;
}

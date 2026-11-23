// Shared body of car_body.gdshader / car_body_2s.gdshader (see vehicles/car_mesh.gd).
// One opaque surface per car: the vertex colour alpha picks the material class,
//   1.0 paint (uniform `paint`, metallic flakes, clear coat, dirt near the sills)
//   0.0 matte plastic / rubber / interior   0.25 gloss black (window trims, grilles)
//   0.5 chrome   0.62 brushed alloy (rims, brake discs)   0.78 lamp (emissive, far LOD)
// Direct light is shaded here (light()) so the clear coat gets a crisp sun highlight
// and a stylised sky / ground horizon reflection, the classic "glossy car" cue,
// scaled by the sun colour (golden at dusk, faint moon at night). Ambient and
// reflection probes / sky radiance still come from the engine.

uniform vec4 paint : source_color = vec4(0.6, 0.6, 0.62, 1.0);
uniform float dirt : hint_range(0.0, 1.0) = 0.3;
uniform float burnt : hint_range(0.0, 1.0) = 0.0;
uniform float sill = 0.34;
uniform float lamp_glow = 2.0;
uniform float flakes : hint_range(0.0, 1.0) = 1.0;
uniform float env_gain = 0.4;

varying vec3 l_pos;
varying vec3 v_refl;
varying vec3 v_nc;
varying vec3 v_alb;
varying float v_coat;
varying float v_rough;
varying float v_metal;
varying float v_flake;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	l_pos = VERTEX;
}

void fragment() {
	float a = COLOR.a;
	vec3 vc = COLOR.rgb;
	vec3 col = vc * (vc * (vc * 0.305306 + 0.682171) + 0.012523);   // sRGB -> linear
	float is_paint = step(0.9, a);
	float is_gloss = step(0.15, a) * (1.0 - step(0.35, a));
	float is_chrome = step(0.4, a) * (1.0 - step(0.56, a));
	float is_alloy = step(0.56, a) * (1.0 - step(0.7, a));
	float is_lamp = step(0.7, a) * (1.0 - step(0.9, a));

	vec3 base = mix(col, paint.rgb * col, is_paint);
	float rough = 0.7;
	rough = mix(rough, 0.4, is_paint);
	rough = mix(rough, 0.14, is_gloss);
	rough = mix(rough, 0.07, is_chrome);
	rough = mix(rough, 0.3, is_alloy);
	float metal = is_paint * 0.25 + is_chrome + is_alloy * 0.85;
	float coat = is_paint + is_gloss * 0.6;

	// Metallic flakes: sparse glints around the sun highlight (light()), faded with
	// distance so they never shimmer on a phone screen.
	vec3 n = NORMAL;
	vec3 n_smooth = NORMAL;
	float dist = length(VERTEX);
	float fade = (1.0 - smoothstep(2.0, 9.0, dist)) * flakes * is_paint;
	v_flake = 0.0;
	if (fade > 0.001) {
		v_flake = step(0.93, hash13(floor(l_pos * 260.0))) * fade;
	}

	// Road dust: a ragged band up from the sills and over the lower doors.
	float h = l_pos.y - sill;
	float nz = vnoise(l_pos * vec3(2.5, 9.0, 2.5));
	float d = (1.0 - smoothstep(-0.08, 0.42, h + (nz - 0.5) * 0.22)) * dirt * (1.0 - is_lamp);
	base = mix(base, vec3(0.15, 0.125, 0.095), d * 0.7);
	rough = mix(rough, 0.88, d);
	coat *= 1.0 - d * 0.85;
	metal *= 1.0 - d * 0.6;

	base = mix(base, vec3(0.022, 0.02, 0.018), burnt);
	rough = mix(rough, 0.96, burnt);
	metal *= 1.0 - burnt * 0.85;
	coat *= 1.0 - burnt;

	ALBEDO = base;
	METALLIC = metal;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.06;
	// Baked ambient occlusion toward the ground and in the wheel wells.
	AO = mix(0.3, 1.0, smoothstep(sill - 0.2, sill + 0.5, l_pos.y));
	AO_LIGHT_AFFECT = 0.0;
	EMISSION = col * is_lamp * lamp_glow * (1.0 - burnt);
	NORMAL = n;

	v_nc = n_smooth;
	v_refl = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, v_nc), 0.0)).xyz;
	v_alb = base;
	v_coat = coat;
	v_rough = rough;
	v_metal = metal;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float ndv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
	vec3 lc = LIGHT_COLOR * ATTENUATION;
	DIFFUSE_LIGHT += ndl * lc / PI;

	// Base layer: GGX.
	vec3 hv = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, hv), 0.0, 1.0);
	float ldh = clamp(dot(LIGHT, hv), 0.0, 1.0);
	float al = max(v_rough * v_rough, 0.003);
	float a2 = al * al;
	float dd = ndh * ndh * (a2 - 1.0) + 1.0;
	float dist_d = a2 / (PI * dd * dd);
	float vis = 0.5 / (ndl * (ndv * (1.0 - al) + al) + ndv * (ndl * (1.0 - al) + al) + 0.0001);
	vec3 f0 = mix(vec3(0.04), v_alb, v_metal);
	vec3 fr = f0 + (1.0 - f0) * pow(1.0 - ldh, 5.0);
	SPECULAR_LIGHT += lc * ndl * min(dist_d * vis, 60.0) * fr;
	SPECULAR_LIGHT += lc * ndl * v_flake * pow(ndh, 24.0) * 2.5 * v_alb;

	// Clear coat: a sharp lobe on the smooth normal.
	float ndlc = clamp(dot(v_nc, LIGHT), 0.0, 1.0);
	float ndvc = clamp(dot(v_nc, VIEW), 0.0, 1.0);
	float fc = 0.04 + 0.96 * pow(1.0 - ndvc, 5.0);
	if (v_coat > 0.01) {
		float ndhc = clamp(dot(v_nc, hv), 0.0, 1.0);
		float ac2 = 0.0144 * 0.0144;
		float dc = ndhc * ndhc * (ac2 - 1.0) + 1.0;
		SPECULAR_LIGHT += lc * ndlc * min(ac2 / (PI * dc * dc), 120.0) * 0.25 * (0.04 + 0.96 * pow(1.0 - ldh, 5.0)) * v_coat;
	}

	// Stylised environment: bright sky above the horizon, dark street below.
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 r = normalize(v_refl);
		float sky = smoothstep(-0.03, 0.05, r.y);
		vec3 sky_col = mix(vec3(1.0, 0.95, 0.86), vec3(0.42, 0.56, 0.85), clamp(r.y * 1.4, 0.0, 1.0));
		vec3 env = mix(vec3(0.015, 0.015, 0.017), sky_col, sky);
		float k = v_coat * fc + step(0.9, v_metal) * (1.0 - v_rough) * 0.5;
		SPECULAR_LIGHT += env * (LIGHT_COLOR / PI) * k * env_gain;
	}
}

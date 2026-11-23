shader_type spatial;
// Tinted car glass (vehicles/car_mesh.gd). Darker and more opaque at grazing angles
// (Fresnel), with a sharp sun glint and the same sky / street horizon reflection
// as the paint. The same surface also carries the soft contact shadow under the
// car: vertices with COLOR.r = 1 are a ground blob whose opacity is COLOR.g.
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(0.018, 0.022, 0.027, 1.0);
uniform float env_gain = 0.45;

varying vec3 v_refl;
varying float v_fr;
varying float v_blob;

void vertex() {
	v_blob = COLOR.r;
}

void fragment() {
	if (v_blob > 0.5) {
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = COLOR.g * COLOR.g * 0.7;
		v_fr = 0.0;
	} else {
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		v_fr = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);
		ALBEDO = tint.rgb;
		METALLIC = 0.0;
		ROUGHNESS = 0.04;
		SPECULAR = 0.6;
		ALPHA = mix(0.88, 0.985, smoothstep(0.0, 0.4, v_fr));
	}
	v_refl = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
}

void light() {
	float glass = 1.0 - step(0.5, v_blob);
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 lc = LIGHT_COLOR * ATTENUATION * glass;
	DIFFUSE_LIGHT += ndl * lc / PI;
	vec3 hv = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, hv), 0.0, 1.0);
	SPECULAR_LIGHT += lc * ndl * pow(ndh, 900.0) * 3.0;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 r = normalize(v_refl);
		float sky = smoothstep(-0.03, 0.05, r.y);
		vec3 sky_col = mix(vec3(1.0, 0.95, 0.86), vec3(0.42, 0.56, 0.85), clamp(r.y * 1.4, 0.0, 1.0));
		vec3 env = mix(vec3(0.012, 0.012, 0.014), sky_col, sky);
		SPECULAR_LIGHT += env * (LIGHT_COLOR / PI) * (0.06 + v_fr * 0.9) * env_gain * glass;
	}
}

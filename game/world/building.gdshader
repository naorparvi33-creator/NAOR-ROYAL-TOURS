shader_type spatial;
// City building facades. Everything is computed from the world position, so a whole
// block of buildings is one mesh per facade material (one draw call each).
//
// Per-vertex data (see city.gd _add_box / _add_quad):
//   COLOR.rgb = tint, COLOR.a = building seed (drives every per-building choice below)
//   UV.x      = part kind: 0 facade with windows, 1 plain wall (cornices, parapets, balconies),
//               2 metal (AC units, railings, antennas, frames), 3 awning canvas,
//               4 billboard (UV2 = atlas uv), 5 water tank (wood staves), 6 roof gravel/tar
//   UV.y      = building top height (windows stop under it)
//   UV2       = facade: (u0, u1) extent of the building face along its wall axis, so the
//               window columns are centred on each face with solid corners.
//
// Typologies (uniform `style`): 0 brick low-rise, 1 stucco apartments / art-deco,
// 2 concrete offices, 3 glass curtain-wall towers.
// Windows show a fake room behind the glass (interior mapping) and a fake reflection of the
// sky and of the buildings across the street (cheap: no cubemaps, no screen-space effects).
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/terrain_noise.gdshaderinc"

uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sky_pano : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ads : source_color, filter_linear_mipmap_anisotropic;
uniform int style = 1;
uniform float wall_tile = 3.0;
uniform float brightness = 1.0;
uniform float floor_h = 3.3;
uniform float ground_floor_h = 4.2;
// 0 = low (flat glass, no fake rooms), 1 = medium, 2 = high.
uniform int detail = 1;
// Night (set by world/env/city_lights.gd): 0 = day, 1 = windows and shops lit.
uniform float night_lights = 0.0;
uniform float lit_ratio = 0.4;

const vec3 SIGN_PAL[6] = vec3[](vec3(0.45, 0.06, 0.05), vec3(0.06, 0.1, 0.25), vec3(0.06, 0.22, 0.12),
	vec3(0.85, 0.8, 0.68), vec3(0.06, 0.06, 0.07), vec3(0.75, 0.4, 0.08));

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 vcol;
varying vec2 vdata;
varying vec2 vext;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
	vdata = UV;
	vext = UV2;
}

float box_mask(vec2 p, vec2 lo, vec2 hi) {
	vec2 fw = max(fwidth(p) * 0.7, vec2(1e-4));
	vec2 a = smoothstep(lo - fw, lo + fw, p);
	vec2 b = 1.0 - smoothstep(hi - fw, hi + fw, p);
	return a.x * a.y * b.x * b.y;
}

float aa_step(float edge, float x) {
	float fw = max(fwidth(x) * 0.7, 1e-4);
	return smoothstep(edge - fw, edge + fw, x);
}

vec3 hash3(vec2 p) {
	return vec3(tn_hash(p), tn_hash(p + 17.31), tn_hash(p + 41.7));
}

vec2 pano_uv(vec3 d) {
	vec2 c = vec2(atan(d.x, -d.z), acos(clamp(d.y, -1.0, 1.0)));
	return c / vec2(2.0 * PI, PI) + vec2(0.5, 0.0);
}

// Fake environment seen in glass: sky photo above, buildings across the street around
// the horizon (a procedural skyline with windows) and the sunny street below.
vec3 fake_reflection(vec3 r, float seed, float skyline) {
	vec3 sky = textureLod(sky_pano, pano_uv(r), 2.0).rgb;
	sky = mix(sky, vec3(0.95, 0.85, 0.7), (1.0 - smoothstep(0.0, 0.25, r.y)) * 0.35);
	float az = atan(r.x, r.z);
	float elev = r.y;
	// Skyline height (in r.y) varies by azimuth: towers of different heights.
	float cell = floor(az * 7.0 + seed * 13.0);
	float hgt = mix(0.08, 0.45, tn_hash(vec2(cell, seed * 7.0))) * skyline;
	vec3 bcol = mix(vec3(0.3, 0.28, 0.26), vec3(0.55, 0.5, 0.44), tn_hash(vec2(cell, 3.0)));
	// Window rows / columns on the reflected buildings.
	float wr = step(0.45, fract(elev * 38.0)) * step(0.3, fract(az * 70.0));
	bcol = mix(bcol, vec3(0.1, 0.13, 0.16), wr * 0.7);
	vec3 col = mix(sky, bcol, step(elev, hgt) * step(-0.02, elev));
	// Street below: warm asphalt and pavement.
	col = mix(col, vec3(0.2, 0.19, 0.18), smoothstep(0.0, -0.06, elev));
	return col;
}

// Interior mapping: ray from the window into a box room [0,1]^3 (x along the wall,
// y up, z into the building). Returns the colour of the surface hit.
vec3 fake_room(vec2 p, vec3 d, vec3 rnd, float shop, out float depth) {
	d.z = max(d.z, 1e-3);
	vec3 o = vec3(p, 0.0);
	vec3 t3 = (step(vec3(0.0), d) - o) / d;
	float tx = abs(d.x) > 1e-4 ? t3.x : 1e5;
	float ty = abs(d.y) > 1e-4 ? t3.y : 1e5;
	float tz = t3.z;
	float t = min(min(tx, ty), tz);
	vec3 h = o + d * t;
	depth = h.z;
	vec3 wallc = mix(vec3(0.82, 0.78, 0.7), vec3(0.62, 0.68, 0.7), rnd.x);
	wallc = mix(wallc, vec3(0.75, 0.55, 0.45), step(0.85, rnd.y));
	vec3 c;
	if (t == tz) {
		c = wallc;
		// Furniture / shelves on the back wall.
		if (shop > 0.5) {
			float row = step(0.5, fract(h.y * 6.0)) * step(h.y, 0.75);
			vec3 goods = hash3(floor(vec2(h.x * 14.0, h.y * 6.0)) + rnd.xy * 9.0);
			c = mix(c * 0.9, goods * 0.8 + 0.1, row);
		} else {
			float sofa = box_mask(h.xy, vec2(0.15 + rnd.z * 0.2, 0.0), vec2(0.65 + rnd.z * 0.2, 0.28));
			c = mix(c, mix(vec3(0.25, 0.2, 0.18), vec3(0.3, 0.35, 0.45), rnd.y), sofa);
			float pic = box_mask(h.xy, vec2(0.35, 0.5), vec2(0.6, 0.72)) * step(0.4, rnd.x);
			c = mix(c, vec3(0.2, 0.25, 0.3), pic);
		}
	} else if (t == ty) {
		if (d.y < 0.0) {
			c = mix(vec3(0.45, 0.32, 0.22), vec3(0.6, 0.58, 0.55), rnd.z);   // floor
			if (shop > 0.5) c = vec3(0.7, 0.7, 0.68);
		} else {
			c = vec3(0.9, 0.9, 0.88);   // ceiling
			// Office / shop light panels.
			float lamp = step(0.8, fract(h.z * 3.0)) * step(0.2, fract(h.x * 2.0));
			c += lamp * (0.6 + shop);
		}
	} else {
		c = wallc * 0.82;
		// A cupboard against one side wall.
		c = mix(c, vec3(0.5, 0.42, 0.35), box_mask(h.zy, vec2(0.3, 0.0), vec2(0.7, 0.75)) * step(0.5, rnd.y));
	}
	// Rooms get darker toward the back (light comes through the window).
	c *= mix(1.0, 0.45, h.z) * mix(0.75, 1.0, h.y);
	return c;
}

void fragment() {
	vec3 an = abs(wnorm);
	int kind = int(vdata.x + 0.5);
	// Quantised: vertex colours are 8-bit, and interpolation jitter must not reach the hashes.
	float seed = floor(vcol.a * 255.0 + 0.5) / 255.0;
	vec3 h3 = vec3(fract(seed * 13.71), fract(seed * 71.33), fract(seed * 197.1));
	vec3 V = normalize(wpos - CAMERA_POSITION_WORLD);
	float day = 1.0 - night_lights;
	vec3 emission = vec3(0.0);

	vec3 albedo;
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float rough = 0.9;
	float spec = 0.4;
	float metal = 0.0;

	if (an.y > 0.6 || kind == 6) {
		// Roofs: tar / gravel with patches, puddle stains and seams.
		vec2 rp = wpos.xz;
		float g = tn_noise(rp * 7.0) * 0.5 + tn_noise(rp * 23.0) * 0.5;
		albedo = mix(vec3(0.4, 0.38, 0.35), vec3(0.55, 0.52, 0.47), g);
		if (style == 3 || h3.x > 0.6) {
			albedo = mix(albedo, vec3(0.62, 0.62, 0.6), 0.5);   // white membrane
		}
		albedo *= mix(0.75, 1.08, tn_fbm(rp * 0.15 + seed * 30.0));
		// Membrane seams every 2 m, darker damp patches, dirt collected at the parapets.
		albedo *= 1.0 - 0.15 * (step(0.96, fract(rp.x * 0.5)) + step(0.96, fract(rp.y * 0.5)));
		albedo *= 1.0 - 0.25 * smoothstep(0.6, 0.8, tn_fbm(rp * 0.4 + seed * 9.0));
		if (kind != 0 && kind != 6) {
			albedo = vcol.rgb * texture(wall_albedo, rp / wall_tile).rgb * brightness * 0.9;
			if (kind == 2) albedo = vec3(0.45, 0.46, 0.47);
			if (kind == 5) albedo = vec3(0.32, 0.24, 0.17);
			if (kind == 3) albedo = vcol.rgb;
		}
		rough = 0.95;
		spec = 0.2;
	} else if (kind == 2) {
		// Painted metal: AC units, railings, antennas. Grille slats on the faces.
		float u = an.x > an.z ? wpos.z : wpos.x;
		float slat = step(0.5, fract(wpos.y * 9.0));
		albedo = mix(vec3(0.72, 0.72, 0.7), vec3(0.55, 0.56, 0.56), slat) * mix(0.8, 1.0, tn_noise(vec2(u, wpos.y) * 3.0));
		albedo *= mix(vec3(1.0), vcol.rgb, 0.6);
		rough = 0.55;
		metal = 0.4;
	} else if (kind == 3) {
		// Awning canvas: stripes or plain, faded and a bit dirty.
		float u = an.x > an.z ? wpos.z : wpos.x;
		float stripes = step(0.5, fract(u / 0.6)) * step(0.5, h3.z);
		albedo = mix(vcol.rgb, vec3(0.92, 0.9, 0.85), stripes);
		albedo *= mix(0.85, 1.0, tn_noise(vec2(u * 2.0, wpos.y * 4.0)));
		rough = 0.85;
		spec = 0.2;
	} else if (kind == 4) {
		// Billboard: one advert from the atlas, lit by a bit of self light (backlit panel).
		vec2 auv = vext;
		vec3 ad = texture(ads, auv).rgb;
		albedo = ad * 0.85;
		emission = ad * (0.15 * day + 0.9 * night_lights);
		rough = 0.5;
	} else if (kind == 5) {
		// Wooden water tank: vertical staves and steel hoops.
		float u = an.x > an.z ? wpos.z : wpos.x;
		float stave = step(0.12, fract(u * 4.0));
		float hoop = step(0.92, fract(wpos.y * 1.7));
		albedo = mix(vec3(0.25, 0.18, 0.12), vec3(0.42, 0.31, 0.2), stave);
		albedo *= mix(0.75, 1.05, tn_noise(vec2(u * 6.0, wpos.y * 0.7)));
		albedo = mix(albedo, vec3(0.2, 0.2, 0.21), hoop);
		rough = 0.9;
	} else {
		float u = an.x > an.z ? wpos.z : wpos.x;
		float v = wpos.y;
		vec3 n_out = an.x > an.z ? vec3(sign(wnorm.x), 0.0, 0.0) : vec3(0.0, 0.0, sign(wnorm.z));
		vec3 t_u = an.x > an.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec2 tuv = vec2(u, v) / wall_tile;
		// Two scales of the wall texture break up tiling.
		vec3 tex = texture(wall_albedo, tuv).rgb;
		vec3 tex2 = texture(wall_albedo, tuv * 0.37 + vec2(0.31, 0.17)).rgb;
		vec3 wall = mix(tex, tex * (tex2 / max(dot(tex2, vec3(0.333)), 0.05)) * 0.9, 0.35);
		wall *= vcol.rgb * brightness;
		nmap = texture(wall_normal, tuv).rgb;

		// Large-scale discolouration / repainting patches.
		float blotch = tn_fbm(vec2(u * 0.12, v * 0.09) + seed * 50.0);
		wall *= mix(0.86, 1.06, blotch);

		float glass = 0.0;
		float frame = 0.0;
		float sill = 0.0;
		float lintel = 0.0;
		float streak = 0.0;
		float reveal = 0.0;
		float blinds = 0.0;
		float pilaster = 0.0;
		vec2 room_p = vec2(0.5);
		vec3 room_d = vec3(0.0, 0.0, 1.0);
		vec3 rnd = vec3(0.5);
		float shop = 0.0;
		float lit = 0.0;
		float glow_on = 0.0;
		vec3 glow_col = vec3(1.0, 0.78, 0.52);
		float face_w = vext.y - vext.x;
		bool known = face_w > 0.5 && face_w < 900.0;
		float edge_d = known ? min(u - vext.x, vext.y - u) : 99.0;
		float top = vdata.y;

		if (kind == 0) {
			if (v < ground_floor_h) {
				// ---------- storefronts (world 4.5 m grid: matches street_dressing shutters)
				float cw = 4.5;
				vec2 c = vec2(fract(u / cw), v);
				float cell = floor(u / cw);
				// Shops span 1-3 cells: neighbouring cells of one shop share colours.
				float shop_id = floor((cell + floor(seed * 7.0)) / (1.0 + floor(h3.y * 3.0)));
				vec3 sr = hash3(vec2(shop_id, seed * 11.0));
				float door = step(0.72, tn_hash(vec2(cell, seed * 5.0)));
				float sill_y = door > 0.5 ? 0.17 : 0.6;
				float pil = 0.28 / cw;
				glass = box_mask(c, vec2(pil, sill_y), vec2(1.0 - pil, 3.05));
				float transom = box_mask(c, vec2(pil, 3.12), vec2(1.0 - pil, 3.45));
				float mull = box_mask(c, vec2(0.49, 0.0), vec2(0.51, 9.0)) * (1.0 - door);
				frame = box_mask(c, vec2(pil - 0.012, sill_y - 0.05), vec2(1.0 - pil + 0.012, 3.5)) - glass - transom * 0.9;
				frame = clamp(frame + mull * glass, 0.0, 1.0);
				glass = max(glass * (1.0 - mull), transom);
				// Kick plate (dark stone) under the glass.
				float kick = (1.0 - step(sill_y, v)) * box_mask(c, vec2(pil, 0.0), vec2(1.0 - pil, 0.7));
				wall = mix(wall, mix(vec3(0.16, 0.15, 0.14), vec3(0.42, 0.4, 0.38), sr.z), kick);
				// Fascia sign band above the windows.
				float fascia = box_mask(c, vec2(0.0, 3.55), vec2(1.0, 4.1));
				vec3 fcol = SIGN_PAL[int(sr.x * 5.99)];
				if (style == 3) fcol = vec3(0.12, 0.13, 0.14);
				float letters = box_mask(vec2(fract(u / 0.5), v), vec2(0.15, 3.68), vec2(0.8, 3.98))
					* box_mask(c, vec2(0.12, 0.0), vec2(0.88, 9.0))
					* step(0.35, tn_hash(vec2(floor(u / 0.5), shop_id))) * step(0.35, sr.z) * (style == 3 ? 0.0 : 1.0);
				vec3 lcol = mix(vec3(0.95, 0.93, 0.88), vec3(1.0, 0.85, 0.35), step(0.6, sr.y));
				wall = mix(wall, fcol, fascia);
				wall = mix(wall, lcol, letters * fascia);
				emission += lcol * letters * fascia * night_lights * 1.4;
				room_p = vec2(c.x, clamp((v - sill_y) / (3.05 - sill_y), 0.0, 1.0));
				float rw = cw, rh = 3.05 - sill_y;
				room_d = vec3(dot(V, t_u) / rw, V.y / rh, dot(V, -n_out) / 7.0);
				rnd = sr;
				shop = 1.0;
				lit = 0.0;
				glow_on = 1.0;
				glow_col = mix(vec3(1.0, 0.86, 0.65), vec3(0.85, 0.95, 1.0), step(0.7, sr.z));
				reveal = 1.0 - smoothstep(0.0, 0.14, 3.05 - v);
			} else if (v < top - 1.0) {
				// ---------- upper floors
				float fv = (v - ground_floor_h) / floor_h;
				float fl = floor(fv);
				float fy = fract(fv);
				float sp;
				float ww;
				float wh;
				float wy;
				if (style == 0) {        // brick: tall sash windows
					sp = mix(2.6, 3.3, h3.x); ww = mix(1.1, 1.5, h3.y); wh = mix(0.5, 0.62, h3.z); wy = 0.22;
				} else if (style == 1) { // stucco: wide windows / french doors
					sp = mix(3.0, 4.2, h3.x); ww = mix(1.4, 2.4, h3.y); wh = mix(0.48, 0.66, h3.z); wy = 0.24;
				} else if (style == 2) { // concrete offices: ribbon windows
					sp = mix(1.6, 2.2, h3.x); ww = sp - mix(0.12, 0.5, h3.y); wh = mix(0.45, 0.6, h3.z); wy = 0.28;
				} else {                 // curtain wall: full height glass, slim mullions
					sp = mix(1.3, 1.8, h3.x); ww = sp - 0.08; wh = 0.74; wy = 0.13;
				}
				float margin = style == 3 ? 0.15 : mix(0.8, 1.6, h3.z);
				float u0 = known ? vext.x + margin : 0.0;
				float avail = known ? face_w - margin * 2.0 : 1e4;
				float ncol = max(1.0, floor(avail / sp + 0.35));
				float cw = known ? avail / ncol : sp;
				float cu = (u - u0) / cw;
				float col = floor(cu);
				float inside = known ? step(0.0, cu) * step(cu, ncol) : 1.0;
				float fx = fract(cu);
				float wfrac = min(ww / cw, 0.96);
				vec2 c = vec2(fx, fy);
				vec2 lo = vec2(0.5 - wfrac * 0.5, wy);
				vec2 hi = vec2(0.5 + wfrac * 0.5, wy + wh);
				glass = box_mask(c, lo, hi) * inside;
				float fwm = 0.07 / cw;
				float fwv = 0.07 / floor_h;
				float outer = box_mask(c, lo - vec2(fwm, fwv), hi + vec2(fwm, fwv)) * inside;
				frame = outer - glass;
				// Mullions / transoms inside the opening.
				float mid = 0.0;
				if (style == 0) {
					mid = box_mask(c, vec2(lo.x, lo.y + wh * 0.5 - 0.012), vec2(hi.x, lo.y + wh * 0.5 + 0.012));
				} else if (style == 1 && ww > 1.8) {
					mid = box_mask(c, vec2(0.49, lo.y), vec2(0.51, hi.y));
				} else if (style == 3) {
					mid = box_mask(c, vec2(lo.x, 0.86), vec2(hi.x, 0.9));
				}
				mid *= glass;
				frame = clamp(frame + mid, 0.0, 1.0);
				glass *= 1.0 - mid;
				// Sill (light stone) and its shadow; brick lintels; dirt streaks below.
				if (style != 3) {
					sill = box_mask(c, vec2(lo.x - fwm * 2.0, lo.y - 0.045), vec2(hi.x + fwm * 2.0, lo.y - fwv)) * inside;
					float below = clamp((lo.y - fy) / 0.6, 0.0, 1.0);
					float sx = step(lo.x, fx) * step(fx, hi.x);
					streak = sx * (1.0 - below) * step(fy, lo.y) * smoothstep(0.35, 0.8, tn_noise(vec2(u * 9.0, fl + seed * 3.0)));
					if (style == 0) {
						lintel = box_mask(c, vec2(lo.x - fwm, hi.y + fwv), vec2(hi.x + fwm, hi.y + 0.08)) * inside;
					}
				}
				// Art-deco stucco: raised vertical piers between window columns.
				if (style == 1 && h3.z > 0.72) {
					pilaster = (1.0 - box_mask(vec2(fx, 0.5), vec2(0.5 - wfrac * 0.5 - 0.06, 0.0), vec2(0.5 + wfrac * 0.5 + 0.06, 1.0))) * inside;
					// Spandrel panels with chevrons under the windows.
					float chev = step(0.5, fract((abs(fx - 0.5) * 6.0 + fy * 8.0))) * step(fy, lo.y - 0.04) * (1.0 - pilaster);
					wall *= 1.0 - chev * 0.08;
				}
				// Curtain wall: dark spandrel bands at the slabs, everything else glass.
				if (style == 3) {
					float spandrel = 1.0 - box_mask(c, vec2(-1.0, wy - 0.01), vec2(2.0, wy + wh + 0.01));
					wall = mix(wall, vec3(0.2, 0.22, 0.24) * vcol.rgb, 0.85);
					glass = max(glass, spandrel * 0.85 * inside);   // spandrel glass is opaque-backed
					frame = clamp(frame, 0.0, 1.0);
				}
				room_p = vec2((fx - lo.x) / max(hi.x - lo.x, 1e-3), (fy - lo.y) / max(hi.y - lo.y, 1e-3));
				float rw = cw * wfrac;
				float rh = floor_h * wh;
				room_d = vec3(dot(V, t_u) / rw, V.y / rh * 0.8, dot(V, -n_out) / 4.5);
				rnd = hash3(vec2(col, fl) + seed * 37.0);
				// Blinds / curtains pulled to random heights.
				float bl = rnd.y > 0.55 ? mix(0.25, 1.0, rnd.z) : 1.0;
				blinds = step(bl, room_p.y) * glass;
				lit = rnd.x;
				float h2 = tn_hash(vec2(col, fl) * 1.37 + seed * 31.0 + 5.0);
				glow_on = step(h2, lit_ratio) * mix(0.6, 1.4, fract(h2 * 57.3));
				glow_col = mix(vec3(1.0, 0.72, 0.42), vec3(0.75, 0.85, 1.0), step(0.8, fract(h2 * 13.1)));
				if (style >= 2) glow_col = mix(glow_col, vec3(0.9, 0.95, 1.0), 0.6);
				// Window recess: the reveal shades the top of the glass.
				reveal = 1.0 - smoothstep(0.0, 0.12, hi.y - fy);
			}
		}

		// ---------- weathering on the wall
		float base = 1.0 - smoothstep(0.0, 1.6 + tn_noise(vec2(u * 1.3, seed)) * 1.2, v - 0.15);
		wall *= mix(1.0, 0.62, base * 0.85);
		// Rain run-off from the roof line.
		float run = (1.0 - smoothstep(0.0, 6.0, top - v)) * smoothstep(0.4, 0.85, tn_noise(vec2(u * 3.0, seed * 9.0)));
		wall *= 1.0 - run * 0.22;
		wall *= 1.0 - streak * 0.28;
		// Corners: slight wear and a little ambient occlusion where faces meet.
		float corner = 1.0 - smoothstep(0.0, 0.35, edge_d);
		if (style == 0) {
			// Stone quoins on brick corners.
			float q = step(0.5, fract(v / 0.6)) * (1.0 - step(mix(0.45, 0.75, step(0.5, fract(v / 1.2))), edge_d));
			wall = mix(wall, mix(wall, vec3(0.72, 0.68, 0.6), 0.55), q * step(0.4, h3.y) * 0.45);
		} else {
			wall *= mix(1.0, 1.08, corner * tn_noise(vec2(u * 5.0, v * 5.0)));
		}
		wall = mix(wall, vec3(0.85, 0.83, 0.78), sill * 0.85);
		wall = mix(wall, wall * 0.7 + vec3(0.06), lintel);
		wall *= mix(1.0, 1.1, pilaster);

		vec3 frame_col = h3.y < 0.4 ? vec3(0.88, 0.87, 0.83) : (h3.y < 0.7 ? vec3(0.12, 0.12, 0.12) : vec3(0.32, 0.27, 0.22));
		if (style == 3) frame_col = mix(vec3(0.55, 0.57, 0.6), vcol.rgb * 0.5, 0.4);

		// ---------- glass
		vec3 N = n_out;
		vec3 R = reflect(V, N);
		float cos_t = clamp(-dot(V, N), 0.0, 1.0);
		float fres = 0.04 + 0.96 * pow(1.0 - cos_t, 5.0);
		vec3 room = vec3(0.12, 0.13, 0.14);
		float rdepth = 0.5;
		if (detail > 0 && glass > 0.01) {
			room = fake_room(clamp(room_p, 0.0, 1.0), room_d, rnd, shop, rdepth);
			// Far away the rooms fade into dark glass (also hides interior aliasing).
			room = mix(room, vec3(0.1, 0.11, 0.12), smoothstep(45.0, 140.0, length(wpos - CAMERA_POSITION_WORLD)));
		}
		// Blinds: pale fabric with slats.
		vec3 blind_col = mix(vec3(0.85, 0.82, 0.74), vec3(0.6, 0.55, 0.48), rnd.z) * mix(0.85, 1.0, step(0.3, fract(room_p.y * 14.0)));
		room = mix(room, blind_col * 0.75, blinds);
		float tint_strength = style == 3 ? 0.75 : (style == 2 ? 0.45 : 0.3);
		vec3 gtint = style == 3 ? mix(vec3(0.45, 0.6, 0.65), vcol.rgb, 0.6) : vec3(0.75, 0.8, 0.82);
		vec3 refl = detail > 0 ? fake_reflection(R, seed + floor(u / 30.0) * 0.13, style == 3 ? 1.0 : 0.8)
			: textureLod(sky_pano, pano_uv(R), 3.0).rgb;
		// Slightly wavy glass panes: each pane reflects at its own tiny angle.
		float kref = mix(0.12, 0.75, fres);
		if (style == 3) kref = mix(0.5, 0.9, fres);
		if (shop > 0.5) kref = mix(0.06, 0.45, fres);
		vec3 room_seen = room * (shop > 0.5 ? 0.45 : 0.3) * gtint;
		vec3 glass_albedo = mix(room_seen, room_seen * 0.4, kref * tint_strength) * (1.0 - reveal * 0.35);
		vec3 glass_emis = refl * kref * gtint * day * 0.65 * (1.0 - reveal * 0.3);
		// Night: lit rooms and shops glow.
		float night_glow = glow_on * night_lights;
		vec3 night_col = glow_col * (room * 1.6 + 0.15) * night_glow * (shop > 0.5 ? 1.2 : 0.8);

		vec3 col = mix(wall, frame_col, clamp(frame, 0.0, 1.0));
		col = mix(col, glass_albedo, glass);
		albedo = col;
		emission += (glass_emis + night_col) * glass;
		nmap = mix(nmap, vec3(0.5, 0.5, 1.0), max(glass, frame));
		rough = mix(0.88, 0.08, glass);
		rough = mix(rough, 0.45, frame);
		spec = mix(0.35, 0.12, glass);
		if (kind == 1) {
			// Plain trim: a bit lighter and smoother (painted concrete / cast stone).
			albedo = wall * 1.05;
			if (style == 0) {
				// Cast stone trim on brick: the brick pattern must not show.
				albedo = vcol.rgb * (0.48 + 0.25 * dot(tex, vec3(0.333))) * mix(0.85, 1.05, blotch);
			}
		}
	}

	ALBEDO = albedo;
	NORMAL_MAP = nmap;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
	EMISSION = emission;
}

shader_type sky;
// Day/night sky (world/env/day_night.gd drives every uniform, a few times per second at most,
// so the reflection/ambient cubemap only updates when something visibly changed).
//  * Day: the scanned sky photo, turned around the vertical axis so its sun follows the real sun.
//  * Dawn / dusk: the photo fades into a gradient with a glow around the low sun and a sun disc.
//  * Night: dark gradient, stars and a moon.
//  * Weather: the whole dome blends toward a flat grey overcast (cloudy / rain / storm).
// No TIME is used, so the sky is not redrawn into the cubemap every frame.

uniform sampler2D panorama : source_color, filter_linear;
uniform float pano_rot = 0.0;
uniform float photo_mix = 1.0;
uniform float photo_energy = 1.0;
uniform vec3 sky_top : source_color = vec3(0.3, 0.5, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.75, 0.8, 0.88);
uniform vec3 ground_col : source_color = vec3(0.35, 0.36, 0.38);
uniform vec3 glow_col : source_color = vec3(1.0, 0.5, 0.25);
uniform float glow = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float sun_disc = 0.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float moon = 0.0;
uniform float stars = 0.0;
uniform float overcast = 0.0;
uniform vec3 cloud_col : source_color = vec3(0.55, 0.57, 0.6);
uniform float flash = 0.0;

vec2 pano_uv(vec3 d) {
	vec2 c = vec2(atan(d.x, -d.z), acos(clamp(d.y, -1.0, 1.0)));
	if (c.x < 0.0) {
		c.x += 2.0 * PI;
	}
	return c / vec2(2.0 * PI, PI);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float up = clamp(h, 0.0, 1.0);

	// Procedural gradient (dawn, dusk, night).
	vec3 grad = mix(sky_horizon, sky_top, sqrt(up));
	float sd = max(dot(d, sun_dir), 0.0);
	float low = 1.0 - smoothstep(-0.05, 0.55, h);
	grad += glow_col * glow * (pow(sd, 8.0) * 0.9 + pow(sd, 2.0) * 0.3) * low;
	grad = mix(grad, ground_col, smoothstep(0.0, -0.08, h));

	// Sky photo turned so its sun sits where the light comes from.
	float cr = cos(pano_rot);
	float sr = sin(pano_rot);
	vec3 rd = vec3(cr * d.x - sr * d.z, d.y, sr * d.x + cr * d.z);
	vec3 photo = texture(panorama, pano_uv(rd)).rgb * photo_energy;
	vec3 col = mix(grad, photo, photo_mix);

	// Low sun disc (the photo has its own at day).
	col += vec3(1.0, 0.75, 0.45) * sun_disc * smoothstep(0.9993, 0.9997, sd) * 12.0 * step(-0.02, h);

	// Night: stars and the moon (skipped for the ambient/reflection cubemap).
	if (!AT_CUBEMAP_PASS) {
		if (stars > 0.0 && h > 0.0) {
			vec3 cell = floor(d * 260.0);
			float r = hash13(cell);
			vec3 f = fract(d * 260.0) - 0.5;
			float s = step(0.9965, r) * (1.0 - smoothstep(0.05, 0.3, length(f)));
			s *= 0.6 + 2.4 * fract(r * 913.7);
			col += vec3(0.85, 0.9, 1.0) * s * stars * smoothstep(0.0, 0.2, h) * (1.0 - overcast);
		}
	}
	float md = max(dot(d, moon_dir), 0.0);
	vec3 moon_c = vec3(0.92, 0.94, 1.0) * (smoothstep(0.99955, 0.99975, md) * 3.0 + pow(md, 300.0) * 0.12 + pow(md, 30.0) * 0.03);
	col += moon_c * moon * (1.0 - overcast * 0.85) * step(0.0, h);

	// Overcast: the dome turns grey; keep a hint of the photo's cloud shapes.
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 grey = cloud_col * mix(0.7, 1.05, smoothstep(-0.05, 0.5, h)) * mix(0.85, 1.15, clamp(lum, 0.0, 1.0));
	grey = mix(grey, ground_col, smoothstep(0.0, -0.08, h));
	col = mix(col, grey, overcast);
	col += vec3(0.75, 0.8, 1.0) * flash;
	COLOR = col;
}

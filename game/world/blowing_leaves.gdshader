shader_type spatial;
// Wind-blown leaves / litter. Each instance drifts with the wind from its own start
// point (instance origin, local to the follow box), wrapped into a 36 m box around
// the camera, hopping and tumbling. INSTANCE_CUSTOM = (speed, phase, spin, kind).
render_mode world_vertex_coords, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://world/terrain_noise.gdshaderinc"

uniform vec2 wind_dir = vec2(0.86, 0.5);
const float BOX = 36.0;

varying vec3 tint;
varying float fade;

mat3 rot(vec3 axis, float a) {
	float s = sin(a);
	float c = cos(a);
	float oc = 1.0 - c;
	return mat3(vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y + axis.z * s, oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s, oc * axis.y * axis.z - axis.x * s, oc * axis.z * axis.z + c));
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	vec3 inst = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 local = VERTEX - inst;
	// Start point: the instance's offset inside the box (independent of where the box is).
	vec2 start = (inst - NODE_POSITION_WORLD).xz;
	float gust = 0.6 + 0.4 * sin(TIME * 0.7 + cd.y);
	vec2 drift = start + wind_dir * TIME * cd.x * 1.4 * gust + vec2(sin(TIME * 0.9 + cd.y), cos(TIME * 0.7 + cd.y * 2.0)) * 0.8;
	vec2 cam = CAMERA_POSITION_WORLD.xz;
	vec2 w = cam + mod(drift - cam + BOX * 0.5, BOX) - BOX * 0.5;
	// Ground under the piece: sidewalks are raised, the park lawn and roads are not.
	vec2 m = mod(w + CITY_PITCH * 0.5, CITY_PITCH) - CITY_PITCH * 0.5;
	float on_block = step(abs(m.x), (CITY_PITCH - ROAD_W) * 0.5) * step(abs(m.y), (CITY_PITCH - ROAD_W) * 0.5);
	float ground = 0.15 * on_block * (1.0 - tn_park(w));
	float hop = abs(sin(TIME * (1.4 + cd.z * 0.1) + cd.y)) * 0.08 * gust;
	float lift = pow(max(sin(TIME * 0.23 + cd.y * 3.0), 0.0), 16.0) * 0.9;
	vec3 axis = normalize(vec3(sin(cd.y), 0.6, cos(cd.y * 1.3)));
	float spin = TIME * cd.z * (0.3 + hop + lift);
	vec3 p = rot(axis, spin) * local;
	VERTEX = vec3(w.x, ground + 0.02 + hop + lift, w.y) + p;
	NORMAL = rot(axis, spin) * vec3(0.0, 1.0, 0.0);
	tint = COLOR.rgb;
	float d = distance(w, cam);
	fade = 1.0 - smoothstep(14.0, 17.5, d);
	VERTEX.y -= (1.0 - fade) * 3.0;   // sink the far pieces instead of popping
}

void fragment() {
	ALBEDO = tint * (0.85 + 0.15 * sin(UV.x * 40.0));
	ROUGHNESS = 0.9;
	BACKLIGHT = tint * 0.4;
}

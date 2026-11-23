extends RefCounted
## Exterior ballistics shared by the live bullets and the scope reticle, so the
## holdover marks always match where the bullets really land.
##  * gravity 9.81 m/s^2, quadratic air drag a = -k |v| v (k from the rifle), no wind
##  * fixed-step integration (STEP) used everywhere, the reticle table included
##  * each rifle is zeroed at ZERO_RANGE: the bore is tilted up a little so the bullet
##    crosses the line of sight there (sight and bore share the same origin).

const G := 9.81
const STEP := 1.0 / 240.0
const ZERO_RANGE := 100.0
const MAX_TIME := 5.0
const TABLE_STEP := 100.0        # holdover marks every 100 m
const TABLE_MAX := 1500.0


## One integration step (semi-implicit Euler). Returns [pos, vel].
static func step(pos: Vector3, vel: Vector3, k: float, dt: float) -> Array:
	var a := Vector3(0.0, -G, 0.0) - vel * (k * vel.length())
	var v := vel + a * dt
	return [pos + v * dt, v]


## Flies a bullet in a vertical plane (x forward, y up) launched at `angle` above the
## line of sight. Returns {"d": [distances], "y": [heights], "t": [times], "v": [speeds]}
## sampled at every TABLE_STEP metres up to max_d.
static func trace(v0: float, k: float, angle: float, max_d: float) -> Dictionary:
	var out := {"d": [], "y": [], "t": [], "v": []}
	var pos := Vector3.ZERO
	var vel := Vector3(0.0, sin(angle), -cos(angle)) * v0
	var t := 0.0
	var next := TABLE_STEP
	while t < MAX_TIME and next <= max_d + 0.01:
		var r := step(pos, vel, k, STEP)
		var np: Vector3 = r[0]
		var nv: Vector3 = r[1]
		var d0 := -pos.z
		var d1 := -np.z
		while next <= d1 and next <= max_d + 0.01:
			var f := (next - d0) / maxf(d1 - d0, 1e-6)
			out["d"].append(next)
			out["y"].append(lerpf(pos.y, np.y, f))
			out["t"].append(t + STEP * f)
			out["v"].append(lerpf(vel.length(), nv.length(), f))
			next += TABLE_STEP
		pos = np
		vel = nv
		t += STEP
	return out


## Height of the bullet over the line of sight at distance d for a launch angle.
static func height_at(v0: float, k: float, angle: float, d: float) -> float:
	var pos := Vector3.ZERO
	var vel := Vector3(0.0, sin(angle), -cos(angle)) * v0
	var t := 0.0
	while t < MAX_TIME:
		var r := step(pos, vel, k, STEP)
		var np: Vector3 = r[0]
		if -np.z >= d:
			var f := (d + pos.z) / maxf(pos.z - np.z, 1e-6)
			return lerpf(pos.y, np.y, f)
		pos = np
		vel = r[1]
		t += STEP
	return -1000.0


## Bore elevation (radians) that zeroes the rifle at ZERO_RANGE.
static func zero_angle(v0: float, k: float) -> float:
	var lo := 0.0
	var hi := 0.02
	for i in 40:
		var mid := (lo + hi) * 0.5
		if height_at(v0, k, mid, ZERO_RANGE) < 0.0:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Holdover table for a rifle: for every 100 m, the angle (radians, positive = aim
## higher / mark below the centre) and the time of flight.
static func holdover_table(v0: float, k: float) -> Dictionary:
	var z := zero_angle(v0, k)
	var tr := trace(v0, k, z, TABLE_MAX)
	var angles: Array[float] = []
	for i in tr["d"].size():
		angles.append(atan2(-float(tr["y"][i]), float(tr["d"][i])))
	return {"zero": z, "d": tr["d"], "angle": angles, "t": tr["t"], "v": tr["v"]}

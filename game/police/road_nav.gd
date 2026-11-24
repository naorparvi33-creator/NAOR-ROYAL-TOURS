extends RefCounted
## Grid navigation on the city's road network (no navmesh needed).
## Roads run between the blocks along x = (k + 0.5) * PITCH and z = (k + 0.5) * PITCH.
## A mover that cannot see its goal first steps onto the nearest road, follows it to
## the row/column of the goal, turns, and walks/drives the last part directly.
## Must match world/city.gd (PITCH, RINGS).

const PITCH := 106.0
const RINGS := 2
const ON_ROAD := 7.5          # metres from a road centre line that count as "on" it
const BESIDE := 22.0          # goal this close to a road line is reached along that road

static var _lines: PackedFloat32Array = PackedFloat32Array()


static func lines() -> PackedFloat32Array:
	if _lines.is_empty():
		for k in range(-RINGS - 1, RINGS + 1):
			_lines.append((k + 0.5) * PITCH)
	return _lines


## Index of the road line nearest to a coordinate.
static func nearest_line(v: float) -> int:
	var ls := lines()
	var best := 0
	var bd := INF
	for i in ls.size():
		var d := absf(ls[i] - v)
		if d < bd:
			bd = d
			best = i
	return best


static func line(i: int) -> float:
	return lines()[clampi(i, 0, lines().size() - 1)]


static func node_pos(i: int, j: int) -> Vector3:
	return Vector3(line(i), 0.0, line(j))


## Nearest intersection to a point.
static func nearest_node(p: Vector3) -> Vector3:
	return node_pos(nearest_line(p.x), nearest_line(p.z))


## Next point to head for when walking/driving from `p` to `goal` along roads.
## Returns [point, is_road_point]. Call again every few metres.
static func next_point(p: Vector3, goal: Vector3) -> Array:
	var ix := nearest_line(p.x)
	var jz := nearest_line(p.z)
	var on_v := absf(p.x - line(ix)) < ON_ROAD      # on a north-south road
	var on_h := absf(p.z - line(jz)) < ON_ROAD      # on an east-west road
	var ig := nearest_line(goal.x)
	var jg := nearest_line(goal.z)
	if not on_v and not on_h:
		# Step onto the nearest road, toward the goal where that is shorter.
		var dx := absf(p.x - line(ix))
		var dz := absf(p.z - line(jz))
		if dx < dz:
			return [Vector3(line(ix), p.y, clampf(goal.z, p.z - 12.0, p.z + 12.0)), true]
		return [Vector3(clampf(goal.x, p.x - 12.0, p.x + 12.0), p.y, line(jz)), true]
	# Goal beside the road we are on: run along it to the goal.
	if on_v and absf(goal.x - line(ix)) < BESIDE:
		return [Vector3(line(ix), p.y, goal.z), true]
	if on_h and absf(goal.z - line(jz)) < BESIDE:
		return [Vector3(goal.x, p.y, line(jz)), true]
	var n := lines().size()
	if on_v and on_h:
		if ig == ix and jg == jz:
			return [goal, false]     # goal is in a corner of a block touching this crossing
		# At a crossing: take the axis with the longer way to go first.
		var go_x := absf(line(ig) - p.x) > absf(line(jg) - p.z)
		if ig == ix:
			go_x = false
		elif jg == jz:
			go_x = true
		if go_x:
			return [Vector3(line(clampi(ix + signi(ig - ix), 0, n - 1)), p.y, line(jz)), true]
		return [Vector3(line(ix), p.y, line(clampi(jz + signi(jg - jz), 0, n - 1))), true]
	if on_v:
		# Follow the north-south road to the next crossing toward the goal's row.
		var tj := jz
		var dz := signf(line(jg) - p.z)
		if dz != 0.0 and signf(line(jz) - p.z) != dz:
			tj = clampi(jz + int(dz), 0, n - 1)
		return [Vector3(line(ix), p.y, line(tj)), true]
	# On an east-west road: follow it to the next crossing toward the goal's column.
	var ti := ix
	var dx := signf(line(ig) - p.x)
	if dx != 0.0 and signf(line(ix) - p.x) != dx:
		ti = clampi(ix + int(dx), 0, n - 1)
	return [Vector3(line(ti), p.y, line(jz)), true]


## Point on the right-hand lane when driving from `p` toward `target`.
static func lane_point(p: Vector3, target: Vector3, offset: float) -> Vector3:
	var d := target - p
	d.y = 0.0
	if d.length() < 0.1:
		return target
	var right := d.normalized().cross(Vector3.UP)
	return target + right * offset

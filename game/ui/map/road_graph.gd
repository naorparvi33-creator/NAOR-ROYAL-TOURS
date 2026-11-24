extends RefCounted
## Road network of the city as a graph: one node per intersection on the road grid
## (roads run between the blocks at (k + 0.5) * PITCH), one edge per road segment.
## Used by the GPS: A* between intersections plus a short leg from / to the nearest
## point on a road. Positions are Vector2(x, z) on the ground plane.

## Street names: roads along Z (constant x) and roads along X (constant z), west->east / north->south.
const V_KEYS := ["st_v0", "st_v1", "st_v2", "st_v3", "st_v4", "st_v5"]
const H_KEYS := ["st_h0", "st_h1", "st_h2", "st_h3", "st_h4", "st_h5"]

var pitch := 106.0
var road_w := 16.0
var lines: PackedFloat32Array = []   # road centre coordinates (same for x and z)
var n := 0
## Edges that may not be used (e.g. a closed road): key "a:b" with a < b.
var blocked := {}


func setup(p_pitch: float, p_road_w: float, rings: int) -> void:
	pitch = p_pitch
	road_w = p_road_w
	lines.clear()
	for k in range(-rings - 1, rings + 1):
		lines.append((k + 0.5) * pitch)
	n = lines.size()


func node_pos(id: int) -> Vector2:
	return Vector2(lines[id / n], lines[id % n])


func node_id(i: int, j: int) -> int:
	return i * n + j


func min_coord() -> float:
	return lines[0]


func max_coord() -> float:
	return lines[n - 1]


func _segment_index(v: float) -> int:
	for k in n - 1:
		if v <= lines[k + 1]:
			return k
	return n - 2


## Nearest point on any road centre line: {point, a, b, street (loc key), along_z}.
func nearest(p: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	var lo := lines[0]
	var hi := lines[n - 1]
	for i in n:
		# Road along Z at x = lines[i].
		var z := clampf(p.y, lo, hi)
		var c := Vector2(lines[i], z)
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			var j := _segment_index(z)
			best = {"point": c, "a": node_id(i, j), "b": node_id(i, j + 1), "street": V_KEYS[i % V_KEYS.size()], "along_z": true}
		# Road along X at z = lines[i].
		var x := clampf(p.x, lo, hi)
		c = Vector2(x, lines[i])
		d = c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			var j2 := _segment_index(x)
			best = {"point": c, "a": node_id(j2, i), "b": node_id(j2 + 1, i), "street": H_KEYS[i % H_KEYS.size()], "along_z": false}
	return best


## Street name key for the road segment a->b (both on the grid).
func street_between(a: Vector2, b: Vector2) -> String:
	var mid := (a + b) * 0.5
	if absf(b.x - a.x) < absf(b.y - a.y):
		return V_KEYS[_closest_line(mid.x) % V_KEYS.size()]
	return H_KEYS[_closest_line(mid.y) % H_KEYS.size()]


func _closest_line(v: float) -> int:
	var best := 0
	for k in n:
		if absf(lines[k] - v) < absf(lines[best] - v):
			best = k
	return best


func _neighbours(id: int) -> Array[int]:
	var out: Array[int] = []
	var i := id / n
	var j := id % n
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ni: int = i + d.x
		var nj: int = j + d.y
		if ni < 0 or nj < 0 or ni >= n or nj >= n:
			continue
		var o := node_id(ni, nj)
		if blocked.has(_edge_key(id, o)):
			continue
		out.append(o)
	return out


func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


## Route along the roads from `from` to `to` (both anywhere in the city).
## Returns the polyline: from, road entry point, intersections..., road exit point, to.
func find_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if n < 2:
		return out
	var s := nearest(from)
	var t := nearest(to)
	var sp: Vector2 = s["point"]
	var tp: Vector2 = t["point"]
	var mid := PackedVector2Array()
	var same_seg: bool = (s["a"] == t["a"] and s["b"] == t["b"])
	if not same_seg:
		mid = _astar(sp, [s["a"], s["b"]], tp, [t["a"], t["b"]])
	_push(out, from)
	_push(out, sp)
	for q in mid:
		_push(out, q)
	_push(out, tp)
	_push(out, to)
	return _simplify(out)


## A* from a virtual start node (on a segment, linked to its two ends) to a virtual goal.
func _astar(sp: Vector2, s_links: Array, tp: Vector2, t_links: Array) -> PackedVector2Array:
	var total := n * n
	var START := total
	var GOAL := total + 1
	var g := {}
	var came := {}
	var open := {}
	g[START] = 0.0
	open[START] = sp.distance_to(tp)
	var closed := {}
	while not open.is_empty():
		# Small graph: a linear scan of the open set is fastest in GDScript.
		var cur := -1
		var best := INF
		for k in open:
			if float(open[k]) < best:
				best = open[k]
				cur = k
		open.erase(cur)
		if cur == GOAL:
			break
		closed[cur] = true
		var cur_pos := sp if cur == START else node_pos(cur)
		var nbrs: Array[int] = []
		if cur == START:
			for l in s_links:
				nbrs.append(int(l))
		else:
			nbrs = _neighbours(cur)
			if cur in t_links:
				nbrs.append(GOAL)
		for nb in nbrs:
			if closed.has(nb):
				continue
			var nb_pos := tp if nb == GOAL else node_pos(nb)
			var cost: float = float(g[cur]) + cur_pos.distance_to(nb_pos)
			# Small penalty per turn so the GPS prefers fewer corners on equal length.
			if came.has(cur):
				var prev: int = came[cur]
				var pp := sp if prev == START else node_pos(prev)
				var d1 := (cur_pos - pp).normalized()
				var d2 := (nb_pos - cur_pos).normalized()
				if d1.dot(d2) < 0.9:
					cost += 6.0
			if not g.has(nb) or cost < float(g[nb]):
				g[nb] = cost
				came[nb] = cur
				open[nb] = cost + nb_pos.distance_to(tp)
	var path := PackedVector2Array()
	if not came.has(GOAL):
		return path
	var c: int = came[GOAL]
	while c != START:
		path.append(node_pos(c))
		c = came[c]
	path.reverse()
	return path


func _push(arr: PackedVector2Array, p: Vector2) -> void:
	if arr.is_empty() or arr[arr.size() - 1].distance_to(p) > 0.5:
		arr.append(p)


## Drops points that lie on a straight line between their neighbours.
func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var d1 := (pts[i] - out[out.size() - 1]).normalized()
		var d2 := (pts[i + 1] - pts[i]).normalized()
		if d1.dot(d2) < 0.999:
			out.append(pts[i])
	out.append(pts[pts.size() - 1])
	return out


static func length_of(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## Next turn on a route seen from its first point:
## {dist, turn (-1 left, 1 right, 2 u-turn, 0 none = arrive), street (loc key), total}.
func next_turn(route: PackedVector2Array) -> Dictionary:
	var total := length_of(route)
	var acc := 0.0
	for i in range(1, route.size() - 1):
		acc += route[i - 1].distance_to(route[i])
		var din := route[i] - route[i - 1]
		var dout := route[i + 1] - route[i]
		if din.length() < 0.5 or dout.length() < 0.5:
			continue
		din = din.normalized()
		dout = dout.normalized()
		var dotv := din.dot(dout)
		# Skip the tiny first leg from the player onto the road.
		if i == 1 and route[0].distance_to(route[1]) < road_w:
			continue
		if dotv > 0.85:
			continue
		var cross := din.x * dout.y - din.y * dout.x
		var turn := 1 if cross > 0.0 else -1
		if dotv < -0.85:
			turn = 2
		# The last leg from the road to the destination is not a street.
		var street := ""
		if i + 1 < route.size() - 1:
			street = street_between(route[i], route[i + 1])
		return {"dist": acc, "turn": turn, "street": street, "total": total}
	return {"dist": total, "turn": 0, "street": "", "total": total}

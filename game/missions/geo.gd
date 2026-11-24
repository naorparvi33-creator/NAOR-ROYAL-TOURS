extends RefCounted
## City geometry helpers shared by the campaign scripts (story, events, collectibles,
## stunts). Mirrors the layout constants of world/city.gd:
##  * blocks at (i, j) * PITCH for i, j in -RINGS..RINGS (the park is block 0,0)
##  * road centre lines at (n + 0.5) * PITCH; "nodes" are the intersections, n in -RINGS..RINGS-1
##  * sidewalk side 0 = +X edge, 1 = +Z, 2 = -X, 3 = -Z

const PITCH := 106.0
const ROAD_W := 16.0
const BLOCK := 90.0
const CURB_H := 0.15
const RINGS := 2
const WALK_IN := 42.5        # sidewalk path, metres from the block centre
const WALL_IN := 41.3        # right against the building line
const LANE := 2.5            # mission AI cars drive this far right of the centre line


static func block_center(bi: int, bj: int) -> Vector3:
	return Vector3(bi * PITCH, 0.0, bj * PITCH)


static func side_out(side: int) -> Vector3:
	return [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)][side % 4]


## A point on the sidewalk of block (bi, bj), side `side`, t in -1..1 along that side.
static func walk_point(bi: int, bj: int, side: int, t: float, inset := WALK_IN) -> Vector3:
	var out := side_out(side)
	var along := out.cross(Vector3.UP)
	var p := block_center(bi, bj) + out * inset + along * t * (BLOCK * 0.5 - 6.0)
	p.y = CURB_H
	return p


## The road point just outside a sidewalk point (in the outer lane, for parked cars).
static func curb_road_point(bi: int, bj: int, side: int, t: float) -> Vector3:
	var p := walk_point(bi, bj, side, t, BLOCK * 0.5 + 2.2)
	p.y = 0.0
	return p


static func node_pos(n: Vector2i) -> Vector3:
	return Vector3((n.x + 0.5) * PITCH, 0.0, (n.y + 0.5) * PITCH)


static func node_valid(n: Vector2i) -> bool:
	return n.x >= -RINGS and n.x < RINGS and n.y >= -RINGS and n.y < RINGS


static func nearest_node(p: Vector3) -> Vector2i:
	var n := Vector2i(clampi(roundi(p.x / PITCH - 0.5), -RINGS, RINGS - 1), clampi(roundi(p.z / PITCH - 0.5), -RINGS, RINGS - 1))
	return n


static func neighbours(n: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if node_valid(n + d):
			out.append(n + d)
	return out


## Right-hand vector for driving along `dir` (cars face +Z, right is -X when driving +Z).
static func right_of(dir: Vector3) -> Vector3:
	return Vector3(dir.x, 0, dir.z).normalized().cross(Vector3.UP)


## Lane points for driving through a list of intersections (two points per road piece,
## the car rounds the corners itself).
static func lane_points(nodes: Array, lane := LANE) -> Array:
	var pts: Array = []
	for k in range(nodes.size() - 1):
		var a := node_pos(nodes[k])
		var b := node_pos(nodes[k + 1])
		var d := (b - a).normalized()
		var r := right_of(d) * lane
		if k > 0:
			# Where the incoming and outgoing lanes cross inside the intersection, so
			# turning cars stay off the sidewalk corners.
			var d_in := (a - node_pos(nodes[k - 1])).normalized()
			pts.append(a + right_of(d_in) * lane + r)
		pts.append(a + d * 14.0 + r)
		pts.append(b - d * 14.0 + r)
	return pts


## Height of the ground (anything on the world layer) under p, or `fallback`.
static func ground_y(world: World3D, p: Vector3, fallback := 0.0, from_h := 3.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, from_h, 0), p + Vector3(0, -6.0, 0), 1)
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return (hit["position"] as Vector3).y


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

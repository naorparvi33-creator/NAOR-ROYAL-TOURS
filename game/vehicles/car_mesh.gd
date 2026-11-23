class_name CarMesh
## Procedural vehicle bodies (all types in vehicles/vehicle_types.gd). Faces +Z.
## Cars: a body lofted from rounded cross-sections along a roof-line profile, a glass
## greenhouse with pillars, wheel wells with fender lips, door shut lines, chrome
## trims, light clusters with bezels, grille, bumpers, mirrors, a dark interior
## (seats, dash, steering wheel) and yellow licence plates. The motorcycle is built
## from tubes and shells, its fork / front wheel / bars are a separate mesh that steers.
##
## Surfaces (fixed order, see S_*): paint (dented on impacts), glass, trim (vertex
## coloured: plastics, plates, interior), chrome, head L/R, tail L/R. Head and tail
## each share one material per car so brake / head lights stay in sync; a broken
## lamp just gets the broken-lens material on its own surface.
## Geometry is built once per type and cached; every car gets its own ArrayMesh
## (cheap: add_surface_from_arrays) so dents and broken lights stay per car.

const L := 4.4
const W := 1.8
const EX := 0.35          # cross-section superellipse exponents (smaller = boxier)
const EY := 0.45
const VT := preload("res://vehicles/vehicle_types.gd")

enum { S_PAINT, S_GLASS, S_TRIM, S_CHROME, S_HEAD_L, S_HEAD_R, S_TAIL_L, S_TAIL_R, S_COUNT }

const C_BLACK := Color(0.035, 0.035, 0.04)
const C_PLASTIC := Color(0.07, 0.07, 0.075)
const C_INTERIOR := Color(0.11, 0.105, 0.1)
const C_SEAT := Color(0.16, 0.14, 0.13)
const C_PLATE := Color(0.95, 0.78, 0.08)
const C_WELL := Color(0.015, 0.015, 0.018)

static var _geo_cache := {}
static var _mat_cache := {}
static var _wheel_cache := {}
static var _rider_cache := {}


# ================================================================ public API

## Sedan, kept for older callers (police / traffic cars).
static func build(paint: Color) -> ArrayMesh:
	return build_type("sedan", paint)


## A new mesh of the given type with its own paint / light materials.
## Meta on the mesh: "kinds" (surface kind per index), "plate_f", "plate_r" (local
## plate centres, Vector3.ZERO if none), "head_mat", "tail_mat", "paint_mat".
static func build_type(vtype: String, paint: Color) -> ArrayMesh:
	var geo: Dictionary = _geometry(vtype)
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = paint
	paint_mat.metallic = 0.55
	paint_mat.roughness = 0.22
	paint_mat.clearcoat_enabled = true
	paint_mat.clearcoat = 0.8
	paint_mat.clearcoat_roughness = 0.1
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(0.95, 0.95, 0.9)
	head.emission_enabled = true
	head.emission = Color(1, 0.97, 0.85)
	head.emission_energy_multiplier = 1.5
	head.roughness = 0.1
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.7, 0.03, 0.03)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.03)
	tail.emission_energy_multiplier = 1.2
	tail.roughness = 0.15
	var mats := [paint_mat, shared_mat("glass"), shared_mat("trim"), shared_mat("chrome"), head, head, tail, tail]
	var mesh := ArrayMesh.new()
	var kinds: Array[int] = []
	var surfs: Array = geo["surfs"]
	for k in S_COUNT:
		if surfs[k] == null:
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfs[k])
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
		kinds.append(k)
	mesh.set_meta("kinds", kinds)
	mesh.set_meta("plate_f", geo["plate_f"])
	mesh.set_meta("plate_r", geo["plate_r"])
	mesh.set_meta("paint_mat", paint_mat)
	mesh.set_meta("head_mat", head)
	mesh.set_meta("tail_mat", tail)
	return mesh


## The cached paint-surface vertices of a type (for dents).
static func body_vertices(vtype: String) -> PackedVector3Array:
	var geo: Dictionary = _geometry(vtype)
	var arr: Array = geo["surfs"][S_PAINT]
	return (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()


## Rebuilds `mesh` with new paint-surface vertices, keeping every current material.
static func apply_body_vertices(mesh: ArrayMesh, vtype: String, verts: PackedVector3Array) -> void:
	var geo: Dictionary = _geometry(vtype)
	var surfs: Array = geo["surfs"]
	var mats: Array[Material] = []
	for i in mesh.get_surface_count():
		mats.append(mesh.surface_get_material(i))
	var kinds: Array = mesh.get_meta("kinds", [])
	mesh.clear_surfaces()
	for i in kinds.size():
		var k: int = kinds[i]
		var arr: Array = surfs[k]
		if k == S_PAINT:
			arr = arr.duplicate()
			arr[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(i, mats[i])


## Surface index of a kind in a mesh built by build_type (-1 if missing).
static func surface_of(mesh: ArrayMesh, kind: int) -> int:
	var kinds: Array = mesh.get_meta("kinds", [])
	return kinds.find(kind)


static func shared_mat(kind: String) -> StandardMaterial3D:
	if _mat_cache.has(kind):
		return _mat_cache[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"glass":
			m.albedo_color = Color(0.06, 0.08, 0.1, 0.62)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.6
			m.roughness = 0.04
		"trim":
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.roughness = 0.6
		"chrome":
			m.albedo_color = Color(0.82, 0.83, 0.85)
			m.metallic = 1.0
			m.roughness = 0.12
		"broken_lens":
			m.albedo_color = Color(0.08, 0.07, 0.07)
			m.roughness = 0.9
		"burnt":
			m.albedo_color = Color(0.045, 0.04, 0.035)
			m.roughness = 0.95
			m.metallic = 0.2
		"burnt_glass":
			m.albedo_color = Color(0.02, 0.02, 0.02, 0.9)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
		"tire":
			m.albedo_color = Color(0.045, 0.045, 0.048)
			m.roughness = 0.92
		"rim":
			m.albedo_color = Color(0.72, 0.73, 0.76)
			m.metallic = 0.9
			m.roughness = 0.28
		"rider":
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.roughness = 0.75
	_mat_cache[kind] = m
	return m


## Tyre + alloy rim (5 spokes) with its axle along X, outer face toward +X.
static func wheel_mesh(radius := 0.34, width := 0.24) -> ArrayMesh:
	var key := "%.3f_%.3f" % [radius, width]
	if _wheel_cache.has(key):
		return _wheel_cache[key]
	var mesh := ArrayMesh.new()
	var seg := 22
	# Tyre: a lathe of a rounded profile (radius, x) around the X axis.
	var hw := width * 0.5
	var r_in := radius * 0.68
	var prof: Array[Vector2] = [
		Vector2(r_in, -hw), Vector2(radius * 0.9, -hw), Vector2(radius * 0.98, -hw * 0.8),
		Vector2(radius, -hw * 0.45), Vector2(radius, hw * 0.45), Vector2(radius * 0.98, hw * 0.8),
		Vector2(radius * 0.9, hw), Vector2(r_in, hw)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(st, prof, seg)
	st.generate_normals()
	st.set_material(shared_mat("tire"))
	st.commit(mesh)
	# Rim: dished face, spokes, hub and the inner barrel.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rr := r_in * 1.01
	var face_x := hw * 0.55
	var rim_prof: Array[Vector2] = [Vector2(rr, -hw * 0.9), Vector2(rr, face_x), Vector2(rr * 0.9, face_x + 0.005)]
	_lathe(st, rim_prof, seg)
	st.set_smooth_group(-1)
	for i in 5:
		var a := TAU * i / 5.0
		var dir := Vector3(0, cos(a), sin(a))
		var side := Vector3(1, 0, 0).cross(dir)
		_box_b(st, Vector3(0.03, rr * 0.82, 0.055), Vector3(face_x - 0.01, 0, 0) + dir * rr * 0.47,
			Basis(Vector3(1, 0, 0), dir, side).orthonormalized())
	_cyl(st, Vector3(face_x - 0.04, 0, 0), Vector3(face_x + 0.012, 0, 0), rr * 0.2, 10, true)
	# Brake disc behind the spokes.
	_cyl(st, Vector3(-0.02, 0, 0), Vector3(0.0, 0, 0), rr * 0.78, 16, true)
	st.set_smooth_group(0)
	st.generate_normals()
	st.set_material(shared_mat("rim"))
	st.commit(mesh)
	_wheel_cache[key] = mesh
	return mesh


## Seated figure for the driver's seat (car) or riding pose (motorcycle). Local origin
## is the hip point; faces +Z. One vertex-coloured surface.
static func rider_mesh(moto: bool) -> ArrayMesh:
	var key := "moto" if moto else "car"
	if _rider_cache.has(key):
		return _rider_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var jacket := Color(0.09, 0.1, 0.13) if moto else Color(0.25, 0.28, 0.35)
	var jeans := Color(0.12, 0.15, 0.22)
	var skin := Color(0.72, 0.53, 0.4)
	var helmet := Color(0.06, 0.06, 0.07)
	var lean := 0.55 if moto else 0.12        # torso forward lean (rad)
	var torso_dir := Vector3(0, cos(lean), sin(lean))
	var shoulder := torso_dir * 0.52
	st.set_color(jacket)
	_capsule(st, Vector3(0, 0.05, 0), shoulder, 0.17, 0.2)
	# Head (helmet on the bike).
	var head := shoulder + torso_dir * 0.2 + Vector3(0, 0.03, 0.02)
	st.set_color(helmet if moto else skin)
	_ellipsoid(st, head, Vector3(0.13, 0.15, 0.15) if moto else Vector3(0.1, 0.12, 0.11), 10, 7)
	if moto:
		st.set_color(Color(0.2, 0.25, 0.3))
		_ellipsoid(st, head + Vector3(0, 0.0, 0.1), Vector3(0.1, 0.05, 0.06), 8, 4)    # visor
	else:
		st.set_color(Color(0.12, 0.08, 0.05))
		_ellipsoid(st, head + Vector3(0, 0.06, -0.01), Vector3(0.105, 0.07, 0.11), 8, 5)   # hair
	# Arms reach to the bars / wheel.
	var hands_z := 0.65 if moto else 0.5
	var hands_y := 0.3
	for sx in [-1.0, 1.0]:
		var sh := shoulder + Vector3(sx * 0.2, -0.03, 0)
		var hand := Vector3(sx * (0.3 if moto else 0.19), hands_y, hands_z)
		var elbow := (sh + hand) * 0.5 + Vector3(sx * 0.06, -0.08, -0.02)
		st.set_color(jacket)
		_capsule(st, sh, elbow, 0.055, 0.055)
		_capsule(st, elbow, hand, 0.05, 0.045)
		st.set_color(Color(0.05, 0.05, 0.05) if moto else skin)
		_ellipsoid(st, hand, Vector3(0.045, 0.045, 0.05), 6, 4)
		# Legs: thighs forward, shins down (car) or back to the pegs (bike).
		var hip := Vector3(sx * 0.1, 0.02, 0)
		var knee := Vector3(sx * (0.2 if moto else 0.13), 0.08 if moto else 0.1, 0.42 if moto else 0.45)
		var foot := Vector3(sx * 0.18, -0.38, 0.1) if moto else Vector3(sx * 0.13, -0.3, 0.72)
		st.set_color(jeans)
		_capsule(st, hip, knee, 0.085, 0.07)
		_capsule(st, knee, foot, 0.065, 0.055)
		st.set_color(Color(0.05, 0.04, 0.04))
		_ellipsoid(st, foot + Vector3(0, -0.02, 0.05), Vector3(0.05, 0.045, 0.11), 6, 4)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, shared_mat("rider"))
	_rider_cache[key] = mesh
	return mesh


# ================================================================ geometry (cached)

static func _geometry(vtype: String) -> Dictionary:
	if _geo_cache.has(vtype):
		return _geo_cache[vtype]
	var sp: Dictionary = VT.get_spec(vtype)
	var b := Builder.new()
	b.sp = sp
	if sp["style"] == "moto":
		_build_moto(b)
	else:
		_build_car(b)
	var surfs: Array = []
	for k in S_COUNT:
		surfs.append(b.commit(k))
	var geo := {"surfs": surfs, "plate_f": b.plate_f, "plate_r": b.plate_r}
	_geo_cache[vtype] = geo
	return geo


## Holds one SurfaceTool per surface kind while a body is assembled.
class Builder:
	var sp: Dictionary
	var tools: Array = []
	var used: Array[bool] = []
	var plate_f := Vector3.ZERO
	var plate_r := Vector3.ZERO

	func _init() -> void:
		for k in CarMesh.S_COUNT:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			if k == CarMesh.S_TRIM:
				st.set_color(CarMesh.C_PLASTIC)
			tools.append(st)
			used.append(false)

	func get_st(k: int) -> SurfaceTool:
		used[k] = true
		return tools[k]

	func commit(k: int) -> Variant:
		if not used[k]:
			return null
		var st: SurfaceTool = tools[k]
		st.generate_normals()
		return st.commit_to_arrays()


# ---------------------------------------------------------------- loft helpers

## Roof / shoulder height at u (-1 tail .. 1 nose), smooth between profile keys.
static func _top(sp: Dictionary, u: float) -> float:
	var prof: Array = sp["prof"]
	if u <= float(prof[0][0]):
		return float(prof[0][1])
	for i in prof.size() - 1:
		var u0: float = prof[i][0]
		var u1: float = prof[i + 1][0]
		if u <= u1:
			var t := smoothstep(u0, u1, u)
			return lerpf(float(prof[i][1]), float(prof[i + 1][1]), t)
	return float(prof[prof.size() - 1][1])


static func _hw(sp: Dictionary, u: float) -> float:
	var pinch := 0.1 if sp["style"] == "sports" else 0.06
	var w: float = sp["W"]
	return w * 0.5 * (1.0 - pinch * pow(absf(u), 5.0))


static func _u(sp: Dictionary, z: float) -> float:
	return clampf(z / (float(sp["L"]) * 0.5), -1.0, 1.0)


## Point on the body surface at (u, angle). e > 0 lifts it off the surface.
static func _P(sp: Dictionary, u: float, a: float, e := 0.0) -> Vector3:
	var top := _top(sp, u) + e
	var bot: float = float(sp["bottom"]) - e * 0.5
	var hw := _hw(sp, u) + e
	var hh := (top - bot) * 0.5
	var cy := bot + hh
	var c := cos(a)
	var s := sin(a)
	var x := hw * signf(c) * pow(absf(c), EX)
	var y := cy + hh * signf(s) * pow(absf(s), EY)
	return Vector3(x, y, u * float(sp["L"]) * 0.5)


## Angle on the right side (+X) where the body surface has height y.
static func _a_at(sp: Dictionary, u: float, y: float) -> float:
	var top := _top(sp, u)
	var bot: float = sp["bottom"]
	var hh := (top - bot) * 0.5
	var t := clampf((y - (bot + hh)) / hh, -1.0, 1.0)
	return asin(signf(t) * pow(absf(t), 1.0 / EY))


## Height of the body surface where its half width equals x (upper side).
static func _y_at_x(sp: Dictionary, u: float, x: float) -> float:
	var top := _top(sp, u)
	var bot: float = sp["bottom"]
	var hh := (top - bot) * 0.5
	var c := clampf(x / _hw(sp, u), 0.0, 1.0)
	c = pow(c, 1.0 / EX)
	var s := sqrt(maxf(1.0 - c * c, 0.0))
	return bot + hh + hh * pow(s, EY)


## Patch that follows the body surface between u0..u1 and heights y0..y1 on one side
## (side = 1 right / -1 left) or over the top (side = 0, y0 = edge height).
static func _patch(st: SurfaceTool, sp: Dictionary, u0: float, u1: float, y0: float, y1: float,
		side: int, e: float, nu: int, nv: int) -> void:
	var grid: Array = []
	for i in nu + 1:
		var u := lerpf(u0, u1, float(i) / nu)
		var a0: float
		var a1: float
		if side > 0:
			a0 = _a_at(sp, u, y0)
			a1 = _a_at(sp, u, y1)
		elif side < 0:
			a0 = PI - _a_at(sp, u, y1)
			a1 = PI - _a_at(sp, u, y0)
		else:
			a0 = _a_at(sp, u, y0)
			a1 = PI - a0
		var row: Array[Vector3] = []
		for j in nv + 1:
			row.append(_P(sp, u, lerpf(a0, a1, float(j) / nv), e))
		grid.append(row)
	for i in nu:
		for j in nv:
			_quad(st, grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])


# ---------------------------------------------------------------- car body

static func _build_car(b: Builder) -> void:
	var sp := b.sp
	var style: String = sp["style"]
	var Lh: float = float(sp["L"]) * 0.5
	var bottom: float = sp["bottom"]
	var wh: Dictionary = sp["wheel"]
	var paint := b.get_st(S_PAINT)
	var trim := b.get_st(S_TRIM)
	var chrome := b.get_st(S_CHROME)

	# --- main shell
	var stations := 30
	var ring := 24
	var rings: Array = []
	for i in stations + 1:
		var u := -1.0 + 2.0 * float(i) / stations
		var pts: Array[Vector3] = []
		for k in ring:
			pts.append(_P(sp, u, TAU * float(k) / ring))
		rings.append(pts)
	for i in stations:
		for k in ring:
			var k2 := (k + 1) % ring
			_quad(paint, rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])
	for end in [0, stations]:
		var pts: Array = rings[end]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		for k in ring:
			var k2 := (k + 1) % ring
			if end == 0:
				_tri(paint, c, pts[k2], pts[k])
			else:
				_tri(paint, c, pts[k], pts[k2])

	# --- wheel wells (dark) with a paint lip around them
	var arch_r: float = float(wh["r"]) + 0.07
	for wz in [float(wh["zf"]), float(wh["zr"])]:
		for side in [1, -1]:
			_arch(b, sp, wz, float(wh["y"]), arch_r, side)

	# --- greenhouse (glass, pillars, roof)
	var gh: Dictionary = sp["gh"]
	var belt_f := 0.0
	var belt_r := 0.0
	if not gh.is_empty():
		var res := _greenhouse(b, sp, gh)
		belt_f = res[0]
		belt_r = res[1]
	else:
		_van_glass(b, sp)

	# --- shut lines, handles, side trims
	var low := bottom + 0.12
	var doors: Array = []
	match style:
		"sedan":
			doors = [0.78, -0.2, -1.12]
		"hatch":
			doors = [0.7, -0.35, -1.45]
		"sports":
			doors = [0.55, -0.75]
		"pickup":
			doors = [1.2, 0.15, -0.38]
		"van":
			doors = [1.45, 0.55, -0.35]
	var door_top := (_top(sp, 0.0) - 0.04) if gh.is_empty() else (minf(belt_f, belt_r) - 0.02)
	if style == "van":
		door_top = 1.88
	for side in [1, -1]:
		for dz in doors:
			var u := _u(sp, float(dz))
			trim.set_color(C_BLACK)
			_patch(trim, sp, u - 0.0035, u + 0.0035, low, door_top, side, 0.003, 1, 6)
		# Handles at the rear edge of each door.
		for di in doors.size() - 1:
			var hz: float = float(doors[di]) - 0.2
			var hy := door_top - 0.14
			var hx := _side_x(sp, _u(sp, hz), hy)
			_box(chrome, Vector3(0.025, 0.035, 0.16), Vector3(side * (hx + 0.008), hy, hz))
		# Lower body moulding and sill.
		trim.set_color(C_PLASTIC)
		var mu0 := _u(sp, float(wh["zr"]) + arch_r + 0.05)
		var mu1 := _u(sp, float(wh["zf"]) - arch_r - 0.05)
		_patch(trim, sp, mu0, mu1, bottom + 0.02, bottom + 0.1, side, 0.004, 6, 2)
		if style in ["sedan", "pickup", "van"]:
			_patch(chrome, sp, mu0, mu1, bottom + 0.2, bottom + 0.225, side, 0.005, 6, 1)
	if style == "van":
		# Sliding door rail and the split of the rear doors.
		trim.set_color(C_BLACK)
		_patch(trim, sp, _u(sp, -1.5), _u(sp, 0.55), 1.62, 1.645, -1, 0.004, 6, 1)
		_box(trim, Vector3(0.012, 1.4, 0.02), Vector3(0, 1.15, -Lh - 0.005))
		_box(chrome, Vector3(0.18, 0.03, 0.03), Vector3(0.12, 1.15, -Lh - 0.02))

	# --- nose and tail
	var front_z := _face_z(sp, 1.0, float(sp["head"][1]) + float(sp["head"][3]) * 0.5,
		float(sp["head"][0]) + float(sp["head"][2]) * 0.5)
	var rear_z := _face_z(sp, -1.0, float(sp["tail"][1]) + float(sp["tail"][3]) * 0.5,
		float(sp["tail"][0]) + float(sp["tail"][2]) * 0.5)
	_lights(b, sp, front_z, rear_z)
	var gr: Array = sp["grille"]
	var gw: float = gr[0]
	var gy: float = gr[1]
	var gz := _face_z(sp, 1.0, gy + 0.1)
	trim.set_color(C_BLACK)
	_box(trim, Vector3(gw, 0.17 if style != "van" else 0.28, 0.08), Vector3(0, gy, gz - 0.02))
	for gi in 3:
		var yy := gy - 0.05 + gi * 0.05 if style != "van" else gy - 0.09 + gi * 0.09
		_box(chrome, Vector3(gw * 0.96, 0.014, 0.02), Vector3(0, yy, gz + 0.025))
	_frame(chrome, Vector3(0, gy, gz + 0.02), gw + 0.03, (0.17 if style != "van" else 0.28) + 0.03, 0.02)

	# Bumpers: dark plastic with a chrome strip on the classic shapes.
	var bw: float = float(sp["W"]) * 0.97
	var by := bottom + 0.1
	trim.set_color(C_PLASTIC)
	_box(trim, Vector3(bw, 0.2, 0.22), Vector3(0, by, _face_z(sp, 1.0, by + 0.1) - 0.04))
	_box(trim, Vector3(bw, 0.2, 0.22), Vector3(0, by, _face_z(sp, -1.0, by + 0.1) + 0.04))
	if style in ["sedan", "pickup", "van"]:
		_box(chrome, Vector3(bw * 0.9, 0.03, 0.03), Vector3(0, by + 0.07, _face_z(sp, 1.0, by + 0.1) + 0.08))
		_box(chrome, Vector3(bw * 0.9, 0.03, 0.03), Vector3(0, by + 0.07, _face_z(sp, -1.0, by + 0.1) - 0.08))
	if style == "pickup":
		# Steel bash plate and tow hook, side steps.
		_box(chrome, Vector3(0.9, 0.05, 0.3), Vector3(0, bottom - 0.05, Lh - 0.25))
		for side in [1, -1]:
			trim.set_color(C_BLACK)
			_box(trim, Vector3(0.18, 0.05, 1.5), Vector3(side * (float(sp["W"]) * 0.5 - 0.02), bottom - 0.03, 0.4))
	# Licence plates (invented numbers are drawn by car.gd with a Label3D).
	var py: float = sp["plate_y"]
	var pf := Vector3(0, py, _face_z(sp, 1.0, py + 0.07) + 0.075)
	var pr := Vector3(0, py, _face_z(sp, -1.0, py + 0.07) - 0.075)
	if style in ["pickup", "van"]:
		pr.y = bottom + 0.32
		pr.z = _face_z(sp, -1.0, pr.y + 0.07) - 0.03
	trim.set_color(C_PLATE)
	_box(trim, Vector3(0.52, 0.12, 0.012), pf)
	_box(trim, Vector3(0.52, 0.12, 0.012), pr)
	b.plate_f = pf + Vector3(0, 0, 0.008)
	b.plate_r = pr - Vector3(0, 0, 0.008)
	# Exhaust tips.
	var ex_y := bottom + 0.06
	var ex_z := _face_z(sp, -1.0, bottom + 0.15)
	var tips := [-0.55, 0.55] if style == "sports" else [-0.55]
	for tx in tips:
		_cyl(chrome, Vector3(float(tx), ex_y, ex_z + 0.15), Vector3(float(tx), ex_y, ex_z - 0.05), 0.045, 10, true)

	# Mirrors on the doors at the base of the A pillar.
	if not gh.is_empty():
		var mz: float = float(gh["z0"]) - 0.18
		var my := belt_f + 0.06
		for side in [1, -1]:
			var mx := _side_x(sp, _u(sp, mz), belt_f - 0.05)
			trim.set_color(C_BLACK)
			_box(trim, Vector3(0.12, 0.04, 0.06), Vector3(side * (mx + 0.04), my - 0.03, mz))
			_box(paint, Vector3(0.07, 0.11, 0.16), Vector3(side * (mx + 0.11), my + 0.02, mz), Basis(Vector3.UP, side * 0.15))
	else:
		for side in [1, -1]:
			trim.set_color(C_BLACK)
			_box(trim, Vector3(0.05, 0.24, 0.12), Vector3(side * (float(sp["W"]) * 0.5 + 0.1), 1.45, 1.42))
			_box(trim, Vector3(0.14, 0.03, 0.03), Vector3(side * (float(sp["W"]) * 0.5 + 0.03), 1.4, 1.42))

	# --- extras per style
	match style:
		"sports":
			# Rear wing on two struts, side air intakes, splitter.
			var wz := -Lh + 0.22
			var wy := _top(sp, _u(sp, wz)) + 0.2
			_box(paint, Vector3(1.55, 0.035, 0.3), Vector3(0, wy, wz), Basis(Vector3.RIGHT, -0.08))
			for sx in [-0.55, 0.55]:
				trim.set_color(C_BLACK)
				_box(trim, Vector3(0.04, 0.2, 0.12), Vector3(sx, wy - 0.1, wz))
			for side in [1, -1]:
				trim.set_color(C_BLACK)
				_patch(trim, sp, _u(sp, -0.95), _u(sp, -0.6), 0.48, 0.66, side, 0.004, 3, 3)
			_box(trim, Vector3(float(sp["W"]) * 0.9, 0.025, 0.2), Vector3(0, bottom - 0.02, Lh - 0.08))
		"hatch":
			# Roof spoiler and rear wiper.
			var z3: float = gh["z3"]
			_box(paint, Vector3(1.1, 0.04, 0.2), Vector3(0, float(gh["y1"]) + 0.005, float(gh["z2"]) - 0.08))
			trim.set_color(C_BLACK)
			_box(trim, Vector3(0.45, 0.02, 0.02), Vector3(0.05, float(gh["y0"]) + 0.12, z3 + 0.06), Basis(Vector3.BACK, 0.4))
		"pickup":
			var bed: Array = sp["bed"]
			var bz0: float = bed[0]
			var bz1: float = bed[1]
			var top_y := _top(sp, _u(sp, (bz0 + bz1) * 0.5))
			var inner := _hw(sp, _u(sp, (bz0 + bz1) * 0.5)) - 0.07
			# Tonneau cover over the bed, rails and a roll bar behind the cab.
			trim.set_color(Color(0.05, 0.05, 0.055))
			_box(trim, Vector3(inner * 2.0, 0.02, bz1 - bz0), Vector3(0, top_y + 0.005, (bz0 + bz1) * 0.5))
			for side in [1, -1]:
				_cyl(chrome, Vector3(side * inner, top_y + 0.03, bz0 + 0.05), Vector3(side * inner, top_y + 0.03, bz1 - 0.05), 0.022, 8, true)
				_cyl(chrome, Vector3(side * (inner - 0.05), top_y, bz1 - 0.12), Vector3(side * (inner - 0.08), top_y + 0.5, bz1 - 0.12), 0.035, 8, true)
			_cyl(chrome, Vector3(-(inner - 0.08), top_y + 0.5, bz1 - 0.12), Vector3(inner - 0.08, top_y + 0.5, bz1 - 0.12), 0.035, 8, true)
			# Tailgate shut line and handle.
			trim.set_color(C_BLACK)
			_box(trim, Vector3(float(sp["W"]) * 0.9, 0.015, 0.02), Vector3(0, top_y - 0.5, -Lh - 0.004))
			_box(chrome, Vector3(0.22, 0.05, 0.03), Vector3(0, top_y - 0.12, -Lh - 0.01))
			# Roof lights bar.
			trim.set_color(C_BLACK)
			_box(trim, Vector3(1.1, 0.06, 0.08), Vector3(0, float(gh["y1"]) + 0.04, float(gh["z1"]) - 0.1))

	# --- interior (seen through the glass and from the cockpit camera)
	_interior(b, sp)


## Dark wheel well with a paint lip, following the body side.
static func _arch(b: Builder, sp: Dictionary, wz: float, wy: float, r: float, side: int) -> void:
	var trim := b.get_st(S_TRIM)
	var paint := b.get_st(S_PAINT)
	var bottom: float = sp["bottom"]
	var seg := 14
	var a0 := -0.35
	var a1 := PI + 0.35
	var ring_in: Array[Vector3] = []
	var ring_out: Array[Vector3] = []
	var ring_lip: Array[Vector3] = []
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / seg)
		var z := wz + cos(a) * r
		var y := maxf(wy + sin(a) * r, bottom + 0.01)
		var yl := maxf(wy + sin(a) * (r + 0.05), bottom + 0.01)
		var zl := wz + cos(a) * (r + 0.05)
		ring_out.append(_side_pt(sp, z, y, side, 0.006))
		ring_lip.append(_side_pt(sp, zl, yl, side, 0.011))
		ring_in.append(_side_pt(sp, wz + cos(a) * 0.02, maxf(wy - 0.05, bottom + 0.01), side, 0.006))
	trim.set_color(C_WELL)
	for i in seg:
		if side < 0:
			_quad(trim, ring_in[i], ring_out[i], ring_out[i + 1], ring_in[i + 1])
			_quad(paint, ring_out[i], ring_lip[i], ring_lip[i + 1], ring_out[i + 1])
		else:
			_quad(trim, ring_in[i + 1], ring_out[i + 1], ring_out[i], ring_in[i])
			_quad(paint, ring_out[i + 1], ring_lip[i + 1], ring_lip[i], ring_out[i])


## Body side point at (z, y) on one side, lifted by e.
static func _side_pt(sp: Dictionary, z: float, y: float, side: int, e: float) -> Vector3:
	var u := _u(sp, z)
	var a := _a_at(sp, u, y)
	var p := _P(sp, u, a, e)
	p.x *= float(side)
	return p


static func _side_x(sp: Dictionary, u: float, y: float) -> float:
	return _P(sp, u, _a_at(sp, u, y)).x


## z of the nose (dir 1) or tail (dir -1) at height y: where the shell is tall
## enough (at half width x, the shell is rounded toward its edges).
static func _face_z(sp: Dictionary, dir: float, y: float, x := 0.0) -> float:
	var u := dir
	for i in 80:
		var h := _top(sp, u) if x <= 0.0 else _y_at_x(sp, u, x)
		if h >= y:
			break
		u -= dir * 0.01
	return u * float(sp["L"]) * 0.5


## Glass cabin on top of the body. Returns [belt height front, belt height rear].
static func _greenhouse(b: Builder, sp: Dictionary, gh: Dictionary) -> Array:
	var glass := b.get_st(S_GLASS)
	var paint := b.get_st(S_PAINT)
	var trim := b.get_st(S_TRIM)
	var chrome := b.get_st(S_CHROME)
	var z0: float = gh["z0"]
	var z1: float = gh["z1"]
	var z2: float = gh["z2"]
	var z3: float = gh["z3"]
	var y1: float = gh["y1"]
	var wb: float = gh["wb"]
	var wt: float = gh["wt"]
	# The base sits on the shoulder of the body where its width is wb.
	var y0f := _y_at_x(sp, _u(sp, z0), wb) - 0.012
	var y0r := _y_at_x(sp, _u(sp, z3), wb) - 0.012
	var corners := {}
	for s in [1, -1]:
		corners[s] = [Vector3(s * wb, y0f, z0), Vector3(s * wt, y1, z1), Vector3(s * wt, y1, z2), Vector3(s * wb, y0r, z3)]
	var R: Array = corners[1]
	var Lf: Array = corners[-1]
	# Side windows (right: outward is +X).
	_quad(glass, R[3], R[2], R[1], R[0])
	_quad(glass, Lf[0], Lf[1], Lf[2], Lf[3])
	# Windshield and rear glass.
	_quad(glass, R[0], R[1], Lf[1], Lf[0])
	_quad(glass, Lf[3], Lf[2], R[2], R[3])
	# Roof with a slight crown.
	var nseg := 4
	for i in nseg:
		var t0 := float(i) / nseg
		var t1 := float(i + 1) / nseg
		var x0 := lerpf(wt, -wt, t0)
		var x1 := lerpf(wt, -wt, t1)
		var c0 := 0.035 * (1.0 - pow(2.0 * t0 - 1.0, 2.0))
		var c1 := 0.035 * (1.0 - pow(2.0 * t1 - 1.0, 2.0))
		_quad(paint, Vector3(x0, y1 + c0, z2), Vector3(x1, y1 + c1, z2), Vector3(x1, y1 + c1, z1), Vector3(x0, y1 + c0, z1))
	# Headliner: the roof seen from below / from the cockpit.
	trim.set_color(Color(0.42, 0.4, 0.37))
	_quad(trim, Vector3(-wt, y1 - 0.012, z2), Vector3(wt, y1 - 0.012, z2), Vector3(wt, y1 - 0.012, z1), Vector3(-wt, y1 - 0.012, z1))
	# Pillars: A and C in paint, B in black; drip rail chrome.
	for s in [1, -1]:
		var c: Array = corners[s]
		var out := Vector3(float(s), 0, 0)
		_pillar(paint, c[0], c[1], out, 0.07, s, Vector3(0, 0, -1))
		_pillar(paint, c[3], c[2], out, 0.09 if sp["style"] != "hatch" else 0.06, s, Vector3(0, 0, 1))
		# B pillar halfway between the A and C pillars.
		var zb := lerpf(z1, z2, 0.42) if sp["style"] != "sports" else lerpf(z1, z2, 0.9)
		var pb_top := Vector3(s * wt, y1, zb)
		var yb := lerpf(y0f, y0r, inverse_lerp(z0, z3, zb))
		var pb_bot := Vector3(s * wb, yb, zb)
		trim.set_color(C_BLACK)
		_strip(trim, pb_bot, pb_top, Vector3(0, 0, 0.045), out * 0.006, s)
		# Chrome window line along the belt.
		_strip(chrome, c[0], c[3], Vector3(0, 0.012, 0), out * 0.008, -s)
		_strip(chrome, c[1], c[2], Vector3(0, 0.01, 0), out * 0.006 + Vector3(0, 0.004, 0), -s)
	# Wipers at the windshield base.
	trim.set_color(C_BLACK)
	for wx in [-0.1, 0.45]:
		_box(trim, Vector3(0.5, 0.015, 0.02), Vector3(float(wx) - 0.1, y0f + 0.04, z0 - 0.06), Basis(Vector3.BACK, 0.12))
	return [y0f, y0r]


## Thin strip from p0 to p1 widened by `half` and lifted by `lift` (outward).
static func _strip(st: SurfaceTool, p0: Vector3, p1: Vector3, half: Vector3, lift: Vector3, s: int) -> void:
	var a := p0 - half + lift
	var bb := p0 + half + lift
	var c := p1 + half + lift
	var d := p1 - half + lift
	st.set_smooth_group(-1)
	if s > 0:
		_quad(st, a, bb, c, d)
		_quad(st, d, c, bb, a)
	else:
		_quad(st, d, c, bb, a)
		_quad(st, a, bb, c, d)
	st.set_smooth_group(0)


## A pillar band along the window edge e0 -> e1, `w` wide toward `inward`.
static func _pillar(st: SurfaceTool, e0: Vector3, e1: Vector3, out: Vector3, w: float, s: int, inward: Vector3) -> void:
	var lift := out * 0.006
	var a := e0 + lift
	var bb := e1 + lift
	var c := e1 + inward * w + lift
	var d := e0 + inward * w + lift
	# Emit both windings so the band shows from outside and from the cockpit.
	st.set_smooth_group(-1)
	_quad(st, a, bb, c, d)
	_quad(st, d, c, bb, a)
	st.set_smooth_group(0)


## Van: flush windshield over the sloped nose, cab side windows.
static func _van_glass(b: Builder, sp: Dictionary) -> void:
	var glass := b.get_st(S_GLASS)
	var trim := b.get_st(S_TRIM)
	var u0 := 0.445
	var u1 := 0.645
	_patch(glass, sp, u0, u1, 1.25, 0.0, 0, 0.006, 6, 10)
	trim.set_color(C_BLACK)
	_patch(trim, sp, u1, u1 + 0.012, 1.2, 0.0, 0, 0.007, 1, 10)
	for side in [1, -1]:
		_patch(glass, sp, _u(sp, 0.62), _u(sp, 1.42), 1.38, 1.9, side, 0.006, 3, 3)
		trim.set_color(C_BLACK)
		_patch(trim, sp, _u(sp, 0.6), _u(sp, 0.64), 1.36, 1.92, side, 0.008, 1, 3)


static func _lights(b: Builder, sp: Dictionary, front_z: float, rear_z: float) -> void:
	var chrome := b.get_st(S_CHROME)
	var trim := b.get_st(S_TRIM)
	var hd: Array = sp["head"]
	var tl: Array = sp["tail"]
	for s in [1, -1]:
		var hst := b.get_st(S_HEAD_L if s > 0 else S_HEAD_R)
		var hp := Vector3(s * float(hd[0]), float(hd[1]), front_z - 0.03)
		_box(hst, Vector3(float(hd[2]), float(hd[3]), 0.12), hp)
		_box(chrome, Vector3(float(hd[2]) + 0.04, float(hd[3]) + 0.03, 0.1), hp - Vector3(0, 0, 0.018))
		# Daytime running strip and turn signal under the lamp.
		_box(hst, Vector3(float(hd[2]) * 0.8, 0.018, 0.04), hp + Vector3(0, -float(hd[3]) * 0.5 - 0.025, 0.035))
		var tst := b.get_st(S_TAIL_L if s > 0 else S_TAIL_R)
		var tp := Vector3(s * float(tl[0]), float(tl[1]), rear_z + 0.03)
		_box(tst, Vector3(float(tl[2]), float(tl[3]), 0.12), tp)
		trim.set_color(Color(0.85, 0.85, 0.82))
		var rev := Vector3(float(tl[2]) * 0.35, float(tl[3]) * 0.3, 0.02)
		_box(trim, rev, tp + Vector3(-s * float(tl[2]) * 0.25, -float(tl[3]) * 0.22, -0.055))
		trim.set_color(C_BLACK)
		_box(trim, Vector3(float(tl[2]) + 0.03, float(tl[3]) + 0.03, 0.1), tp + Vector3(0, 0, 0.018))
	# Third brake light on the roof edge / tailgate.
	var gh: Dictionary = sp["gh"]
	if not gh.is_empty():
		var t3 := b.get_st(S_TAIL_L)
		_box(t3, Vector3(0.36, 0.035, 0.03), Vector3(0, float(gh["y1"]) - 0.03, float(gh["z2"]) - 0.02))


static func _interior(b: Builder, sp: Dictionary) -> void:
	var trim := b.get_st(S_TRIM)
	var seat: Vector3 = sp["seat"]
	var gh: Dictionary = sp["gh"]
	var z_dash := seat.z + 0.8
	var y_dash := _y_at_x(sp, _u(sp, z_dash), 0.3) - 0.05
	var iw: float = float(sp["W"]) * 0.42
	trim.set_color(C_INTERIOR)
	_box(trim, Vector3(iw * 2.0, 0.2, 0.42), Vector3(0, y_dash - 0.05, z_dash - 0.1))
	# Instrument hood and centre console.
	trim.set_color(C_BLACK)
	_box(trim, Vector3(0.4, 0.07, 0.18), Vector3(seat.x, y_dash + 0.07, z_dash - 0.2))
	_box(trim, Vector3(0.22, 0.25, 0.7), Vector3(0, seat.y - 0.05, seat.z + 0.35))
	# Steering wheel (ring of segments) on a column.
	var wc := Vector3(seat.x, y_dash - 0.02, seat.z + 0.52)
	var wb := Basis(Vector3.RIGHT, -0.45)
	var n := 18
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := wc + wb * Vector3(cos(a0) * 0.18, sin(a0) * 0.18, 0)
		var p1 := wc + wb * Vector3(cos(a1) * 0.18, sin(a1) * 0.18, 0)
		_cyl(trim, p0, p1, 0.014, 5, false)
	_cyl(trim, wc, wc + wb * Vector3(0, 0, 0.3), 0.03, 6, true)
	_cyl(trim, wc + wb * Vector3(-0.17, 0, 0), wc + wb * Vector3(0.17, 0, 0), 0.015, 4, false)
	# Seats: cushion, backrest and head rest for both fronts, a bench behind.
	trim.set_color(C_SEAT)
	var eye: Vector3 = sp["eye"]
	var back_h := clampf(eye.y - 0.2 - seat.y, 0.3, 0.6)
	for sx in [seat.x, -seat.x]:
		_box(trim, Vector3(0.46, 0.14, 0.5), Vector3(sx, seat.y - 0.02, seat.z + 0.05))
		_box(trim, Vector3(0.46, back_h, 0.12), Vector3(sx, seat.y + back_h * 0.5 + 0.02, seat.z - 0.24), Basis(Vector3.RIGHT, -0.18))
		_box(trim, Vector3(0.24, 0.15, 0.08), Vector3(sx, eye.y - 0.08, seat.z - 0.3))
	if sp["style"] in ["sedan", "hatch"]:
		_box(trim, Vector3(iw * 1.9, 0.14, 0.5), Vector3(0, seat.y - 0.02, seat.z - 0.9))
		_box(trim, Vector3(iw * 1.9, 0.55, 0.12), Vector3(0, seat.y + 0.3, seat.z - 1.18), Basis(Vector3.RIGHT, -0.2))
	if sp["style"] == "van":
		# Bulkhead behind the cab.
		trim.set_color(C_INTERIOR)
		_box(trim, Vector3(iw * 2.0, 1.3, 0.05), Vector3(0, 1.3, seat.z - 0.55))


# ---------------------------------------------------------------- motorcycle

static func _build_moto(b: Builder) -> void:
	var paint := b.get_st(S_PAINT)
	var trim := b.get_st(S_TRIM)
	var chrome := b.get_st(S_CHROME)
	var glass := b.get_st(S_GLASS)
	var wh: Dictionary = b.sp["wheel"]
	var wy: float = wh["y"]
	var zr: float = wh["zr"]
	# Fuel tank, seat unit and tail.
	_ellipsoid(paint, Vector3(0, 0.97, 0.16), Vector3(0.15, 0.1, 0.3), 14, 8)
	_ellipsoid(paint, Vector3(0, 0.93, -0.58), Vector3(0.09, 0.06, 0.3), 10, 6)
	trim.set_color(C_BLACK)
	_ellipsoid(trim, Vector3(0, 0.91, -0.2), Vector3(0.13, 0.045, 0.3), 10, 5)
	# Radiator shrouds beside the tank and a belly pan.
	for s in [1.0, -1.0]:
		_ellipsoid(paint, Vector3(s * 0.13, 0.86, 0.4), Vector3(0.05, 0.12, 0.17), 8, 5)
	trim.set_color(C_PLASTIC)
	_ellipsoid(trim, Vector3(0, 0.36, 0.1), Vector3(0.14, 0.07, 0.32), 10, 5)
	# Frame tubes, swing arm, engine and exhaust.
	trim.set_color(Color(0.12, 0.12, 0.13))
	for s in [1.0, -1.0]:
		_cyl(trim, Vector3(s * 0.1, 0.98, 0.5), Vector3(s * 0.12, 0.55, -0.1), 0.028, 6, true)
		_cyl(trim, Vector3(s * 0.12, 0.55, -0.1), Vector3(s * 0.1, 0.9, -0.45), 0.022, 6, true)
		_cyl(trim, Vector3(s * 0.09, 0.5, -0.12), Vector3(s * 0.09, wy, zr), 0.03, 6, true)
		# Foot pegs.
		_cyl(trim, Vector3(s * 0.12, 0.45, -0.18), Vector3(s * 0.22, 0.45, -0.18), 0.015, 5, true)
	trim.set_color(Color(0.16, 0.16, 0.17))
	_box(trim, Vector3(0.26, 0.24, 0.38), Vector3(0, 0.5, 0.1))
	trim.set_color(Color(0.3, 0.3, 0.32))
	for fi in 4:
		_box(trim, Vector3(0.3, 0.018, 0.2), Vector3(0, 0.62 + fi * 0.045, 0.22), Basis(Vector3.RIGHT, -0.5))
	_cyl(trim, Vector3(-0.16, 0.48, 0.12), Vector3(0.16, 0.48, 0.12), 0.08, 10, true)
	_cyl(chrome, Vector3(0, 0.62, 0.26), Vector3(0, 0.82, 0.38), 0.07, 10, true)
	_cyl(chrome, Vector3(0, 0.6, 0.05), Vector3(0, 0.8, -0.05), 0.07, 10, true)
	_cyl(chrome, Vector3(0.1, 0.4, 0.2), Vector3(0.17, 0.38, -0.25), 0.035, 8, true)
	_cyl(chrome, Vector3(0.17, 0.38, -0.25), Vector3(0.18, 0.55, -0.75), 0.06, 10, true)
	trim.set_color(C_BLACK)
	_cyl(trim, Vector3(0.18, 0.55, -0.75), Vector3(0.185, 0.565, -0.79), 0.05, 10, true)
	# Rear fender, number plate and tail light.
	trim.set_color(C_PLASTIC)
	_box(trim, Vector3(0.14, 0.03, 0.35), Vector3(0, 0.78, -0.82), Basis(Vector3.RIGHT, -0.5))
	trim.set_color(C_PLATE)
	_box(trim, Vector3(0.24, 0.12, 0.012), Vector3(0, 0.7, -0.97), Basis(Vector3.RIGHT, -0.25))
	b.plate_r = Vector3(0, 0.7, -0.98)
	b.plate_f = Vector3.ZERO
	_box(b.get_st(S_TAIL_L), Vector3(0.13, 0.05, 0.05), Vector3(0, 0.92, -0.86))
	_box(b.get_st(S_TAIL_R), Vector3(0.05, 0.03, 0.04), Vector3(0.1, 0.8, -0.9))
	_box(b.get_st(S_TAIL_R), Vector3(0.05, 0.03, 0.04), Vector3(-0.1, 0.8, -0.9))
	# Front fairing nose, screen, headlight (fixed to the frame).
	_ellipsoid(paint, Vector3(0, 1.0, 0.64), Vector3(0.13, 0.11, 0.2), 12, 6)
	_quad(glass, Vector3(-0.13, 1.12, 0.66), Vector3(-0.08, 1.3, 0.5), Vector3(0.08, 1.3, 0.5), Vector3(0.13, 1.12, 0.66))
	_quad(glass, Vector3(0.13, 1.12, 0.66), Vector3(0.08, 1.3, 0.5), Vector3(-0.08, 1.3, 0.5), Vector3(-0.13, 1.12, 0.66))
	_box(b.get_st(S_HEAD_L), Vector3(0.18, 0.08, 0.06), Vector3(0, 1.02, 0.8))
	_box(b.get_st(S_HEAD_R), Vector3(0.06, 0.03, 0.04), Vector3(0.13, 0.98, 0.76))
	_box(b.get_st(S_HEAD_R), Vector3(0.06, 0.03, 0.04), Vector3(-0.13, 0.98, 0.76))
	# Instrument panel behind the screen.
	trim.set_color(C_BLACK)
	_box(trim, Vector3(0.16, 0.08, 0.06), Vector3(0, 1.12, 0.46), Basis(Vector3.RIGHT, 0.6))


## The steering part of the bike: forks, front fender, handle bars and mirrors.
## Pivot at the steering head; the front wheel itself is a separate wheel mesh.
static func moto_front_mesh() -> ArrayMesh:
	if _rider_cache.has("moto_front"):
		return _rider_cache["moto_front"]
	var sp: Dictionary = VT.get_spec("moto")
	var wh: Dictionary = sp["wheel"]
	var head := Vector3(0, 1.0, 0.5)
	var axle := Vector3(0, float(wh["y"]), float(wh["zf"])) - head
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [1.0, -1.0]:
		_cyl(st, Vector3(s * 0.085, 0.05, 0), Vector3(s * 0.085, 0, 0) + axle * 0.55, 0.03, 8, true)
	st.generate_normals()
	st.set_material(shared_mat("chrome"))
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.12, 0.12, 0.13))
	for s in [1.0, -1.0]:
		_cyl(st, Vector3(s * 0.085, 0, 0) + axle * 0.55, Vector3(s * 0.085, 0, 0) + axle, 0.04, 8, true)
		_cyl(st, Vector3(s * 0.03, 0.1, 0.0), Vector3(s * 0.36, 0.12, -0.05), 0.016, 6, true)
		st.set_color(C_BLACK)
		_cyl(st, Vector3(s * 0.26, 0.115, -0.04), Vector3(s * 0.37, 0.12, -0.05), 0.024, 6, true)
		_cyl(st, Vector3(s * 0.25, 0.12, -0.04), Vector3(s * 0.3, 0.32, -0.02), 0.008, 4, true)
		_box(st, Vector3(0.1, 0.06, 0.02), Vector3(s * 0.31, 0.34, -0.02))
		st.set_color(Color(0.12, 0.12, 0.13))
	_box(st, Vector3(0.22, 0.04, 0.12), Vector3(0, 0.08, 0))
	# Front fender over the tyre.
	st.set_color(C_PLASTIC)
	var fc := axle + Vector3(0, float(wh["r"]) + 0.06, 0)
	for i in 6:
		var a0 := lerpf(-0.6, 1.2, i / 6.0)
		var a1 := lerpf(-0.6, 1.2, (i + 1) / 6.0)
		var p0 := fc + Vector3(0, cos(a0) - 1.0, sin(a0)) * 0.36
		var p1 := fc + Vector3(0, cos(a1) - 1.0, sin(a1)) * 0.36
		_box(st, Vector3(0.14, 0.02, p0.distance_to(p1) + 0.01), (p0 + p1) * 0.5,
			Basis(Vector3.RIGHT, -(a0 + a1) * 0.5))
	st.generate_normals()
	st.set_material(shared_mat("trim"))
	st.commit(mesh)
	_rider_cache["moto_front"] = mesh
	return mesh


# ================================================================ primitives

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


## Axis-aligned (or rotated) box with flat shading.
static func _box(st: SurfaceTool, s: Vector3, pos: Vector3, basis := Basis()) -> void:
	_box_b(st, s, pos, basis)


static func _box_b(st: SurfaceTool, s: Vector3, pos: Vector3, basis: Basis) -> void:
	var X := basis.x * s.x * 0.5
	var Y := basis.y * s.y * 0.5
	var Z := basis.z * s.z * 0.5
	st.set_smooth_group(-1)
	_face(st, pos + X, Y, Z)
	_face(st, pos - X, Z, Y)
	_face(st, pos + Y, Z, X)
	_face(st, pos - Y, X, Z)
	_face(st, pos + Z, X, Y)
	_face(st, pos - Z, Y, X)
	st.set_smooth_group(0)


## Quad centred on c spanning +-u and +-v; faces along u x v.
static func _face(st: SurfaceTool, c: Vector3, u: Vector3, v: Vector3) -> void:
	_quad(st, c - u - v, c + u - v, c + u + v, c - u + v)


## Rectangular frame (four bars) in the XY plane around c.
static func _frame(st: SurfaceTool, c: Vector3, w: float, h: float, t: float) -> void:
	_box(st, Vector3(w, t, t), c + Vector3(0, h * 0.5, 0))
	_box(st, Vector3(w, t, t), c - Vector3(0, h * 0.5, 0))
	_box(st, Vector3(t, h, t), c + Vector3(w * 0.5, 0, 0))
	_box(st, Vector3(t, h, t), c - Vector3(w * 0.5, 0, 0))


## Cylinder from a to b (smooth sides, optional flat caps).
static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, r: float, seg: int, caps: bool) -> void:
	var axis := b - a
	if axis.length() < 0.0001:
		return
	var d := axis.normalized()
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	var u := d.cross(ref).normalized()
	var v := d.cross(u)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var o0 := (u * cos(a0) + v * sin(a0)) * r
		var o1 := (u * cos(a1) + v * sin(a1)) * r
		# Outward: (o1 - o0) x d ... ordered so normals point away from the axis.
		_quad(st, a + o0, a + o1, b + o1, b + o0)
		if caps:
			_tri(st, b, b + o0, b + o1)
			_tri(st, a, a + o1, a + o0)


## Capsule-ish limb: a tapered cylinder with ball ends.
static func _capsule(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float) -> void:
	var axis := b - a
	if axis.length() < 0.0001:
		return
	var d := axis.normalized()
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	var u := d.cross(ref).normalized()
	var v := d.cross(u)
	var seg := 8
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var c0 := u * cos(a0) + v * sin(a0)
		var c1 := u * cos(a1) + v * sin(a1)
		_quad(st, a + c0 * ra, a + c1 * ra, b + c1 * rb, b + c0 * rb)
	_ellipsoid(st, a, Vector3.ONE * ra, 8, 5)
	_ellipsoid(st, b, Vector3.ONE * rb, 8, 5)


static func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, seg: int, rings: int) -> void:
	for j in rings:
		var p0 := PI * float(j) / rings - PI * 0.5
		var p1 := PI * float(j + 1) / rings - PI * 0.5
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var q00 := c + Vector3(cos(p0) * cos(a0) * r.x, sin(p0) * r.y, cos(p0) * sin(a0) * r.z)
			var q10 := c + Vector3(cos(p0) * cos(a1) * r.x, sin(p0) * r.y, cos(p0) * sin(a1) * r.z)
			var q01 := c + Vector3(cos(p1) * cos(a0) * r.x, sin(p1) * r.y, cos(p1) * sin(a0) * r.z)
			var q11 := c + Vector3(cos(p1) * cos(a1) * r.x, sin(p1) * r.y, cos(p1) * sin(a1) * r.z)
			_quad(st, q00, q01, q11, q10)


## Revolves a (radius, x) profile around the X axis.
static func _lathe(st: SurfaceTool, prof: Array[Vector2], seg: int) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for k in prof.size() - 1:
			var p: Vector2 = prof[k]
			var q: Vector2 = prof[k + 1]
			var v00 := Vector3(p.y, cos(a0) * p.x, sin(a0) * p.x)
			var v01 := Vector3(p.y, cos(a1) * p.x, sin(a1) * p.x)
			var v10 := Vector3(q.y, cos(a0) * q.x, sin(a0) * q.x)
			var v11 := Vector3(q.y, cos(a1) * q.x, sin(a1) * q.x)
			_quad(st, v00, v01, v11, v10)

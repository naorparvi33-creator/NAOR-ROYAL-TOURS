extends RefCounted
## Places scanned street props (Poly Haven, CC0) around the city:
## roll-up shutters on shop fronts, fire escapes on brick buildings, trash cans,
## trash bags and utility boxes on sidewalks, covered cars parked at the curb and
## benches in the park. Every prop only draws within a limited range and uses the
## LODs Godot generates on import, so the phone renders only what is near.

const MODELS := "res://assets/models/%s/%s.gltf"
const SHOP_CELL := 4.5        # must match building.gdshader shop window spacing
const PARK_LANE := 46.3       # parking lane centre, measured from the block centre

var _city: Node3D
var _static: StaticBody3D
var _scenes := {}


func dress(city: Node3D, buildings: Array, rng: RandomNumberGenerator) -> void:
	_city = city
	_static = StaticBody3D.new()
	_static.name = "Props"
	city.add_child(_static)
	var c: Variant = city
	var half: float = c.BLOCK * 0.5
	var curb_h: float = c.CURB_H

	for b in buildings:
		var pos: Vector3 = b["pos"]
		var size: Vector3 = b["size"]
		var block: Vector3 = b["block"]
		for face in 4:
			var n := Vector3(1, 0, 0).rotated(Vector3.UP, -face * PI * 0.5)
			var along := n.cross(Vector3.UP)
			var half_depth := absf((size * 0.5).dot(n))
			var half_len := absf((size * 0.5).dot(along))
			var wall := pos + n * half_depth
			# Only faces that look onto a street.
			if absf((wall - block).dot(n)) < half - 6.0:
				continue
			var face_basis := Basis.looking_at(-n, Vector3.UP)   # +Z = out of the wall
			# Shutters on some shop windows (shop cells follow world coordinates).
			var u_axis := absf(n.x) > 0.5   # wall runs along z when the normal is along x
			var u0 := (wall.z if u_axis else wall.x) - half_len
			var u1 := (wall.z if u_axis else wall.x) + half_len
			var k := ceili(u0 / SHOP_CELL)
			while (k + 1) * SHOP_CELL <= u1:
				if rng.randf() < 0.22:
					var uc := (k + 0.5) * SHOP_CELL
					var p := Vector3(wall.x, curb_h, uc) if u_axis else Vector3(uc, curb_h, wall.z)
					var xf := Transform3D(face_basis, p + n * 0.02)
					_place("rollershutter_door", xf.translated_local(Vector3(-1.0, 0, 0)), 70.0, false)
				k += 1
			# Fire escape on tall brick buildings.
			if b["m"] == 0 and size.y > 16.0 and rng.randf() < 0.7:
				var off := rng.randf_range(-half_len * 0.4, half_len * 0.4)
				var p := wall + along * off
				p.y = curb_h + 4.2 + 3.7
				_place("modular_fire_escape", Transform3D(face_basis, p + n * 0.8), 160.0, true)
				if size.y > 28.0:
					_place("modular_fire_escape", Transform3D(face_basis, p + n * 0.8 + Vector3(0, 9.7, 0)), 160.0, true)
			# Trash bags piled against the wall now and then.
			if rng.randf() < 0.45:
				var bp := wall + n * 0.35 + along * rng.randf_range(-half_len * 0.8, half_len * 0.8)
				bp.y = curb_h
				for i in rng.randi_range(1, 3):
					var jitter := along * rng.randf_range(-0.6, 0.6) + n * rng.randf_range(0.0, 0.4)
					_place("trashbag", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), bp + jitter), 45.0, false)

	# Curb-side items and parked cars along every block side.
	var rings: int = c.RINGS
	var pitch: float = c.PITCH
	for i in range(-rings, rings + 1):
		for j in range(-rings, rings + 1):
			var center := Vector3(i * pitch, curb_h, j * pitch)
			var park := i == 0 and j == 0
			for side in 4:
				var out := Vector3(1, 0, 0).rotated(Vector3.UP, -side * PI * 0.5)
				var along := out.cross(Vector3.UP)
				var face := Basis.looking_at(out, Vector3.UP)   # +Z toward the building
				if rng.randf() < 0.7:
					var p := center + out * (half - 1.4) + along * rng.randf_range(-30, 30)
					_place("metal_trash_can", Transform3D(face, p), 55.0, false, Vector3(0.9, 0.9, 0.5))
				if rng.randf() < 0.5:
					var p := center + out * (half - 0.7) + along * rng.randf_range(-35, 35)
					_place("utility_box_01", Transform3D(face, p), 55.0, false, Vector3(0.5, 1.1, 0.45))
				if park:
					for t in [-22.0, 0.0, 22.0]:
						var bp: Vector3 = center + out * (half - 4.6) + along * (float(t) + 5.5)
						_place("painted_wooden_bench", Transform3D(Basis.looking_at(-out, Vector3.UP), bp), 50.0, false, Vector3(1.2, 0.9, 0.5))
				# Parked covered cars in the curb lane (kept clear of the crossings).
				var t := -32.0
				while t < 32.0:
					if rng.randf() < 0.3:
						var cp := Vector3(center.x, 0.0, center.z) + out * PARK_LANE + along * t
						var cb := Basis.looking_at(along if rng.randf() < 0.5 else -along, Vector3.UP)
						_place("covered_car", Transform3D(cb, cp), 150.0, true, Vector3(1.8, 1.4, 4.4))
					t += 7.0


## Instantiates a model, limits its draw distance and adds a box collider if given.
func _place(model: String, xf: Transform3D, draw_range: float, shadows: bool, collider := Vector3.ZERO) -> void:
	if not _scenes.has(model):
		_scenes[model] = load(MODELS % [model, model])
	var inst: Node3D = _scenes[model].instantiate()
	inst.transform = xf
	_city.add_child(inst)
	_setup_geometry(inst, draw_range, shadows)
	if collider != Vector3.ZERO:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = collider
		col.shape = bs
		col.transform = Transform3D(xf.basis, xf.origin + Vector3(0, collider.y * 0.5, 0))
		_static.add_child(col)


func _setup_geometry(n: Node, draw_range: float, shadows: bool) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.visibility_range_end = draw_range
		g.visibility_range_end_margin = 5.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		_setup_geometry(ch, draw_range, shadows)

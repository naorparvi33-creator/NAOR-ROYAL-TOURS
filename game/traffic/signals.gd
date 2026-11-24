extends Node3D
## Traffic-light lamps that follow the global phase cycle.
## world/city.gd places one traffic light per block corner as a MultiMesh with a
## permanently lit red bulb. This node switches that bulb off and draws lit red /
## amber / green bulbs on top as six small MultiMeshes (per road axis and colour);
## a phase change only toggles their visibility, so it costs nothing per frame.

const RED := 0
const AMBER := 1
const GREEN := 2
# Bulb centres in the traffic light mesh (see world/props.gd traffic_light()).
const BULBS := [Vector3(3.9, 5.3, -0.155), Vector3(3.9, 5.0, -0.155), Vector3(3.9, 4.7, -0.155)]
const COLORS := [Color(1.0, 0.1, 0.05), Color(1.0, 0.62, 0.05), Color(0.15, 1.0, 0.45)]

var _mmi := {}   # "z0" .. "x2" -> MultiMeshInstance3D
var _state := [-1, -1]


## world: the city node. Returns false if the city has no traffic lights.
func build(world: Node) -> bool:
	var xfs: Variant = world.get("_signals")
	if not (xfs is Array) or (xfs as Array).is_empty():
		return false
	_dim_baked_red(world, (xfs as Array).size())
	var lists := {"z": [], "x": []}
	for xf in xfs:
		var t: Transform3D = xf
		# The lamps face -Z, so the cars they control drive along +Z of the light.
		var approach: Vector3 = t.basis.z
		lists["z" if absf(approach.z) > 0.5 else "x"].append(t)
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	for axis in ["z", "x"]:
		for c in 3:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = COLORS[c]
			mat.emission_enabled = true
			mat.emission = COLORS[c]
			mat.emission_energy_multiplier = 3.0
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = sphere
			var list: Array = lists[axis]
			mm.instance_count = list.size()
			for i in list.size():
				var t: Transform3D = list[i]
				mm.set_instance_transform(i, Transform3D(t.basis, t * (BULBS[c] as Vector3)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visible = false
			add_child(mmi)
			_mmi[axis + str(c)] = mmi
	return true


## z_state / x_state: RED, AMBER or GREEN for traffic driving along Z / X.
func show_phase(z_state: int, x_state: int) -> void:
	var states := [z_state, x_state]
	var axes := ["z", "x"]
	for k in 2:
		if states[k] == _state[k]:
			continue
		_state[k] = states[k]
		for c in 3:
			(_mmi[axes[k] + str(c)] as Node3D).visible = c == states[k]


## The city's traffic light mesh has a red bulb that is always lit: make it dark.
func _dim_baked_red(world: Node, count: int) -> void:
	for ch in world.get_children():
		if not (ch is MultiMeshInstance3D):
			continue
		var mm: MultiMesh = (ch as MultiMeshInstance3D).multimesh
		if mm == null or mm.instance_count != count or mm.mesh == null or mm.mesh.get_surface_count() != 3:
			continue
		var red := mm.mesh.surface_get_material(1) as StandardMaterial3D
		if red and red.emission_enabled:
			red.emission_enabled = false
			red.albedo_color = Color(0.08, 0.09, 0.08)
			red.roughness = 0.3

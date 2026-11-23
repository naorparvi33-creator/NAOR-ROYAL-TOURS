extends Node3D
## Glowing ground ring + sign that teleports the player to / from the sniper range.
## Uses the player's context button: it sits in the "pickup" group with a ctx_label,
## and puts itself back after being "collected" so it can be used again.

var module: Node
var to_range := true
var _ring: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	add_to_group("pickup")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.6, 0.15, 0.6)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	_ring.mesh = tm
	_ring.material_override = glow
	_ring.position.y = 0.6
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.05
	cm.height = 2.4
	cm.radial_segments = 8
	pole.mesh = cm
	pole.material_override = Mats.plain(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	pole.position = Vector3(1.1, 1.2, 0)
	add_child(pole)
	var sign := Label3D.new()
	sign.text = Loc.t("snp_marker_range") if to_range else Loc.t("snp_marker_city")
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.85, 0.5)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(1.1, 2.75, 0)
	add_child(sign)


func _process(delta: float) -> void:
	_t += delta
	_ring.position.y = 0.6 + sin(_t * 2.0) * 0.06
	_ring.rotation.y = _t * 0.6


func collect(player: Node) -> void:
	if module:
		module.teleport(to_range)
	call_deferred("_restore", player)


func _restore(player: Node) -> void:
	add_to_group("pickup")
	# This was not a collectible: undo the player's pickup counter.
	if player and "collected" in player:
		player.collected = maxi(int(player.collected) - 1, 0)
		player.collected_changed.emit(player.collected)

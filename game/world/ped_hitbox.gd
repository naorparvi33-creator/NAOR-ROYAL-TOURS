extends StaticBody3D
## Collision capsule that follows a pedestrian; forwards bullet and fist hits to the manager.

var manager: Node
var ped: Dictionary


func on_hit(point: Vector3, damage: float, dir: Vector3, bullet: bool) -> void:
	manager.damage(ped, point, damage, dir, bullet)

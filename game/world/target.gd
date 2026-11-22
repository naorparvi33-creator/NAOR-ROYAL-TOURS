extends StaticBody3D
## Simple practice target that flashes when hit.

var _mat: StandardMaterial3D
var _base := Color(0.85, 0.85, 0.8)
var _flash := 0.0


func setup(mat: StandardMaterial3D) -> void:
	_mat = mat
	_base = mat.albedo_color
	set_process(false)


func on_hit(_point: Vector3) -> void:
	_flash = 1.0
	set_process(true)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_mat.albedo_color = _base.lerp(Color(1.0, 0.25, 0.1), _flash)
	if _flash <= 0.0:
		set_process(false)

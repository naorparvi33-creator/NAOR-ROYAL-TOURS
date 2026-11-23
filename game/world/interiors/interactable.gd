extends Node3D
## A spot the player's context button can use again and again (shop counter, bed,
## wardrobe, garage door, elevator). Joins the player's "pickup" scan with a label;
## player.gd calls interact() instead of collecting it.

var label_key := "ctx_use"
var action: Callable
var enabled := true:
	set(v):
		enabled = v
		if is_inside_tree():
			_sync_group()


func _ready() -> void:
	set_meta("ctx_label", label_key)
	_sync_group()


func set_label(key: String) -> void:
	label_key = key
	set_meta("ctx_label", key)


func interact(player: Node) -> void:
	if enabled and action.is_valid():
		action.call(player)


func _sync_group() -> void:
	if enabled:
		add_to_group("pickup")
	elif is_in_group("pickup"):
		remove_from_group("pickup")

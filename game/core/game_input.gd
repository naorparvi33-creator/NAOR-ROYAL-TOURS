extends Node
## One place that merges every input source (touch HUD, Bluetooth gamepad, keyboard)
## into a simple state the player reads. Gameplay code never reads raw devices.

## Movement in screen convention: x = right, y = -1 forward.
var touch_move := Vector2.ZERO
var touch_sprint := false
var fire_held := false          # main fire button (touch)
var fire_alt_held := false      # second fire button (touch)
var menu_open := false
## Driving (set by the touch HUD or keyboard while in a vehicle).
var vehicle_mode := false
var drive_gas := false
var drive_brake := false
var drive_handbrake := false
var drive_horn := false         # held horn (touch: the crouch button while driving)

## Accumulated look rotation in degrees (x = yaw, y = pitch). Consumed once per frame.
var _look := Vector2.ZERO
var _pulses := {}

const PAD_LOOK_DEG_PER_SEC := 190.0
const PAD_DEADZONE := 0.15


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()


func _setup_actions() -> void:
	_add_action("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add_action("fire", [_key(KEY_F), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add_action("ads", [_key(KEY_R), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action("jump", [_key(KEY_SPACE), _btn(JOY_BUTTON_A)])
	_add_action("crouch", [_key(KEY_C), _btn(JOY_BUTTON_B)])
	_add_action("swap", [_key(KEY_Q), _btn(JOY_BUTTON_Y)])
	_add_action("context", [_key(KEY_E), _btn(JOY_BUTTON_X)])
	_add_action("sprint", [_key(KEY_SHIFT), _btn(JOY_BUTTON_LEFT_STICK)])
	_add_action("menu", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)])
	_add_action("radio", [_key(KEY_T), _btn(JOY_BUTTON_DPAD_UP)])


func _add_action(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for e in events:
		InputMap.action_add_event(action_name, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard / gamepad one-shot actions.
	for a in ["jump", "crouch", "swap", "context", "menu", "ads", "radio"]:
		if event.is_action_pressed(a):
			pulse(a)


func _process(delta: float) -> void:
	if menu_open:
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down", PAD_DEADZONE)
	if stick != Vector2.ZERO:
		# Gentle response curve for precise aiming with a thumbstick.
		var curved := stick * stick.length()
		add_look(curved * PAD_LOOK_DEG_PER_SEC * delta * current_sens())


## Movement vector from every source. Length is 0..1.
func get_move() -> Vector2:
	if menu_open:
		return Vector2.ZERO
	var pad := Input.get_vector("move_left", "move_right", "move_forward", "move_back", PAD_DEADZONE)
	var v := touch_move if touch_move.length() > pad.length() else pad
	return v.limit_length(1.0)


func is_sprinting() -> bool:
	return touch_sprint or Input.is_action_pressed("sprint")


func is_firing() -> bool:
	if menu_open:
		return false
	return fire_held or fire_alt_held or Input.is_action_pressed("fire")


## 0 = normal, 1 = aiming down sights, 2 = sniper scope. Set by the player.
var aim_state := 0


## Separate sensitivity for walking around, ADS and scope.
func current_sens() -> float:
	match aim_state:
		1:
			return float(Settings.get_value("sens_ads"))
		2:
			return float(Settings.get_value("sens_scope"))
	return float(Settings.get_value("sens_look"))


func add_look(deg: Vector2) -> void:
	_look += deg


func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


## Fire a one-shot action (jump, crouch, swap, context, menu, ads).
func pulse(action: String) -> void:
	_pulses[action] = true


func consume(action: String) -> bool:
	if _pulses.get(action, false):
		_pulses[action] = false
		return true
	return false


func _physics_process(_delta: float) -> void:
	if vehicle_mode and not menu_open:
		# Keyboard / gamepad driving extras (touch sets the same flags from the HUD).
		if Input.is_action_pressed("jump"):
			drive_handbrake = true
		elif not _touch_handbrake:
			drive_handbrake = false


var _touch_handbrake := false


func set_touch_drive(gas: bool, brake: bool, hand: bool) -> void:
	drive_gas = gas
	drive_brake = brake
	_touch_handbrake = hand
	drive_handbrake = hand


func reset_touch() -> void:
	touch_move = Vector2.ZERO
	touch_sprint = false
	fire_held = false
	fire_alt_held = false
	drive_gas = false
	drive_brake = false
	drive_handbrake = false
	drive_horn = false
	_touch_handbrake = false

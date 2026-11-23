extends CharacterBody3D
## On-foot player: walk / run / sprint (analog joystick), jump, crouch,
## and automatic step-up, vault and ledge climb so no extra buttons are needed.

signal context_changed(visible: bool, label: String)
signal collected_changed(count: int)
signal health_changed(hp: float)
signal money_changed(amount: int)
signal vehicle_changed(v: Node3D)
signal died

const WALK := 2.6
const RUN := 5.0
const SPRINT := 7.6
const CROUCH_SPEED := 1.9
const AIM_SPEED := 2.6
const ACCEL := 13.0
const AIR_ACCEL := 3.0
const GRAVITY := 22.0
const JUMP_VELOCITY := 7.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const RADIUS := 0.33
const STEP_MAX := 0.45
const VAULT_MAX := 1.35
const CLIMB_MAX := 2.3
const CONTEXT_RANGE := 2.3

var rig: Node3D            # camera_rig.gd
var model: Node3D          # player_model.gd
var weapon: Node           # weapon_basic.gd
var crouching := false
var aiming := false
var collected := 0
var health := 100.0
var money := 0
var in_vehicle := false
var vehicle: Node3D = null
var _ctx_kind := ""
var _regen_delay := 0.0

var _shape: CapsuleShape3D
var _col: CollisionShape3D
var _move_t := 0.0         # vault / climb progress
var _move_dur := 0.0
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_arc := 0.0
var _ctx_target: Node3D = null
var _ctx_timer := 0.0
var _facing := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4      # world, cars and people
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	floor_constant_speed = true
	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape.height = STAND_HEIGHT
	_col = CollisionShape3D.new()
	_col.shape = _shape
	_col.position.y = STAND_HEIGHT * 0.5
	add_child(_col)

	model = preload("res://player/human_model.gd").new()
	model.model_path = "res://assets/characters/player.glb"
	add_child(model)

	rig = preload("res://player/camera_rig.gd").new()
	rig.target = self
	add_child(rig)

	weapon = preload("res://weapons/weapon_basic.gd").new()
	weapon.player = self
	add_child(weapon)


func _physics_process(delta: float) -> void:
	if in_vehicle:
		_drive_tick(delta)
		return
	_regen(delta)
	if _move_dur > 0.0:
		_process_vault(delta)
		return

	if GameInput.consume("crouch"):
		_set_crouch(not crouching)
	if GameInput.consume("ads"):
		aiming = not aiming
	if GameInput.consume("context"):
		_do_context()

	var input := GameInput.get_move()
	var sprint := GameInput.is_sprinting() and input.length() > 0.5 and not aiming
	if sprint and crouching:
		_set_crouch(false)
	var firing: bool = GameInput.is_firing()

	var dir: Vector3 = rig.flat_basis() * Vector3(input.x, 0, input.y)
	var amount := input.length()
	var max_speed := RUN
	if crouching:
		max_speed = CROUCH_SPEED
	elif aiming:
		max_speed = AIM_SPEED
	elif sprint:
		max_speed = SPRINT
	# Analog: light push = walk, full push = run.
	var speed := 0.0
	if amount > 0.05:
		speed = lerpf(WALK * 0.5, max_speed, clampf((amount - 0.05) / 0.85, 0.0, 1.0))
		if sprint:
			speed = SPRINT
	var target_vel: Vector3 = dir.normalized() * speed if amount > 0.05 else Vector3.ZERO

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var horiz := Vector3(velocity.x, 0, velocity.z).lerp(target_vel, 1.0 - exp(-accel * delta))
	velocity.x = horiz.x
	velocity.z = horiz.z

	if is_on_floor():
		if GameInput.consume("jump"):
			if crouching:
				_set_crouch(false)
			elif not _try_auto_traverse(dir if amount > 0.1 else -rig.flat_basis().z, true, false):
				velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
		GameInput.consume("jump")

	move_and_slide()

	# Automatic step-up / vault / climb when pushing into an obstacle.
	if is_on_floor() and is_on_wall() and amount > 0.3:
		var n := get_wall_normal()
		if n.dot(dir.normalized()) < -0.6:
			_try_auto_traverse(dir.normalized(), amount > 0.85, true)

	# Facing: toward movement while exploring, toward the camera while aiming/firing.
	var face_cam := aiming or firing
	if face_cam:
		_facing = lerp_angle(_facing, deg_to_rad(rig.yaw), 1.0 - exp(-20.0 * delta))
	elif horiz.length() > 0.3:
		_facing = lerp_angle(_facing, atan2(-horiz.x, -horiz.z), 1.0 - exp(-10.0 * delta))
	model.rotation.y = _facing

	rig.aiming = aiming
	rig.sprinting = sprint and horiz.length() > 4.0
	rig.eye_height = 1.1 if crouching else 1.6
	GameInput.aim_state = 1 if aiming else 0
	model.animate(delta, horiz.length(), is_on_floor(), crouching, face_cam)

	_ctx_timer -= delta
	if _ctx_timer <= 0.0:
		_ctx_timer = 0.15
		_update_context()

	if global_position.y < -50.0:
		reset_to_spawn()


func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	if not on and _blocked_above():
		return
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_shape.height = h
	_col.position.y = h * 0.5


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, CROUCH_HEIGHT, 0),
		global_position + Vector3(0, STAND_HEIGHT + 0.05, 0), 1)
	return not space.intersect_ray(q).is_empty()


## Looks at the obstacle in front and steps up, vaults or climbs automatically.
## Returns true if a traversal started.
func _try_auto_traverse(fwd: Vector3, allow_climb: bool, allow_step: bool) -> bool:
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return false
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var reach := RADIUS + 0.55
	var exclude := [get_rid()]
	# Something in front at knee height?
	var knee := _ray(space, feet + Vector3(0, 0.25, 0), feet + Vector3(0, 0.25, 0) + fwd * reach, exclude)
	if knee.is_empty():
		return false
	# Find the top surface of the obstacle.
	var probe_xz: Vector3 = knee["position"] + fwd * (RADIUS + 0.1)
	var top := _ray(space, Vector3(probe_xz.x, feet.y + CLIMB_MAX + 0.3, probe_xz.z),
		Vector3(probe_xz.x, feet.y + 0.05, probe_xz.z), exclude)
	if top.is_empty():
		return false
	var h: float = top["position"].y - feet.y
	if h < 0.12 or h > CLIMB_MAX:
		return false
	# Enough room to stand on top?
	var land: Vector3 = top["position"] + Vector3(0, 0.05, 0)
	if not _ray(space, land, land + Vector3(0, STAND_HEIGHT * 0.9, 0), exclude).is_empty():
		return false
	if h <= STEP_MAX:
		if not allow_step:
			return false
		_start_traverse(land + fwd * 0.15, 0.12, 0.0)
	elif h <= VAULT_MAX:
		_start_traverse(land + fwd * 0.35, 0.38, 0.35)
	elif allow_climb:
		_start_traverse(land + fwd * 0.3, 0.75, 0.25)
	else:
		return false
	return true


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, exclude)
	return space.intersect_ray(q)


func _start_traverse(to: Vector3, dur: float, arc: float) -> void:
	_move_from = global_position
	_move_to = to
	_move_dur = dur
	_move_t = 0.0
	_move_arc = arc
	velocity = Vector3.ZERO


func _process_vault(delta: float) -> void:
	_move_t += delta
	var t := clampf(_move_t / _move_dur, 0.0, 1.0)
	# Rise first, then move forward: feels like pulling up onto the ledge.
	var up_t := clampf(t * 1.6, 0.0, 1.0)
	var fwd_t := clampf((t - 0.3) / 0.7, 0.0, 1.0)
	var p := Vector3(
		lerpf(_move_from.x, _move_to.x, fwd_t),
		lerpf(_move_from.y, _move_to.y, up_t) + sin(t * PI) * _move_arc,
		lerpf(_move_from.z, _move_to.z, fwd_t))
	global_position = p
	model.animate(delta, 2.0, false, false, false)
	if t >= 1.0:
		_move_dur = 0.0
		var flat := (_move_to - _move_from)
		flat.y = 0.0
		velocity = flat.normalized() * 2.0


## One context button for everything: pick up, get into a car.
func _update_context() -> void:
	var best: Node3D = null
	var best_d := CONTEXT_RANGE
	var kind := ""
	for n in get_tree().get_nodes_in_group("pickup"):
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best = n
			best_d = d
			kind = "pickup"
	for v in get_tree().get_nodes_in_group("vehicle"):
		var d := global_position.distance_to((v as Node3D).global_position)
		if d < 3.4 and d < best_d + 1.0 and float(v.health) > 0.0:
			best = v
			best_d = d
			kind = "vehicle"
	if best != _ctx_target:
		_ctx_target = best
		_ctx_kind = kind
		var label := "ctx_pickup"
		if kind == "vehicle":
			label = "ctx_enter_car"
		elif best and best.has_meta("ctx_label"):
			label = best.get_meta("ctx_label")
		context_changed.emit(best != null, label)


func _do_context() -> void:
	if _ctx_target == null or not is_instance_valid(_ctx_target):
		return
	if _ctx_kind == "vehicle":
		enter_vehicle(_ctx_target)
		return
	if _ctx_target.has_method("collect"):
		_ctx_target.collect(self)
	else:
		_ctx_target.queue_free()
	_ctx_target.remove_from_group("pickup")
	_ctx_target = null
	collected += 1
	collected_changed.emit(collected)
	context_changed.emit(false, "")


# ------------------------------------------------------------ vehicles

func enter_vehicle(v: Node3D) -> void:
	in_vehicle = true
	vehicle = v
	v.enter(self)
	model.visible = false
	_col.disabled = true
	velocity = Vector3.ZERO
	aiming = false
	rig.set_vehicle(v)
	GameInput.vehicle_mode = true
	GameInput.reset_touch()
	Sfx.set_in_car(true)
	vehicle_changed.emit(v)
	context_changed.emit(true, "ctx_exit_car")


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var out: Vector3 = vehicle.exit()
	in_vehicle = false
	global_position = out
	reset_physics_interpolation()
	model.visible = true
	_col.disabled = false
	rig.vehicle = null
	GameInput.vehicle_mode = false
	GameInput.reset_touch()
	Sfx.set_in_car(false)
	vehicle = null
	_ctx_target = null
	vehicle_changed.emit(null)
	context_changed.emit(false, "")


func _drive_tick(_delta: float) -> void:
	global_position = vehicle.global_position + Vector3(0, 0.5, 0)
	if GameInput.consume("context"):
		exit_vehicle()
		return
	if GameInput.consume("swap") or GameInput.consume("radio"):
		Sfx.next_station()
	GameInput.consume("jump")
	GameInput.consume("crouch")
	GameInput.consume("ads")
	if float(vehicle.health) <= 0.0:
		exit_vehicle()


# ------------------------------------------------------------ health and money

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_regen_delay = 5.0
	health_changed.emit(health)
	model.flinch()
	if health <= 0.0:
		died.emit()


func _regen(delta: float) -> void:
	_regen_delay -= delta
	if _regen_delay <= 0.0 and health < 100.0:
		health = minf(health + delta * 4.0, 100.0)
		health_changed.emit(health)


func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	money_changed.emit(money)
	if amount > 0:
		Sfx.play_ui("money")


func respawn_after_death() -> void:
	if in_vehicle:
		exit_vehicle()
	add_money(-mini(money, 100))      # hospital bill
	health = 100.0
	health_changed.emit(health)
	reset_to_spawn()


var spawn_point := Vector3(0, 1, 0)


func reset_to_spawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	reset_physics_interpolation()

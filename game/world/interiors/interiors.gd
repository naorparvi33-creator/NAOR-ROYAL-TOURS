extends Node3D
## Enterable buildings and services (feature module, created from world/main.gd).
##  * Safehouse: ground-floor apartment near the park. Bed = sleep (skips 8 hours,
##    restores health, saves the game), wardrobe = change outfit, garage with a roll-up
##    door; a car parked inside is saved and comes back next time.
##  * Gun shop: ammo for pistol / rifle / sniper rifles, weapon unlocks, body armour.
##  * Clothing store (outfits tint the player's shirt / pants / shoes), restaurant (eat to
##    heal), hospital (respawn point, treatment), police station (pay a fine to clear the
##    wanted level), apartment tower with a lobby, stairs and an elevator to a roof
##    that makes a good sniping spot.
## The buildings are real city buildings carved hollow on their street side (carver.gd),
## chosen at start-up near preferred spots, so city.gd stays untouched.
## Everything is used with the existing context button; menus are big touch buttons.
##
## Ammo and armour live here: player.get_meta("armour") / interiors.ammo for other modules.

const Carver := preload("res://world/interiors/carver.gd")
const Sites := preload("res://world/interiors/sites.gd")
const Interactable := preload("res://world/interiors/interactable.gd")
const ShopMenu := preload("res://world/interiors/shop_menu.gd")
const GarageDoor := preload("res://world/interiors/garage_door.gd")
const Strings := preload("res://world/interiors/strings.gd")
const SAVE_PATH := "user://interiors.cfg"

## Preferred spots (x, z) for each place; the nearest suitable street face wins.
const SITES := [
	{"id": "safehouse", "target": Vector2(0, 66), "w": 18.0, "d": 9.0},
	{"id": "hospital", "target": Vector2(-66, 45), "w": 15.0, "d": 11.0},
	{"id": "gunshop", "target": Vector2(66, -30), "w": 12.0, "d": 9.0},
	{"id": "clothes", "target": Vector2(-66, -30), "w": 14.0, "d": 10.0},
	{"id": "restaurant", "target": Vector2(30, -66), "w": 14.0, "d": 10.0},
	{"id": "police", "target": Vector2(66, 50), "w": 15.0, "d": 11.0},
	{"id": "tower", "target": Vector2(-40, -66), "w": 9.8, "d": 8.4, "min_top": 10.5, "max_top": 27.0},
]

## Weapons that must be bought (any other weapon key is owned from the start).
const WEAPON_PRICES := {"weapon_rifle": 900, "weapon_sniper_medium": 3500, "weapon_sniper_heavy": 6000}
## [rounds per pack, price, max carried]
const AMMO := {"pistol": [24, 60, 360], "rifle": [90, 180, 900], "sniper": [10, 150, 120]}
const ARMOUR_PRICE := 400
const ARMOUR_ABSORB := 0.75       # share of every hit the vest takes while it lasts

const FOOD := [
	{"key": "food_falafel", "price": 15, "heal": 25.0},
	{"key": "food_burger", "price": 25, "heal": 50.0},
	{"key": "food_family", "price": 45, "heal": 100.0},
]
const TREATMENT_PRICE := 150

## Outfits: colours multiply the model's shirt / pants / shoes materials (null = original).
const OUTFITS := [
	{"id": "street", "price": 0, "shirt": null, "pants": null, "shoes": null},
	{"id": "red", "price": 180, "shirt": Color(0.72, 0.08, 0.08), "pants": Color(0.55, 0.6, 0.78), "shoes": Color(0.95, 0.95, 0.95)},
	{"id": "sport", "price": 150, "shirt": Color(0.95, 0.72, 0.08), "pants": Color(0.18, 0.18, 0.2), "shoes": Color(0.15, 0.15, 0.16)},
	{"id": "navy", "price": 220, "shirt": Color(0.1, 0.15, 0.36), "pants": Color(0.9, 0.78, 0.55), "shoes": Color(0.35, 0.22, 0.14)},
	{"id": "pink", "price": 200, "shirt": Color(0.92, 0.45, 0.6), "pants": Color(0.32, 0.38, 0.55), "shoes": Color(0.95, 0.95, 0.95)},
	{"id": "black", "price": 250, "shirt": Color(0.07, 0.07, 0.08), "pants": Color(0.3, 0.3, 0.33), "shoes": Color(0.08, 0.08, 0.08)},
	{"id": "olive", "price": 400, "shirt": Color(0.3, 0.35, 0.2), "pants": Color(0.42, 0.38, 0.28), "shoes": Color(0.25, 0.2, 0.14)},
	{"id": "white", "price": 600, "shirt": Color(0.98, 0.98, 0.97), "pants": Color(1.6, 1.6, 1.6), "shoes": Color(0.3, 0.2, 0.12)},
]

var main: Node
var player: CharacterBody3D
var menu: CanvasLayer

# Persistent state.
var armour := 0.0
var ammo := {"pistol": 60, "rifle": 0, "sniper": 20}
var owned := {}               # weapon key -> true (only the ones that must be bought)
var outfits := ["street"]
var outfit := "street"

var sites := {}               # id -> {root, info, cv basis/origin}
var hospital_spawn: Variant = null
var _garage_door: Node3D = null
var _garage_root: Node3D = null
var _garage_box := AABB()
var _clerks: Array = []
var _last_hp := 100.0
var _guard := false
var _hud: Control
var _fade: ColorRect
var _layer: CanvasLayer
var _visual_id := 0
var _check_t := 0.0
var _busy := false


func _ready() -> void:
	Loc.register(Strings.TABLE)
	add_to_group("interiors")     # missions ask is_owned() / give_mission_ammo()
	add_to_group("new_game_listeners")
	player = main.player
	_load_state()
	_build_sites()
	_setup_ui()
	_setup_combat()
	apply_outfit()
	_restore_garage_car()
	if hospital_spawn != null:
		player.spawn_point = hospital_spawn


# ================================================================== world

func _build_sites() -> void:
	var city: Node3D = main.world
	var cv: Variant = Carver.new(city)
	var builder: Variant = Sites.new()
	var used := {}
	var buildings: Array = city.get("_buildings")
	for s in SITES:
		var pick := _pick_face(cv, buildings, s, used)
		if pick.is_empty():
			push_warning("interiors: no building for " + str(s["id"]))
			continue
		var rec: Dictionary = pick["rec"]
		used[str(rec["pos"])] = true
		cv.begin(rec, pick["n"])
		var root := Node3D.new()
		root.name = "Site_" + str(s["id"])
		root.transform = Transform3D(cv.basis(), cv.origin)
		add_child(root)
		var cx: float = pick["cx"]
		var info: Dictionary = builder.call("build_" + str(s["id"]), cv, root, cx)
		cv.finish()
		_clear_front(city, root, info.get("lot_clear", [cx - 8.0, cx + 8.0]), info.get("garage_lane", []))
		sites[s["id"]] = {"root": root, "info": info}
		_add_uses(str(s["id"]), root, info)
		for c in info.get("clerks", []):
			_add_clerk(root, c[0], float(c[1]), str(c[2]))
		var mk := Node3D.new()
		mk.position = Vector3(cx, 0, -1.0)
		mk.add_to_group("map_marker")
		mk.set_meta("map_kind", "hospital" if s["id"] == "hospital" else "shop")
		mk.set_meta("map_label", Loc.t("place_" + str(s["id"])))
		root.add_child(mk)
		if s["id"] == "hospital":
			hospital_spawn = root.to_global(info["spawn"])
		if s["id"] == "safehouse":
			_setup_garage(root, info)


## Finds the street face nearest the site's preferred spot that fits the rooms.
func _pick_face(cv: Variant, buildings: Array, s: Dictionary, used: Dictionary) -> Dictionary:
	var target := Vector3(s["target"].x, 0, s["target"].y)
	var w: float = s["w"]
	var need_d: float = float(s["d"]) + 3.0
	var best := {}
	var best_score := INF
	for pass_i in 2:
		for rec in buildings:
			if used.has(str(rec["pos"])):
				continue
			var size: Vector3 = rec["size"]
			if s.has("min_top") and size.y < float(s["min_top"]):
				continue
			if pass_i == 0 and s.has("max_top") and size.y > float(s["max_top"]):
				continue
			for n in cv.street_faces(rec):
				var nn: Vector3 = n
				var d := -nn
				var u := Vector3.UP.cross(d)
				var length := absf(size.dot(u))
				var depth := absf(size.dot(d))
				if length < w + 6.0 or depth < need_d:
					continue
				var pos: Vector3 = rec["pos"]
				var fc := Vector3(pos.x, 0, pos.z) + nn * depth * 0.5
				var lim := length * 0.5 - w * 0.5 - 3.0
				var t := clampf((target - fc).dot(u), -lim, lim)
				var score := (fc + u * t).distance_to(target)
				if score < best_score:
					best_score = score
					best = {"rec": rec, "n": nn, "cx": t}
		if not best.is_empty():
			break
	return best


## Removes street props (shutters, bags, fire escapes, covered cars) in front of a site,
## and for the garage also palms / lamps and parked cars in the driveway.
func _clear_front(city: Node3D, root: Node3D, xr: Array, lane: Array) -> void:
	var inv := root.global_transform.affine_inverse()
	var x0: float = xr[0]
	var x1: float = xr[1]
	for ch in city.get_children():
		if not (ch is Node3D):
			continue
		var n := ch as Node3D
		var lp: Vector3 = inv * n.global_position
		if n.scene_file_path.contains("/assets/models/"):
			var inside := lp.x > x0 and lp.x < x1 and lp.z > -4.5 and lp.z < 1.5
			var drive := not lane.is_empty() and lp.x > float(lane[0]) - 2.5 and lp.x < float(lane[1]) + 2.5 and lp.z > -7.5 and lp.z < 0.5
			if inside or drive:
				n.queue_free()
		elif n.is_in_group("vehicle") and not lane.is_empty():
			if lp.x > float(lane[0]) - 2.5 and lp.x < float(lane[1]) + 2.5 and lp.z > -7.5 and lp.z < 0.5:
				n.queue_free()
		elif n is MultiMeshInstance3D and n.get_script() == null and not lane.is_empty():
			var mm := (n as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				var ip: Vector3 = inv * xf.origin
				if ip.x > float(lane[0]) - 0.8 and ip.x < float(lane[1]) + 0.8 and ip.z > -4.5 and ip.z < 0.5:
					mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - Vector3(0, 60, 0)))
	# Colliders of removed props / trees / poles.
	var bodies: Array = []
	var props := city.get_node_or_null("Props")
	if props:
		bodies.append(props)
	if not lane.is_empty():
		bodies.append(city.get("_static"))
	for bd in bodies:
		for col in (bd as Node).get_children():
			if not (col is CollisionShape3D):
				continue
			var cs := col as CollisionShape3D
			var lp: Vector3 = inv * cs.global_position
			var is_pole := cs.shape is CylinderShape3D
			if bd == props:
				var inside := lp.x > x0 and lp.x < x1 and lp.z > -4.5 and lp.z < 1.5
				var drive := not lane.is_empty() and lp.x > float(lane[0]) - 2.5 and lp.x < float(lane[1]) + 2.5 and lp.z > -7.5 and lp.z < 0.5
				if inside or drive:
					cs.queue_free()
			elif is_pole and lp.x > float(lane[0]) - 0.8 and lp.x < float(lane[1]) + 0.8 and lp.z > -4.5 and lp.z < 0.5:
				cs.queue_free()


func _add_uses(site_id: String, root: Node3D, info: Dictionary) -> void:
	var uses: Dictionary = info.get("use", {})
	for key in uses:
		var spot: Array = uses[key]
		var it: Node3D = Interactable.new()
		it.label_key = str(spot[1])
		it.position = spot[0]
		var k := str(key)
		it.action = func(_p): _use(k, it)
		root.add_child(it)
		if k == "garage":
			sites[site_id]["garage_use"] = it


## Shop assistants: real character models standing behind the counters.
func _add_clerk(root: Node3D, pos: Vector3, rot: float, model: String) -> void:
	var m: Node3D = preload("res://player/human_model.gd").new()
	var path := "res://assets/characters/%s.glb" % model
	if not ResourceLoader.exists(path):
		path = "res://assets/characters/ped_01.glb"
	m.model_path = path
	m.armed = false
	m.weapon_kind = 0
	m.position = pos
	m.rotation.y = rot
	root.add_child(m)
	_clerks.append(m)


# ================================================================== interactions

func _use(key: String, it: Node3D) -> void:
	if _busy:
		return
	match key:
		"gunshop":
			menu.open(Loc.t("place_gunshop"), _gun_items)
		"clothes":
			menu.open(Loc.t("place_clothes"), _clothes_items)
		"food":
			menu.open(Loc.t("place_restaurant"), _food_items)
		"hospital":
			menu.open(Loc.t("place_hospital"), _hospital_items)
		"police":
			menu.open(Loc.t("place_police"), _police_items)
		"bed":
			menu.open(Loc.t("place_bed"), _bed_items)
		"wardrobe":
			menu.open(Loc.t("place_wardrobe"), _wardrobe_items)
		"garage":
			if _garage_door:
				_garage_door.toggle()
				it.set_label("ctx_garage_close" if _garage_door.open else "ctx_garage_open")
		"lift_up", "lift_down":
			if not sites.has("tower"):
				return
			var info: Dictionary = sites["tower"]["info"]
			var root: Node3D = sites["tower"]["root"]
			var to: Vector3 = info["lift_top"] if key == "lift_up" else info["lift_bottom"]
			_teleport(root.to_global(to), Loc.t("lift_roof") if key == "lift_up" else Loc.t("lift_lobby"))


func _buy(price: int) -> bool:
	if player.money < price:
		menu.note(Loc.t("int_no_money"))
		Sfx.play_ui("mission_fail")
		return false
	player.add_money(-price)
	Sfx.play_ui("money")
	return true


# ---- gun shop

func _gun_items() -> Array:
	var items: Array = []
	var w: Node = player.weapon
	var have_sniper := false
	for wd in w.WEAPONS:
		if (wd as Dictionary).has("sniper"):
			have_sniper = true
	for cls in ["pistol", "rifle", "sniper"]:
		if cls == "sniper" and not have_sniper:
			continue
		var pack: Array = AMMO[cls]
		var full: bool = int(ammo[cls]) >= int(pack[2])
		items.append({"text": Loc.t("ammo_" + cls) + "  +%d" % int(pack[0]), "price": int(pack[1]),
			"sub": Loc.t("int_have") % int(ammo[cls]), "enabled": not full,
			"action": func():
				if _buy(int(pack[1])):
					ammo[cls] = mini(int(ammo[cls]) + int(pack[0]), int(pack[2]))
					_after_purchase()})
	items.append({"text": Loc.t("armour_buy"), "price": ARMOUR_PRICE, "sub": Loc.t("armour_have") % int(armour),
		"enabled": armour < 99.0,
		"action": func():
			if _buy(ARMOUR_PRICE):
				armour = 100.0
				_after_purchase()})
	for wd in w.WEAPONS:
		var key: String = wd["key"]
		if not WEAPON_PRICES.has(key) or owned.has(key):
			continue
		var price: int = WEAPON_PRICES[key]
		items.append({"text": Loc.t("int_unlock") % Loc.t(key), "price": price, "sub": Loc.t("int_unlock_sub"),
			"action": func():
				if _buy(price):
					owned[key] = true
					var cls := _class_of(wd)
					if cls != "":
						var pack: Array = AMMO[cls]
						ammo[cls] = mini(int(ammo[cls]) + int(pack[0]), int(pack[2]))
					_after_purchase()
					_hud_toast(Loc.t("int_unlocked") % Loc.t(key))})
	return items


# ---- clothes

func _outfit(id: String) -> Dictionary:
	for o in OUTFITS:
		if o["id"] == id:
			return o
	return OUTFITS[0]


func _clothes_items() -> Array:
	var items: Array = []
	for o in OUTFITS:
		var id: String = o["id"]
		var have := outfits.has(id)
		var wearing := outfit == id
		var text := Loc.t("outfit_" + id)
		var sub := Loc.t("int_wearing") if wearing else (Loc.t("int_owned") if have else "")
		items.append({"text": text, "price": -1 if have else int(o["price"]), "sub": sub, "enabled": not wearing,
			"action": func():
				if not have:
					if not _buy(int(o["price"])):
						return false
					outfits.append(id)
				outfit = id
				apply_outfit()
				_after_purchase()})
	return items


func _wardrobe_items() -> Array:
	var items: Array = []
	for o in OUTFITS:
		var id: String = o["id"]
		if not outfits.has(id):
			continue
		var wearing := outfit == id
		items.append({"text": Loc.t("outfit_" + id), "sub": Loc.t("int_wearing") if wearing else "", "enabled": not wearing,
			"action": func():
				outfit = id
				apply_outfit()
				_save_state()})
	if outfits.size() < OUTFITS.size():
		items.append({"text": Loc.t("int_more_clothes"), "enabled": false})
	return items


# ---- food, hospital, police

func _food_items() -> Array:
	var items: Array = []
	for f in FOOD:
		var heal: float = f["heal"]
		items.append({"text": Loc.t(f["key"]), "price": int(f["price"]), "sub": Loc.t("int_heal") % int(heal),
			"enabled": player.health < 99.5,
			"action": func():
				if _buy(int(f["price"])):
					_heal(heal)
					Sfx.play_ui("mission_done")})
	if player.health >= 99.5:
		items.append({"text": Loc.t("int_full"), "enabled": false})
	return items


func _hospital_items() -> Array:
	var hurt: bool = player.health < 99.5
	var items: Array = [
		{"text": Loc.t("int_treat"), "price": TREATMENT_PRICE, "sub": Loc.t("int_heal") % 100, "enabled": hurt,
			"action": func():
				if _buy(TREATMENT_PRICE):
					_heal(100.0)
					Sfx.play_ui("mission_done")},
		{"text": Loc.t("int_respawn_info"), "enabled": false},
	]
	return items


func _police() -> Node:
	for n in get_tree().get_nodes_in_group("crime_listeners"):
		if "stars" in n:
			return n
	return null


func _police_items() -> Array:
	var p := _police()
	var stars := int(p.get("stars")) if p else 0
	if stars <= 0:
		return [{"text": Loc.t("int_no_wanted"), "enabled": false}]
	var price := 250 * stars
	return [{"text": Loc.t("int_pay_fine") % stars, "price": price, "sub": Loc.t("int_fine_sub"),
		"action": func():
			if _buy(price):
				if p.has_method("_clear"):
					p.call("_clear", false)
				elif "stars" in p:
					p.set("stars", 0)
				_hud_toast(Loc.t("int_fine_paid"))
				return true}]


# ---- home

func _bed_items() -> Array:
	return [
		{"text": Loc.t("int_sleep"), "sub": Loc.t("int_sleep_sub"), "action": func():
			_sleep()
			return true},
		{"text": Loc.t("save_now"), "action": func():
			_save_all()
			menu.note(Loc.t("saved"))},
	]


func _sleep() -> void:
	var p := _police()
	if p and int(p.get("stars")) > 0:
		_hud_toast(Loc.t("int_no_sleep_wanted"))
		return
	_busy = true
	await _fade_to(1.0, 0.8)
	for dn in get_tree().get_nodes_in_group("day_night"):
		if dn.has_method("set_hour"):
			dn.set_hour(fmod(float(dn.get("hour")) + 8.0, 24.0))
	_heal(100.0)
	_save_all()
	await get_tree().create_timer(0.8, true).timeout
	await _fade_to(0.0, 0.8)
	_hud_toast(Loc.t("int_slept"))
	_busy = false


func _heal(amount: float) -> void:
	player.health = minf(player.health + amount, 100.0)
	_last_hp = player.health
	player.health_changed.emit(player.health)


func _after_purchase() -> void:
	_fix_weapon()
	_save_all()


# ---- teleport (elevator)

func _teleport(to: Vector3, text: String) -> void:
	_busy = true
	GameInput.reset_touch()
	await _fade_to(1.0, 0.35)
	player.global_position = to
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await get_tree().create_timer(0.25).timeout
	await _fade_to(0.0, 0.35)
	_hud_toast(text)
	_busy = false


func _fade_to(a: float, t: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


func _hud_toast(text: String) -> void:
	if main.hud and main.hud.has_method("toast"):
		main.hud.toast(text)


# ================================================================== garage

func _setup_garage(root: Node3D, info: Dictionary) -> void:
	_garage_root = root
	_garage_box = info["garage_box"]
	var door: Node3D = GarageDoor.new()
	door.player = player
	door.position = info["garage_door"]
	root.add_child(door)
	_garage_door = door
	door.moved.connect(func(open):
		var it: Variant = sites["safehouse"].get("garage_use")
		if it:
			(it as Node).call("set_label", "ctx_garage_close" if open else "ctx_garage_open"))


func _car_in_garage() -> Node3D:
	if _garage_root == null:
		return null
	var inv := _garage_root.global_transform.affine_inverse()
	for v in get_tree().get_nodes_in_group("vehicle"):
		if (v as Node).is_in_group("police_car") or not ("paint" in v):
			continue
		var lp: Vector3 = inv * (v as Node3D).global_position
		if _garage_box.grow(0.6).has_point(lp):
			return v
	return null


func _restore_garage_car() -> void:
	if _garage_root == null:
		return
	var cfg := ConfigFile.new()
	var has_save := cfg.load(SAVE_PATH) == OK
	var paint: Color = Color(0.06, 0.07, 0.08)     # a first car waits in the garage
	var hp := 100.0
	if has_save:
		if not cfg.get_value("garage", "has_car", false):
			return
		paint = cfg.get_value("garage", "paint", paint)
		hp = cfg.get_value("garage", "health", 100.0)
	var car: VehicleBody3D = preload("res://vehicles/car.gd").new()
	car.set_meta("player_owned", true)     # your own garage car is never "stolen"
	car.paint = paint
	var info: Dictionary = sites["safehouse"]["info"]
	var pos := _garage_root.to_global(info["garage_car"])
	var d := _garage_root.global_basis.z
	car.transform = Transform3D(Basis.looking_at(d, Vector3.UP), pos)
	main.world.add_child(car)
	car.peds = main.peds
	car.health = clampf(hp, 25.0, 100.0)
	# Do not start the game standing inside the car.
	if player.global_position.distance_to(pos) < 3.0:
		player.global_position = _garage_root.to_global(info["door"])
		player.reset_physics_interpolation()


# ================================================================== combat: ammo and armour

func _setup_combat() -> void:
	var w: Node = player.weapon
	w.fired.connect(_on_fired)
	w.weapon_changed.connect(func(_k): _fix_weapon(true))
	player.health_changed.connect(_on_health)
	player.died.connect(func():
		armour = 0.0)
	_last_hp = player.health
	_fix_weapon.call_deferred()


func _class_of(wd: Dictionary) -> String:
	if wd.has("sniper"):
		return "sniper"
	match int(wd.get("kind", 0)):
		1:
			return "pistol"
		2:
			return "rifle"
	return ""


## Title screen "New game": purchases, ammo and armour back to the defaults.
func on_new_game() -> void:
	armour = 0.0
	ammo = {"pistol": 60, "rifle": 0, "sniper": 20}
	owned = {}
	outfits = ["street"]
	outfit = "street"
	player.set_meta("armour", armour)
	apply_outfit()
	_fix_weapon()
	_save_state()


## Missions that hand the player a weapon make sure it has some rounds.
func give_mission_ammo(wd: Dictionary, at_least: int) -> void:
	var cls := _class_of(wd)
	if cls != "":
		ammo[cls] = maxi(int(ammo.get(cls, 0)), at_least)


func is_owned(key: String) -> bool:
	return not WEAPON_PRICES.has(key) or owned.has(key)


func _usable(i: int) -> bool:
	var wd: Dictionary = player.weapon.WEAPONS[i]
	if not is_owned(str(wd["key"])):
		return false
	var cls := _class_of(wd)
	return cls == "" or int(ammo.get(cls, 0)) > 0


## Keeps the selected weapon one the player owns and has ammo for (fists always work).
## cycling = the player pressed the weapon button: take the next usable one, fists
## included; otherwise prefer a gun and fall back to the fists.
func _fix_weapon(cycling := false) -> void:
	var w: Node = player.weapon
	var n: int = w.WEAPONS.size()
	var cur: int = w.current
	if _usable(cur):
		return
	for pass_i in 2:
		for k in range(1, n + 1):
			var i := (cur + k) % n
			if not _usable(i):
				continue
			if pass_i == 0 and not cycling and _class_of(w.WEAPONS[i]) == "":
				continue
			w.current = i
			player.model.set_weapon(int(w.WEAPONS[i]["kind"]))
			w.weapon_changed.emit(str(w.WEAPONS[i]["key"]))
			return


func _on_fired() -> void:
	var w: Node = player.weapon
	var cls := _class_of(w.WEAPONS[w.current])
	if cls == "":
		return
	ammo[cls] = maxi(int(ammo[cls]) - 1, 0)
	if int(ammo[cls]) <= 0:
		_hud_toast(Loc.t("int_out_of_ammo") % Loc.t("ammo_" + cls))
		_fix_weapon.call_deferred()


## Body armour: takes part of every hit before health does (runs inside take_damage,
## before the death check, so a vest can save your life).
func _on_health(hp: float) -> void:
	if _guard:
		return
	var prev := _last_hp
	_last_hp = hp
	if hp < prev and armour > 0.0:
		var absorb := minf((prev - hp) * ARMOUR_ABSORB, armour)
		armour -= absorb
		_guard = true
		player.health = minf(hp + absorb, 100.0)
		_last_hp = player.health
		player.health_changed.emit(player.health)
		_guard = false
	player.set_meta("armour", armour)


# ================================================================== outfits

## Tints the player's clothing materials (works with separate shirt / pants / shoes
## materials, or one shared "cloth" material).
func apply_outfit() -> void:
	var o := _outfit(outfit)
	var model: Node = player.model
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(s)
			if not (base is BaseMaterial3D):
				continue
			var nm := base.resource_name.to_lower()
			var part := ""
			if nm.contains("shirt") or nm.contains("top") or nm.contains("jacket") or nm.contains("cloth"):
				part = "shirt"
			elif nm.contains("pant") or nm.contains("jean") or nm.contains("trouser"):
				part = "pants"
			elif nm.contains("shoe"):
				part = "shoes"
			if part == "":
				continue
			var tint: Variant = o[part]
			if tint == null:
				m.set_surface_override_material(s, null)
				continue
			var mat := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
			var c: Color = tint
			if mat.albedo_texture != null:
				mat.albedo_color = Color(minf(c.r * 1.25, 2.0), minf(c.g * 1.25, 2.0), minf(c.b * 1.25, 2.0))
			else:
				mat.albedo_color = Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1))
			m.set_surface_override_material(s, mat)
	var vis: Variant = model.get("_visual")
	_visual_id = (vis as Object).get_instance_id() if vis is Object else 0


# ================================================================== per frame

func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		# Another module may swap the character model: dress it again.
		var vis: Variant = player.model.get("_visual") if player.model else null
		var id: int = (vis as Object).get_instance_id() if vis is Object else 0
		if id != _visual_id:
			apply_outfit()
	# Shop assistants breathe and shift their weight when the player is near.
	var pp := player.global_position
	for c in _clerks:
		var n := c as Node3D
		if n.global_position.distance_squared_to(pp) < 900.0:
			n.call("animate", delta, 0.0, true, false, false)
	if _hud:
		_hud.queue_redraw()


# ================================================================== UI

func _setup_ui() -> void:
	menu = ShopMenu.new()
	menu.player = player
	add_child(menu)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	_layer.add_child(_hud)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)


func _draw_hud() -> void:
	var font := _hud.get_theme_default_font()
	var s := _hud.size
	# Armour bar right under the health bar (top-left).
	if armour > 0.0:
		var r := Rect2(110, 64, 260, 8)
		_hud.draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
		_hud.draw_rect(Rect2(r.position, Vector2(r.size.x * armour / 100.0, r.size.y)), Color(0.35, 0.6, 1.0))
	# Ammo for the current gun, above the weapon name (bottom centre).
	if player.in_vehicle or menu.is_open():
		return
	var w: Node = player.weapon
	var cls := _class_of(w.WEAPONS[w.current])
	if cls == "":
		return
	var t := "%s %d" % [Loc.t("int_ammo"), int(ammo[cls])]
	var col := Color(1, 1, 1, 0.9) if int(ammo[cls]) > 10 else Color(1.0, 0.45, 0.35, 0.95)
	var pos := Vector2(s.x * 0.5 - 200, s.y - 74)
	_hud.draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 400, 24, 6, Color(0, 0, 0, 0.75))
	_hud.draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_CENTER, 400, 24, col)


# ================================================================== save / load

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if player:
				_save_state()


func _save_all() -> void:
	if main.has_method("_save_game"):
		main.call("_save_game")
	_save_state()


func _save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "armour", armour)
	cfg.set_value("player", "ammo", ammo)
	cfg.set_value("player", "owned", owned.keys())
	cfg.set_value("player", "outfits", outfits)
	cfg.set_value("player", "outfit", outfit)
	var car := _car_in_garage()
	cfg.set_value("garage", "has_car", car != null)
	if car:
		cfg.set_value("garage", "paint", car.get("paint"))
		cfg.set_value("garage", "health", float(car.get("health")))
	cfg.save(SAVE_PATH)


func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	armour = float(cfg.get_value("player", "armour", 0.0))
	var a: Variant = cfg.get_value("player", "ammo", ammo)
	if a is Dictionary:
		for k in ammo:
			ammo[k] = int((a as Dictionary).get(k, ammo[k]))
	for k in cfg.get_value("player", "owned", []):
		owned[str(k)] = true
	var o: Variant = cfg.get_value("player", "outfits", outfits)
	if o is Array:
		outfits = []
		for x in o:
			outfits.append(str(x))
		if not outfits.has("street"):
			outfits.append("street")
	outfit = str(cfg.get_value("player", "outfit", "street"))
	player.set_meta("armour", armour)

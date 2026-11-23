extends Node
## Map feature module: minimap (top-left), full-screen map, GPS route and 3D route ribbon.
##  * Map art is drawn once from the city layout (roads, park, blocks, building footprints, shops).
##  * Markers (missions, targets, pickups, checkpoints, shops, cars, police) refresh at 10 Hz.
##  * GPS: A* over the road intersections to the mission target (main.missions.waypoint())
##    or to a custom waypoint placed on the full map; turn-by-turn hint under the minimap.
## Open the full map by tapping the minimap, or with M / gamepad Back.

const RoadGraph := preload("res://ui/map/road_graph.gd")
const MapArt := preload("res://ui/map/map_art.gd")

const MARKER_HZ := 10.0
const ROUTE_EVERY := 0.35
const ARRIVE_DIST := 14.0
const CAR_RADIUS := 160.0
const MAX_CARS := 24

var main: Node

var graph := RoadGraph.new()
var markers: Array = []          # {kind, pos: Vector2, label, extra, edge (clamp to minimap edge), poi}
var route := PackedVector2Array()
var route_kind := ""             # "mission" / "custom" / ""
var turn := {}
var custom_wp: Variant = null    # Vector2 or null
var custom_label := ""
var search_area: Variant = null  # Vector3(x, z, radius) while police search, or null
var shops: Array = []            # {pos: Vector2, name}
var time := 0.0
var map_open := false

var minimap: Control
var full_map: Control
var _layer_mini: CanvasLayer
var _layer_full: CanvasLayer
var _gps_line: MeshInstance3D
var _marker_t := 0.0
var _route_t := 0.0
var _last_from := Vector2(INF, INF)
var _last_to := Vector2(INF, INF)
var _was_paused := false
var _mini_finger := -1
var _mini_press_pos := Vector2.ZERO
var _police: Node = null
var _police_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_strings()
	Settings.register_defaults({"minimap": true, "gps_3d": true, "minimap_rotate": true})
	if not InputMap.has_action("map"):
		InputMap.add_action("map", 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_M
		InputMap.action_add_event("map", k)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("map", b)

	var city: Node = main.world
	graph.setup(float(city.PITCH), float(city.ROAD_W), int(city.RINGS))
	_find_shops()

	_layer_mini = CanvasLayer.new()
	_layer_mini.layer = 9          # under the HUD layer (10): the settings menu covers it
	add_child(_layer_mini)
	minimap = preload("res://ui/map/minimap.gd").new()
	minimap.module = self
	_layer_mini.add_child(minimap)

	_layer_full = CanvasLayer.new()
	_layer_full.layer = 12
	add_child(_layer_full)
	full_map = preload("res://ui/map/full_map.gd").new()
	full_map.module = self
	full_map.visible = false
	_layer_full.add_child(full_map)

	_gps_line = preload("res://ui/map/gps_line.gd").new()
	main.world.add_child(_gps_line)
	Settings.changed.connect(func(_k): _apply_settings())
	_apply_settings()


## Builds a MapArt node with the static city drawing (each map view owns one).
func make_art() -> Node2D:
	var city: Node = main.world
	var art: Node2D = MapArt.new()
	art.pitch = float(city.PITCH)
	art.road_w = float(city.ROAD_W)
	art.block = float(city.BLOCK)
	art.walk_w = float(city.WALK_W)
	art.rings = int(city.RINGS)
	var list: Array = []
	if "_buildings" in city:
		for b in city._buildings:
			list.append({"pos": b["pos"], "size": b["size"]})
	art.buildings = list
	art.shops = shops
	return art


func _find_shops() -> void:
	# Shops add an interior node to the city with a sign (Label3D) on it.
	shops.clear()
	var names: Array = preload("res://world/shop.gd").NAMES
	for c in main.world.get_children():
		if not c is Node3D:
			continue
		for g in c.get_children():
			if g is Label3D and (g as Label3D).text in names:
				var p := (c as Node3D).global_position
				shops.append({"pos": Vector2(p.x, p.z), "name": (g as Label3D).text})
				break


func _apply_settings() -> void:
	minimap.visible = bool(Settings.get_value("minimap"))


# ------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	time += delta
	if main == null or main.player == null:
		return
	if Input.is_action_just_pressed("map") and not _menu_visible():
		toggle_map()
	if map_open and _menu_visible():
		close_map()
	if get_tree().paused and not map_open:
		return
	_marker_t -= delta
	if _marker_t <= 0.0:
		_marker_t = 1.0 / MARKER_HZ
		_collect_markers()
	_route_t -= delta
	if _route_t <= 0.0:
		_route_t = ROUTE_EVERY
		_update_route()
	var p: Node3D = main.player
	_gps_line.visible = bool(Settings.get_value("gps_3d")) and bool(p.in_vehicle) and route.size() >= 4 and not map_open


func player_pos() -> Vector2:
	var p: Vector3 = (main.player as Node3D).global_position
	return Vector2(p.x, p.z)


## Heading of the player (or car) on the map, as a direction Vector2(x, z).
func player_dir() -> Vector2:
	var pl: Node3D = main.player
	var d := Vector3.FORWARD
	if pl.in_vehicle and pl.vehicle != null:
		d = (pl.vehicle as Node3D).global_basis.z
	elif "model" in pl and pl.model != null:
		d = -(pl.model as Node3D).global_basis.z
	var v := Vector2(d.x, d.z)
	return v.normalized() if v.length() > 0.01 else Vector2(0, -1)


## Direction the camera looks at on the map (minimap "up").
func camera_dir() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2(0, -1)
	var f := -cam.global_basis.z
	var v := Vector2(f.x, f.z)
	return v.normalized() if v.length() > 0.01 else Vector2(0, -1)


func _menu_visible() -> bool:
	var hud: Node = main.hud
	if hud == null:
		return false
	var m: Variant = hud.get("menu")
	return m != null and (m as Control).visible


func _edit_mode() -> bool:
	var hud: Node = main.hud
	if hud == null or hud.get("touch") == null:
		return false
	return bool(hud.touch.edit_mode)


# ------------------------------------------------------------ markers

func _collect_markers() -> void:
	var out: Array = []
	var ms: Node = main.missions
	var pp := player_pos()
	if ms != null:
		var active: int = ms.active
		var defs: Array = ms.MISSIONS
		var givers: Array = ms.get("_givers") if ms.get("_givers") != null else []
		if active < 0:
			for i in defs.size():
				var d: Dictionary = defs[i]
				if i < givers.size() and not (givers[i] as Node3D).visible:
					continue
				var g: Vector3 = d["giver"]
				out.append({"kind": "giver", "pos": Vector2(g.x, g.z), "label": str(d["title"]), "edge": false, "poi": true})
		else:
			var step: String = str(ms.get("_step"))
			var wp: Variant = ms.waypoint()
			if step == "collect":
				var items: Array = ms.get("_items")
				for it in items:
					if is_instance_valid(it) and (it as Node).is_in_group("pickup"):
						var ip := (it as Node3D).global_position
						out.append({"kind": "item", "pos": Vector2(ip.x, ip.z), "label": "", "edge": true, "poi": false})
			elif step == "race":
				var cps: Array = ms.get("_checkpoints")
				var idx: int = ms.get("_cp_index")
				for k in range(idx + 1, mini(idx + 3, cps.size())):
					var cp: Vector3 = cps[k]
					out.append({"kind": "checkpoint", "pos": Vector2(cp.x, cp.z), "label": "", "extra": str(k + 1), "edge": false, "poi": false})
			if wp != null:
				var w: Vector3 = wp
				var kind := "target" if step == "kill" else ("checkpoint" if step == "race" else "objective")
				var extra := ""
				if step == "race":
					extra = str(int(ms.get("_cp_index")) + 1)
				out.append({"kind": kind, "pos": Vector2(w.x, w.z), "label": Loc.t("map_lg_objective"), "extra": extra, "edge": true, "poi": false})
	for sh in shops:
		out.append({"kind": "shop", "pos": sh["pos"], "label": sh["name"], "edge": false, "poi": true})
	var pl: Node3D = main.player
	var sp: Vector3 = pl.spawn_point
	out.append({"kind": "hospital", "pos": Vector2(sp.x, sp.z), "label": Loc.t("map_lg_hospital"), "edge": false, "poi": true})
	# Cars nearby (not the one we drive, not police: those are drawn as police).
	var cars := 0
	for v in get_tree().get_nodes_in_group("vehicle"):
		if cars >= MAX_CARS:
			break
		if v == pl.vehicle or (v as Node).is_in_group("police_car") or not (v as Node3D).is_inside_tree():
			continue
		var vp := (v as Node3D).global_position
		var v2 := Vector2(vp.x, vp.z)
		if v2.distance_to(pp) < CAR_RADIUS:
			out.append({"kind": "car", "pos": v2, "label": "", "edge": false, "poi": false})
			cars += 1
	for u in get_tree().get_nodes_in_group("police_unit"):
		if u == pl.vehicle or not (u as Node3D).visible:
			continue
		var up := (u as Node3D).global_position
		out.append({"kind": "police", "pos": Vector2(up.x, up.z), "label": "", "edge": false, "poi": false})
	# Other modules can show things with group "map_marker" + meta "map_kind" (and optional "map_label").
	for n in get_tree().get_nodes_in_group("map_marker"):
		if n is Node3D and (n as Node3D).is_visible_in_tree():
			var np := (n as Node3D).global_position
			out.append({"kind": str(n.get_meta("map_kind", "objective")), "pos": Vector2(np.x, np.z),
				"label": str(n.get_meta("map_label", "")), "edge": bool(n.get_meta("map_edge", false)), "poi": false})
	if custom_wp != null:
		out.append({"kind": "custom", "pos": custom_wp, "label": custom_label, "edge": true, "poi": false})
	markers = out
	_update_police()


func _update_police() -> void:
	_police_t -= 1.0 / MARKER_HZ
	if _police == null and _police_t <= 0.0:
		_police_t = 2.0
		for n in get_tree().get_nodes_in_group("crime_listeners"):
			if "stars" in n:
				_police = n
				break
	search_area = null
	if _police != null and is_instance_valid(_police):
		if int(_police.get("stars")) > 0 and bool(_police.get("searching")):
			var lk: Vector3 = _police.get("last_known")
			search_area = Vector3(lk.x, lk.z, 55.0)


# ------------------------------------------------------------ GPS

## Current GPS destination: the mission target first, else the custom waypoint.
func destination() -> Variant:
	var ms: Node = main.missions
	if ms != null:
		var wp: Variant = ms.waypoint()
		if wp != null:
			var w: Vector3 = wp
			route_kind = "mission"
			return Vector2(w.x, w.z)
	if custom_wp != null:
		route_kind = "custom"
		return custom_wp
	route_kind = ""
	return null


func _update_route() -> void:
	var dest: Variant = destination()
	var from := player_pos()
	if custom_wp != null and from.distance_to(custom_wp) < ARRIVE_DIST:
		clear_custom()
		_toast(Loc.t("map_arrived"))
		Sfx.play_ui("money")
	if dest == null:
		if not route.is_empty():
			route = PackedVector2Array()
			turn = {}
			_gps_line.set_route(route)
		return
	var to: Vector2 = dest
	if from.distance_to(_last_from) < 2.5 and to.distance_to(_last_to) < 2.5 and not route.is_empty():
		_refresh_turn()
		return
	_last_from = from
	_last_to = to
	if from.distance_to(to) < 25.0:
		route = PackedVector2Array([from, to])
	else:
		route = graph.find_route(from, to)
	_refresh_turn()
	_gps_line.set_route(route)


func _refresh_turn() -> void:
	if route.size() < 2:
		turn = {}
		return
	turn = graph.next_turn(route)
	# Driving away from the route: suggest a U-turn.
	var pl: Node3D = main.player
	if pl.in_vehicle and route.size() >= 3 and pl.vehicle != null:
		var vel: Vector3 = (pl.vehicle as Node3D).get("linear_velocity") if (pl.vehicle as Node3D).get("linear_velocity") != null else Vector3.ZERO
		var leg := (route[2] - route[1]).normalized()
		var v2 := Vector2(vel.x, vel.z)
		if v2.length() > 3.0 and v2.normalized().dot(leg) < -0.6 and route[0].distance_to(route[1]) < graph.road_w:
			turn = {"dist": 0.0, "turn": 2, "street": "", "total": turn.get("total", 0.0)}


func set_custom(p: Vector2, label := "") -> void:
	var lim := graph.max_coord() + graph.road_w * 0.5
	custom_wp = p.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
	custom_label = label
	_last_to = Vector2(INF, INF)
	_route_t = 0.0
	_marker_t = 0.0
	Sfx.play_ui("mission_start")


func clear_custom() -> void:
	custom_wp = null
	custom_label = ""
	_last_to = Vector2(INF, INF)
	_route_t = 0.0
	_marker_t = 0.0


## Forces a marker + route refresh (the full map calls this while the game is paused).
func refresh_now() -> void:
	_collect_markers()
	_update_route()


static func format_dist(m: float) -> String:
	if m >= 1000.0:
		return Loc.t("map_km") % (m / 1000.0)
	return Loc.t("map_m") % (int(m / 10.0) * 10 if m > 50.0 else int(m))


## Hebrew / English turn-by-turn text, e.g. "בעוד 120 מ' פנה ימינה לרחוב הזית".
func turn_text() -> String:
	if turn.is_empty():
		return ""
	var t: int = turn["turn"]
	var d: float = turn["dist"]
	match t:
		2:
			return Loc.t("gps_uturn")
		0:
			return Loc.t("gps_arrive") % format_dist(d)
	var street: String = turn["street"]
	var dir := Loc.t("gps_right") if t == 1 else Loc.t("gps_left")
	if street != "":
		return Loc.t("gps_turn_to") % [format_dist(d), dir, Loc.t(street)]
	return Loc.t("gps_turn") % [format_dist(d), dir]


## Two-line form for the minimap: [instruction, street ("" if none)].
func turn_parts() -> Array:
	if turn.is_empty():
		return ["", ""]
	var t: int = turn["turn"]
	if t == 0 or t == 2:
		return [turn_text(), ""]
	var dir := Loc.t("gps_right") if t == 1 else Loc.t("gps_left")
	var street: String = turn["street"]
	return [Loc.t("gps_turn") % [format_dist(float(turn["dist"])), dir],
		Loc.t("gps_onto") % Loc.t(street) if street != "" else ""]


func current_street() -> String:
	var nr: Dictionary = graph.nearest(player_pos())
	if nr.is_empty() or (nr["point"] as Vector2).distance_to(player_pos()) > graph.road_w * 0.5 + 5.0:
		return ""
	return Loc.t(str(nr["street"]))


func _toast(text: String) -> void:
	var hud: Node = main.hud
	if hud != null and hud.has_method("toast"):
		hud.toast(text)


# ------------------------------------------------------------ open / close

func toggle_map() -> void:
	if map_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if map_open or _edit_mode():
		return
	map_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	GameInput.menu_open = true
	GameInput.reset_touch()
	var hud: Node = main.hud
	if hud != null and hud.get("touch") != null and hud.touch.has_method("_release_all"):
		hud.touch._release_all()
	refresh_now()
	full_map.open()


func close_map() -> void:
	if not map_open:
		return
	map_open = false
	full_map.visible = false
	if not _menu_visible():
		GameInput.menu_open = false
		get_tree().paused = _was_paused
	_mini_finger = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and map_open:
		# Android back closes the map instead of opening the settings menu.
		GameInput.consume("menu")
		close_map()


func _input(event: InputEvent) -> void:
	if map_open:
		if event.is_action_pressed("menu") or (event is InputEventKey and event.is_action_pressed("ui_cancel")):
			get_viewport().set_input_as_handled()
			close_map()
		return
	if GameInput.menu_open or _edit_mode() or not minimap.visible:
		return
	# Tap on the minimap opens the full map. Touches that start on it never reach the
	# touch controls (so the camera does not jump).
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _mini_finger == -1 and minimap.hit(st.position):
			_mini_finger = st.index
			_mini_press_pos = st.position
			get_viewport().set_input_as_handled()
		elif not st.pressed and st.index == _mini_finger:
			_mini_finger = -1
			get_viewport().set_input_as_handled()
			if st.position.distance_to(_mini_press_pos) < 60.0:
				open_map()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _mini_finger:
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ strings

func _register_strings() -> void:
	Loc.register({
		"he": {
			"map_title": "מפת העיר",
			"map_close": "סגור",
			"map_center": "מרכז עליי",
			"map_clear": "הסר יעד",
			"map_gps3d": "קו GPS על הכביש",
			"map_hint": "גרירה: הזזה  •  צביטה: זום  •  הקשה: סימון יעד",
			"map_arrived": "הגעת ליעד",
			"map_wp_set": "יעד סומן",
			"map_m": "%d מ'",
			"map_km": "%.1f ק\"מ",
			"map_dist": "מרחק ליעד: %s",
			"map_lg_player": "אתה",
			"map_lg_objective": "יעד משימה",
			"map_lg_giver": "משימה חדשה",
			"map_lg_target": "מטרה",
			"map_lg_item": "שקית כסף",
			"map_lg_checkpoint": "נקודת ביקורת",
			"map_lg_custom": "היעד שלך",
			"map_lg_shop": "חנות",
			"map_lg_car": "רכב",
			"map_lg_police": "משטרה",
			"map_lg_hospital": "בית חולים",
			"map_lg_route": "מסלול GPS",
			"map_search": "אזור חיפוש משטרתי",
			"map_north": "צ",
			"map_park": "הפארק העירוני",
			"map_downtown": "מרכז העסקים",
			"gps_left": "שמאלה",
			"gps_right": "ימינה",
			"gps_turn_to": "בעוד %s פנה %s ל%s",
			"gps_turn": "בעוד %s פנה %s",
			"gps_onto": "אל %s",
			"gps_arrive": "היעד בעוד %s",
			"gps_uturn": "בצע פניית פרסה",
			"st_v0": "רחוב הנמל",
			"st_v1": "שדרות הדקלים",
			"st_v2": "רחוב השוק",
			"st_v3": "רחוב האלון",
			"st_v4": "רחוב הגפן",
			"st_v5": "דרך הים",
			"st_h0": "דרך הצפון",
			"st_h1": "רחוב הזית",
			"st_h2": "רחוב הפרחים",
			"st_h3": "רחוב התאנה",
			"st_h4": "רחוב הברושים",
			"st_h5": "דרך הדרום",
		},
		"en": {
			"map_title": "City map",
			"map_close": "Close",
			"map_center": "Center on me",
			"map_clear": "Clear waypoint",
			"map_gps3d": "GPS line on road",
			"map_hint": "Drag: pan  •  Pinch: zoom  •  Tap: set waypoint",
			"map_arrived": "You have arrived",
			"map_wp_set": "Waypoint set",
			"map_m": "%d m",
			"map_km": "%.1f km",
			"map_dist": "Distance: %s",
			"map_lg_player": "You",
			"map_lg_objective": "Objective",
			"map_lg_giver": "New mission",
			"map_lg_target": "Target",
			"map_lg_item": "Cash bag",
			"map_lg_checkpoint": "Checkpoint",
			"map_lg_custom": "Your waypoint",
			"map_lg_shop": "Shop",
			"map_lg_car": "Car",
			"map_lg_police": "Police",
			"map_lg_hospital": "Hospital",
			"map_lg_route": "GPS route",
			"map_search": "Police search area",
			"map_north": "N",
			"map_park": "City Park",
			"map_downtown": "Downtown",
			"gps_left": "left",
			"gps_right": "right",
			"gps_turn_to": "In %s turn %s onto %s",
			"gps_turn": "In %s turn %s",
			"gps_onto": "onto %s",
			"gps_arrive": "Destination in %s",
			"gps_uturn": "Make a U-turn",
			"st_v0": "Harbor St",
			"st_v1": "Palm Ave",
			"st_v2": "Market St",
			"st_v3": "Oak St",
			"st_v4": "Vine St",
			"st_v5": "Sea Rd",
			"st_h0": "North Rd",
			"st_h1": "Olive St",
			"st_h2": "Flower St",
			"st_h3": "Fig St",
			"st_h4": "Cypress St",
			"st_h5": "South Rd",
		},
	})

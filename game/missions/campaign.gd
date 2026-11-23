extends Node
## Campaign module (registered in world/main.gd): story chapters, hidden statuettes,
## stunt jumps, random street events and the odd jobs of mission_manager.gd, with
## progress kept in the [campaign] section of user://save.cfg.
##
## Saving: main.gd writes the player section; this module writes its own section
## after every bit of progress and whenever the app goes to the background / closes
## (it re-reads the file first, so no other section is lost).

const SAVE_PATH := "user://save.cfg"
const Data := preload("res://missions/story_data.gd")

var main: Node
var ui: CanvasLayer
var story: Node3D
var owls: Node3D
var stunts: Node3D
var events: Node3D
var _leftovers: Array = []
var _leftover_t := 0.0


func _ready() -> void:
	Loc.register(Data.STRINGS)
	var player: Node3D = main.player
	var missions: Node = main.missions

	ui = preload("res://missions/campaign_ui.gd").new()
	add_child(ui)

	story = preload("res://missions/story_runner.gd").new()
	story.campaign = self
	story.player = player
	story.peds = main.peds
	story.city = main.world
	story.missions = missions
	story.ui = ui

	owls = preload("res://missions/collectibles.gd").new()
	owls.player = player
	owls.ui = ui

	stunts = preload("res://missions/stunts.gd").new()
	stunts.player = player
	stunts.ui = ui

	events = preload("res://missions/street_events.gd").new()
	events.campaign = self
	events.player = player
	events.peds = main.peds
	events.missions = missions
	events.ui = ui

	_load_state()
	add_child(story)
	add_child(owls)
	add_child(stunts)
	add_child(events)

	if "external_waypoint" in missions:
		missions.external_waypoint = waypoint
	if missions.has_signal("job_finished"):
		missions.job_finished.connect(func(_id, _passed): save_state())
	story.chapter_finished.connect(func(_i, passed):
		if passed:
			save_state())
	owls.collected.connect(func(_id, _c): save_state())
	stunts.jump_done.connect(func(_id, _d, first):
		if first:
			save_state())
	events.event_finished.connect(func(_k, passed):
		if passed:
			save_state())
	Loc.language_changed.connect(_update_progress)
	_update_progress()


## True while any story chapter, odd job or street event runs.
func is_busy() -> bool:
	if story != null and story.is_active():
		return true
	if events != null and events.is_active():
		return true
	return int(main.missions.active) >= 0


func waypoint() -> Variant:
	if story.is_active():
		return story.waypoint()
	if events.is_active():
		return events.waypoint()
	return null


## A mission car the player drove off in: freed later, once the player has left it far behind.
func add_leftover(n: Node) -> void:
	if not (n in _leftovers):
		_leftovers.append(n)
	if n.get_parent() != self:
		var xf: Transform3D = (n as Node3D).global_transform
		n.reparent(self)
		(n as Node3D).global_transform = xf


func _process(delta: float) -> void:
	_leftover_t -= delta
	if _leftover_t > 0.0:
		return
	_leftover_t = 2.0
	_update_progress()
	var player: Node3D = main.player
	for n in _leftovers.duplicate():
		if not is_instance_valid(n):
			_leftovers.erase(n)
			continue
		if player.get("vehicle") == n:
			continue
		if (n as Node3D).global_position.distance_to(player.global_position) > 160.0:
			_leftovers.erase(n)
			n.queue_free()


func _update_progress() -> void:
	ui.progress_text = Loc.t("progress_line") % [mini(story.story_index, 8), owls.count(), stunts.count(), stunts.ramps.size()]


# ------------------------------------------------------------ save / load

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)       # keep the other sections (player, other modules)
	# Money changes with every reward: keep it current as well.
	var player: Node3D = main.player
	cfg.set_value("player", "money", player.money)
	cfg.set_value("campaign", "story_index", story.story_index)
	cfg.set_value("campaign", "owls", owls.found.duplicate())
	cfg.set_value("campaign", "stunts", stunts.done.duplicate())
	cfg.set_value("campaign", "events_done", events.done_count)
	if "completions" in main.missions:
		cfg.set_value("campaign", "odd_jobs", (main.missions.completions as Dictionary).duplicate())
	cfg.save(SAVE_PATH)
	_update_progress()


func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	story.story_index = clampi(int(cfg.get_value("campaign", "story_index", 0)), 0, 8)
	var o: Variant = cfg.get_value("campaign", "owls", [])
	if o is Array:
		owls.found = (o as Array).duplicate()
	var s: Variant = cfg.get_value("campaign", "stunts", [])
	if s is Array:
		stunts.done = (s as Array).duplicate()
	events.done_count = int(cfg.get_value("campaign", "events_done", 0))
	var jobs: Variant = cfg.get_value("campaign", "odd_jobs", {})
	if jobs is Dictionary and "completions" in main.missions:
		main.missions.completions = (jobs as Dictionary).duplicate()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if story != null:
				save_state()

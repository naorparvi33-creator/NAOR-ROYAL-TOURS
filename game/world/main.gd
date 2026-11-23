extends Node3D
## Entry point: sets up the UI font/theme, the test world, the player and the HUD.
## Also saves the game when Android sends the app to the background.

const SAVE_PATH := "user://save.cfg"

var player: CharacterBody3D
var hud: CanvasLayer
var missions: Node3D
var world: Node3D
var peds: Node3D


func _ready() -> void:
	_setup_theme()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false

	world = preload("res://world/city.gd").new()
	add_child(world)

	player = preload("res://player/player.gd").new()
	player.name = "Player"
	add_child(player)
	player.spawn_point = Vector3(2, 0.4, 43)
	player.position = player.spawn_point
	world.set_follow(player)
	player.rig.yaw = 180.0   # face the street
	_load_game()

	peds = preload("res://world/pedestrians.gd").new()
	peds.player = player
	peds.city = world
	add_child(peds)
	for v in get_tree().get_nodes_in_group("vehicle"):
		v.peds = peds

	missions = preload("res://missions/mission_manager.gd").new()
	missions.player = player
	missions.city = world
	missions.peds = peds
	add_child(missions)

	hud = preload("res://ui/hud.gd").new()
	hud.missions = missions
	hud.player = player
	add_child(hud)

	# MODULES: each feature module is created here with one line, e.g.
	#   _add_module("res://police/police.gd")
	# Modules get main (self) through `main` and find player/world/peds/missions/hud on it.
	_add_module("res://missions/campaign.gd")
	# (end of modules)


## Creates a feature module (a Node script with an optional `main` property).
func _add_module(path: String) -> Node:
	var m: Node = load(path).new()
	if "main" in m:
		m.main = self
	add_child(m)
	return m


func _setup_theme() -> void:
	# Default Godot font for Latin + bundled Noto Sans Hebrew (OFL) as fallback.
	var heb: FontFile = load("res://ui/fonts/NotoSansHebrew-Bold.ttf")
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.fallbacks = [heb]
	# Changing the engine default theme reaches every control, including popups.
	var theme := ThemeDB.get_default_theme()
	theme.default_font = font
	theme.default_font_size = 30
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 30


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_save_game()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_game()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button opens / closes the menu instead of quitting.
			GameInput.pulse("menu")


func _save_game() -> void:
	if player == null:
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # keep sections written by modules (campaign progress, ...)
	cfg.set_value("player", "position", player.global_position)
	cfg.set_value("player", "yaw", player.rig.yaw)
	cfg.set_value("player", "money", player.money)
	cfg.save(SAVE_PATH)


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player.position = cfg.get_value("player", "position", player.spawn_point)
	player.rig.yaw = cfg.get_value("player", "yaw", 0.0)
	player.money = cfg.get_value("player", "money", 0)

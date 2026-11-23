extends Node3D
## Entry point: sets up the UI font/theme, the test world, the player and the HUD.
## Also saves the game when Android sends the app to the background.

const SAVE_PATH := "user://save.cfg"

var player: CharacterBody3D
var hud: CanvasLayer


func _ready() -> void:
	_setup_theme()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false

	var world = preload("res://world/test_world.gd").new()
	add_child(world)

	player = preload("res://player/player.gd").new()
	player.name = "Player"
	add_child(player)
	player.spawn_point = Vector3(0, 0.2, 6)
	player.position = player.spawn_point
	world.set_follow(player)
	_load_game()

	hud = preload("res://ui/hud.gd").new()
	hud.player = player
	add_child(hud)


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
	cfg.set_value("player", "position", player.global_position)
	cfg.set_value("player", "yaw", player.rig.yaw)
	cfg.save(SAVE_PATH)


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player.position = cfg.get_value("player", "position", player.spawn_point)
	player.rig.yaw = cfg.get_value("player", "yaw", 0.0)

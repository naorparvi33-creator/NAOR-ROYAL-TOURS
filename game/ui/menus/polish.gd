extends Node
## Game-wide polish, registered in main.gd with one line. Creates:
##   core/quality.gd           quality presets, per-block culling, crowd density
##   core/ambience.gd          ambience, footsteps, weapon / UI sounds, combat music
##   ui/menus/damage_feedback  screen-edge damage indicator + vibration
##   ui/menus/photo_mode       free camera photo mode
##   ui/menus/pause_menu       pause menu in front of the existing settings screen
##   ui/menus/title_screen     main menu with a cinematic fly-over

var main: Node


func _ready() -> void:
	name = "Polish"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_strings()
	Settings.register_defaults({"vibration": true})
	var _quality := _make("res://core/quality.gd")
	var _amb := _make("res://core/ambience.gd")
	var _dmg := _make("res://ui/menus/damage_feedback.gd")
	var photo := _make("res://ui/menus/photo_mode.gd")
	var title := _make("res://ui/menus/title_screen.gd", false)
	var pause := _make("res://ui/menus/pause_menu.gd", false)
	pause.photo = photo
	pause.title = title
	main.add_child(title)
	main.add_child(pause)
	# The settings screen was built before these strings existed.
	if main.hud and main.hud.menu and main.hud.menu.has_method("_build"):
		main.hud.menu.call_deferred("_build")


func _make(path: String, add := true) -> Node:
	var m: Node = load(path).new()
	if "main" in m:
		m.main = main
	if add:
		main.add_child(m)
	return m


func _register_strings() -> void:
	Loc.register({
		"he": {
			"game_title": "צלף בעיר",
			"game_tagline": "Open World Sniper · עולם פתוח",
			"continue": "המשך",
			"new_game": "משחק חדש",
			"credits": "קרדיטים",
			"quit_game": "יציאה מהמשחק",
			"back": "חזרה",
			"new_game_q": "להתחיל משחק חדש?",
			"new_game_warn": "ההתקדמות השמורה (כסף ומיקום) תימחק. ההגדרות נשארות.",
			"new_game_yes": "כן, משחק חדש",
			"paused": "המשחק מושהה",
			"paused_sub": "כפתור התפריט או 'חזור' בטלפון ממשיכים את המשחק",
			"main_menu": "תפריט ראשי",
			"photo_mode": "מצב צילום",
			"photo_exit": "יציאה",
			"photo_wide": "רחב",
			"photo_tele": "זום",
			"photo_take": "צלם",
			"photo_hide_ui": "הסתר",
			"photo_hint": "אגודל שמאל: תזוזה · אגודל ימין: מבט",
			"photo_tap_show": "נגיעה במסך מחזירה את הכפתורים",
			"photo_saved": "התמונה נשמרה",
			"photo_failed": "שמירת התמונה נכשלה",
			"quality_preset": "איכות גרפיקה",
			"q_auto": "אוטומטי",
			"q_low": "נמוכה",
			"q_medium": "בינונית",
			"q_high": "גבוהה",
			"q_custom": "מותאם אישית",
			"npc_density": "צפיפות אנשים ורכבים",
			"vibration": "רטט בפגיעה",
			"cr_textures": "טקסטורות",
			"cr_textures_d": "Poly Haven (polyhaven.com) · רישיון CC0: דשא, אדמה, אספלט, בטון, טיח, לבנים, רעפים, עץ, סלע, בד ועור.",
			"cr_models": "אובייקטי רחוב סרוקים",
			"cr_models_d": "Poly Haven · CC0: תריסים, מדרגות חירום, פחים, שקיות אשפה, ארונות חשמל, ספסלים ורכב מכוסה.",
			"cr_sky": "שמיים",
			"cr_sky_d": "תמונת שמיים HDRI מ-Poly Haven · CC0.",
			"cr_people": "דמויות אנושיות",
			"cr_people_d": "MakeHuman / MPFB2 · CC0. הדמויות בדיוניות ונוצרות במחולל של הפרויקט; האנימציה נעשית בקוד.",
			"cr_font": "גופן",
			"cr_font_d": "Noto Sans Hebrew · רישיון SIL Open Font License 1.1.",
			"cr_icu": "תמיכה בעברית",
			"cr_icu_d": "נתוני ICU מתוך Godot (רישיון Unicode) לכתיבה מימין לשמאל.",
			"cr_audio": "צלילים ומוזיקה",
			"cr_audio_d": "כל הצלילים והמוזיקה נוצרו בסינתזה בקוד Python (tools/audiogen), בלי דגימות.",
			"cr_code": "עולם ואובייקטים",
			"cr_code_d": "העיר, הבניינים, העצים, הדקלים, הנשק והרכבים נבנים בקוד.",
			"cr_engine": "מנוע",
			"cr_engine_d": "Godot Engine 4 · רישיון MIT. Jolt Physics · רישיון MIT.",
		},
		"en": {
			"game_title": "Open World Sniper",
			"game_tagline": "An open-world city",
			"continue": "Continue",
			"new_game": "New game",
			"credits": "Credits",
			"quit_game": "Quit game",
			"back": "Back",
			"new_game_q": "Start a new game?",
			"new_game_warn": "Saved progress (money and position) will be erased. Settings are kept.",
			"new_game_yes": "Yes, new game",
			"paused": "Paused",
			"paused_sub": "The menu button or phone Back resumes the game",
			"main_menu": "Main menu",
			"photo_mode": "Photo mode",
			"photo_exit": "Exit",
			"photo_wide": "Wide",
			"photo_tele": "Zoom",
			"photo_take": "Shoot",
			"photo_hide_ui": "Hide",
			"photo_hint": "Left thumb: move · Right thumb: look",
			"photo_tap_show": "Tap the screen to show the buttons",
			"photo_saved": "Photo saved",
			"photo_failed": "Could not save the photo",
			"quality_preset": "Graphics quality",
			"q_auto": "Auto",
			"q_low": "Low",
			"q_medium": "Medium",
			"q_high": "High",
			"q_custom": "Custom",
			"npc_density": "People & traffic density",
			"vibration": "Vibrate on hits",
			"cr_textures": "Textures",
			"cr_textures_d": "Poly Haven (polyhaven.com) · CC0: grass, dirt, asphalt, concrete, stucco, brick, tiles, wood, rock, fabric and leather.",
			"cr_models": "Scanned street props",
			"cr_models_d": "Poly Haven · CC0: shutters, fire escapes, trash cans and bags, utility boxes, benches and a covered car.",
			"cr_sky": "Sky",
			"cr_sky_d": "HDRI sky from Poly Haven · CC0.",
			"cr_people": "Human characters",
			"cr_people_d": "MakeHuman / MPFB2 · CC0. All characters are fictional and made by the project's generator; animation is procedural.",
			"cr_font": "Font",
			"cr_font_d": "Noto Sans Hebrew · SIL Open Font License 1.1.",
			"cr_icu": "Hebrew support",
			"cr_icu_d": "ICU data from Godot (Unicode license) for right-to-left text.",
			"cr_audio": "Sound and music",
			"cr_audio_d": "Every sound and music track is synthesized in Python code (tools/audiogen), no samples.",
			"cr_code": "World and objects",
			"cr_code_d": "The city, buildings, trees, palms, weapons and cars are built in code.",
			"cr_engine": "Engine",
			"cr_engine_d": "Godot Engine 4 · MIT license. Jolt Physics · MIT license.",
		},
	})

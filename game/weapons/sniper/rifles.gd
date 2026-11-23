extends RefCounted
## The three sniper rifles: ballistics, handling and looks.
##  v0     muzzle velocity (m/s)        k      drag factor (1/m), lower = flatter far away
##  damage base damage per hit          bolt   seconds to cycle the bolt
##  mag    rounds per magazine          reload seconds to reload
##  sway   breathing sway multiplier    kick   recoil (degrees)
##  zooms  scope magnifications (switchable inside the scope)

const RIFLES := {
	"light": {"key": "weapon_sniper_light", "v0": 750.0, "k": 0.00085, "damage": 90.0, "bolt": 0.85,
		"mag": 6, "reload": 2.2, "sway": 0.85, "kick": 1.6, "zooms": [4.0, 8.0, 12.0], "pitch": 1.12,
		"barrel": 0.55, "color": Color(0.22, 0.25, 0.2), "stock": Color(0.36, 0.3, 0.22)},
	"medium": {"key": "weapon_sniper_medium", "v0": 850.0, "k": 0.00063, "damage": 115.0, "bolt": 1.1,
		"mag": 5, "reload": 2.6, "sway": 1.0, "kick": 2.2, "zooms": [4.0, 8.0, 12.0], "pitch": 1.0,
		"barrel": 0.66, "color": Color(0.07, 0.07, 0.075), "stock": Color(0.5, 0.42, 0.3)},
	"heavy": {"key": "weapon_sniper_heavy", "v0": 950.0, "k": 0.00044, "damage": 160.0, "bolt": 1.45,
		"mag": 5, "reload": 3.2, "sway": 1.25, "kick": 3.2, "zooms": [4.0, 8.0, 12.0], "pitch": 0.82,
		"barrel": 0.8, "color": Color(0.09, 0.09, 0.09), "stock": Color(0.16, 0.17, 0.15)},
}

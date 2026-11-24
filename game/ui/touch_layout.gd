class_name TouchLayout
## Default button positions. pos is a fraction of the screen (0..1, y down),
## r is the radius in pixels on a 1080-pixel-high screen.
##
## Two-thumb layout rules: everything important sits in the bottom corners where
## the thumbs rest. Nothing important at the top center. The left thumb only moves.

const TWO_THUMBS := {
	"fire":   {"pos": Vector2(0.800, 0.700), "r": 92.0, "label": "fire"},
	"fire2":  {"pos": Vector2(0.940, 0.420), "r": 58.0, "label": "fire2"},
	"ads":    {"pos": Vector2(0.690, 0.860), "r": 56.0, "label": "ads"},
	"jump":   {"pos": Vector2(0.930, 0.830), "r": 60.0, "label": "jump"},
	"crouch": {"pos": Vector2(0.930, 0.620), "r": 50.0, "label": "crouch"},
	"swap":   {"pos": Vector2(0.810, 0.470), "r": 46.0, "label": "swap"},
	"context": {"pos": Vector2(0.660, 0.640), "r": 58.0, "label": "ctx_pickup"},
	"menu":   {"pos": Vector2(0.030, 0.065), "r": 34.0, "label": "menu"},
}

## Claw layout for players who use index fingers too.
const FOUR_FINGERS := {
	"fire":   {"pos": Vector2(0.090, 0.300), "r": 70.0, "label": "fire"},
	"fire2":  {"pos": Vector2(0.820, 0.700), "r": 80.0, "label": "fire2"},
	"ads":    {"pos": Vector2(0.910, 0.300), "r": 62.0, "label": "ads"},
	"jump":   {"pos": Vector2(0.940, 0.820), "r": 58.0, "label": "jump"},
	"crouch": {"pos": Vector2(0.940, 0.600), "r": 48.0, "label": "crouch"},
	"swap":   {"pos": Vector2(0.780, 0.300), "r": 46.0, "label": "swap"},
	"context": {"pos": Vector2(0.680, 0.640), "r": 56.0, "label": "ctx_pickup"},
	"menu":   {"pos": Vector2(0.030, 0.065), "r": 34.0, "label": "menu"},
}

## The left part of the screen where the floating joystick appears.
const JOYSTICK_ZONE_MAX_X := 0.45
const JOYSTICK_ZONE_MIN_Y := 0.22
const JOYSTICK_RADIUS := 115.0


static func defaults(preset: String) -> Dictionary:
	return FOUR_FINGERS if preset == "four_fingers" else TWO_THUMBS

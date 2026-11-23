extends RefCounted
## Vehicle catalogue: handling, sound and body shape of every drivable type.
## car.gd reads a spec by its `vtype` and car_mesh.gd builds the body from it.
##
## Handling values:
##   accel   peak acceleration in m/s2 (turned into engine force per driven wheel)
##   top     top speed in m/s, steer = steering lock (rad) at a standstill
##   drive   "fwd" / "rwd" / "awd" - which wheels push
##   wheel   radius, tyre width, front/rear axle z, half track, suspension and grip
##   gears   gearbox steps (engine pitch follows the revs of the current gear)
## Body values (car_mesh.gd): length, width, floor height, a roof-line profile along
## the car (u = -1 tail .. +1 nose), the glass greenhouse corners and the lights.

const SPECS := {
	"sedan": {
		"name": "veh_sedan", "mass": 1250.0, "accel": 10.5, "top": 42.0, "steer": 0.55,
		"drive": "awd", "brake": 60.0, "gears": 5, "sound": "car_engine", "pitch": 1.0, "horn": "veh_horn_car",
		"com": Vector3(0, 0.45, 0.1), "roll_assist": 0.0,
		"wheel": {"r": 0.34, "w": 0.24, "zf": 1.38, "zr": -1.35, "x": 0.8, "y": 0.42, "rest": 0.16, "travel": 0.22,
			"stiff": 48.0, "dc": 2.4, "dr": 3.0, "slip_f": 2.8, "slip_r": 2.5, "roll": 0.12, "maxf": 9000.0},
		"cols": [[Vector3(1.78, 0.62, 4.3), Vector3(0, 0.66, 0)], [Vector3(1.5, 0.46, 1.9), Vector3(0, 1.18, -0.3)]],
		"seat": Vector3(0.37, 0.62, -0.25), "eye": Vector3(0.37, 1.22, -0.2), "hood_cam": Vector3(0, 1.12, 0.75),
		"L": 4.4, "W": 1.8, "bottom": 0.34,
		"prof": [[-1.0, 0.8], [-0.75, 0.97], [-0.2, 0.97], [0.45, 0.9], [1.0, 0.7]],
		"gh": {"z0": 0.85, "z1": 0.2, "z2": -0.85, "z3": -1.2, "y0": 0.95, "y1": 1.42, "wb": 0.8, "wt": 0.64},
		"head": [0.58, 0.62, 0.32, 0.08], "tail": [0.62, 0.82, 0.34, 0.1], "plate_y": 0.5,
		"grille": [0.6, 0.6], "style": "sedan",
	},
	"hatch": {
		"name": "veh_hatch", "mass": 1050.0, "accel": 9.0, "top": 38.0, "steer": 0.6,
		"drive": "fwd", "brake": 55.0, "gears": 5, "sound": "veh_engine_hatch", "pitch": 1.05, "horn": "veh_horn_car",
		"com": Vector3(0, 0.45, 0.25), "roll_assist": 0.0,
		"wheel": {"r": 0.31, "w": 0.21, "zf": 1.24, "zr": -1.2, "x": 0.78, "y": 0.4, "rest": 0.16, "travel": 0.22,
			"stiff": 46.0, "dc": 2.3, "dr": 2.9, "slip_f": 2.9, "slip_r": 2.6, "roll": 0.12, "maxf": 8000.0},
		"cols": [[Vector3(1.7, 0.62, 3.85), Vector3(0, 0.64, 0)], [Vector3(1.42, 0.52, 2.1), Vector3(0, 1.2, -0.45)]],
		"seat": Vector3(0.36, 0.6, -0.1), "eye": Vector3(0.36, 1.22, -0.05), "hood_cam": Vector3(0, 1.1, 0.65),
		"L": 3.9, "W": 1.74, "bottom": 0.32,
		"prof": [[-1.0, 0.86], [-0.9, 1.0], [-0.3, 0.99], [0.42, 0.92], [1.0, 0.7]],
		"gh": {"z0": 0.75, "z1": 0.05, "z2": -1.55, "z3": -1.86, "y0": 0.97, "y1": 1.48, "wb": 0.77, "wt": 0.63},
		"head": [0.56, 0.62, 0.3, 0.085], "tail": [0.64, 0.84, 0.16, 0.16], "plate_y": 0.52,
		"grille": [0.5, 0.58], "style": "hatch",
	},
	"sports": {
		"name": "veh_sports", "mass": 1380.0, "accel": 14.5, "top": 64.0, "steer": 0.5,
		"drive": "rwd", "brake": 80.0, "gears": 6, "sound": "veh_engine_sport", "pitch": 1.0, "horn": "veh_horn_car",
		"com": Vector3(0, 0.33, -0.05), "roll_assist": 0.0,
		"wheel": {"r": 0.35, "w": 0.3, "zf": 1.45, "zr": -1.38, "x": 0.84, "y": 0.4, "rest": 0.1, "travel": 0.13,
			"stiff": 88.0, "dc": 4.2, "dr": 5.0, "slip_f": 3.5, "slip_r": 3.2, "roll": 0.08, "maxf": 13000.0},
		"cols": [[Vector3(1.9, 0.5, 4.4), Vector3(0, 0.55, 0)], [Vector3(1.4, 0.36, 1.8), Vector3(0, 0.96, -0.35)]],
		"seat": Vector3(0.38, 0.45, -0.4), "eye": Vector3(0.38, 1.02, -0.4), "hood_cam": Vector3(0, 0.88, 0.95),
		"L": 4.5, "W": 1.92, "bottom": 0.26,
		"prof": [[-1.0, 0.7], [-0.82, 0.84], [-0.35, 0.86], [0.25, 0.76], [0.7, 0.66], [1.0, 0.5]],
		"gh": {"z0": 0.6, "z1": -0.05, "z2": -0.65, "z3": -1.75, "y0": 0.8, "y1": 1.18, "wb": 0.82, "wt": 0.6},
		"head": [0.66, 0.58, 0.4, 0.06], "tail": [0.6, 0.72, 0.5, 0.06], "plate_y": 0.42,
		"grille": [0.9, 0.42], "style": "sports",
	},
	"pickup": {
		"name": "veh_pickup", "mass": 2150.0, "accel": 9.5, "top": 45.0, "steer": 0.5,
		"drive": "awd", "brake": 100.0, "gears": 5, "sound": "veh_engine_diesel", "pitch": 0.95, "horn": "veh_horn_truck",
		"com": Vector3(0, 0.7, 0.2), "roll_assist": 0.0,
		"wheel": {"r": 0.44, "w": 0.3, "zf": 1.72, "zr": -1.58, "x": 0.85, "y": 0.55, "rest": 0.26, "travel": 0.36,
			"stiff": 30.0, "dc": 1.7, "dr": 2.3, "slip_f": 3.0, "slip_r": 2.8, "roll": 0.2, "maxf": 17000.0},
		"cols": [[Vector3(1.93, 0.74, 5.15), Vector3(0, 0.92, 0)], [Vector3(1.66, 0.7, 1.65), Vector3(0, 1.6, 0.45)]],
		"seat": Vector3(0.4, 0.98, 0.25), "eye": Vector3(0.4, 1.62, 0.3), "hood_cam": Vector3(0, 1.55, 1.25),
		"L": 5.2, "W": 1.95, "bottom": 0.55,
		"prof": [[-1.0, 1.22], [-0.96, 1.27], [0.3, 1.27], [0.62, 1.24], [1.0, 1.02]],
		"gh": {"z0": 1.25, "z1": 0.65, "z2": -0.3, "z3": -0.42, "y0": 1.27, "y1": 1.96, "wb": 0.86, "wt": 0.74},
		"head": [0.62, 0.92, 0.36, 0.13], "tail": [0.86, 1.0, 0.1, 0.36], "plate_y": 0.75,
		"grille": [0.82, 0.92], "style": "pickup", "bed": [-2.5, -0.5],
	},
	"van": {
		"name": "veh_van", "mass": 1950.0, "accel": 7.5, "top": 37.0, "steer": 0.52,
		"drive": "rwd", "brake": 90.0, "gears": 5, "sound": "veh_engine_diesel", "pitch": 1.15, "horn": "veh_horn_truck",
		"com": Vector3(0, 0.75, 0.1), "roll_assist": 0.0,
		"wheel": {"r": 0.36, "w": 0.24, "zf": 1.62, "zr": -1.45, "x": 0.88, "y": 0.45, "rest": 0.18, "travel": 0.25,
			"stiff": 42.0, "dc": 2.2, "dr": 2.8, "slip_f": 2.9, "slip_r": 2.7, "roll": 0.2, "maxf": 15000.0},
		"cols": [[Vector3(1.93, 1.55, 4.85), Vector3(0, 1.22, -0.05)]],
		"seat": Vector3(0.4, 0.88, 0.7), "eye": Vector3(0.4, 1.58, 0.76), "hood_cam": Vector3(0, 1.32, 2.05),
		"L": 4.9, "W": 1.95, "bottom": 0.42,
		"prof": [[-1.0, 2.0], [-0.97, 2.06], [0.42, 2.06], [0.66, 1.32], [0.78, 1.18], [1.0, 0.98]],
		"gh": {}, "head": [0.66, 0.86, 0.32, 0.13], "tail": [0.88, 1.15, 0.1, 0.5], "plate_y": 0.58,
		"grille": [0.9, 0.74], "style": "van",
	},
	"moto": {
		"name": "veh_moto", "mass": 240.0, "accel": 11.5, "top": 55.0, "steer": 0.42,
		"drive": "rwd", "brake": 14.0, "gears": 6, "sound": "veh_engine_moto", "pitch": 1.0, "horn": "veh_horn_moto",
		"com": Vector3(0, 0.38, 0.0), "roll_assist": 1.0,
		"wheel": {"r": 0.31, "w": 0.16, "zf": 0.72, "zr": -0.68, "x": 0.16, "y": 0.36, "rest": 0.14, "travel": 0.18,
			"stiff": 44.0, "dc": 2.6, "dr": 3.2, "slip_f": 3.2, "slip_r": 3.0, "roll": 0.0, "maxf": 3200.0},
		"cols": [[Vector3(0.55, 0.75, 1.95), Vector3(0, 0.72, 0)]],
		"seat": Vector3(0, 0.82, -0.2), "eye": Vector3(0, 1.62, -0.08), "hood_cam": Vector3(0, 1.35, 0.35),
		"L": 2.1, "W": 0.7, "bottom": 0.3, "style": "moto",
	},
}

## Types parked near the start, in this order, one per slot.
const SHOWCASE := ["sports", "hatch", "pickup", "moto", "van", "sedan", "sports", "moto"]
## Random drivable parked cars pick from this list.
const PARK_MIX := ["sedan", "sedan", "hatch", "hatch", "sports", "pickup", "van", "moto"]

static var _registered := false


static func get_spec(t: String) -> Dictionary:
	return SPECS.get(t, SPECS["sedan"])


## Invented licence plate text (yellow plates, digits only, never a real format check).
static func random_plate(rng: RandomNumberGenerator) -> String:
	var a := rng.randi_range(10, 99)
	var b := rng.randi_range(100, 999)
	var c := rng.randi_range(10, 99)
	return "%d-%d-%d" % [a, b, c]


## Settings defaults and UI strings of the vehicle module. Safe to call many times.
static func register() -> void:
	if _registered:
		return
	_registered = true
	Settings.register_defaults({
		"veh_cam": 0,             # 0 chase, 1 hood, 2 cockpit / helmet
		"veh_tilt": 0,            # 0 off, 1 tilt steering, 2 tilt steering inverted
		"veh_tilt_sens": 1.0,
		"veh_steer_assist": 0.6,  # 0 = raw .. 1 = strong (speed-sensitive lock, counter-steer)
	})
	Loc.register({
		"he": {
			"veh_sedan": "סדאן", "veh_hatch": "האצ'בק", "veh_sports": "מכונית ספורט",
			"veh_pickup": "טנדר 4x4", "veh_van": "מסחרית", "veh_moto": "אופנוע",
			"horn": "צופר", "veh_cam": "מצלמת רכב", "veh_cam_chase": "מאחור", "veh_cam_hood": "מכסה מנוע",
			"veh_cam_cockpit": "גוף ראשון", "veh_tilt": "היגוי בהטיה", "veh_tilt_inv": "הפוך",
			"veh_tilt_sens": "רגישות הטיה", "veh_steer_assist": "סיוע היגוי",
			"veh_cam_hint": "הקשה כפולה במסך: החלפת מצלמה", "veh_wrecked": "הרכב הושמד",
			"veh_gear_r": "R", "veh_gear_n": "N",
		},
		"en": {
			"veh_sedan": "Sedan", "veh_hatch": "Hatchback", "veh_sports": "Sports car",
			"veh_pickup": "Pickup 4x4", "veh_van": "Van", "veh_moto": "Motorcycle",
			"horn": "Horn", "veh_cam": "Vehicle camera", "veh_cam_chase": "Chase", "veh_cam_hood": "Hood",
			"veh_cam_cockpit": "First person", "veh_tilt": "Tilt steering", "veh_tilt_inv": "Inverted",
			"veh_tilt_sens": "Tilt sensitivity", "veh_steer_assist": "Steering assist",
			"veh_cam_hint": "Double-tap the screen: change camera", "veh_wrecked": "Vehicle destroyed",
			"veh_gear_r": "R", "veh_gear_n": "N",
		},
	})

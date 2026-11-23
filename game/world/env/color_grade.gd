extends RefCounted
## Procedural 3D colour-grading LUTs (no image files).
## Three looks are defined as small parameter sets:
##   golden : warm late-afternoon grade, rich saturated highlights, teal-leaning shadows
##   day    : teal-orange split tone, punchy but clean midday
##   night  : cool blue shadows, warm sodium highlights, slightly lifted blacks
## blend() mixes the parameter sets by weight and bake() turns one set into the bytes of
## an N x N x N RGB8 LUT for Environment.adjustment_color_correction (applied after
## tonemapping, in display space). bake() is pure (no scene access), so it can run on a
## worker thread.

const LOOKS := {
	"golden": {
		"curve": 0.32, "pivot": 0.4, "sat": 1.22, "vib": 0.18,
		"shadow": Vector3(-0.030, 0.004, 0.036), "high": Vector3(0.060, 0.016, -0.060),
		"gain": Vector3(1.05, 0.995, 0.90), "lift": Vector3(0.012, 0.010, 0.016),
	},
	"day": {
		"curve": 0.3, "pivot": 0.45, "sat": 1.16, "vib": 0.14,
		"shadow": Vector3(-0.026, 0.008, 0.032), "high": Vector3(0.034, 0.012, -0.030),
		"gain": Vector3(1.025, 1.0, 0.965), "lift": Vector3(0.008, 0.009, 0.013),
	},
	"night": {
		"curve": 0.30, "pivot": 0.32, "sat": 1.0, "vib": 0.1,
		"shadow": Vector3(-0.012, 0.004, 0.040), "high": Vector3(0.050, 0.020, -0.030),
		"gain": Vector3(0.97, 1.0, 1.06), "lift": Vector3(0.010, 0.016, 0.032),
	},
	"overcast": {
		"curve": 0.30, "pivot": 0.45, "sat": 0.92, "vib": 0.05,
		"shadow": Vector3(-0.010, 0.006, 0.020), "high": Vector3(0.010, 0.006, -0.004),
		"gain": Vector3(0.99, 1.0, 1.02), "lift": Vector3(0.012, 0.013, 0.016),
	},
}


## weights: {look_name: weight}. Returns one blended parameter set.
static func blend(weights: Dictionary) -> Dictionary:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var out := {}
	for k in weights:
		var w := float(weights[k]) / maxf(total, 0.0001)
		if w <= 0.0:
			continue
		var look: Dictionary = LOOKS[k]
		for p in look:
			var v: Variant = look[p]
			if out.has(p):
				out[p] = out[p] + v * w
			else:
				out[p] = v * w
	return out


## Distance between two parameter sets (to skip rebakes that would not show).
static func distance(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return 1.0
	var d := 0.0
	for p in a:
		var va: Variant = a[p]
		var vb: Variant = b.get(p, va)
		if va is Vector3:
			d = maxf(d, ((va as Vector3) - (vb as Vector3)).abs().length())
		else:
			d = maxf(d, absf(float(va) - float(vb)))
	return d


## Bakes the LUT: returns one Image (n x n, RGB8) per blue slice.
static func bake(p: Dictionary, n: int) -> Array[Image]:
	var curve := float(p["curve"])
	var pivot := float(p["pivot"])
	var sat := float(p["sat"])
	var vib := float(p["vib"])
	var sh: Vector3 = p["shadow"]
	var hi: Vector3 = p["high"]
	var gain: Vector3 = p["gain"]
	var lift: Vector3 = p["lift"]
	# Tints are luminance-neutral so they shift hue, not brightness.
	sh -= Vector3.ONE * (sh.x * 0.2126 + sh.y * 0.7152 + sh.z * 0.0722)
	hi -= Vector3.ONE * (hi.x * 0.2126 + hi.y * 0.7152 + hi.z * 0.0722)
	var layers: Array[Image] = []
	var inv := 1.0 / float(n)
	for bz in n:
		var bytes := PackedByteArray()
		bytes.resize(n * n * 3)
		var b := (bz + 0.5) * inv
		var i := 0
		for gy in n:
			var g := (gy + 0.5) * inv
			for rx in n:
				var c := Vector3((rx + 0.5) * inv, g, b)
				c = _grade(c, curve, pivot, sat, vib, sh, hi, gain, lift)
				bytes[i] = clampi(int(c.x * 255.0 + 0.5), 0, 255)
				bytes[i + 1] = clampi(int(c.y * 255.0 + 0.5), 0, 255)
				bytes[i + 2] = clampi(int(c.z * 255.0 + 0.5), 0, 255)
				i += 3
		layers.append(Image.create_from_data(n, n, false, Image.FORMAT_RGB8, bytes))
	return layers


static func _grade(c: Vector3, curve: float, pivot: float, sat: float, vib: float,
		sh: Vector3, hi: Vector3, gain: Vector3, lift: Vector3) -> Vector3:
	# Filmic S-curve around a pivot (deeper shadows, rolled-off highlights).
	var s := Vector3(_s(c.x, pivot), _s(c.y, pivot), _s(c.z, pivot))
	c = c.lerp(s, curve)
	var l := c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722
	# Split toning: teal into the shadows, warm into the highlights.
	var ws := (1.0 - l) * (1.0 - l)
	var wh := l * l
	c += sh * ws + hi * wh
	# Saturation with vibrance (muted colours gain more than already-strong ones).
	var mx := maxf(c.x, maxf(c.y, c.z))
	var mn := minf(c.x, minf(c.y, c.z))
	var chroma := mx - mn
	var k := sat + vib * (1.0 - clampf(chroma * 2.0, 0.0, 1.0))
	c = Vector3(l, l, l) + (c - Vector3(l, l, l)) * k
	c *= gain
	# Film-like black lift.
	c = lift + c * (Vector3.ONE - lift)
	return c.clamp(Vector3.ZERO, Vector3.ONE)


static func _s(x: float, pivot: float) -> float:
	# Two smooth halves meeting at the pivot: contrast around mid-grey.
	if x < pivot:
		var t := x / pivot
		return pivot * t * t * (3.0 - 2.0 * t) * 0.5 + pivot * t * 0.5
	var u := (x - pivot) / (1.0 - pivot)
	return pivot + (1.0 - pivot) * (u * u * (3.0 - 2.0 * u) * 0.5 + u * 0.5)

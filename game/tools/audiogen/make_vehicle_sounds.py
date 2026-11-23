"""Generates the vehicle sounds (engines, horns, tyre squeal, explosion, glass, fire)
with numpy synthesis - no samples, everything is free to use.
Run: python3 make_vehicle_sounds.py <out_dir>
Loops (engines, horns, skid, fire) are cross-faded so they repeat without a click;
their .import files use loop_mode=2 (forward)."""
import sys, wave, os
import numpy as np

OUT = sys.argv[1]
SR = 22050
rng = np.random.default_rng(7)


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack, decay):
    tt = np.arange(n) / SR
    return np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def loopify(x, fade_sec=0.15):
    """Cross-fades the tail into the head so the clip loops seamlessly."""
    f = int(fade_sec * SR)
    head = x[:f]
    tail = x[-f:]
    k = np.linspace(0, 1, f)
    out = x[:-f].copy()
    out[:f] = tail * (1 - k) + head * k
    return out


def engine(name, f0, harmonics, rasp, rasp_cut, firing_pulse, wobble, peak=0.7, length=1.0):
    n = int((length + 0.15) * SR)
    tt = np.arange(n) / SR
    # Slight random cycle-to-cycle jitter makes it sound mechanical rather than electronic.
    jitter = lowpass(noise(n), 6) * wobble
    phase = 2 * np.pi * np.cumsum(f0 * (1 + jitter)) / SR
    x = np.zeros(n)
    for k, amp in enumerate(harmonics, start=1):
        x += amp * np.sin(k * phase + k * 0.7)
    # Combustion pulses: sharp bursts of noise once per firing.
    pulse = np.maximum(np.sin(phase * firing_pulse), 0) ** 6
    x += lowpass(noise(n), rasp_cut) * pulse * rasp
    x += lowpass(noise(n), 300) * 0.15
    save(name, norm(loopify(x), peak))


# Small 4-cylinder hatchback: buzzy, higher idle.
engine("veh_engine_hatch", 38.0, [1.0, 0.7, 0.5, 0.55, 0.25, 0.2, 0.1, 0.08], 0.6, 2200, 1.0, 0.01)
# Sports car V8: deep uneven burble (strong half-order) and a raspy exhaust.
engine("veh_engine_sport", 30.0, [0.6, 1.0, 0.45, 0.8, 0.3, 0.35, 0.2, 0.15, 0.1], 1.2, 3200, 0.5, 0.02)
# Diesel pickup / van: low, clattery.
engine("veh_engine_diesel", 24.0, [1.0, 0.8, 0.6, 0.3, 0.25, 0.1], 1.6, 4200, 1.0, 0.015)
# Motorcycle twin: sharp pulses, lots of exhaust noise.
engine("veh_engine_moto", 46.0, [1.0, 0.4, 0.6, 0.2, 0.3, 0.1], 1.4, 3800, 0.5, 0.03, 0.65)


def horn(name, freqs, length=0.6, bright=2600):
    n = int((length + 0.15) * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        # Square-ish tone through a low-pass: the classic electric horn buzz.
        x += np.tanh(4 * np.sin(2 * np.pi * f * tt))
    x = lowpass(x, bright) * 0.8 + x * 0.2
    save(name, norm(loopify(x, 0.1), 0.7))


horn("veh_horn_car", [415.0, 494.0])
horn("veh_horn_truck", [277.0, 349.0], bright=1800)
horn("veh_horn_moto", [622.0, 740.0], bright=3600)

# Tyre squeal loop: band-passed noise plus a wavering squeal tone.
n = int(1.15 * SR)
tt = np.arange(n) / SR
sq_f = 960 + 90 * np.sin(2 * np.pi * 3.0 * tt) + 40 * lowpass(noise(n), 8) * 30
sq = np.sin(2 * np.pi * np.cumsum(sq_f) / SR)
sq += 0.5 * np.sin(2 * np.pi * np.cumsum(sq_f * 2.01) / SR)
hiss = highpass(lowpass(noise(n), 3500), 700)
amp = 0.7 + 0.3 * lowpass(noise(n), 12) * 10
save("veh_skid", norm(loopify(sq * 0.55 * amp + hiss * 0.9), 0.6))

# Explosion: a low thump that sweeps down, a noise blast and a crackling tail.
n = int(3.0 * SR)
tt = np.arange(n) / SR
thump = np.sin(2 * np.pi * (70 * np.exp(-tt * 2.5) + 28) * tt) * env(n, 0.002, 0.45)
blast = lowpass(noise(n), 1800) * env(n, 0.001, 0.35)
rumble = lowpass(noise(n), 250) * env(n, 0.02, 1.1) * 1.4
crackle = (rng.uniform(0, 1, n) > 0.9985) * rng.uniform(-1, 1, n) * 3.0
crackle = lowpass(crackle, 2500) * env(n, 0.3, 1.0)
save("veh_explosion", norm(thump * 1.2 + blast + rumble + crackle, 0.95))

# Glass breaking: tinkling high partials and a short crunch.
n = int(0.7 * SR)
tt = np.arange(n) / SR
glass = highpass(noise(n), 3000) * env(n, 0.001, 0.05)
for i in range(14):
    t0 = rng.uniform(0.0, 0.35)
    f = rng.uniform(2500, 6500)
    e = np.where(tt > t0, np.exp(-(tt - t0) / rng.uniform(0.03, 0.12)), 0.0)
    glass += np.sin(2 * np.pi * f * tt) * e * rng.uniform(0.2, 0.5)
save("veh_glass", norm(glass, 0.6))

# Burning wreck: low roar with random crackles (loop).
n = int(2.15 * SR)
roar = lowpass(noise(n), 400) * (0.8 + 0.2 * lowpass(noise(n), 3) * 20)
cr = (rng.uniform(0, 1, n) > 0.997) * rng.uniform(-1, 1, n) * 4.0
cr = highpass(lowpass(cr, 4000), 600)
save("veh_fire", norm(loopify(roar + cr, 0.2), 0.6))

print("vehicle sounds written to", OUT)

"""Generates the weather sounds (rain loop, distant thunder) with numpy synthesis,
so they are free to use. Run: python3 make_weather_sounds.py <out_dir>"""
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


def onepole(x, cutoff, hp=False):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return x - y if hp else y


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def rain(length=6.0, fade=0.6):
    n = int((length + fade) * SR)
    # Steady wash: band-limited noise (hiss of many tiny drops on asphalt).
    wash = onepole(onepole(rng.uniform(-1, 1, n), 5200), 380, hp=True)
    # Lower roar from drops on roofs and cars, slowly breathing.
    roar = onepole(rng.uniform(-1, 1, n), 700)
    tt = np.arange(n) / SR
    roar *= 0.75 + 0.25 * np.sin(2 * np.pi * tt / (length + fade) * 3)
    # Individual nearby drops: short filtered ticks at random times.
    drops = np.zeros(n)
    k = np.arange(600)
    for _ in range(int(length * 70)):
        p = rng.integers(0, n - 800)
        f = rng.uniform(1800, 5200)
        drops[p:p + 600] += np.sin(2 * np.pi * f * k / SR) * np.exp(-k / rng.uniform(25, 90)) * rng.uniform(0.2, 1.0)
    x = norm(wash) * 0.55 + norm(roar) * 0.35 + norm(drops) * 0.25
    # Seamless loop: cross-fade the extra tail into the start.
    m = int(fade * SR)
    out = x[:n - m].copy()
    w = np.linspace(0, 1, m)
    out[:m] = x[:m] * w + x[n - m:] * (1 - w)
    save("rain_loop", norm(out, 0.8))


def thunder(length=5.5):
    n = int(length * SR)
    tt = np.arange(n) / SR
    brown = np.cumsum(rng.uniform(-1, 1, n))
    brown = onepole(brown - onepole(brown, 20), 160)
    # Several rolling rumbles after the first crack.
    env = np.zeros(n)
    for start, dec, amp in [(0.0, 0.35, 1.0), (0.35, 0.9, 0.8), (1.1, 1.4, 0.6), (2.2, 1.8, 0.45)]:
        e = np.clip((tt - start) / 0.06, 0, 1) * np.exp(-np.clip(tt - start, 0, None) / dec)
        env = np.maximum(env, e * amp)
    crack = onepole(rng.uniform(-1, 1, n), 2500) * np.exp(-tt / 0.08) * 0.5
    x = norm(brown) * env + crack
    x *= np.clip((length - tt) / 0.5, 0, 1)
    save("thunder", norm(x, 0.95))


rain()
thunder()

"""Generates the sniper sounds with numpy synthesis (no samples, free to use).
Run: python3 make_sounds.py <out_dir>"""
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


def tt(n):
    return np.arange(n) / SR


def noise(n):
    return rng.uniform(-1, 1, n)


def onepole(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay):
    t = tt(n)
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)


def norm(x, peak=0.92):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def shot():
    n = int(2.2 * SR)
    t = tt(n)
    crack = noise(n) * env(n, 0.0003, 0.006)
    blast = onepole(noise(n), 2500) * env(n, 0.0008, 0.05) * 1.6
    boom = np.sin(2 * np.pi * 62 * t * (1 - t * 0.6)) * env(n, 0.002, 0.12)
    # Echoes rolling back from far buildings / hills.
    tail = np.zeros(n)
    for d, g in [(0.18, 0.5), (0.42, 0.35), (0.75, 0.25), (1.1, 0.15)]:
        k = int(d * SR)
        e = onepole(noise(n - k), 600) * env(n - k, 0.02, 0.35) * g
        tail[k:] += e
    x = crack * 1.0 + blast + boom * 0.9 + tail * 1.8
    save("sniper_shot", norm(x))


def bolt():
    n = int(0.75 * SR)
    x = np.zeros(n)
    for start, f, g in [(0.02, 3200, 1.0), (0.12, 1800, 0.6), (0.42, 2600, 0.8), (0.5, 4200, 1.0)]:
        k = int(start * SR)
        m = int(0.05 * SR)
        c = noise(m) * env(m, 0.0004, 0.006)
        c += np.sin(2 * np.pi * f * tt(m)) * env(m, 0.0002, 0.01) * 0.6
        x[k:k + m] += c * g
    # Sliding metal between the two clicks.
    k0, k1 = int(0.14 * SR), int(0.42 * SR)
    x[k0:k1] += onepole(noise(k1 - k0), 3000) * 0.08
    save("sniper_bolt", norm(x, 0.7))


def tick():
    n = int(0.09 * SR)
    t = tt(n)
    x = np.sin(2 * np.pi * 2900 * t) * env(n, 0.0005, 0.018) + noise(n) * env(n, 0.0002, 0.004) * 0.5
    save("hit_tick", norm(x, 0.8))


def ding():
    n = int(1.4 * SR)
    t = tt(n)
    x = np.zeros(n)
    for f, g, d in [(820, 1.0, 0.5), (1371, 0.6, 0.35), (2210, 0.4, 0.22), (3150, 0.25, 0.12)]:
        x += np.sin(2 * np.pi * f * t) * env(n, 0.0005, d) * g
    x += noise(n) * env(n, 0.0002, 0.003) * 0.6
    save("steel_ding", norm(x, 0.85))


def breath(name, rise):
    n = int(0.7 * SR)
    t = tt(n)
    shape = np.sin(np.pi * np.minimum(t / 0.7, 1.0)) ** (1.5 if rise else 0.8)
    x = onepole(noise(n), 900 if rise else 650) * shape
    save(name, norm(x, 0.35))


def heartbeat():
    n = int(0.9 * SR)
    x = np.zeros(n)
    for s, g in [(0.0, 1.0), (0.22, 0.7)]:
        k = int(s * SR)
        m = int(0.15 * SR)
        x[k:k + m] += np.sin(2 * np.pi * 48 * tt(m)) * env(m, 0.004, 0.04) * g
    save("heartbeat", norm(x, 0.5))


if __name__ == "__main__":
    shot(); bolt(); tick(); ding(); breath("breath_in", True); breath("breath_out", False); heartbeat()

"""Polish sounds: ambient city loops, surface footsteps, weapon handling, UI clicks,
photo shutter and the combat music layer. Pure numpy synthesis (no samples), so all
of it is free to use. Filters are done in the frequency domain, which also makes the
ambient loops wrap around seamlessly.

Run: python3 make_polish_sounds.py <out_dir>      (e.g. ../../assets/audio)
"""
import os
import sys
import wave

import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SR = 22050
rng = np.random.default_rng(2026)


def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tt(sec):
    return np.arange(int(sec * SR)) / SR


def noise(n):
    return rng.uniform(-1, 1, n)


def band(x, lo, hi, soft=0.25):
    """Circular FFT band-pass with smooth edges (lo=0 -> low-pass)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 / soft))
    if hi > 0:
        g *= 1 / (1 + (f / hi) ** (2 / soft))
    return np.fft.irfft(spec * g, len(x))


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def loop_lfo(n, cycles, phase=0.0):
    """A slow wobble that completes whole cycles over the loop (so it wraps)."""
    return np.sin(2 * np.pi * cycles * np.arange(n) / n + phase)


# ------------------------------------------------------------------ ambience
def amb_city():
    sec = 16.0
    n = int(sec * SR)
    hum = band(noise(n), 30, 260) * 1.0                      # far traffic rumble
    hum *= 0.75 + 0.18 * loop_lfo(n, 3) + 0.07 * loop_lfo(n, 7, 1.0)
    hiss = band(noise(n), 900, 3500) * 0.12                    # tyres on asphalt, far away
    hiss *= 0.6 + 0.4 * (0.5 + 0.5 * loop_lfo(n, 5, 2.0))
    x = hum + hiss
    # A few passing cars (doppler-ish swell of filtered noise), placed so they wrap.
    for c in range(5):
        centre = rng.uniform(0, n)
        width = rng.uniform(1.2, 2.5) * SR
        idx = np.arange(n)
        d = np.minimum(np.abs(idx - centre), n - np.abs(idx - centre))
        swell = np.exp(-(d / width) ** 2)
        x += band(noise(n), 120, 900) * swell * 0.35
    # Two very distant horns.
    for c in range(2):
        start = int(rng.uniform(0.1, 0.8) * n)
        ln = int(rng.uniform(0.25, 0.45) * SR)
        t = np.arange(ln) / SR
        f = rng.uniform(380, 470)
        horn = (np.sign(np.sin(2 * np.pi * f * t)) + np.sign(np.sin(2 * np.pi * f * 1.26 * t))) * 0.5
        horn = band(np.concatenate([horn, np.zeros(SR)]), 200, 1200)[:ln]
        horn *= np.minimum(t / 0.03, 1) * np.minimum((ln / SR - t) / 0.06, 1)
        x[start:start + ln] += horn * 0.05
    save("amb_city", norm(x, 0.6))


def amb_birds():
    sec = 14.0
    n = int(sec * SR)
    x = band(noise(n), 1500, 6000) * 0.03                     # leaves / light air
    t_all = np.arange(n) / SR
    for _ in range(38):
        start = rng.uniform(0, sec - 0.8)
        kind = rng.integers(0, 3)
        notes = rng.integers(2, 6)
        base = rng.uniform(2600, 4800)
        pos = start
        vol = rng.uniform(0.25, 0.8)
        for k in range(notes):
            ln = rng.uniform(0.04, 0.12)
            m = int(ln * SR)
            t = np.arange(m) / SR
            if kind == 0:       # chirp up
                f = base * (1 + 0.6 * t / ln)
            elif kind == 1:     # warble
                f = base * (1 + 0.12 * np.sin(2 * np.pi * 38 * t))
            else:               # falling whistle
                f = base * (1.3 - 0.5 * t / ln)
            ph = 2 * np.pi * np.cumsum(f) / SR
            s = np.sin(ph) * np.sin(np.pi * t / ln) ** 2
            i = int(pos * SR)
            x[i:i + m] += s[: max(0, min(m, n - i))] * vol * 0.35
            pos += ln + rng.uniform(0.02, 0.09)
    del t_all
    save("amb_birds", norm(x, 0.5))


def amb_wind():
    sec = 15.0
    n = int(sec * SR)
    base = band(noise(n), 60, 700)
    gust = 0.55 + 0.3 * loop_lfo(n, 2) + 0.15 * loop_lfo(n, 5, 0.7)
    whistle = band(noise(n), 700, 1400, 0.12) * (0.5 + 0.5 * loop_lfo(n, 3, 2.1)) * 0.25
    save("amb_wind", norm(base * gust + whistle, 0.55))


# ------------------------------------------------------------------ footsteps
def step(name, lo, hi, thump_hz, decay, crunch=0.0, variants=3):
    for v in range(variants):
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        heel = band(noise(n), lo, hi) * env(n, 0.001, decay)
        toe_d = int(rng.uniform(0.035, 0.06) * SR)
        toe = np.zeros(n)
        toe[toe_d:] = band(noise(n - toe_d), lo * 1.4, hi * 1.2) * env(n - toe_d, 0.001, decay * 0.7) * 0.55
        thump = np.sin(2 * np.pi * thump_hz * rng.uniform(0.9, 1.1) * t) * env(n, 0.002, 0.03) * 0.7
        x = heel + toe + thump
        if crunch > 0:
            # Grass: many tiny clicks of blades and leaves.
            c = np.zeros(n)
            for _ in range(40):
                i = int(rng.uniform(0, 0.12) * SR)
                c[i] += rng.uniform(-1, 1)
            c = band(c, 2000, 7000) * crunch
            x += c * env(n, 0.005, 0.07)
        save("%s_%d" % (name, v + 1), norm(x, 0.8))


# ------------------------------------------------------------------ weapon handling
def click(n, f, d):
    t = np.arange(n) / SR
    return (band(noise(n), f * 0.5, f * 2) * 0.8 + np.sin(2 * np.pi * f * t) * 0.4) * env(n, 0.0005, d)


def place(dst, src, at_sec, vol=1.0):
    i = int(at_sec * SR)
    m = min(len(src), len(dst) - i)
    dst[i:i + m] += src[:m] * vol


def weapon_sounds():
    # Reload: magazine out (slide + click), magazine in (thunk), charging handle (rack).
    n = int(1.3 * SR)
    x = np.zeros(n)
    place(x, click(int(0.08 * SR), 2400, 0.01), 0.02, 0.8)
    slide = band(noise(int(0.18 * SR)), 1200, 5000) * np.hanning(int(0.18 * SR)) * 0.35
    place(x, slide, 0.06)
    place(x, click(int(0.1 * SR), 900, 0.03), 0.55, 1.0)
    place(x, np.sin(2 * np.pi * 140 * tt(0.12)) * env(int(0.12 * SR), 0.001, 0.03), 0.55, 0.6)
    place(x, click(int(0.06 * SR), 3200, 0.006), 0.62, 0.7)
    rack = band(noise(int(0.12 * SR)), 1500, 6000) * np.hanning(int(0.12 * SR)) * 0.4
    place(x, rack, 0.95)
    place(x, click(int(0.09 * SR), 1800, 0.015), 1.06, 1.0)
    save("weapon_reload", norm(x, 0.8))

    # Weapon switch: cloth rustle + metal tick.
    n = int(0.45 * SR)
    x = np.zeros(n)
    rustle = band(noise(int(0.25 * SR)), 300, 2500) * np.hanning(int(0.25 * SR)) * 0.5
    place(x, rustle, 0.0)
    place(x, click(int(0.08 * SR), 2600, 0.012), 0.22, 0.9)
    place(x, click(int(0.06 * SR), 1500, 0.01), 0.28, 0.5)
    save("weapon_switch", norm(x, 0.75))


# ------------------------------------------------------------------ UI + photo
def ui_sounds():
    n = int(0.07 * SR)
    t = np.arange(n) / SR
    c = (np.sin(2 * np.pi * 1700 * t) * 0.6 + np.sin(2 * np.pi * 2550 * t) * 0.3) * env(n, 0.001, 0.012)
    c += band(noise(n), 3000, 8000) * env(n, 0.0005, 0.004) * 0.3
    save("ui_click", norm(c, 0.6))
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = 600 + 500 * t / 0.18
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.005, 0.06)
    save("ui_open", norm(s, 0.5))
    # Camera shutter: two quick mechanical clicks.
    n = int(0.25 * SR)
    x = np.zeros(n)
    place(x, click(int(0.05 * SR), 3500, 0.006), 0.0, 1.0)
    place(x, band(noise(int(0.06 * SR)), 1500, 6000) * env(int(0.06 * SR), 0.001, 0.02), 0.03, 0.5)
    place(x, click(int(0.05 * SR), 2800, 0.008), 0.11, 0.8)
    save("photo_shutter", norm(x, 0.8))


# ------------------------------------------------------------------ combat music
def note_hz(semi):
    return 110.0 * 2 ** (semi / 12.0)


def music_action():
    bpm = 124
    beat = 60.0 / bpm
    bars = 16
    n = int(bars * 4 * beat * SR)
    mix = np.zeros(n + SR)
    roots = [0, 0, -4, -2]     # A minor: Am Am F G
    for b in range(bars):
        root = roots[(b // 2) % 4]
        bar0 = b * 4 * beat
        # Driving 16th bass ostinato.
        for k in range(16):
            ln = int(beat / 4 * 0.85 * SR)
            t = np.arange(ln) / SR
            semi = root + (12 if k % 8 == 6 else 0) - 12
            f = note_hz(semi)
            saw = 2 * ((f * t) % 1.0) - 1
            tone = band(np.concatenate([saw, np.zeros(256)]), 0, 900)[:ln] * env(ln, 0.002, 0.08)
            place(mix, tone, bar0 + k * beat / 4, 0.32)
        # Drums: kick on 1 and 3 (+ pickup), snare on 2 and 4, tom fill every 4th bar.
        for k in range(8):
            pos = bar0 + k * beat / 2
            if k in (0, 4) or k == 7:
                kl = int(0.35 * SR)
                t = np.arange(kl) / SR
                kick = np.sin(2 * np.pi * (48 + 100 * np.exp(-t * 35)) * t) * np.exp(-t * 10)
                place(mix, kick, pos, 0.9)
            if k in (2, 6):
                sl = int(0.25 * SR)
                t = np.arange(sl) / SR
                sn = (band(noise(sl), 800, 7000) * 0.8 + np.sin(2 * np.pi * 185 * t) * 0.4) * np.exp(-t * 16)
                place(mix, sn, pos, 0.55)
            hl = int(0.05 * SR)
            place(mix, band(noise(hl), 6000, 10000) * env(hl, 0.0005, 0.012), pos, 0.3)
            place(mix, band(noise(hl), 6000, 10000) * env(hl, 0.0005, 0.008), pos + beat / 4, 0.18)
        if b % 4 == 3:
            for k in range(4):
                tl = int(0.3 * SR)
                t = np.arange(tl) / SR
                tom = np.sin(2 * np.pi * (160 - k * 25) * t) * np.exp(-t * 12)
                place(mix, tom, bar0 + 3 * beat + k * beat / 4, 0.5)
        # Tense string-like stabs (detuned saws, filtered) on the off-beats.
        for k in (1, 3):
            sl = int(beat * 0.45 * SR)
            t = np.arange(sl) / SR
            chord = [root, root + 3, root + 7]
            st = sum(2 * ((note_hz(s + 12) * d * t) % 1.0) - 1 for s in chord for d in (0.997, 1.003))
            st = band(np.concatenate([st, np.zeros(256)]), 200, 2500)[:sl] * env(sl, 0.01, 0.12)
            place(mix, st, bar0 + k * beat, 0.07)
        # Rising pulse in the last two bars of every 8 to build tension.
        if b % 8 >= 6:
            pl = int(4 * beat * SR)
            t = np.arange(pl) / SR
            f = note_hz(root + 24) * (1 + 0.06 * t / (4 * beat))
            pulse = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 8 / beat * t)))
            place(mix, pulse * np.linspace(0.0, 1.0, pl), bar0, 0.05)
    mix = mix[:n]
    fade = int(0.03 * SR)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix[-fade:] *= np.linspace(1, 0, fade)
    save("music_action", norm(mix, 0.75))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    amb_city()
    amb_birds()
    amb_wind()
    step("step_pave", 200, 3000, 90, 0.025)
    step("step_grass", 300, 4500, 70, 0.04, crunch=0.6)
    step("step_indoor", 120, 1600, 110, 0.03)
    weapon_sounds()
    ui_sounds()
    music_action()
    print("done")

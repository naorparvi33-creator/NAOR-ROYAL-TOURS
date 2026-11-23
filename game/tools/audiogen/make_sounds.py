"""Generates every sound effect and music track of the game with numpy synthesis
(no samples, so everything is free to use). Run: python3 make_sounds.py <out_dir>"""
import sys, wave, os
import numpy as np

OUT = sys.argv[1]
SR = 22050
rng = np.random.default_rng(42)


def save(name, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def t(sec):
    return np.arange(int(sec * SR)) / SR


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    # simple one-pole low-pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay):
    tt = np.arange(n) / SR
    e = np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)
    return e


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


# ---------------- weapons
def gunshot(name, body_hz, crack_decay, tail_decay, length):
    n = int(length * SR)
    tt = np.arange(n) / SR
    crack = noise(n) * env(n, 0.0005, crack_decay)
    boom = np.sin(2 * np.pi * body_hz * tt * (1 - tt * 0.8)) * env(n, 0.001, crack_decay * 4)
    tail = lowpass(noise(n), 900) * env(n, 0.01, tail_decay) * 0.6     # echo off buildings
    x = crack * 0.9 + boom * 0.8 + tail
    save(name, norm(x))


gunshot("gun_rifle", 95, 0.012, 0.35, 0.9)
gunshot("gun_pistol", 140, 0.008, 0.22, 0.6)

# ---------------- impacts
n = int(0.25 * SR)
tt = np.arange(n) / SR
thud = np.sin(2 * np.pi * 70 * tt) * env(n, 0.002, 0.05) + lowpass(noise(n), 1500) * env(n, 0.001, 0.03)
save("punch", norm(thud))
squish = lowpass(noise(n), 2500) * env(n, 0.001, 0.06) + np.sin(2 * np.pi * 110 * tt) * env(n, 0.001, 0.04) * 0.6
save("hit_flesh", norm(squish, 0.8))
n = int(0.18 * SR)
tt = np.arange(n) / SR
tick = noise(n) * env(n, 0.0003, 0.01) + np.sin(2 * np.pi * (3200 - 9000 * tt) * tt) * env(n, 0.001, 0.05) * 0.3
save("bullet_impact", norm(tick, 0.6))

# ---------------- car
# Engine loop: harmonics of a 4-cylinder idle at ~30 Hz firing, seamless 1 s loop.
n = SR
tt = np.arange(n) / SR
f0 = 32.0
eng = sum(np.sin(2 * np.pi * f0 * k * tt + k) / k for k in range(1, 9))
eng += lowpass(noise(n), 400) * 0.25
eng *= 0.8 + 0.2 * np.sin(2 * np.pi * f0 * 0.5 * tt)
save("car_engine", norm(eng, 0.7))
n = int(0.35 * SR)
tt = np.arange(n) / SR
door = np.sin(2 * np.pi * 90 * tt) * env(n, 0.001, 0.06) + lowpass(noise(n), 1200) * env(n, 0.001, 0.04)
save("car_door", norm(door))
n = int(1.0 * SR)
crash = lowpass(noise(n), 3000) * env(n, 0.001, 0.25) + np.sin(2 * np.pi * 55 * np.arange(n) / SR) * env(n, 0.001, 0.2)
save("car_crash", norm(crash))

# ---------------- UI / mission jingles
def tone_seq(notes, dur, wave_shape=np.sin, vol=0.6):
    out = []
    for f in notes:
        n = int(dur * SR)
        tt = np.arange(n) / SR
        s = wave_shape(2 * np.pi * f * tt) * env(n, 0.005, dur * 0.6)
        out.append(s)
    return np.concatenate(out) * vol


save("mission_start", norm(tone_seq([392, 523, 659], 0.12)))
save("mission_done", norm(tone_seq([523, 659, 784, 1047], 0.14)))
save("mission_fail", norm(tone_seq([392, 330, 262], 0.18)))
save("money", norm(tone_seq([1318, 1760], 0.07)))


# ---------------- music
def note_hz(semis):
    return 220.0 * 2 ** (semis / 12.0)


def pad(freqs, length, bright=0.3):
    n = int(length * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        for det in (-0.6, 0.0, 0.7):
            ff = f * 2 ** (det / 1200 * 10)
            x += np.sin(2 * np.pi * ff * tt) + bright * np.sin(4 * np.pi * ff * tt)
    attack = np.minimum(tt / 0.4, 1)
    release = np.minimum((length - tt) / 0.4, 1)
    return x * attack * release / (len(freqs) * 3)


def kick(n):
    tt = np.arange(n) / SR
    return np.sin(2 * np.pi * (50 + 90 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 9)


def snare(n):
    tt = np.arange(n) / SR
    return (noise(n) * 0.7 + np.sin(2 * np.pi * 190 * tt) * 0.3) * np.exp(-tt * 18)


def hat(n):
    tt = np.arange(n) / SR
    return noise(n) * np.exp(-tt * 70) * 0.5


def song(name, bpm, chords, bars, drums, bass_oct=-12, lead=None, swing=0.0, lofi=False):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bars * bar
    n = int(total * SR)
    mix = np.zeros(n + SR)
    for b in range(bars):
        ch = chords[b % len(chords)]
        start = int(b * bar * SR)
        p = pad([note_hz(s) for s in ch], bar, 0.25)
        mix[start:start + len(p)] += p * 0.5
        # bass on beats
        for k in range(4):
            bs = int((b * bar + k * beat) * SR)
            ln = int(beat * 0.9 * SR)
            tt = np.arange(ln) / SR
            f = note_hz(ch[0] + bass_oct)
            mix[bs:bs + ln] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 3) * 0.45
        if drums:
            for k in range(8):
                pos = b * bar + k * beat / 2 + (swing * beat / 2 if k % 2 else 0)
                s = int(pos * SR)
                if k in (0, 4) or (drums == "busy" and k == 3):
                    kk = kick(int(0.4 * SR)); mix[s:s + len(kk)] += kk * 0.8
                if k in (2, 6):
                    sn = snare(int(0.25 * SR)); mix[s:s + len(sn)] += sn * 0.45
                hh = hat(int(0.08 * SR)); mix[s:s + len(hh)] += hh * (0.25 if k % 2 else 0.35)
        if lead:
            for k, semi in enumerate(lead[b % len(lead)]):
                if semi is None:
                    continue
                s = int((b * bar + k * beat / 2) * SR)
                ln = int(beat / 2 * SR)
                tt = np.arange(ln) / SR
                f = note_hz(semi + 12)
                tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sign(np.sin(2 * np.pi * f * tt))) * env(ln, 0.01, 0.18)
                mix[s:s + ln] += tone * 0.22
    mix = mix[:n]
    if lofi:
        mix = lowpass(mix, 3500) + lowpass(noise(n), 6000) * 0.012   # warm, slight vinyl hiss
    # Seamless loop: short crossfade of the tail into the head.
    fade = int(0.05 * SR)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix[-fade:] *= np.linspace(1, 0, fade)
    save(name, norm(mix, 0.75))


# Calm city walk: lo-fi, Am - F - C - G
song("music_city", 78, [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]], 12, "soft", lofi=True, swing=0.18,
     lead=[[12, None, 10, None, 7, None, None, None], [8, None, 7, None, 5, None, None, None],
           [10, None, 12, None, 15, None, 14, None], [10, None, 9, None, 7, None, None, None]])
# Radio 1: driving synthwave, Dm - Bb - F - C
song("radio_synth", 112, [[5, 8, 12], [1, 5, 8], [8, 12, 15], [3, 7, 10]], 16, "busy",
     lead=[[17, 17, 20, 17, 15, None, 13, None], [13, 13, 17, 13, 12, None, 10, None],
           [12, 15, 20, 15, 12, None, 15, None], [10, 12, 15, 12, 10, None, None, None]])
# Radio 2: laid-back hip-hop beat, Em - C - G - D
song("radio_beats", 90, [[7, 10, 14], [3, 7, 10], [10, 14, 17], [5, 9, 12]], 16, "busy", lofi=True, swing=0.25)
print("done")

"""Generates the police siren loop (synthesised, free to use).
Run: python3 make_siren.py <out_dir>   (writes siren.wav)

A classic electronic "wail": a bright, slightly square tone that sweeps up and down
over four seconds, with a short horn-like resonance and a touch of saturation.
The sweep is phase-continuous and the loop length holds a whole number of cycles of
every partial, so it loops without a click (the .import file sets loop mode)."""
import sys, wave, os
import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SR = 22050
LENGTH = 4.0            # one wail cycle = one loop
F_LO, F_HI = 640.0, 1380.0


def save(name, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def wail():
    n = int(LENGTH * SR)
    tt = np.arange(n) / SR
    # Rise quickly, hold near the top, fall slowly: like a motor-driven siren.
    u = tt / LENGTH
    shape = np.where(u < 0.42, np.sin(u / 0.42 * np.pi * 0.5), np.cos((u - 0.42) / 0.58 * np.pi * 0.5))
    shape = shape ** 1.3
    f = F_LO + (F_HI - F_LO) * shape
    phase = np.cumsum(f) / SR
    # Round the total phase to whole cycles so the loop is seamless.
    total = phase[-1]
    phase *= np.round(total) / total
    p = 2 * np.pi * phase
    tone = np.sin(p) + 0.45 * np.sin(2 * p) + 0.3 * np.sin(3 * p) + 0.12 * np.sin(5 * p)
    tone = np.tanh(tone * 1.6)                        # horn driver saturation
    tone = lowpass(tone, 4200) * 0.8 + tone * 0.2
    # Slight amplitude flutter from the rotating horn.
    tone *= 0.9 + 0.1 * np.sin(2 * np.pi * 6.0 * tt)
    tone = tone / (np.max(np.abs(tone)) + 1e-9) * 0.8
    return tone


save("siren", wail())
print("siren.wav written to", OUT)

#!/usr/bin/env python3
"""Procedural palm trunk texture: ringed leaf scars, fibres and weathering.

Writes game/assets/textures/palmbark_albedo.jpg and palmbark_normal.jpg (512x512,
seamless in both directions). U wraps once around the trunk, V repeats once per
metre of height (see Props.palm), so there are 5 rings per metre.

Run:  python3 game/tools/foliagegen/make_palm_trunk.py
"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures")
N = 512
RINGS = 5


def tile_noise(rng, n, cells):
    """Seamless value noise (bilinear on a wrapped grid)."""
    g = rng.random((cells, cells))
    x = np.linspace(0, cells, n, endpoint=False)
    i0 = np.floor(x).astype(int)
    f = x - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = g[np.ix_(i0, i0)]
    b = g[np.ix_(i0, i1)]
    c = g[np.ix_(i1, i0)]
    d = g[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def main():
    rng = np.random.default_rng(5)
    v = np.linspace(0, 1, N, endpoint=False)[:, None]
    u = np.linspace(0, 1, N, endpoint=False)[None, :]
    # Ring position wobbles around the trunk (seamless: integer frequencies in u).
    wob = 0.004 * np.sin(u * np.pi * 2 * 2 + 1.0) + 0.003 * np.sin(u * np.pi * 2 * 7 + 2.0)
    wob = wob + 0.012 * (tile_noise(rng, N, 16)[0:1, :] - 0.5)
    ph = (v + wob) * RINGS
    fr = ph - np.floor(ph)
    # Leaf-scar profile: sharp groove, then a rounded bulge.
    groove = np.exp(-((fr - 0.04) / 0.035) ** 2) + np.exp(-((fr - 1.04) / 0.035) ** 2)
    bulge = np.sin(np.clip(fr - 0.08, 0, 1) / 0.92 * np.pi) ** 0.7
    fib = tile_noise(rng, N, 128)
    fib_v = np.repeat(tile_noise(rng, N, 96)[:, :1], N, 1).T  # vertical fibres
    height = bulge * 0.6 - groove * 0.9 + fib * 0.15 + fib_v * 0.25
    big = tile_noise(rng, N, 6)
    mid = tile_noise(rng, N, 24)

    base = np.array([118, 106, 90], np.float32)
    grey = np.array([150, 146, 138], np.float32)
    dark = np.array([58, 48, 40], np.float32)
    w = np.clip(big * 0.8 + mid * 0.4 - 0.35, 0, 1)[..., None]   # weathered grey patches
    col = base * (1 - w) + grey * w
    col = col * (0.8 + 0.3 * bulge[..., None] + 0.2 * (fib[..., None] - 0.5) + 0.25 * (fib_v[..., None] - 0.5))
    g = np.clip(groove, 0, 1)[..., None]
    col = col * (1 - g * 0.75) + dark * g * 0.75
    alb = Image.fromarray(np.uint8(np.clip(col, 0, 255)), "RGB")
    alb.save(os.path.join(OUT, "palmbark_albedo.jpg"), quality=92)

    # Normal map (OpenGL convention, as the other Poly Haven maps).
    gy, gx = np.gradient(np.pad(height, 1, mode="wrap"))
    gx, gy = gx[1:-1, 1:-1], gy[1:-1, 1:-1]
    s = 6.0
    nx, ny, nz = -gx * s, gy * s, np.ones_like(gx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    Image.fromarray(np.uint8(nrm * 255), "RGB").save(os.path.join(OUT, "palmbark_normal.jpg"), quality=95)
    print("wrote palmbark_albedo.jpg, palmbark_normal.jpg")


if __name__ == "__main__":
    main()

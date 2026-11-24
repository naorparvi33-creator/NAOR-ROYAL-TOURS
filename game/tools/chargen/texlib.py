"""Small numpy helpers for the procedural character textures (no external data)."""
import numpy as np
from PIL import Image, ImageFilter


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761 + 97)
    h = h & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def vnoise3(p, cell, seed=0):
    """Smooth value noise 0..1 over 3D points p (...x3). cell: feature size (scalar or 3-vector)."""
    q = p / np.asarray(cell, np.float32)
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3.0 - 2.0 * f)
    out = np.zeros(p.shape[:-1], np.float32)
    for dx in (0, 1):
        wx = f[..., 0] if dx else 1.0 - f[..., 0]
        for dy in (0, 1):
            wy = f[..., 1] if dy else 1.0 - f[..., 1]
            for dz in (0, 1):
                wz = f[..., 2] if dz else 1.0 - f[..., 2]
                out += wx * wy * wz * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    return out


def fbm3(p, cell, seed=0, octaves=3):
    tot, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        tot = tot + vnoise3(p, cell / (2.0 ** o), seed + o * 17) * amp
        norm += amp
        amp *= 0.5
    return tot / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def blur(a, r):
    if r <= 0:
        return a
    lo, hi = float(a.min()), float(a.max())
    span = max(hi - lo, 1e-6)
    a8 = ((a - lo) / span * 255).astype(np.uint8)
    b = np.asarray(Image.fromarray(a8).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0
    return b * span + lo


def height_to_normal(h, k):
    """Tangent-space (OpenGL, +Y = +V) normal map from an image-space height field."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * k
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * k
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def combine_normals(base, detail_xy):
    """base: HxWx3 unit normals, detail_xy: extra slope (HxWx2) -> unit normals."""
    n = base.copy()
    n[..., 0] += detail_xy[..., 0]
    n[..., 1] += detail_xy[..., 1]
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def bleed(col, cov, steps=4):
    """Grows painted UV islands outward so mipmaps never pick up unrelated texels."""
    col = col.copy()
    cov = cov.copy()
    chans = col.shape[2] if col.ndim == 3 else 1
    c3 = col if col.ndim == 3 else col[..., None]
    for _ in range(steps):
        num = np.stack([np.asarray(Image.fromarray(np.clip(c3[..., c] * cov * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(3)), np.float32) for c in range(chans)], axis=2)
        den = np.asarray(Image.fromarray((cov * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(3)), np.float32)[..., None]
        fill = (cov < 0.5) & (den[..., 0] > 0.5)
        c3[fill] = num[fill] / den[fill]
        cov = np.maximum(cov, fill.astype(np.float32))
    return c3 if col.ndim == 3 else c3[..., 0]

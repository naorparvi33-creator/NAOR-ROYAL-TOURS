#!/usr/bin/env python3
"""Procedural foliage textures (no photos, no third-party assets).

Writes into game/assets/foliage/:
  grass_card.png    512x256  short lawn blades (alpha)
  palm_frond.png    512x128  feather palm frond, rachis along the middle (alpha)
  leaf_cluster.png  512x512  broadleaf twig clusters for tree canopies (alpha)
  flower_card.png   256x256  low flowering shrub card for flower beds (alpha)
  hedge_albedo.png  256x256  seamless dense leaf surface for clipped hedges

Run:  python3 game/tools/foliagegen/make_foliage.py
Transparent pixels get the surrounding leaf colour ("colour bleeding") so mipmaps
and alpha-scissor edges do not show dark or white halos.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "foliage")
SS = 2  # supersampling


def bleed(img: Image.Image) -> Image.Image:
    a = np.asarray(img).astype(np.float32)
    alpha = a[..., 3:4] / 255.0
    rgb = a[..., :3]
    pm = Image.fromarray(np.uint8(np.clip(np.concatenate([rgb * alpha, alpha * 255], -1), 0, 255)), "RGBA")
    blur = np.asarray(pm.filter(ImageFilter.GaussianBlur(12))).astype(np.float32)
    ba = np.maximum(blur[..., 3:4], 1.0) / 255.0
    fill = blur[..., :3] / ba
    mean = (rgb * alpha).sum((0, 1)) / max(float(alpha.sum()), 1.0)
    fill = np.where(blur[..., 3:4] > 2, fill, mean)
    out = np.where(alpha > 0.02, rgb, fill)
    return Image.fromarray(np.uint8(np.clip(np.concatenate([out, a[..., 3:4]], -1), 0, 255)), "RGBA")


def finish(img: Image.Image, size, name: str) -> None:
    img = img.resize(size, Image.LANCZOS)
    img = bleed(img)
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def jitter(c, r, amount=14):
    return tuple(max(0, min(255, int(v + r.uniform(-amount, amount)))) for v in c[:3]) + (255,)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ------------------------------------------------------------------ grass
def grass_card():
    r = random.Random(7)
    W, H = 512 * SS, 256 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base_cols = [(70, 112, 38), (88, 128, 44), (104, 140, 52), (78, 118, 46), (120, 148, 60), (96, 120, 50)]
    for i in range(420):
        x0 = r.uniform(0.04, 0.96) * W
        h = r.uniform(0.35, 0.95) * H
        lean = r.uniform(-0.25, 0.25) * h
        w0 = r.uniform(3.0, 6.5) * SS
        col = r.choice(base_cols)
        if r.random() < 0.12:
            col = (150, 150, 78)  # a dry blade here and there
        segs = 10
        pts_l, pts_r = [], []
        for s in range(segs + 1):
            t = s / segs
            x = x0 + lean * t * t
            y = H - t * h
            w = w0 * (1.0 - t) ** 0.8
            pts_l.append((x - w * 0.5, y))
            pts_r.append((x + w * 0.5, y))
        poly = pts_l + pts_r[::-1]
        dark = lerp(col, (30, 45, 20), 0.55)
        d.polygon(poly, fill=dark + (255,))
        top = pts_l[segs // 3:] + pts_r[segs // 3:][::-1]
        d.polygon(top, fill=jitter(col, r, 10))
        tip = pts_l[2 * segs // 3:] + pts_r[2 * segs // 3:][::-1]
        d.polygon(tip, fill=jitter(lerp(col, (175, 190, 95), 0.35), r, 8))
    finish(img, (512, 256), "grass_card.png")


# ------------------------------------------------------------------ palm frond
def palm_frond():
    r = random.Random(11)
    W, H = 512 * SS, 128 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    mid = H * 0.5
    n = 70
    for i in range(n):
        t = 0.03 + 0.95 * i / n
        x = t * W
        L = (math.sin(min(t * 1.1, 1.0) * math.pi) ** 0.5) * H * 0.62 + 6 * SS
        for side in (-1, 1):
            ang = math.radians(r.uniform(38, 50))
            ex = x + math.cos(ang) * L * 0.9
            ey = mid + side * math.sin(ang) * L * 1.15
            w = r.uniform(5, 8) * SS * (1.0 - t * 0.4)
            g = r.uniform(0.0, 1.0)
            col = lerp((52, 96, 34), (96, 132, 48), g)
            if t > 0.85 or r.random() < 0.06:
                col = lerp(col, (150, 140, 70), 0.45)
            seg = 8
            left, right = [], []
            for s in range(seg + 1):
                u = s / seg
                px = x + (ex - x) * u
                py = mid + (ey - mid) * u + side * math.sin(u * math.pi) * 4 * SS
                ww = w * math.sin(min(u * 1.3, 1.0) * math.pi * 0.5) * (1 - u) ** 0.6 + 0.5
                nx, ny = -(ey - mid), (ex - x)
                nl = math.hypot(nx, ny) or 1
                left.append((px + nx / nl * ww, py + ny / nl * ww))
                right.append((px - nx / nl * ww, py - ny / nl * ww))
            d.polygon(left + right[::-1], fill=jitter(col, r, 8))
            d.line([(x, mid), (ex, ey)], fill=jitter(lerp(col, (170, 180, 100), 0.3), r, 6), width=SS)
    d.line([(0, mid), (W, mid)], fill=(120, 112, 62, 255), width=4 * SS)
    finish(img, (512, 128), "palm_frond.png")


# ------------------------------------------------------------------ broadleaf
def leaf(d, cx, cy, ang, L, Wd, col):
    pts = []
    for s in range(13):
        u = s / 12.0
        w = math.sin(u * math.pi) ** 0.8 * Wd * (1.0 - 0.25 * u)
        pts.append((u * L, w))
    pts += [(p[0], -p[1]) for p in reversed(pts)]
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    d.polygon(poly, fill=col)
    half = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts[:13]]
    shade = tuple(int(c * 0.82) for c in col[:3]) + (255,)
    d.polygon(half + [(cx + L * ca, cy + L * sa)], fill=shade)
    d.line([(cx, cy), (cx + L * ca * 0.9, cy + L * sa * 0.9)],
           fill=tuple(min(255, int(c * 1.15)) for c in col[:3]) + (255,), width=max(1, SS))


def leaf_cluster():
    r = random.Random(23)
    S = 512 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cols = [(58, 92, 34), (72, 108, 40), (86, 122, 46), (64, 100, 44), (98, 130, 52), (52, 84, 36)]
    twigs = []
    for i in range(34):
        a = r.uniform(0, math.tau)
        L = r.uniform(0.22, 0.36) * S
        twigs.append((a, L, S * 0.5 + r.uniform(-30, 30) * SS))
    for layer in range(3):
        for a, L, ox in twigs:
            oy = S * 0.5
            if layer == 0:
                d.line([(ox, oy), (ox + math.cos(a) * L, oy + math.sin(a) * L)], fill=(70, 56, 40, 255), width=3 * SS)
            for k in range(9):
                t = r.uniform(0.25, 1.0)
                px = ox + math.cos(a) * L * t + r.uniform(-18, 18) * SS
                py = oy + math.sin(a) * L * t + r.uniform(-18, 18) * SS
                la = a + r.uniform(-1.3, 1.3)
                ll = r.uniform(26, 44) * SS
                c = r.choice(cols)
                c = lerp(c, (20, 40, 18), 0.35 - layer * 0.17)
                if layer == 2 and r.random() < 0.3:
                    c = lerp(c, (150, 170, 80), 0.3)
                leaf(d, px, py, la, ll, ll * 0.33, jitter(c, r, 8))
    finish(img, (512, 512), "leaf_cluster.png")


# Mixed bedding: red, hot pink, coral, yellow, white, violet.
PETALS = [(170, 40, 50), (190, 80, 130), (210, 120, 90), (220, 190, 70), (225, 222, 210), (130, 90, 170)]


def flower_card():
    r = random.Random(31)
    S = 256 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(140):
        x = r.uniform(0.05, 0.95) * S
        y = r.uniform(0.35, 1.0) * S
        leaf(d, x, y, math.radians(r.uniform(-170, -10)), r.uniform(14, 24) * SS, 6 * SS,
             jitter(lerp((50, 90, 36), (80, 120, 44), r.random()), r, 8))
    for i in range(55):
        x = r.uniform(0.07, 0.93) * S
        y = r.uniform(0.2, 0.75) * S
        rad = r.uniform(4, 7) * SS
        petal = r.choice(PETALS)
        for p in range(5):
            a = p * math.tau / 5 + r.uniform(0, 1)
            px, py = x + math.cos(a) * rad * 0.6, y + math.sin(a) * rad * 0.6
            d.ellipse([px - rad * 0.55, py - rad * 0.55, px + rad * 0.55, py + rad * 0.55], fill=jitter(petal, r, 12))
        d.ellipse([x - rad * 0.25, y - rad * 0.25, x + rad * 0.25, y + rad * 0.25], fill=(235, 200, 60, 255))
    finish(img, (256, 256), "flower_card.png")


def hedge_albedo():
    r = random.Random(41)
    S = 256 * SS
    img = Image.new("RGBA", (S, S), (34, 56, 24, 255))
    d = ImageDraw.Draw(img)
    cols = [(52, 86, 32), (66, 100, 38), (80, 114, 44), (46, 76, 30), (92, 124, 50)]
    for i in range(1400):
        x, y = r.uniform(0, S), r.uniform(0, S)
        c = jitter(r.choice(cols), r, 10)
        L = r.uniform(10, 18) * SS
        a = r.uniform(0, math.tau)
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                if -40 * SS < x + ox < S + 40 * SS and -40 * SS < y + oy < S + 40 * SS:
                    leaf(d, x + ox, y + oy, a, L, L * 0.4, c)
    img = img.resize((256, 256), Image.LANCZOS).convert("RGB")
    img.save(os.path.join(OUT, "hedge_albedo.png"))
    print("wrote hedge_albedo.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    grass_card()
    palm_frond()
    leaf_cluster()
    flower_card()
    hedge_albedo()

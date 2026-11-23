#!/usr/bin/env python3
"""Generates the rooftop billboard atlas (assets/textures/billboards.png).

Eight original, made-up adverts (no real brands), 512 x 128 each, in a 2 x 4 grid.
building.gdshader picks one per billboard from the building seed.
Fonts: Inter (OFL) if installed, else DejaVu; Hebrew: ui/fonts/NotoSansHebrew-Bold.ttf (OFL).
Usage: python3 tools/texgen/make_billboards.py   (from game/)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 512, 128
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME, "assets", "textures", "billboards.png")


def font(size, heavy=True):
    for p in ["/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf" if heavy else "/usr/share/fonts/opentype/inter/Inter-Bold.otf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def heb(size):
    return ImageFont.truetype(os.path.join(GAME, "ui", "fonts", "NotoSansHebrew-Bold.ttf"), size)


def rtl(s):
    # Pillow with libraqm already lays Hebrew out right to left.
    return s


def gradient(c0, c1, horizontal=False):
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            t = x / (W - 1) if horizontal else y / (H - 1)
            px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
    return im


def shadow_text(d, xy, text, f, fill, shadow=(0, 0, 0), anchor="la"):
    d.text((xy[0] + 3, xy[1] + 3), text, font=f, fill=shadow, anchor=anchor)
    d.text(xy, text, font=f, fill=fill, anchor=anchor)


def ad_cola():
    im = gradient((200, 20, 30), (120, 0, 10), True)
    d = ImageDraw.Draw(im)
    for i in range(6):
        d.arc((-60 + i * 12, -200, 380 + i * 12, 260), 300, 360, fill=(255, 255, 255), width=3)
    # Bottle silhouette.
    d.rounded_rectangle((430, 18, 470, 120), 12, fill=(40, 10, 10))
    d.rectangle((442, 4, 458, 24), fill=(40, 10, 10))
    d.rectangle((430, 60, 470, 84), fill=(255, 255, 255))
    shadow_text(d, (24, 18), "FIZZORA", font(64), (255, 255, 255))
    d.text((28, 90), "ICE COLD SINCE 1962", font=font(20, False), fill=(255, 225, 200))
    return im


def ad_radio():
    im = gradient((255, 120, 40), (250, 40, 120), True)
    d = ImageDraw.Draw(im)
    cx, cy = 440, 64
    for r in range(10, 120, 16):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 230, 120), width=4)
    shadow_text(d, (24, 14), "RADIO PALMERA", font(46), (255, 255, 255), (90, 0, 40))
    shadow_text(d, (24, 66), "101.7 FM", font(44), (255, 240, 110), (90, 0, 40))
    return im


def ad_resort():
    im = gradient((40, 150, 220), (250, 200, 120))
    d = ImageDraw.Draw(im)
    d.ellipse((380, 30, 470, 120), fill=(255, 215, 90))
    d.rectangle((0, 100, W, H), fill=(20, 110, 170))
    for x in range(0, W, 24):
        d.arc((x, 92, x + 24, 108), 180, 360, fill=(220, 240, 255), width=2)
    # Palm.
    d.line((330, 128, 345, 40), fill=(60, 40, 20), width=7)
    for a in range(0, 360, 45):
        ex = 345 + math.cos(math.radians(a)) * 46  # frond tip
        ey = 40 + math.sin(math.radians(a)) * 22
        d.line((345, 40, ex, ey), fill=(20, 90, 40), width=9)
    shadow_text(d, (22, 12), "MARISOL BAY", font(48), (255, 255, 255), (10, 60, 110))
    d.text((24, 68), "RESORT & SPA", font=font(24, False), fill=(255, 250, 230))
    return im


def ad_motors():
    im = gradient((15, 15, 20), (55, 60, 70), True)
    d = ImageDraw.Draw(im)
    # Stylised car profile.
    d.polygon([(250, 96), (270, 66), (330, 50), (400, 50), (450, 70), (495, 76), (500, 96)], fill=(210, 30, 30))
    d.polygon([(300, 64), (335, 54), (395, 54), (425, 68)], fill=(120, 170, 210))
    for x in (295, 455):
        d.ellipse((x - 18, 80, x + 18, 116), fill=(10, 10, 10))
        d.ellipse((x - 8, 90, x + 8, 106), fill=(170, 170, 170))
    d.line((0, 116, W, 116), fill=(200, 200, 200), width=2)
    shadow_text(d, (22, 14), "VELARO", font(56), (255, 255, 255))
    d.text((24, 78), "DRIVE THE COAST", font=font(20, False), fill=(230, 60, 60))
    return im


def ad_water():
    im = gradient((230, 248, 255), (120, 200, 240))
    d = ImageDraw.Draw(im)
    random.seed(4)
    for _ in range(40):
        x, y, r = random.randint(300, 510), random.randint(0, 128), random.randint(2, 9)
        d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255), width=2)
    d.rounded_rectangle((420, 14, 462, 122), 14, fill=(60, 150, 220))
    d.rectangle((432, 4, 450, 16), fill=(20, 60, 140))
    shadow_text(d, (22, 16), "BLUE TIDE", font(56), (20, 70, 150), (255, 255, 255))
    d.text((24, 82), "PURE SPRING WATER", font=font(20, False), fill=(20, 90, 160))
    return im


def ad_burger():
    im = gradient((255, 200, 40), (255, 150, 20))
    d = ImageDraw.Draw(im)
    cx = 430
    d.pieslice((cx - 56, 20, cx + 56, 90), 180, 360, fill=(200, 120, 40))
    d.rectangle((cx - 58, 56, cx + 58, 66), fill=(60, 160, 40))
    d.rectangle((cx - 56, 66, cx + 56, 82), fill=(110, 50, 25))
    d.rounded_rectangle((cx - 56, 82, cx + 56, 102), 8, fill=(210, 130, 50))
    shadow_text(d, (22, 12), "NOVA", font(60), (180, 20, 20), (255, 255, 255))
    shadow_text(d, (196, 12), "BURGER", font(60), (40, 20, 10), (255, 240, 200))
    d.text((24, 86), "OPEN 24/7  ·  DRIVE-THRU", font=font(20, False), fill=(90, 30, 10))
    return im


def ad_hebrew_bank():
    im = gradient((10, 40, 90), (20, 90, 150), True)
    d = ImageDraw.Draw(im)
    for i in range(5):
        d.line((380 + i * 26, 128, 470 + i * 26, 0), fill=(240, 190, 60), width=6)
    d.text((340, 20), rtl("בנק החוף"), font=heb(54), fill=(255, 255, 255), anchor="ra")
    d.text((340, 84), rtl("משכנתא בקליק"), font=heb(28), fill=(240, 200, 80), anchor="ra")
    return im


def ad_hebrew_phone():
    im = gradient((30, 10, 60), (120, 20, 140), True)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((40, 10, 104, 120), 12, fill=(20, 20, 24), outline=(200, 200, 220), width=3)
    d.rectangle((48, 22, 96, 104), fill=(60, 200, 230))
    d.text((480, 14), rtl("כוכב"), font=heb(56), fill=(255, 255, 255), anchor="ra")
    d.text((300, 26), "5G", font=font(48), fill=(255, 180, 255), anchor="ra")
    d.text((480, 82), rtl("הרשת הכי מהירה בעיר"), font=heb(26), fill=(255, 180, 255), anchor="ra")
    return im


def main():
    ads = [ad_cola, ad_radio, ad_resort, ad_motors, ad_water, ad_burger, ad_hebrew_bank, ad_hebrew_phone]
    atlas = Image.new("RGB", (W * 2, H * 4))
    for i, fn in enumerate(ads):
        im = fn()
        # A touch of print texture and sun fade so they do not look like UI.
        im = im.filter(ImageFilter.GaussianBlur(0.6))
        atlas.paste(im, ((i % 2) * W, (i // 2) * H))
    atlas.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()

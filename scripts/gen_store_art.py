#!/usr/bin/env python3
"""Draws the Wingy icon, feature graphic and launcher icons with Pillow (original art).

Run: python3 -m venv /tmp/v && /tmp/v/bin/pip install pillow && /tmp/v/bin/python scripts/gen_store_art.py
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SS = 2  # supersampling


def sky(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / h
        c = (int(20 + 80 * t), int(14 + 20 * t), int(70 + 90 * t))
        for x in range(w):
            px[x, y] = c
    return img.convert("RGBA")


def stars(img, n, seed):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(n):
        x, y, r = rnd.randrange(w), rnd.randrange(int(h * 0.8)), rnd.choice((1, 1, 2, 3)) * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=(235, 230, 255, rnd.randrange(110, 230)))


def glow(img, cx, cy, r, col):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(r / 2)))


def spire(img, x, top, bottom, w, flip):
    """Translucent crystal column from top..bottom (y), tip pointing toward the gap."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if not flip:  # hangs from the top, tip points down
        base, end, tip = top, bottom - w * 0.7, bottom
    else:  # rises from the bottom, tip points up
        base, end, tip = bottom, top + w * 0.7, top
    d.polygon([(x, base), (x + w, base), (x + w, end), (x + w / 2, tip), (x, end)], fill=(70, 200, 235, 150))
    d.polygon([(x + w / 2, base), (x + w, base), (x + w, end), (x + w / 2, tip)], fill=(220, 90, 220, 120))
    y0, y1 = min(base, end), max(base, end)
    d.line([(x + w * 0.22, y0), (x + w * 0.22, y1)], fill=(255, 255, 255, 170), width=max(2, int(w / 14)))
    return Image.alpha_composite(img, layer)


def moth(img, cx, cy, s):
    img = glow(img, cx, cy + s * 0.25, s * 1.3, (255, 200, 90, 120))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # wings
    for sgn in (-1, 1):
        d.ellipse([cx + (0 if sgn > 0 else -s * 1.05), cy - s * 0.95,
                   cx + (s * 1.05 if sgn > 0 else 0), cy + s * 0.15], fill=(255, 190, 235, 215))
        d.ellipse([cx + (s * 0.05 if sgn > 0 else -s * 0.8), cy - s * 0.55,
                   cx + (s * 0.8 if sgn > 0 else -s * 0.05), cy + s * 0.55], fill=(190, 150, 255, 225))
    # body + glowing abdomen
    d.ellipse([cx - s * 0.2, cy - s * 0.3, cx + s * 0.2, cy + s * 0.4], fill=(120, 80, 70, 255))
    d.ellipse([cx - s * 0.22, cy + s * 0.15, cx + s * 0.22, cy + s * 0.65], fill=(255, 225, 120, 255))
    # eyes and antennae
    for sgn in (-1, 1):
        d.line([(cx + sgn * s * 0.08, cy - s * 0.28), (cx + sgn * s * 0.4, cy - s * 0.7)],
               fill=(250, 235, 255, 255), width=max(2, int(s / 20)))
    d.ellipse([cx - s * 0.17, cy - s * 0.12, cx - s * 0.04, cy + s * 0.01], fill=(30, 20, 60, 255))
    d.ellipse([cx + s * 0.04, cy - s * 0.12, cx + s * 0.17, cy + s * 0.01], fill=(30, 20, 60, 255))
    return Image.alpha_composite(img, layer)


def scene(w, h, hero_x, hero_y, hero_s, spires, seed):
    W, H = w * SS, h * SS
    img = sky(W, H)
    stars(img, int(w * h / 2500), seed)
    for x, gap_top, gap_bot, sw in spires:
        x, gap_top, gap_bot, sw = x * SS, gap_top * SS, gap_bot * SS, sw * SS
        img = spire(img, x, -sw, gap_top, sw, False)
        img = spire(img, x, gap_bot, H + sw, sw, True)
    img = moth(img, hero_x * SS, hero_y * SS, hero_s * SS)
    return img.resize((w, h), Image.LANCZOS)


FONT = {
    "W": ["10001", "10001", "10101", "10101", "01010"], "I": ["111", "010", "010", "010", "111"],
    "N": ["10001", "11001", "10101", "10011", "10001"], "G": ["01110", "10000", "10111", "10001", "01110"],
    "Y": ["10001", "01010", "00100", "00100", "00100"],
}


def title(img, x0, y0, s):
    d = ImageDraw.Draw(img)
    x = x0
    for ch in "WINGY":
        g = FONT[ch]
        for r, row in enumerate(g):
            for c, v in enumerate(row):
                if v == "1":
                    px, py = x + c * s, y0 + r * s
                    d.rounded_rectangle([px + 3, py + 3, px + s + 3, py + s + 3], s // 5, fill=(10, 5, 40, 120))
                    d.rounded_rectangle([px, py, px + s - 2, py + s - 2], s // 5, fill=(110, 225, 245, 255))
                    d.rounded_rectangle([px + s // 6, py + s // 6, px + s - 2 - s // 6, py + s // 2.5],
                                        s // 6, fill=(225, 250, 255, 255))
        x += (len(g[0]) + 1) * s
    return img


def main():
    out = os.path.join(ROOT, "store", "google-play", "graphics")
    os.makedirs(out, exist_ok=True)
    icon = scene(512, 512, 256, 270, 150,
                 [(40, 60, 250, 90), (390, 200, 450, 90)], 1).convert("RGB")
    icon.save(os.path.join(out, "icon-512.png"))
    fg = scene(1024, 500, 250, 250, 120,
               [(-30, 60, 200, 80), (-30, 340, 440, 80), (880, 150, 350, 90)], 2)
    fg = title(fg, 390, 190, 16).convert("RGB")
    fg.save(os.path.join(out, "feature-graphic-1024x500.png"))
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for name, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(res, f"mipmap-{name}", "ic_launcher.png"))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generates Wingy's icon, feature graphic, screenshots and launcher icons in code.
All art is original and drawn procedurally (Pillow). Run: python3 scripts/gen_store_art.py"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "store", "google-play")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")


def gradient(w, h, top, bot):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return img.convert("RGBA")


def glow(img, xy, r, color, strength=1.0):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([xy[0] - r, xy[1] - r, xy[0] + r, xy[1] + r], fill=color + (int(200 * strength),))
    layer = layer.filter(ImageFilter.GaussianBlur(r * 0.6))
    img.alpha_composite(layer)


def stars(img, n, seed):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(n):
        x, y = rnd.random() * w, rnd.random() * h * 0.8
        r = rnd.choice([1, 1, 2]) * w / 1000 + 0.6
        d.ellipse([x - r, y - r, x + r, y + r], fill=(230, 225, 255, rnd.randint(120, 255)))


def moth(img, cx, cy, s, tilt=0):
    """Round-bodied moth with two soft wings and a glowing abdomen. s = body radius."""
    glow(img, (cx, cy), s * 2.6, (255, 210, 120), 0.9)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - s * 2.2, cy - s * 2.1, cx + s * 0.2, cy + s * 0.2], fill=(190, 150, 255, 170))
    d.ellipse([cx - s * 1.9, cy - s * 0.3, cx + s * 0.1, cy + s * 1.5], fill=(150, 110, 235, 150))
    d.ellipse([cx - s * 1.0, cy - s * 2.6, cx + s * 1.0, cy - s * 0.2], fill=(215, 185, 255, 190))
    layer = layer.filter(ImageFilter.GaussianBlur(s * 0.05))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - s, cy - s * 0.9, cx + s, cy + s * 1.1], fill=(70, 50, 120, 255))
    d.ellipse([cx - s * 0.55, cy + s * 0.15, cx + s * 0.55, cy + s * 1.0], fill=(255, 220, 130, 255))
    d.ellipse([cx + s * 0.15, cy - s * 0.55, cx + s * 0.6, cy - s * 0.1], fill=(255, 255, 255, 255))
    d.ellipse([cx + s * 0.32, cy - s * 0.42, cx + s * 0.52, cy - s * 0.2], fill=(30, 20, 60, 255))
    d.line([cx + s * 0.4, cy - s * 0.9, cx + s * 1.0, cy - s * 1.6], fill=(220, 200, 255, 255), width=max(2, int(s * 0.08)))
    if tilt:
        layer = layer.rotate(tilt, center=(cx, cy), resample=Image.BICUBIC)
    img.alpha_composite(layer)


def spire(img, x, w, y0, y1, tip_at_end):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([x, y0, x + w, y1], fill=(90, 200, 230, 120))
    d.rectangle([x + w * 0.55, y0, x + w, y1], fill=(220, 90, 200, 110))
    d.rectangle([x + w * 0.12, y0, x + w * 0.24, y1], fill=(255, 255, 255, 110))
    tip = y1 if tip_at_end else y0
    d.rectangle([x - w * 0.06, tip - w * 0.1, x + w * 1.06, tip + w * 0.1], fill=(255, 170, 240, 230))
    img.alpha_composite(layer)
    glow(img, (x + w / 2, tip), w * 0.5, (255, 140, 230), 0.5)


SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
       "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


def digits(img, text, cx, cy, hgt):
    d = ImageDraw.Draw(img)
    w = hgt * 0.55
    gap = hgt * 0.3
    t = max(3, int(hgt * 0.14))
    x = cx - (len(text) * w + (len(text) - 1) * gap) / 2
    for ch in text:
        y0, y1, ym = cy - hgt / 2, cy + hgt / 2, cy
        L = {"a": [(x, y0), (x + w, y0)], "b": [(x + w, y0), (x + w, ym)], "c": [(x + w, ym), (x + w, y1)],
             "d": [(x, y1), (x + w, y1)], "e": [(x, ym), (x, y1)], "f": [(x, y0), (x, ym)], "g": [(x, ym), (x + w, ym)]}
        for s in SEG[ch]:
            d.line(L[s], fill=(255, 245, 255, 255), width=t)
        x += w + gap


def scene(w, h, moth_pos, spires, seed, orbs=(), score=None):
    img = gradient(w, h, (22, 12, 60), (96, 48, 140))
    stars(img, int(w * h / 9000), seed)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed + 1)
    pts = [(0, h)]
    for i in range(13):
        pts.append((w * i / 12, h * (0.68 + 0.08 * math.sin(i * 1.3) + rnd.random() * 0.04)))
    pts.append((w, h))
    d.polygon(pts, fill=(60, 30, 105, 255))
    gy = h * 0.91
    for sx, gt, gb in spires:
        spire(img, sx, w * 0.16, 0, gt, True)
        spire(img, sx, w * 0.16, gb, gy, False)
    d = ImageDraw.Draw(img)
    d.rectangle([0, gy, w, h], fill=(26, 18, 40, 255))
    for i in range(9):
        glow(img, (w * (0.05 + i * 0.115), gy + 6), w * 0.012, (120, 255, 200), 0.8)
    for ox, oy in orbs:
        glow(img, (ox, oy), w * 0.03, (255, 240, 150), 1.0)
    moth(img, moth_pos[0], moth_pos[1], w * 0.045, tilt=8)
    if score is not None:
        pw, ph = w * 0.22, h * 0.06
        pill = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(pill).rounded_rectangle(
            [w / 2 - pw / 2, h * 0.06, w / 2 + pw / 2, h * 0.06 + ph], radius=ph / 2,
            fill=(255, 255, 255, 40), outline=(255, 220, 250, 200), width=3)
        img.alpha_composite(pill)
        digits(img, str(score), w / 2, h * 0.06 + ph / 2, ph * 0.62)
    return img


LETTERS = {
    "W": [[(0, 0), (.25, 1), (.5, .4), (.75, 1), (1, 0)]],
    "I": [[(.5, 0), (.5, 1)]],
    "N": [[(0, 1), (0, 0), (1, 1), (1, 0)]],
    "G": [[(1, .15), (.6, 0), (.15, .1), (0, .5), (.15, .9), (.6, 1), (1, .85), (1, .55), (.55, .55)]],
    "Y": [[(0, 0), (.5, .5), (1, 0)], [(.5, .5), (.5, 1)]],
}


def title(img, cx, cy, h):
    t = max(4, int(h * 0.16))
    w = h * 0.7
    gap = h * 0.22
    word = "WINGY"
    x0 = cx - (len(word) * w + (len(word) - 1) * gap) / 2

    def strokes(draw, width, fill):
        x = x0
        for ch in word:
            for st in LETTERS[ch]:
                draw.line([(x + px * w, cy - h / 2 + py * h) for px, py in st], fill=fill, width=width, joint="curve")
            x += w + gap

    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    strokes(ImageDraw.Draw(g), t * 2, (255, 150, 235, 255))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(h * 0.12)))
    strokes(ImageDraw.Draw(img), t, (255, 245, 255, 255))


def icon(size):
    S = size * 2
    img = gradient(S, S, (30, 14, 80), (120, 52, 150))
    stars(img, 30, 5)
    moth(img, S * 0.5, S * 0.52, S * 0.17)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    icon(512).save(os.path.join(OUT, "icon-512.png"))
    for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        d = os.path.join(RES, "mipmap-" + dpi)
        if os.path.isdir(d):
            icon(px).convert("RGB").save(os.path.join(d, "ic_launcher.png"))
    W, H = 2048, 1000
    fg = scene(W, H, (W * 0.74, H * 0.45), [(W * 0.52, H * 0.22, H * 0.55), (W * 0.9, H * 0.15, H * 0.5)], 11,
               orbs=[(W * 0.6, H * 0.4)])
    title(fg, W * 0.27, H * 0.42, H * 0.22)
    ImageDraw.Draw(fg).line([(W * 0.09, H * 0.62), (W * 0.45, H * 0.62)], fill=(255, 170, 240, 200), width=6)
    fg.resize((1024, 500), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "feature-graphic-1024x500.png"))
    SW, SH = 1080, 1920
    shots = [
        ((SW * 0.28, SH * 0.45), [(SW * 0.55, SH * 0.2, SH * 0.5)], [(SW * 0.62, SH * 0.35)], 7, 3),
        ((SW * 0.28, SH * 0.55), [(SW * 0.5, SH * 0.35, SH * 0.68), (SW * 1.0, SH * 0.2, SH * 0.5)], [(SW * 0.6, SH * 0.52)], 23, 12),
        ((SW * 0.28, SH * 0.38), [(SW * 0.45, SH * 0.12, SH * 0.42), (SW * 0.95, SH * 0.3, SH * 0.6)], [], 42, 27),
        ((SW * 0.28, SH * 0.6), [(SW * 0.6, SH * 0.45, SH * 0.77)], [(SW * 0.68, SH * 0.6), (SW * 0.9, SH * 0.3)], 77, 51),
    ]
    for i, (m, sp, orbs, seed, sc) in enumerate(shots, 1):
        scene(SW, SH, m, sp, seed, orbs=orbs, score=sc).convert("RGB").save(os.path.join(OUT, f"screenshot-{i}.png"))


if __name__ == "__main__":
    main()
